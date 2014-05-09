#import "OpenGLMovieLayer.h"
#import <OpenGL/gl.h>
#import <CoreVideo/CVPixelBuffer.h>

@implementation OpenGLMovieLayer

@synthesize movie;
@synthesize output;

static const GLchar* vertexShaderText =
"void main(void)\n"
"{\n"
"    gl_FrontColor = gl_Color;\n"
"    gl_Position = gl_Vertex;\n"
"    gl_TexCoord[0].st = gl_MultiTexCoord0.xy;\n"
"}\n";

static const GLchar* fragmentShaderText =
"uniform sampler2D texture;\n"
"uniform vec2 LensCenter;\n"
"uniform vec2 ScreenCenter;\n"
"uniform vec2 Scale;\n"
"uniform vec2 ScaleIn;\n"
"uniform vec4 HmdWarpParam;\n"
"\n"
"vec2 HmdWarp(vec2 texIn)\n"
"{\n"
"    vec2 theta = (texIn - LensCenter) * ScaleIn;\n"
"    float rSq = theta.x * theta.x + theta.y * theta.y;\n"
"    vec2 theta1 = theta * (HmdWarpParam.x + HmdWarpParam.y * rSq + \n"
"            HmdWarpParam.z * rSq * rSq + HmdWarpParam.w * rSq * rSq * rSq);\n"
"    return LensCenter + Scale * theta1;\n"
"}\n"
"\n"
"void main()\n"
"{\n"
"    vec2 tc = HmdWarp(gl_TexCoord[0].xy);\n"
"    if (any(notEqual(clamp(tc, ScreenCenter-vec2(0.25,0.5), ScreenCenter+vec2(0.25, 0.5)) - tc, vec2(0.0, 0.0))))\n"
"    {\n"
"        gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);\n"
"    }\n"
"    else\n"
"    {\n"
"        gl_FragColor = texture2D(texture, tc);\n"
"    }\n"
"}\n";

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
        vertexShader = [self compileShader:GL_VERTEX_SHADER withSource:(const GLchar *const *)&vertexShaderText];
        fragmentShader = [self compileShader:GL_FRAGMENT_SHADER withSource:(const GLchar *const *)&fragmentShaderText];

        prog = glCreateProgram();
        // Associate shaders with program
        glAttachShader(prog, vertexShader);
        glAttachShader(prog, fragmentShader);

        // Link program
        glLinkProgram(prog);

        // Check the status of the compile/link
        GLint linked;
        glGetProgramiv(prog, GL_LINK_STATUS, &linked);

        if (linked == GL_FALSE) {
            GLsizei len;
            GLchar log[400];
            glGetProgramInfoLog(prog, 400, & len, log);
            glDeleteProgram(prog);
        }

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
            CVOpenGLTextureGetCleanTexCoords(currentFrame,
                                             lowerLeft,
                                             lowerRight,
                                             upperRight,
                                             upperLeft);
            
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
    NSRect bounds = NSRectFromCGRect([self bounds]);
    
    GLfloat minX, minY, maxX, maxY;        
    
    minX = NSMinX(bounds);
    minY = NSMinY(bounds);
    maxX = NSMaxX(bounds);
    maxY = NSMaxY(bounds);
    
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho( minX, maxX, minY, maxY, -1.0, 1.0);
    
    glClearColor(0.0, 0.0, 0.0, 0.0);	     
    glClear(GL_COLOR_BUFFER_BIT);
    
    CGRect imageRect = [self frame];

    GLfloat w = float(upperRight[0] - upperLeft[0]) / float(imageRect.size.width);
    GLfloat h = float(lowerRight[1] - upperRight[1]) / float(imageRect.size.height);
    GLfloat x = float(upperLeft[0]) / float(imageRect.size.width);
    GLfloat y = float(upperLeft[1]) / float(imageRect.size.height);

    GLfloat halfWidthFrame = imageRect.size.width / 2;
    GLfloat halfWidthSource = lowerRight[0] / 2;
    
    const DistortionConfig & distortion = stereoConfig.GetDistortionConfig();

    float aspect = stereoConfig.GetAspect();
    float scaleFactor = 1.0f / stereoConfig.GetDistortionScale();

    // Enable target for the current frame
    glEnable(CVOpenGLTextureGetTarget(currentFrame));
    
