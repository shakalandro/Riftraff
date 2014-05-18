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
    GLuint                  vertexPositionLoc;
    GLuint                  texturePositionLoc;

    // Uniforms
    GLint                   textureLoc;
    GLint                   lensOffsetLoc;
    GLint                   screenSizeLoc;
    GLint                   screenCenterLoc;
    GLint                   scaleLoc;
    GLint                   scaleInLoc;
    GLint                   transInLoc;
    GLint                   hmdWarpParamLoc;
    GLint                   eyeLoc;

    // Vertices array and buffer
    GLuint                  vertexArrayLeft;
    GLuint                  vertexArrayRight;

    // Device info
    HMDInfo                 hmdInfo;
    StereoConfig            stereoConfig;

    // Self coordinates of the frame
    CGRect                  frameBounds;
    CGRect                  frameBoundsLeft;
    CGRect                  frameBoundsRight;

    BOOL                    initialized;

}

@property (retain) AVPlayer *movie;
@property (retain) AVPlayerItemVideoOutput *output;

- (id)initWithMovie:(AVPlayer*)m;

@end
