#import "OpenGLMovieLayer.h"
#import <CoreVideo/CVPixelBuffer.h>
#import <CoreVideo/CVOpenGLTextureCache.h>
#import <OpenGL/gl3.h>

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
    [self setNeedsDisplayOnBoundsChange:YES];
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

    Ptr<DeviceManager> pManager;
    Ptr<HMDDevice>     pHMD;
    pManager = *DeviceManager::Create();
    pHMD = *pManager->EnumerateDevices<HMDDevice>().CreateDevice();
    if (pHMD != NULL) {
        pHMD->GetDeviceInfo(&hmdInfo);
    }

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

        const GLchar* fragmentShaderSource = [OpenGLMovieLayer getShaderString:[[NSBundle mainBundle] URLForResource:@"fragmentShaderRift" withExtension:@"glsl"]];
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
            glDeleteShader(vertexShader);
            glDeleteShader(fragmentShader);
        }

        [self setupVbo];

        textureLoc = glGetUniformLocation(prog, "texture");
        [self reportError:@"after glGetUniformLocation(texture)"];
        lensCenterLoc = glGetUniformLocation(prog, "LensCenter");
        [self reportError:@"after glGetUniformLocation(LensCenter)"];
        screenCenterLoc = glGetUniformLocation(prog, "ScreenCenter");
        [self reportError:@"after glGetUniformLocation(ScreenCenter)"];
        scaleLoc = glGetUniformLocation(prog, "Scale");
        [self reportError:@"after glGetUniformLocation(Scale)"];
        scaleInLoc = glGetUniformLocation(prog, "ScaleIn");
        [self reportError:@"after glGetUniformLocation(ScaleIn)"];
        hmdWarpParamLoc = glGetUniformLocation(prog, "HmdWarpParam");

        NSLog(@"OpenGL Version: %s", glGetString(GL_VERSION));
        NSLog(@"OpenGL Shader Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
        [self reportError:@"after glGetUniformLocation(HmdWarpParam)"];
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

- (void) setupVbo
{
    // Setup the vertex array
    glGenVertexArrays(1, &vertexArray);
    [self reportError:@"after glGenVertexArrays"];
    glBindVertexArray(vertexArray);
    [self reportError:@"after glBindVertexArray"];

    // Setup the vertex buffer
    GLfloat vertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        1.0f,  1.0f,
        -1.0f,  1.0f
    };
    glGenBuffers(1, &vertexBuffer);
    [self reportError:@"after glGenBuffers"];
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    [self reportError:@"after glBindBuffer"];
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    [self reportError:@"after glBufferData"];
    
    // Setup the left eye vertex array
    glGenVertexArrays(1, &vertexArrayLeft);
    [self reportError:@"after glGenVertexArrays"];
    glBindVertexArray(vertexArrayLeft);
    [self reportError:@"after glBindVertexArray"];

    // Setup the vertex buffer
    GLfloat verticesLeft[] = {
        -1.0f, -1.0f,
        0.0f, -1.0f,
        0.0f,  1.0f,
        -1.0f,  1.0f
    };
    glGenBuffers(1, &vertexBufferLeft);
    [self reportError:@"after glGenBuffers"];
    glBindBuffer(GL_ARRAY_BUFFER, vertexBufferLeft);
    [self reportError:@"after glBindBuffer"];
    glBufferData(GL_ARRAY_BUFFER, sizeof(verticesLeft), verticesLeft, GL_STATIC_DRAW);
    [self reportError:@"after glBufferData"];
    
    // Setup the vertex array
    glGenVertexArrays(1, &vertexArray);
    [self reportError:@"after glGenVertexArrays"];
    glBindVertexArray(vertexArray);
    [self reportError:@"after glBindVertexArray"];

    // Setup the vertex buffer
    GLfloat verticesRight[] = {
        0.0f, -1.0f,
        1.0f, -1.0f,
        1.0f,  1.0f,
        0.0f,  1.0f
    };
    glGenBuffers(1, &vertexBufferRight);
    [self reportError:@"after glGenBuffers"];
    glBindBuffer(GL_ARRAY_BUFFER, vertexBufferRight);
    [self reportError:@"after glBindBuffer"];
    glBufferData(GL_ARRAY_BUFFER, sizeof(verticesRight), verticesRight, GL_STATIC_DRAW);
    [self reportError:@"after glBufferData"];
    
    positionLoc = glGetAttribLocation(prog, "inPosition");
    [self reportError:@"after glGetAttribLocation(inPosition)"];
    glEnableVertexAttribArray(positionLoc);
    [self reportError:@"after glEnableVertexAttribArray(inPosition)"];
    glVertexAttribPointer(positionLoc, 2, GL_FLOAT, GL_FALSE, 0, 0);
    [self reportError:@"after glVertexAttribPointer(inPosition)"];

    colorLoc = glGetAttribLocation(prog, "inColor");
    [self reportError:@"after glGetAttribLocation(inColor)"];
    glEnableVertexAttribArray(colorLoc);
    [self reportError:@"after glEnableVertexAttribArray(inColor)"];
    glVertexAttribPointer(colorLoc, 2, GL_FLOAT, GL_FALSE, 0, 0);
    [self reportError:@"after glVertexAttribPointer(inColor)"];
}

