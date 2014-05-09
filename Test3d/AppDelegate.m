//
//  AppDelegate.m
//  Test3d
//
//  Created by Franci Penov on 5/8/14.
//  Copyright (c) 2014 Facebook Inc. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    AVPlayer *player = [AVPlayer playerWithURL:[[NSBundle mainBundle] URLForResource:@"shrek" withExtension:@"mp4"]];

    OpenGLMovieLayer *layer = [[OpenGLMovieLayer alloc] initWithMovie:player];
    [layer setFrame:NSRectToCGRect([[[self window] contentView] bounds])];

    [[[self window] contentView] setWantsLayer:YES];
    [[[[self window] contentView] layer] addSublayer:layer];
    [[layer movie] seekToTime:kCMTimeZero];
    [[layer movie] play];
}

@end
