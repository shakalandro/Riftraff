#import <Cocoa/Cocoa.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGL/OpenGL.h>
#import <CoreVideo/CoreVideo.h>

#import "OVR.h"

using namespace OVR;
using namespace OVR::Util::Render;

@interface OpenGLMovieLayer : CAOpenGLLayer {
    // AV Player, cache and texture
    AVPlayer                *movie;
    AVPlayerItemVideoOutput *output;
    CVOpenGLTextureCacheRef textureCache;
    CVOpenGLTextureRef		currentFrame;

    // Shaders program
    GLuint                  vertexShader;
    GLuint                  fragmentShader;
    GLuint                  prog;

    // Vertex shader attributes
    GLuint                  positionLoc;
    GLuint                  colorLoc;

    // Uniforms
    GLint                   textureLoc;
    GLint                   lensCenterLoc;
    GLint                   screenCenterLoc;
    GLint                   scaleLoc;
    GLint                   scaleInLoc;
    GLint                   hmdWarpParamLoc;

    // Vertices array and buffer
    GLuint                  vertexArray;
    GLuint                  vertexBuffer;

    // Device info
    HMDInfo                 hmdInfo;
    StereoConfig            stereoConfig;

    // Self coordinates of the frame
    CGRect                  frameBounds;
    CGRect                  leftEyeFrameBounds;
    CGRect                  rightEyeFrameBounds;

}

@property (retain) AVPlayer *movie;
@property (retain) AVPlayerItemVideoOutput *output;

- (id)initWithMovie:(AVPlayer*)m;
- (void)setupVisualContext:(CGLContextObj)glContext withPixelFormat:(CGLPixelFormatObj)pixelFormat;
+ (GLchar*)getShaderString:(NSURL*)fromURL;

@end
