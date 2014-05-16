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

    CGColorRef black = CGColorCreateGenericRGB(0, 0, 0, 1);
    [self setBackgroundColor:black];
    [self setNeedsDisplayOnBoundsChange:YES];
    CFRelease(black);
    
    [self setMovie:m];

    [self getHMDInfo];

    initialized = false;

    return self;
}

#pragma mark - Get device info

- (void)getHMDInfo
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
    Ptr<HMDDevice> pHMD;
    pManager = *DeviceManager::Create();
    pHMD = *pManager->EnumerateDevices<HMDDevice>().CreateDevice();
    if (pHMD != NULL) {
        pHMD->GetDeviceInfo(&hmdInfo);
    }

    stereoConfig.SetHMDInfo(hmdInfo);
}

#pragma mark

#pragma mark - Initialize OpenGL context

-(CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask
{
    CGLPixelFormatAttribute attributes[13] = {
        // This sets the context to 3.2
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
        kCGLPFAColorSize,     (CGLPixelFormatAttribute)24,
        kCGLPFAAlphaSize,     (CGLPixelFormatAttribute)8,
        kCGLPFAAccelerated,
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
    [self cleanup];

    CGLContextObj glContext = [super copyCGLContextForPixelFormat:pixelFormat];

    return glContext;
}

- (void)setupVisualContext:(CGLContextObj)glContext
           withPixelFormat:(CGLPixelFormatObj)pixelFormat;
{
    // Create the output
    output = [
               [AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:
               @{
                  (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
                  (id)kCVPixelBufferOpenGLCompatibilityKey: @(YES)
                }
             ];

    [output setSuppressesPlayerRendering:TRUE];

    [[[self movie] currentItem] addOutput:output];
}

- (void) setupVertexArray:(GLuint *)vertexArray
                   forEye:(int)eye
          withTextureRect:(CGRect)textureBounds
{
    glDeleteVertexArrays(1, vertexArray);

    // Setup the vertex array
    glGenVertexArrays(1, vertexArray);
    [self reportError:@"glGenVertexArrays"];
    glBindVertexArray(*vertexArray);
    [self reportError:@"glBindVertexArray"];

    float vertEye = -1.0f * eye;

    float leftVertX = (-1.0f + vertEye) / 2;
    float rightVertX = (1.0f + vertEye) / 2;
    float topVertY = 1.0f;
    float bottomVertY = -1.0f;

    // Setup the left vertex buffer
    // Use absolute texture coordinates and texelFetch() for the GL_TEXTURE_RECTANGLE
    // as normalized ([0,1]) coordinates and texture() don't sample properly
    // for some reason
    GLfloat vertices[] = {
        leftVertX,  topVertY,
        rightVertX, topVertY,
        leftVertX,  bottomVertY,
        rightVertX, bottomVertY,
        (GLfloat)textureBounds.origin.x,
        (GLfloat)textureBounds.origin.y,
        (GLfloat)textureBounds.origin.x + (GLfloat)textureBounds.size.width,
        (GLfloat)textureBounds.origin.y,
        (GLfloat)textureBounds.origin.x,
        (GLfloat)textureBounds.origin.y + (GLfloat)textureBounds.size.height,
        (GLfloat)textureBounds.origin.x + (GLfloat)textureBounds.size.width,
        (GLfloat)textureBounds.origin.y + (GLfloat)textureBounds.size.height,
    };

    GLuint vertexBuffer;

    glGenBuffers(1, &vertexBuffer);
    [self reportError:@"glGenBuffers"];
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    [self reportError:@"glBindBuffer"];
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    [self reportError:@"glBufferData"];

    glEnableVertexAttribArray(vertexPositionLoc);
    [self reportError:@"glEnableVertexAttribArray(vertexPosition)"];
    glVertexAttribPointer(vertexPositionLoc, 2, GL_FLOAT, GL_FALSE, 0, 0);
    [self reportError:@"glVertexAttribPointer(vertexPosition)"];
    glEnableVertexAttribArray(texturePositionLoc);
    [self reportError:@"glEnableVertexAttribArray(texturePosition)"];
    glVertexAttribPointer(texturePositionLoc, 2, GL_FLOAT, GL_TRUE, 0, (GLvoid*)32);
    [self reportError:@"glVertexAttribPointer(texturePosition)"];

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    glDeleteBuffers(1, &vertexBuffer);
}

- (void) setupVertexArrays
{
    if (!vertexArrayLeft) {
        [self setupVertexArray:&vertexArrayLeft
                        forEye:EYE_LEFT
               withTextureRect:frameBoundsLeft];
    }
    if (!vertexArrayRight) {
        [self setupVertexArray:&vertexArrayRight
                        forEye:EYE_RIGHT
               withTextureRect:frameBoundsRight];
    }
}

- (void)releaseCGLContext:(CGLContextObj)glContext
{
    [self cleanup];

    [super releaseCGLContext:glContext];
}

- (void) cleanup
{
    glDeleteVertexArrays(1, &vertexArrayRight);
    glDeleteVertexArrays(1, &vertexArrayLeft);

    glUseProgram(0);
    glDeleteProgram(prog);
    glDeleteShader(fragmentShader);
    glDeleteShader(vertexShader);

    CVOpenGLTextureRelease(currentFrame);
    CVOpenGLTextureCacheRelease(textureCache);

    [[[self movie] currentItem] removeOutput:output];
    output = NULL;
}

#pragma mark

#pragma mark - Shaders

- (GLchar*)getShaderString:(NSURL*)fromURL {
    NSLog(@"loading from %@", [fromURL absoluteURL]);
    NSString* str = [NSString stringWithContentsOfURL:[fromURL absoluteURL] encoding:NSASCIIStringEncoding error:nil];
    NSLog(@"%@",str);
    return (GLchar*)[str UTF8String];
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

- (GLuint)createShader:(GLenum)type withName:(NSString *)name
{
    const GLchar* shaderSource = [self getShaderString:[[NSBundle mainBundle] URLForResource:name withExtension:@"glsl"]];
    return [self compileShader:type withSource:(const GLchar *const *)&shaderSource];
}

- (void)getAttributesLocations
{
    vertexPositionLoc = glGetAttribLocation(prog, "vertexPosition");
    [self reportError:@"glGetAttribLocation(vertexPosition)"];

    texturePositionLoc = glGetAttribLocation(prog, "texturePosition");
    [self reportError:@"glGetAttribLocation(texturePosition)"];
}

- (void)getUniformsLocations
{
    textureLoc = glGetUniformLocation(prog, "texture");
    [self reportError:@"glGetUniformLocation(texture)"];
    lensCenterLoc = glGetUniformLocation(prog, "LensCenter");
    [self reportError:@"glGetUniformLocation(LensCenter)"];
    screenCenterLoc = glGetUniformLocation(prog, "ScreenCenter");
    [self reportError:@"glGetUniformLocation(ScreenCenter)"];
    scaleLoc = glGetUniformLocation(prog, "Scale");
    [self reportError:@"glGetUniformLocation(Scale)"];
    scaleInLoc = glGetUniformLocation(prog, "ScaleIn");
    [self reportError:@"glGetUniformLocation(ScaleIn)"];
    hmdWarpParamLoc = glGetUniformLocation(prog, "HmdWarpParam");
    [self reportError:@"after glGetUniformLocation(HmdWarpParam)"];

}

- (void)createProgram
{
    // Create ID for shaders
    vertexShader = [self createShader:GL_VERTEX_SHADER withName:@"vertexShader"];
    fragmentShader = [self createShader:GL_FRAGMENT_SHADER withName:@"fragmentShaderRift"];

    prog = glCreateProgram();
    [self reportError:@"glCreateProgram"];

    // Associate shaders with program
    glAttachShader(prog, vertexShader);
    [self reportError:@"glAttachShader(vertexShader)"];
    glAttachShader(prog, fragmentShader);
    [self reportError:@"glAttachShader(fragmentShader)"];

    // Link program
    glLinkProgram(prog);
    [self reportError:@"glLinkProgram"];

    // Check the status of the compile/link
    GLint linked;
    glGetProgramiv(prog, GL_LINK_STATUS, &linked);
    if (linked == GL_FALSE) {
        GLsizei len;
        GLchar log[400];
        glGetProgramInfoLog(prog, 400, & len, log);
    }

    [self getAttributesLocations];

    [self getUniformsLocations];

    // Use the shader program
    glUseProgram(prog);
    [self reportError:@"glUseProgram"];
}

#pragma mark

#pragma mark - Render frame

- (BOOL)canDrawInCGLContext:(CGLContextObj)glContext
                pixelFormat:(CGLPixelFormatObj)pixelFormat
               forLayerTime:(CFTimeInterval)timeInterval
                displayTime:(const CVTimeStamp *)timeStamp
{
    CGLSetCurrentContext(glContext);

    if (!initialized) {
        NSLog(@"OpenGL Version: %s", glGetString(GL_VERSION));
        NSLog(@"OpenGL Shader Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
        
        [self setupVisualContext:glContext withPixelFormat:pixelFormat];

        CVOpenGLTextureCacheCreate(kCFAllocatorDefault, NULL, glContext, pixelFormat, NULL, &textureCache);

        [self createProgram];

        initialized = true;
    }

    // There is no point in trying to draw anything if our
    // movie is not playing.
    if( [movie rate] <= 0.0 )
        return NO;

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
            frameBoundsLeft = CGRectMake(frameBounds.origin.x,
                                         frameBounds.origin.y,
                                         frameBounds.size.width/2,
                                         frameBounds.size.height);
            frameBoundsRight = CGRectOffset(frameBoundsLeft,
                                            frameBoundsLeft.size.width,
                                            0);

            // Setup the vertex arrays here because we need the texture size
            [self setupVertexArrays];
            
            return YES;
        }
    }
    
    return NO;
}

- (void)drawInCGLContext:(CGLContextObj)glContext 
             pixelFormat:(CGLPixelFormatObj)pixelFormat 
            forLayerTime:(CFTimeInterval)interval 
             displayTime:(const CVTimeStamp *)timeStamp
{
    CGLSetCurrentContext(glContext);

    // Self coordinates of the view
    CGRect viewBounds = [self bounds];
    CGRect viewBoundsLeft = CGRectMake(viewBounds.origin.x,
                                       viewBounds.origin.y,
                                       viewBounds.size.width/2,
                                       viewBounds.size.height);
    CGRect viewBoundsRight = CGRectOffset(viewBoundsLeft,
                                          viewBoundsLeft.size.width,
                                          0);

    // Clear the buffer
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    // default target for CoreVideo textures is GL_TEXTURE_RECTANGLE
    GLenum textureTarget = CVOpenGLTextureGetTarget(currentFrame);
    GLenum textureName = CVOpenGLTextureGetName(currentFrame);

    assert(textureTarget == GL_TEXTURE_RECTANGLE);

    // Set unit 2 as the active target unit
    glActiveTexture(GL_TEXTURE0);
    [self reportError:@"glActiveTexture"];

    // Bind to the current frame texture
    glBindTexture(GL_TEXTURE_RECTANGLE, textureName);
    [self reportError:@"glBindTexture"];

    // Load the texture index in the sampler
    glUniform1i(textureLoc, 0);
    [self reportError:@"glUniform1i(textureLoc)"];

    // Render left eye
    [self renderEyeInViewBounds:viewBoundsLeft
              withTextureBounds:frameBoundsLeft
                 andVertexArray:vertexArrayLeft
                         forEye:EYE_LEFT];

    // Render right eye
    [self renderEyeInViewBounds:viewBoundsRight
              withTextureBounds:frameBoundsRight
                 andVertexArray:vertexArrayRight
                         forEye:EYE_RIGHT];

    // This CAOpenGLLayer is responsible to flush
    // the OpenGL context so we call super
    [super drawInCGLContext:glContext 
           pixelFormat:pixelFormat
           forLayerTime:interval
           displayTime:timeStamp];
}

- (void)renderEyeInViewBounds:(struct CGRect)viewBounds
            withTextureBounds:(struct CGRect)textureBounds
               andVertexArray:(GLuint)vertexArray
                       forEye:(int)eye
{
    NSLog(@"left eye: %d", eye == EYE_LEFT);
    glBindVertexArray(vertexArray);
    [self reportError:@"glBindVertexArray"];

    // eye is 1|-1
    // eyeVert is -1|1
    // eyeTex is 0|0.5
    float vertEye = -1.0f * eye;
    float eyeTex = (vertEye + 1.0f) / 4.0f;

    // vertex bounds in [-1,1]
    // (-1,1), (0,-1) | (0,1), (1,-1)
    float leftVertX = (-1.0f + vertEye) / 2;
    float rightVertX = (1.0f + vertEye) / 2;
    float topVertY = 1.0f;
    float bottomVertY = -1.0f;

    // normalized texture bounds in [0,1]
    // (0,0), (0.5,1) | (0.5,0), (1,1)
    float leftTexX = (leftVertX + 1) / 2;
    float rightTexX = (rightVertX + 1) / 2;
    float topTexY = ((-1.0f * topVertY) + 1) / 2;
    float bottomTexY = ((-1.0f * bottomVertY) + 1) / 2;

    // normalized texture bounds converted to bounds in [-1,1]
    // always (1,1), (-1,-1)
    // not used currently
    float leftWarpX = (leftTexX - eyeTex) * 4.0f - 1.0f;
    float rightWarpX = (rightTexX - eyeTex) *4.0f - 1.0f;
    float topWarpY = topTexY * 2.0f - 1.0f;
    float bottomWarpY = bottomTexY * 2.0f - 1.0f;

    NSLog(@"leftWarpX: %f, rightWarpX: %f, topWarpY: %f, bottomWarpY: %f", leftWarpX, rightWarpX, topWarpY, bottomWarpY);
    
    float aspect = stereoConfig.GetAspect();
    float scale = stereoConfig.GetDistortionScale();
    float scaleFactor = 1.0f / scale;
    float eyeOffset = eye * stereoConfig.GetProjectionCenterOffset();

    // Oh, so close...
    // TODO: Figure out the proper parameters!!!

    float w = 1.0;
    float h = 2.0;
    float x = -0.5;
    float y = -1.0;

    float param_x;
    float param_y;

    float vertWidth = rightVertX - leftVertX;
    float vertHeight = topVertY - bottomVertY;
//    float texWidth = rightTexX - leftTexX;
//    float texHeight = bottomTexY - topTexY;

    // Eye center is offset from screen center
    param_x = x + w * 0.5f + eyeOffset * 0.5f;
    param_y = y + h * 0.5f;
//    param_x = leftVertX + (vertWidth + eyeOffset) * 0.5f;
//    param_y = bottomVertY + vertHeight * 0.5f;
//    param_x = leftTexX + (texWidth + eyeOffset * 0.5f) * 0.5f;
//    param_y = topTexY + texHeight * 0.5f;
    NSLog(@"lensCenter: (%f, %f)", param_x, param_y);
    glUniform2f(lensCenterLoc, param_x, param_y);
    
    // Screen center
    param_x = x + w * 0.5f;
    param_y = y + h * 0.5f;
//    param_x = leftVertX + vertWidth * 0.5f;
//    param_y = bottomVertY + vertHeight * 0.5f;
//    param_x = leftTexX + texWidth * 0.5f;
//    param_y = topTexY + texHeight * 0.5f;
    NSLog(@"screenCenter: (%f, %f)", param_x, param_y);
    glUniform2f(screenCenterLoc, param_x, param_y);

    // Scale out the distorted sample
    param_x = (w / 2.0f) * scaleFactor;
    param_y = (h / 2) * scaleFactor * aspect;
//    param_x = (vertWidth * 0.5f) * scaleFactor;
//    param_y = (vertHeight * 0.5f) * scaleFactor * aspect;
//    param_x = (texWidth * 0.5f) * scaleFactor;
//    param_y = (texHeight * 0.5f) * scaleFactor * aspect;
    NSLog(@"scaleOut: (%f, %f)", param_x, param_y);
    glUniform2f(scaleLoc, param_x, param_y);

    // Scale in the texture coordinates to [-1,1]
    // in order to do the distortion properly
    param_x = 2.0f / w;
    param_y = (2.0f / h) / aspect;
//    param_x = 2.0f / vertWidth;
//    param_y = (2.0f / vertHeight) / aspect;
//    param_x = 2.0f / texWidth;
//    param_y = (2.0f / texHeight) / aspect;
    NSLog(@"scaleIn: (%f, %f)", param_x, param_y);
    glUniform2f(scaleInLoc, param_x, param_y);

    // Static array of distortion coefficients for the barrel transform function
    glUniform4fv(hmdWarpParamLoc, 1, stereoConfig.GetDistortionConfig().K);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [self reportError:@"glDrawArrays"];

    glBindVertexArray(0);
}

#pragma mark

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

- (void) dealloc
{
    [self cleanup];
}

@end
