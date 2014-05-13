#import "OpenGLMovieLayer.h"
#import <OpenGL/gl.h>
#import <CoreVideo/CVPixelBuffer.h>

@implementation OpenGLMovieLayer

@synthesize movie;
@synthesize output;

const int EYE_LEFT = 1;
const int EYE_RIGHT = -1;

- (id)initWithMovie:(AVPlayer*)m;
{
    self = [super init];
    if( !self )
        return nil;

    [self setAsynchronous:YES];
    [self setContentsGravity:kCAGravityResizeAspect];
    CGColorRef black = CGColorCreateGenericRGB(0, 0, 0, 1);
    [self setBackgroundColor:black];
    CFRelease(black);
    
    [self setMovie:m];

    [self initHMDInfo];

    return self;
}

- (void)initHMDInfo
{
    // DK1 defaults, in case there's no device attached
    hmdInfo.HResolution = 1280;
    hmdInfo.VResolution = 800;
    hmdInfo.HScreenSize = 0.149759993f;
    hmdInfo.VScreenSize = 0.0935999975f;
    hmdInfo.VScreenCenter = 0.0467999987f;
    hmdInfo.EyeToScreenDistance    = 0.0410000011f;
    hmdInfo.LensSeparationDistance = 0.0635000020f;
    hmdInfo.InterpupillaryDistance = 0.0640000030f;
    hmdInfo.DistortionK[0] = 1.00000000f;
    hmdInfo.DistortionK[1] = 0.219999999f;
    hmdInfo.DistortionK[2] = 0.239999995f;
    hmdInfo.DistortionK[3] = 0.000000000f;
    hmdInfo.ChromaAbCorrection[0] = 0.995999992f;
    hmdInfo.ChromaAbCorrection[1] = -0.00400000019f;
    hmdInfo.ChromaAbCorrection[2] = 1.01400006f;
    hmdInfo.ChromaAbCorrection[3] = 0.000000000f;
    hmdInfo.DesktopX = 0;
    hmdInfo.DesktopY = 0;

    stereoConfig.SetHMDInfo(hmdInfo);
}

- (BOOL)canDrawInCGLContext:(CGLContextObj)glContext
                pixelFormat:(CGLPixelFormatObj)pixelFormat
               forLayerTime:(CFTimeInterval)timeInterval
                displayTime:(const CVTimeStamp *)timeStamp
{ 
    // There is no point in trying to draw anything if our
    // movie is not playing.
    if( [movie rate] <= 0.0 )
        return NO;

    if (!output) {
        [self setupVisualContext:glContext withPixelFormat:pixelFormat];
    }

    if (!prog) {
        // Create ID for shaders
        const GLchar* vertexShaderSource = [OpenGLMovieLayer getShaderString:[[NSBundle mainBundle] URLForResource:@"vertexShader" withExtension:@"glsl"]];
        vertexShader = [self compileShader:GL_VERTEX_SHADER withSource:(const GLchar *const *)&vertexShaderSource];

        const GLchar* fragmentShaderSource = [OpenGLMovieLayer getShaderString:[[NSBundle mainBundle] URLForResource:@"fragmentShader" withExtension:@"glsl"]];
        fragmentShader = [self compileShader:GL_FRAGMENT_SHADER withSource:(const GLchar *const *)&fragmentShaderSource];

        prog = glCreateProgram();
        [self reportError:@"after glCreateProgram"];

        // Associate shaders with program
        glAttachShader(prog, vertexShader);
        [self reportError:@"after glAttachShader vertex shader"];
        glAttachShader(prog, fragmentShader);
        [self reportError:@"after glAttachShader fragment shader"];

        // Link program
        glLinkProgram(prog);
        [self reportError:@"after glLinkProgram"];

        // Check the status of the compile/link
        GLint linked;
        glGetProgramiv(prog, GL_LINK_STATUS, &linked);
        if (linked == GL_FALSE) {
            GLsizei len;
            GLchar log[400];
            glGetProgramInfoLog(prog, 400, & len, log);
            glDeleteProgram(prog);
        }

        textureLoc = glGetUniformLocation(prog, "texture");
        lensCenterLoc = glGetUniformLocation(prog, "LensCenter");
        screenCenterLoc = glGetUniformLocation(prog, "ScreenCenter");
        scaleLoc = glGetUniformLocation(prog, "Scale");
        scaleInLoc = glGetUniformLocation(prog, "ScaleIn");
        hmdWarpParamLoc = glGetUniformLocation(prog, "HmdWarpParam");
    }

    if (!textureCache) {
        CVOpenGLTextureCacheCreate(kCFAllocatorDefault, NULL, glContext, pixelFormat, NULL, &textureCache);
    }

    // Check to see if a new frame (image) is ready to be draw at
    // the time specified.
    if (timeStamp) {
        CMTime time = [output itemTimeForCVTimeStamp:*timeStamp];
        if ([output hasNewPixelBufferForItemTime:time])
        {
            // Release the previous frame
            CVOpenGLTextureRelease(currentFrame);

            // Copy the current frame into our image buffer
            CVPixelBufferRef frame = [output copyPixelBufferForItemTime:time itemTimeForDisplay:nil];

            CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, frame, NULL, &currentFrame);

            // Returns the texture coordinates for the
            // part of the image that should be displayed
            GLfloat lowerLeft[2];
            GLfloat lowerRight[2];
            GLfloat upperRight[2];
            GLfloat upperLeft[2];
            CVOpenGLTextureGetCleanTexCoords(currentFrame,
                                             lowerLeft,
                                             lowerRight,
                                             upperRight,
                                             upperLeft);
            
            frameBounds = CGRectMake(upperLeft[0],
                                     upperLeft[1],
                                     lowerRight[0] - upperLeft[0],
                                     lowerRight[1] - upperLeft[1]);
            leftEyeFrameBounds = CGRectMake(frameBounds.origin.x,
                                            frameBounds.origin.y,
                                            frameBounds.size.width/2,
                                            frameBounds.size.height);
            rightEyeFrameBounds = CGRectOffset(leftEyeFrameBounds,
                                               leftEyeFrameBounds.size.width,
                                               0);

            return YES;
        }
    }
    
    return NO;
}

