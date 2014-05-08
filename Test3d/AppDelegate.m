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
    // Insert code here to initialize your application
    [[NSApplication sharedApplication]
     setPresentationOptions:NSApplicationPresentationFullScreen];

    //NSImage* imageObj = [[NSImage alloc] initWithContentsOfFile:@"/Users/francip/Desktop/t.jpg"];
    NSImage* imageObj = [NSImage imageNamed:@"t3.png"];

    [_image setImage:imageObj];
    [_image setImageScaling:NSImageScaleProportionallyUpOrDown];
}

@end
