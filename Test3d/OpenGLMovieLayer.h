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
    
    GLfloat                 lowerLeft[2];
    GLfloat                 lowerRight[2];
    GLfloat                 upperRight[2];
    GLfloat                 upperLeft[2];
    GLuint                  vertexShader;
    GLuint                  fragmentShader;
    GLuint                  prog;

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

@end