- (void)setupVisualContext:(CGLContextObj)glContext
           withPixelFormat:(CGLPixelFormatObj)pixelFormat;
{
    // Create the output
    output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB)}];

    [output setSuppressesPlayerRendering:TRUE];

    [[[self movie] currentItem] addOutput:output];
}

- (GLuint)compileShader:(GLenum)type withSource:(const GLchar *const *)shaderSrc
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, shaderSrc, NULL);
    glCompileShader(shader);

    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);

    if (compiled == GL_FALSE) {
        GLsizei len;
        GLchar log[400];
        glGetShaderInfoLog(shader, 400, & len, log);
        glDeleteShader(shader);
    }

    return shader;
}

- (void)drawInCGLContext:(CGLContextObj)glContext 
             pixelFormat:(CGLPixelFormatObj)pixelFormat 
            forLayerTime:(CFTimeInterval)interval 
             displayTime:(const CVTimeStamp *)timeStamp
{
    // Self coordinates of the view
    CGRect viewBounds = [self bounds];
    CGRect leftEyeViewBounds = CGRectMake(viewBounds.origin.x,
                                          viewBounds.origin.y,
                                          viewBounds.size.width/2,
                                          viewBounds.size.height);
    CGRect rightEyeViewBounds = CGRectOffset(leftEyeViewBounds,
                                            leftEyeViewBounds.size.width,
                                            0);

    // Clear the buffer
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    GLenum textureTarget = CVOpenGLTextureGetTarget(currentFrame);
    GLenum textureName = CVOpenGLTextureGetName(currentFrame);

    // Enable target for the current frame
    glEnable(textureTarget);

    // Set the current texture as the active one
    glActiveTexture(textureTarget);

    // Bind to the current frame texture
    // This tells OpenGL which texture we are wanting
    // to draw so that when we make our glTexCord and
    // glVertex calls, our current frame gets drawn
    // to the context.
    glBindTexture(textureTarget, textureName);

    // Set the texture matrix
    glMatrixMode(GL_TEXTURE);
    glLoadIdentity();

    // Set the model view matrix
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    // Set the projection view matrix
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();

    glOrtho(viewBounds.origin.x,
            viewBounds.origin.x + viewBounds.size.width,
            viewBounds.origin.y,
            viewBounds.origin.y + viewBounds.size.height,
            0, 1.0);

    // TODO: Fix the texture loading
    // Currently this renders with a fragment shader
    // that uses the texture coordinates as red and green
    // components of the fragment color.
    // This proves that the shader receives the correct
    // texture coordinates and the problem is with the
    // texture sampler we are trying to use

    // Configure the shader
    glUseProgram(prog);
    [self reportError:@"after use program"];

    // Load the texture index in the sampler
	glUniform1i(textureLoc, textureTarget-GL_TEXTURE0);

    // Render left eye
    [self renderEyeInViewBounds:leftEyeViewBounds
          withTextureBounds:leftEyeFrameBounds
          forEye:EYE_LEFT];

    // Render right eye
    [self renderEyeInViewBounds:rightEyeViewBounds
          withTextureBounds:rightEyeFrameBounds
          forEye:EYE_RIGHT];

    glUseProgram(0);
    [self reportError:@"after glUseProgram"];

    // This CAOpenGLLayer is responsible to flush
    // the OpenGL context so we call super
    [super drawInCGLContext:glContext 
           pixelFormat:pixelFormat
           forLayerTime:interval
           displayTime:timeStamp];
}

