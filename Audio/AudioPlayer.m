
//  AudioController.m
//  Cog
//
//  Created by Vincent Spader on 8/7/05.
//  Copyright 2005 Vincent Spader. All rights reserved.
//

#import "AudioPlayer.h"
#import "BufferChain.h"
#import "OutputNode.h"
#import "Status.h"
#import "Helper.h"
#import "PluginController.h"

#import "Logging.h"

@implementation AudioPlayer

- (id)init
{
	self = [super init];
	if (self)
	{
		output = NULL;
		bufferChain = NULL;
		outputLaunched = NO;
		endOfInputReached = NO;
		
		chainQueue = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)setDelegate:(id)d
{
	delegate = d;
}

- (id)delegate {
	return delegate;
}

- (void)play:(NSURL *)url
{
	[self play:url withUserInfo:nil];
}

- (void)play:(NSURL *)url withUserInfo:(id)userInfo
{
	if (output)
	{
		[output release];
	}
	output = [[OutputNode alloc] initWithController:self previous:nil];
	[output setup];
	[output setVolume: volume];
	
	@synchronized(chainQueue) {
		NSEnumerator *enumerator = [chainQueue objectEnumerator];
		id anObject;
		while (anObject = [enumerator nextObject])
		{
			[anObject setShouldContinue:NO];
		}
		[chainQueue removeAllObjects];
		endOfInputReached = NO;
		
		if (bufferChain)
		{
			[bufferChain setShouldContinue:NO];

			[bufferChain release];
		}
	}
	
	bufferChain = [[BufferChain alloc] initWithController:self];
	[self notifyStreamChanged:userInfo];
	
	while (![bufferChain open:url withOutputFormat:[output format]])
	{
		[bufferChain release];
		bufferChain = nil;
		
		[self requestNextStream: userInfo];

		url = nextStream;
		if (url == nil)
		{
			return;
		}
	
		userInfo = nextStreamUserInfo;
	
		[self notifyStreamChanged:userInfo];
		
		bufferChain = [[BufferChain alloc] initWithController:self];
	}
	
	[bufferChain setUserInfo:userInfo];

	[self setShouldContinue:YES];
	
	outputLaunched = NO;

	[bufferChain launchThreads];
}

- (void)stop
{
	//Set shouldoContinue to NO on allll things
	[self setShouldContinue:NO];
	[self setPlaybackStatus:kCogStatusStopped waitUntilDone:YES];
}

- (void)pause
{
	[output pause];

	[self setPlaybackStatus:kCogStatusPaused waitUntilDone:YES];
}

- (void)resume
{
	[output resume];

	[self setPlaybackStatus:kCogStatusPlaying waitUntilDone:YES];	
}

- (void)seekToTime:(double)time
{
	//Need to reset everything's buffers, and then seek?
	/*HACK TO TEST HOW WELL THIS WOULD WORK*/
	[output seek:time];
	[bufferChain seek:time];
	/*END HACK*/
}

- (void)setVolume:(double)v
{
	volume = v;
	
	[output setVolume:v];
}

- (double)volume
{
	return volume;
}


//This is called by the delegate DURING a requestNextStream request.
- (void)setNextStream:(NSURL *)url
{
	[self setNextStream:url withUserInfo:nil];
}

- (void)setNextStream:(NSURL *)url withUserInfo:(id)userInfo
{
	[url retain];
	[nextStream release];
	nextStream = url;
	
	[userInfo retain];
	[nextStreamUserInfo release];
	nextStreamUserInfo = userInfo;
	
}

// Called when the playlist changed before we actually started playing a requested stream. We will re-request.
- (void)resetNextStreams
{
	@synchronized (chainQueue) {
		for (id anObject in chainQueue) {
			[anObject setShouldContinue:NO];
		}
		[chainQueue removeAllObjects];

		if (endOfInputReached) {
			[self endOfInputReached:bufferChain];
		} 
	}
}

- (void)setShouldContinue:(BOOL)s
{
	if (bufferChain)
		[bufferChain setShouldContinue:s];
		
	if (output)
		[output setShouldContinue:s];
}

- (double)amountPlayed
{
	return [output amountPlayed];
}

- (void)launchOutputThread
{
	if (outputLaunched == NO) {
		[self setPlaybackStatus:kCogStatusPlaying];	
		[output launchThread];
		outputLaunched = YES;
	}
}

- (void)requestNextStream:(id)userInfo
{
	[self sendDelegateMethod:@selector(audioPlayer:willEndStream:) withObject:userInfo waitUntilDone:YES];
}

- (void)notifyStreamChanged:(id)userInfo
{
	[self sendDelegateMethod:@selector(audioPlayer:didBeginStream:) withObject:userInfo waitUntilDone:NO];
}

- (void)addChainToQueue:(BufferChain *)newChain
{	
	[newChain setUserInfo: nextStreamUserInfo];
	
	[newChain setShouldContinue:YES];
	[newChain launchThreads];
	
	[chainQueue insertObject:newChain atIndex:[chainQueue count]];
}

- (BOOL)endOfInputReached:(BufferChain *)sender //Sender is a BufferChain
{
	@synchronized (chainQueue) {
        // No point in constructing new chain for the next playlist entry
        // if there's already one at the head of chainQueue... r-r-right?
        for (BufferChain *chain in chainQueue)
        {
            if ([chain isRunning])
            {
                return YES;
            }
        }

		BufferChain *newChain = nil;
		
		nextStreamUserInfo = [sender userInfo];
		[nextStreamUserInfo retain]; //Retained because when setNextStream is called, it will be released!!!
		
		[self requestNextStream: nextStreamUserInfo];
		newChain = [[BufferChain alloc] initWithController:self];

		endOfInputReached = YES;
		
		BufferChain *lastChain = [chainQueue lastObject];
		if (lastChain == nil) {
			lastChain = bufferChain;
		}
		
		if ([[nextStream scheme] isEqualToString:[[lastChain streamURL] scheme]]
			&& [[nextStream host] isEqualToString:[[lastChain streamURL] host]]
			&& [[nextStream path] isEqualToString:[[lastChain streamURL] path]])
		{
			if ([lastChain setTrack:nextStream] 
				&& [newChain openWithInput:[lastChain inputNode] withOutputFormat:[output format]])
			{
				[newChain setStreamURL:nextStream];
				[newChain setUserInfo:nextStreamUserInfo];

				[self addChainToQueue:newChain];
				DLog(@"TRACK SET!!! %@", newChain);
				//Keep on-playin
				[newChain release];
				
				return NO;
			}
		}
		
		while (![newChain open:nextStream withOutputFormat:[output format]]) 
		{
			if (nextStream == nil)
			{
				[newChain release];
				return YES;
			}
			
			[newChain release];
			[self requestNextStream: nextStreamUserInfo];

			newChain = [[BufferChain alloc] initWithController:self];
		}
		
		[self addChainToQueue:newChain];

		[newChain release];

        // I'm stupid and can't hold too much stuff in my head all at once, so writing it here.
        //
        // Once we get here:
        // - buffer chain for previous stream finished reading
        // - there are (probably) some bytes of the previous stream in the output buffer which haven't been played
        //   (by output node) yet
        // - self.bufferChain == previous playlist entry's buffer chain
        // - self.nextStream == next playlist entry's URL
        // - self.nextStreamUserInfo == next playlist entry
        // - head of chainQueue is the buffer chain for the next entry (which has launched its threads already)
	}
	
	return YES;
}

- (void)endOfInputPlayed
{
    // Once we get here:
    // - the buffer chain for the next playlist entry (started in endOfInputReached) have been working for some time
    //   already, so that there is some decoded and converted data to play
    // - the buffer chain for the next entry is the first item in chainQueue

	@synchronized(chainQueue) {
		endOfInputReached = NO;
		
		if ([chainQueue count] <= 0)
		{
			//End of playlist
			[self stop];
			
			[bufferChain release];
			bufferChain = nil;
			
			return;
		}

        BufferChain *oldChain = bufferChain;
        bufferChain = [chainQueue objectAtIndex:0];
		[oldChain release];
		[bufferChain retain];

        [chainQueue removeObjectAtIndex:0];
		DLog(@"New!!! %@ %@", bufferChain, [[bufferChain inputNode] decoder]);
	}
	
	[self notifyStreamChanged:[bufferChain userInfo]];
	[output setEndOfStream:NO];
}

- (void)sendDelegateMethod:(SEL)selector withObject:(id)obj waitUntilDone:(BOOL)wait
{
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:selector]];
	[invocation setSelector:selector];
	[invocation setArgument:&self	atIndex:2]; //Indexes start at 2, the first being self, the second being command.
	[invocation setArgument:&obj	atIndex:3];
	
	[self performSelectorOnMainThread:@selector(sendDelegateMethodMainThread:) withObject:invocation waitUntilDone:wait];
}

