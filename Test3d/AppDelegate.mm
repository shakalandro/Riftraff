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
  OVR::System::Init();

  [[NSNotificationCenter defaultCenter]
    addObserver:self
    selector:@selector(windowDidResize:)
    name:NSWindowDidResizeNotification
    object:nil];

  [self setUpMenuItems];
  [self openDocument:self];
  //[self startMovie:[[NSBundle mainBundle] URLForResource:@"shrek" withExtension:@"mp4"]];
}

- (void)startMovie:(NSURL*) url
{
  NSLog(@"playing url = %@", url);
  AVPlayer *player = [AVPlayer playerWithURL:[url absoluteURL]];

  _layer = [[OpenGLMovieLayer alloc] initWithMovie:player];
  [_layer setFrame:NSRectToCGRect([[[self window] contentView] bounds])];

  [[[self window] contentView] setWantsLayer:YES];
  [[[[self window] contentView] layer] addSublayer:_layer];

  [[_layer movie] seekToTime:kCMTimeZero];
  [[_layer movie] play];
}

- (void)setUpMenuItems
{
  NSMenuItem *openMenu = [[NSMenuItem alloc] initWithTitle:@"Open" action:@selector(openDocument:) keyEquivalent:@""];
  [openMenu setEnabled:TRUE];
  NSMenu *myMenu = [[NSMenu alloc] initWithTitle:@"File"];
  [openMenu setSubmenu:myMenu];
  [[NSApp mainMenu] addItem:openMenu];
}

- (IBAction)openDocument:(id)pId {
  NSOpenPanel* openPanelObj	= [NSOpenPanel openPanel];

  NSArray *fileTypesArray;
  fileTypesArray = [NSArray arrayWithObjects:@"mp4", @"avi", nil];
  [openPanelObj setCanChooseFiles:YES];
  [openPanelObj setAllowedFileTypes:fileTypesArray];
  [openPanelObj setAllowsMultipleSelection:FALSE];

  [openPanelObj beginWithCompletionHandler:^(NSInteger result){
    if (result == NSFileHandlingPanelOKButton) {
      NSURL* url = [openPanelObj URL];
      [self startMovie:url];
    }
  }];
}

- (IBAction)windowDidResize:(id)pId {
  NSLog(@"Window did resize");
  [_layer setFrame:NSRectToCGRect([[[self window] contentView] bounds])];
  [[[[self window] contentView] layer] addSublayer:_layer];
}

@end