- (void)renderEyeInViewBounds:(struct CGRect)viewBounds
        withTextureBounds:(struct CGRect)textureBounds
        forEye:(int)eye
{
    // Get the HMD distortion configuration
    const DistortionConfig & distortion = stereoConfig.GetDistortionConfig();

    // The shader is applied in [0,1] coordinates
    float w = float(viewBounds.size.width) / float(textureBounds.size.width*2);
    float h = float(viewBounds.size.height) / float(textureBounds.size.height);
    float x = float(textureBounds.origin.x) / float(textureBounds.size.width*2);
    float y = float(textureBounds.origin.y) / float(textureBounds.size.height);

    float aspect = stereoConfig.GetAspect();
    float scaleFactor = 1.0f / stereoConfig.GetDistortionScale();
    float eyeOffset = eye * distortion.XCenterOffset;

    // Eye center
    glUniform2f(lensCenterLoc,
                x + (w + eyeOffset * 0.5f) * 0.5f,
                y + h * 0.5f);

    // Screen center
    glUniform2f(screenCenterLoc,
                x + w * 0.5f,
                y + h * 0.5f);

    // Scale out the distorted sample
    glUniform2f(scaleLoc,
                (w / 2.0f) * scaleFactor,
                (h / 2) * scaleFactor * aspect);

    // Scale in the texture coordinates to [-1,1] in order
    // to do the distortion properly
    glUniform2f(scaleInLoc,
                2.0f / w,
                (2.0f / h) / aspect);

    // Static array of distortion coefficients for the barrel transform function
    glUniform4fv(hmdWarpParamLoc, 1, distortion.K);

    // Render the eye quads
    glBegin(GL_QUADS);

    // Upper left texture
    glTexCoord2f(textureBounds.origin.x,
                 textureBounds.origin.y);
    // Lower left viewport
    glVertex2f  (viewBounds.origin.x,
                 viewBounds.origin.y + viewBounds.size.height);

    // Upper right texture
    glTexCoord2f(textureBounds.origin.x + textureBounds.size.width,
                 textureBounds.origin.y);
    // Lower right viewport
    glVertex2f  (viewBounds.origin.x + viewBounds.size.width,
                 viewBounds.origin.y + viewBounds.size.height);

    // Lower right texture
    glTexCoord2f(textureBounds.origin.x + textureBounds.size.width,
                 textureBounds.origin.y + textureBounds.size.height);
    // Upper right viewport
    glVertex2f  (viewBounds.origin.x + viewBounds.size.width,
                 viewBounds.origin.y);

    // Lower left texture
    glTexCoord2f(textureBounds.origin.x,
                 textureBounds.origin.y + textureBounds.size.height);
    // Upper left viewport
    glVertex2f  (viewBounds.origin.x,
                 viewBounds.origin.y);

    glEnd();
    [self reportError:@"after glEnd"];
}

- (void)reportError:(NSString*)message
{
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        switch (error) {
            case GL_INVALID_ENUM:
                NSLog ( @"GL error occurred: %u GL_INVALID_ENUM, %@",  error , message);
                break;
            case GL_INVALID_VALUE:
                NSLog ( @"GL error occurred: %u GL_INVALID_VALUE, %@",  error , message );
                break;
            case GL_INVALID_OPERATION:
                NSLog ( @"GL error occurred: %u GL_INVALID_OPERATION, %@",  error , message );
                break;
            case GL_INVALID_FRAMEBUFFER_OPERATION:
                NSLog ( @"GL error occurred: %u GL_INVALID_FRAMEBUFFER_OPERATION, %@",  error , message );
                break;
            case GL_OUT_OF_MEMORY:
                NSLog ( @"GL error occurred: %u GL_OUT_OF_MEMORY, %@",  error , message );
                break;
            default:
                NSLog ( @"GL error occurred: %u UNKNOWN, %@",  error , message );
                break;
        }
    }
}

- (CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pixelFormat;
{
    CVOpenGLTextureRelease(currentFrame);
    CVOpenGLTextureCacheRelease(textureCache);
    [[[self movie] currentItem] removeOutput:output];
    output = NULL;

    glDeleteProgram(prog);
    glDeleteShader(fragmentShader);
    glDeleteShader(vertexShader);

    CGLContextObj context = [super copyCGLContextForPixelFormat:pixelFormat];

	return context;
}

- (void) dealloc
{
	CVOpenGLTextureRelease(currentFrame);
    [[[self movie] currentItem] removeOutput:output];
    output = NULL;
}

+ (GLchar*)getShaderString:(NSURL*)fromURL {
  NSLog(@"loading from %@", [fromURL absoluteURL]);
  NSString* str = [NSString stringWithContentsOfURL:[fromURL absoluteURL] encoding:NSASCIIStringEncoding error:nil];
  NSLog(@"%@",str);
  return (GLchar*)[str UTF8String];
}

@end
