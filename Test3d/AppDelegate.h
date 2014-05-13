//
//  AppDelegate.h
//  Test3d
//
//  Created by Franci Penov on 5/8/14.
//  Copyright (c) 2014 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

#import "OVR.h"

#import "OpenGLMovieLayer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

- (void)setUpMenuItems;
- (void)startMovie:(NSURL*) url;
- (IBAction)openDocument:(id)pId;

@end
