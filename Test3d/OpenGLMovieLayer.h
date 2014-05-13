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
    AVPlayer                *movie;
    AVPlayerItemVideoOutput *output;
    CVOpenGLTextureRef		currentFrame;
    CVOpenGLTextureCacheRef textureCache;

    // Self coordinates of the frame
    CGRect                  frameBounds;
    CGRect                  leftEyeFrameBounds;
    CGRect                  rightEyeFrameBounds;

    GLuint                  vertexShader;
    GLuint                  fragmentShader;
    GLuint                  prog;

    GLint                   textureLoc;
    GLint                   lensCenterLoc;
    GLint                   screenCenterLoc;
    GLint                   scaleLoc;
    GLint                   scaleInLoc;
    GLint                   hmdWarpParamLoc;

    HMDInfo                 hmdInfo;
    StereoConfig            stereoConfig;
}

@property (retain) AVPlayer *movie;
@property (retain) AVPlayerItemVideoOutput *output;

- (id)initWithMovie:(AVPlayer*)m;
- (void)setupVisualContext:(CGLContextObj)glContext withPixelFormat:(CGLPixelFormatObj)pixelFormat;
+ (GLchar*)getShaderString:(NSURL*)fromURL;

@end