//    glUseProgram(prog);

    glUniform4fv(hmdWarpParamLoc, 1, distortion.K);
    glUniform2f(scaleInLoc, 2.0f / w, (2.0f / h) / aspect);
    glUniform2f(scaleLoc, (w / 2) * scaleFactor, (h / 2) * scaleFactor * aspect);

    // Bind to the current frame
    // This tells OpenGL which texture we are wanting 
    // to draw so that when we make our glTexCord and 
    // glVertex calls, our current frame gets drawn
    // to the context.
    glBindTexture(CVOpenGLTextureGetTarget(currentFrame), 
                  CVOpenGLTextureGetName(currentFrame));
    glMatrixMode(GL_TEXTURE);
    glLoadIdentity();
    glColor4f(1.0, 1.0, 1.0, 1.0);
    glBegin(GL_QUADS);

    // Draw the left eye quads
    glUniform2f(screenCenterLoc, x + w * 0.5f, y + h * 0.5f);
    glUniform2f(lensCenterLoc, x + (w + distortion.XCenterOffset * 0.5) * 0.5, y + h * 0.5);

    glTexCoord2f(upperLeft[0], upperLeft[1]);
    glVertex2f  (imageRect.origin.x, 
                 imageRect.origin.y + imageRect.size.height);
    glTexCoord2f(upperRight[0] - halfWidthSource, upperRight[1]);
    glVertex2f  (imageRect.origin.x + imageRect.size.width - halfWidthFrame,
                 imageRect.origin.y + imageRect.size.height);
    glTexCoord2f(lowerRight[0] - halfWidthSource, lowerRight[1]);
    glVertex2f  (imageRect.origin.x + imageRect.size.width - halfWidthFrame,
                 imageRect.origin.y);
    glTexCoord2f(lowerLeft[0], lowerLeft[1]);
    glVertex2f  (imageRect.origin.x, imageRect.origin.y);

    // Draw the right eye quads
    glUniform2f(screenCenterLoc, x + w + w * 0.5f, y + h + h * 0.5f);
    glUniform2f(lensCenterLoc, x + w + (w - distortion.XCenterOffset * 0.5) * 0.5, y + h * 0.5);

    glTexCoord2f(upperLeft[0] + halfWidthSource, upperLeft[1]);
    glVertex2f  (imageRect.origin.x + halfWidthFrame,
                 imageRect.origin.y + imageRect.size.height);
    glTexCoord2f(upperRight[0], upperRight[1]);
    glVertex2f  (imageRect.origin.x + imageRect.size.width,
                 imageRect.origin.y + imageRect.size.height);
    glTexCoord2f(lowerRight[0], lowerRight[1]);
    glVertex2f  (imageRect.origin.x + imageRect.size.width,
                 imageRect.origin.y);
    glTexCoord2f(lowerLeft[0] + halfWidthSource, lowerLeft[1]);
    glVertex2f  (imageRect.origin.x + halfWidthFrame, imageRect.origin.y);

    glEnd();
    
    // This CAOpenGLLayer is responsible to flush
    // the OpenGL context so we call super
    [super drawInCGLContext:glContext 
                pixelFormat:pixelFormat 
               forLayerTime:interval 
                displayTime:timeStamp];

}

- (void)setupVisualContext:(CGLContextObj)glContext 
           withPixelFormat:(CGLPixelFormatObj)pixelFormat;
{
    // Create the output
    output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB)}];

    [output setSuppressesPlayerRendering:TRUE];

    [[[self movie] currentItem] addOutput:output];
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

@end