- (void)setupVisualContext:(CGLContextObj)glContext
           withPixelFormat:(CGLPixelFormatObj)pixelFormat;
{
    // Create the output
    output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB)}];

    [output setSuppressesPlayerRendering:TRUE];

    [[[self movie] currentItem] addOutput:output];
}

- (GLuint)compileShader:(GLenum)type
             withSource:(const GLchar *const *)shaderSrc
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
    CGLSetCurrentContext(glContext);

    // Self coordinates of the view
    CGRect viewBounds = [self bounds];
    NSLog(@"%f, %f", viewBounds.size.width, viewBounds.size.height);
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

    // default target for CoreVideo textures is GL_TEXTURE_RECTANGLE_EXT
    //GLenum textureTarget = CVOpenGLTextureGetTarget(currentFrame);
    GLenum textureName = CVOpenGLTextureGetName(currentFrame);

    // Set unit 0 as the active target unit
    glActiveTexture(GL_TEXTURE0);
    [self reportError:@"after active texture"];

    // Enable the texture target for the current frame
    //glEnable(GL_TEXTURE);
    //[self reportError:@"after enable"];

    // Bind to the current frame texture
    // This tells OpenGL which texture we are wanting
    // to draw so that when we make our glTexCord and
    // glVertex calls, our current frame gets drawn
    // to the context.
    glBindTexture(GL_TEXTURE_RECTANGLE, textureName);
    [self reportError:@"after bind texture"];

//    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//
//    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textureName, 0);
//    [self reportError:@"after frame buffer texture"];

    // Set the model view matrix
//    glMatrixMode(GL_MODELVIEW);
//    glLoadIdentity();

    // Set the projection view matrix
//    glMatrixMode(GL_PROJECTION);
//    glLoadIdentity();
//    glOrtho(viewBounds.origin.x,
//            viewBounds.origin.x + viewBounds.size.width,
//            viewBounds.origin.y,
//            viewBounds.origin.y + viewBounds.size.height,
//            -1.0, 1.0);

    // Configure the shader
    glUseProgram(prog);
    [self reportError:@"after use program"];

    // Load the texture index in the sampler
    glUniform1i(textureLoc, 0);

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
//    float w = float(viewBounds.size.width) / float(textureBounds.size.width*2);
//    float h = float(viewBounds.size.height) / float(textureBounds.size.height);
//    float x = float(textureBounds.origin.x) / float(textureBounds.size.width*2);
//    float y = float(textureBounds.origin.y) / float(textureBounds.size.height);

    float w = 2.0;
    float h = 2.0;
    float x = -1.0;
    float y = -1.0;

    float aspect = stereoConfig.GetAspect();
    float scale = stereoConfig.GetDistortionScale();
    float scaleFactor = 1.0f / scale;
    float eyeOffset = eye * stereoConfig.GetProjectionCenterOffset();

    float param_x = x + w * 0.5f;
    float param_y = y + h * 0.5f;
    // Screen center
    glUniform2f(screenCenterLoc,
                param_x,
                param_y);

    param_x = param_x + eyeOffset;
    // Eye center
    glUniform2f(lensCenterLoc,
                param_x,
                param_y);

    param_x = (w / 2.0f) * scaleFactor;
    param_y = (h / 2) * scaleFactor * aspect;
    // Scale out the distorted sample
    glUniform2f(scaleLoc,
                param_x,
                param_y);

    param_x = 2.0f / w;
    param_y = (2.0f / h) / aspect;
    // Scale in the texture coordinates to [-1,1] in order
    // to do the distortion properly
    glUniform2f(scaleInLoc,
                param_x,
                param_y);

    // Static array of distortion coefficients for the barrel transform function
    glUniform4fv(hmdWarpParamLoc, 1, stereoConfig.GetDistortionConfig().K);

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    [self reportError:@"after glDrawArrays"];
}

- (void)reportError:(NSString*)message
{
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        GLsizei len;
        GLchar log[2000];
        glGetProgramInfoLog(prog, 2000, &len, log);
        glGetShaderInfoLog(fragmentShader, 2000, &len, log);
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

-(CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask
{
	// The default is fine for this demonstration.
    //	return [super copyCGLPixelFormatForDisplayMask:mask];

    CGLPixelFormatAttribute attributes[13] = {
        // This sets the context to 3.2
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
        kCGLPFAColorSize,     (CGLPixelFormatAttribute)24,
        kCGLPFAAlphaSize,     (CGLPixelFormatAttribute)8,
//        kCGLPFAAccelerated,
//        kCGLPFADoubleBuffer,
//        kCGLPFASampleBuffers, (CGLPixelFormatAttribute)1,
//        kCGLPFASamples,       (CGLPixelFormatAttribute)4,
        (CGLPixelFormatAttribute)0
    };

	CGLPixelFormatObj pixelFormatObj = NULL;
	GLint numPixelFormats = 0;

	CGLChoosePixelFormat(attributes, &pixelFormatObj, &numPixelFormats);

	if(pixelFormatObj == NULL)
		NSLog(@"Error: Could not choose pixel format!");

	return pixelFormatObj;
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
