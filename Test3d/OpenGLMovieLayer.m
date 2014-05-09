#import "OpenGLMovieLayer.h"
#import <OpenGL/gl.h>
#import <CoreVideo/CVPixelBuffer.h>

@implementation OpenGLMovieLayer

@synthesize movie;
@synthesize output;

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

    return self;
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
    // Enable target for the current frame
    glEnable(CVOpenGLTextureGetTarget(currentFrame));
    
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

    // Draw the quads
    glTexCoord2f(upperLeft[0], upperLeft[1]);
    glVertex2f  (imageRect.origin.x, 
                 imageRect.origin.y + imageRect.size.height);
    glTexCoord2f(upperRight[0], upperRight[1]);
    glVertex2f  (imageRect.origin.x + imageRect.size.width, 
                 imageRect.origin.y + imageRect.size.height);
    glTexCoord2f(lowerRight[0], lowerRight[1]);
    glVertex2f  (imageRect.origin.x + imageRect.size.width, 
                 imageRect.origin.y);
    glTexCoord2f(lowerLeft[0], lowerLeft[1]);
    glVertex2f  (imageRect.origin.x, imageRect.origin.y);
    
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
	return [super copyCGLContextForPixelFormat:pixelFormat];
}

- (void) dealloc
{
	CVOpenGLTextureRelease(currentFrame);
    [[[self movie] currentItem] removeOutput:output];
    output = NULL;
}

@end