- (void)sendDelegateMethod:(SEL)selector withObject:(id)obj withObject:(id)obj2 waitUntilDone:(BOOL)wait
{
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:selector]];
	[invocation setSelector:selector];
	[invocation setArgument:&self	atIndex:2]; //Indexes start at 2, the first being self, the second being command.
	[invocation setArgument:&obj	atIndex:3];
	[invocation setArgument:&obj2	atIndex:4];
	
	[self performSelectorOnMainThread:@selector(sendDelegateMethodMainThread:) withObject:invocation waitUntilDone:wait];
}


- (void)sendDelegateMethodMainThread:(id)invocation
{
	[invocation invokeWithTarget:delegate];
}

- (void)setPlaybackStatus:(int)status waitUntilDone:(BOOL)wait
{	
	[self sendDelegateMethod:@selector(audioPlayer:didChangeStatus:userInfo:) withObject:[NSNumber numberWithInt:status] withObject:[bufferChain userInfo] waitUntilDone:wait];
}

- (void)setPlaybackStatus:(int)status
{	
	[self setPlaybackStatus:status waitUntilDone:NO];
}

- (BufferChain *)bufferChain
{
	return bufferChain;
}

- (OutputNode *) output
{
	return output;
}

+ (NSArray *)containerTypes
{
	return [[[PluginController sharedPluginController] containers] allKeys];
}

