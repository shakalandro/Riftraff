#import <Cocoa/Cocoa.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGL/OpenGL.h>
#import <CoreVideo/CoreVideo.h>

@interface OpenGLMovieLayer : CAOpenGLLayer {
    AVPlayer                *movie;
    AVPlayerItemVideoOutput *output;
    CVOpenGLTextureRef		currentFrame;
    CVOpenGLTextureCacheRef textureCache;
    
    GLfloat                 lowerLeft[2];
    GLfloat                 lowerRight[2];
    GLfloat                 upperRight[2];
    GLfloat                 upperLeft[2];
}

@property (retain) AVPlayer *movie;
@property (retain) AVPlayerItemVideoOutput *output;

- (id)initWithMovie:(AVPlayer*)m;
- (void)setupVisualContext:(CGLContextObj)glContext withPixelFormat:(CGLPixelFormatObj)pixelFormat;

@end
