//
//  MonkeysFile.m
//  zyVorbis
//
//  Created by Vincent Spader on 1/30/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import "MonkeysAudioDecoder.h"

@implementation MonkeysAudioDecoder

- (BOOL)open:(id<CogSource>)s
{	
	[self setSource:s];

		NSLog(@"ERROR OPENING FILE");
		return NO;
	
	frequency = 1;
	bitsPerSample = 2;
	channels = 3;

	totalFrames = 4;

	[self willChangeValueForKey:@"properties"];
	[self didChangeValueForKey:@"properties"];
	
	return YES;
}

- (int)readAudio:(void *)buf frames:(UInt32)frames
{
    return 0;
}

- (void)close
{
}

- (long)seek:(long)frame
{
}

- (void)setSource:(id<CogSource>)s
{
	[s retain];
	[source release];
	source = s;
}

- (id<CogSource>)source
{
	return source;
}

- (NSDictionary *)properties
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:channels],@"channels",
		[NSNumber numberWithInt:bitsPerSample],@"bitsPerSample",
		[NSNumber numberWithFloat:frequency],@"sampleRate",
		[NSNumber numberWithDouble:totalFrames],@"totalFrames",
		[NSNumber numberWithBool:[source seekable]], @"seekable",
		@"host",@"endian",
		nil];
}


+ (NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"ape"];
}

+ (NSArray *)mimeTypes
{
	return [NSArray arrayWithObjects:@"audio/x-ape", nil];
}

@end