+ (NSArray *)fileTypes
{
	PluginController *pluginController = [PluginController sharedPluginController];
	
	NSArray *containerTypes = [[pluginController containers] allKeys];
	NSArray *decoderTypes = [[pluginController decodersByExtension] allKeys];
	NSArray *metdataReaderTypes = [[pluginController metadataReaders] allKeys];
	NSArray *propertiesReaderTypes = [[pluginController propertiesReadersByExtension] allKeys];
	
	NSMutableSet *types = [NSMutableSet set];
	
	[types addObjectsFromArray:containerTypes];
	[types addObjectsFromArray:decoderTypes];
	[types addObjectsFromArray:metdataReaderTypes];
	[types addObjectsFromArray:propertiesReaderTypes];
	
	return [types allObjects];
}

+ (NSArray *)schemes
{
	PluginController *pluginController = [PluginController sharedPluginController];
	
	return [[pluginController sources] allKeys];
}

- (double)volumeUp:(double)amount
{
	double newVolume = linearToLogarithmic(logarithmicToLinear(volume + amount));
	if (newVolume > MAX_VOLUME)
		newVolume = MAX_VOLUME;
	
	[self setVolume:newVolume];
	
	// the playbackController needs to know the new volume, so it can update the
	// volumeSlider accordingly.
	return newVolume;
}

- (double)volumeDown:(double)amount
{
	double newVolume;
	if (amount > volume)
		newVolume = 0.0;
	else
		newVolume = linearToLogarithmic(logarithmicToLinear(volume - amount));
	
	[self setVolume:newVolume];
	return newVolume;
}


@end
