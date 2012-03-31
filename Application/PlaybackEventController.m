//
//  PlaybackEventController.m
//  Cog
//
//  Created by Vincent Spader on 3/5/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PlaybackEventController.h"

#import "AudioScrobbler.h"
#import "PlaybackController.h"
#import "PlaylistLoader.h"
#import "PlaylistEntry.h"

@implementation PlaybackEventController

- (void)initDefaults
{
	NSDictionary *defaultsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:YES], @"enableAudioScrobbler",
										[NSNumber numberWithBool:NO],  @"automaticallyLaunchLastFM",
										nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDictionary];
}

- (id)init
{
	self = [super init];
	if (self)
	{
		[self initDefaults];
		
		queue = [[NSOperationQueue alloc] init];
		[queue setMaxConcurrentOperationCount:1];
		
		scrobbler = [[AudioScrobbler alloc] init];
		[GrowlApplicationBridge setGrowlDelegate:self];
	}
	
	return self;
}

- (void)dealloc
{
	[queue release];
	
	[super dealloc];
}

- (void)performPlaybackDidBeginActions:(PlaylistEntry *)pe
{
	// Race here, but the worst that could happen is we re-read the data
	if ([pe metadataLoaded] != YES) {
		[pe performSelectorOnMainThread:@selector(setMetadata:) withObject:[playlistLoader readEntryInfo:pe] waitUntilDone:YES];
	}
	
	if (NO == [pe error]) {
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
			[scrobbler start:pe];
		}
		
		// Note: We don't want to send a growl notification on resume.
		[GrowlApplicationBridge notifyWithTitle:[pe title]
									description:[pe artist]
							   notificationName:@"Stream Changed"
									   iconData:[[pe albumArt] TIFFRepresentation]
									   priority:0 
									   isSticky:NO 
								   clickContext:nil];
	}
}

- (void)performPlaybackDidPauseActions
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
		[scrobbler pause];
	}
}

- (void)performPlaybackDidResumeActions
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
		[scrobbler resume];
	}
}

- (void)performPlaybackDidStopActions
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableAudioScrobbler"]) {
		[scrobbler stop];
	}
}


- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidBegin:) name:CogPlaybackDidBeginNotficiation object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidPause:) name:CogPlaybackDidPauseNotficiation object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidResume:) name:CogPlaybackDidResumeNotficiation object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidStop:)  name:CogPlaybackDidStopNotficiation object:nil];
    

    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.enableGrowlMist"		options:0 context:nil];
    
    [self toggleGrowlMist];
}

- (void) toggleGrowlMist
{
    BOOL enableMist = [[NSUserDefaults standardUserDefaults] boolForKey:@"enableGrowlMist"];
    [GrowlApplicationBridge setShouldUseBuiltInNotifications:enableMist];
}

- (void) observeValueForKeyPath:(NSString *)keyPath
					   ofObject:(id)object
						 change:(NSDictionary *)change
                        context:(void *)context
{
	if ([keyPath isEqualToString:@"values.enableGrowlMist"]) {
        [self toggleGrowlMist];
	}
}

- (void)playbackDidBegin:(NSNotification *)notification
{
	NSOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performPlaybackDidBeginActions:) object:[notification object]];
	[queue addOperation:op];
	[op release];
}

- (void)playbackDidPause:(NSNotification *)notification
{
	NSOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performPlaybackDidPauseActions) object:nil];
	[queue addOperation:op];
	[op release];
}

- (void)playbackDidResume:(NSNotification *)notification
{
	NSOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performPlaybackDidResumeActions) object:nil];
	[queue addOperation:op];
	[op release];
}

- (void)playbackDidStop:(NSNotification *)notification
{
	NSOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performPlaybackDidStopActions) object:nil];
	[queue addOperation:op];
	[op release];
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *notifications = [NSArray arrayWithObjects:@"Stream Changed", nil];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"Cog", GROWL_APP_NAME,  
			notifications, GROWL_NOTIFICATIONS_ALL, 
			notifications, GROWL_NOTIFICATIONS_DEFAULT,
			nil];
}

@end
