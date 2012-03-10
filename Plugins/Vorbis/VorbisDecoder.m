//
//  VorbisFile.m
//  zyVorbis
//
//  Created by Vincent Spader on 1/22/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import "VorbisDecoder.h"

#import "Logging.h"

@implementation VorbisDecoder

size_t sourceRead(void *buf, size_t size, size_t nmemb, void *datasource)
{
	id source = (id)datasource;

	return [source read:buf amount:(size*nmemb)];
}

int sourceSeek(void *datasource, ogg_int64_t offset, int whence)
{
	id source = (id)datasource;
	return ([source seek:offset whence:whence] ? 0 : -1);
}

int sourceClose(void *datasource)
{
	id source = (id)datasource;
	[source close];

	return 0;
}

long sourceTell(void *datasource)
{
	id source = (id)datasource;

	return [source tell];
}

- (BOOL)open:(id<CogSource>)s
{
	source = [s retain];
	
	ov_callbacks callbacks = {
		.read_func =  sourceRead,
		.seek_func =  sourceSeek,
		.close_func =  sourceClose,
		.tell_func =  sourceTell
	};
	
	if (ov_open_callbacks(source, &vorbisRef, NULL, 0, callbacks) != 0)
	{
		DLog(@"FAILED TO OPEN VORBIS FILE");
		return NO;
	}
	
	vorbis_info *vi;
	
	vi = ov_info(&vorbisRef, -1);
	
	bitsPerSample = vi->channels * 8;
	bitrate = (vi->bitrate_nominal/1000.0);
	channels = vi->channels;
	frequency = vi->rate;
	
	seekable = ov_seekable(&vorbisRef);
	
	totalFrames = ov_pcm_total(&vorbisRef, -1);

	[self willChangeValueForKey:@"properties"];
	[self didChangeValueForKey:@"properties"];
	
	return YES;
}

- (int)readAudio:(void *)buf frames:(UInt32)frames
{
	int numread;
	int total = 0;
	
	if (currentSection != lastSection) {
		vorbis_info *vi;
		vi = ov_info(&vorbisRef, -1);
		
		bitsPerSample = vi->channels * 8;
		bitrate = (vi->bitrate_nominal/1000.0);
		channels = vi->channels;
		frequency = vi->rate;
		
		[self willChangeValueForKey:@"properties"];
		[self didChangeValueForKey:@"properties"];
	}
	
	int size = frames * channels * (bitsPerSample/8);
	
    do {
		lastSection = currentSection;
		numread = ov_read(&vorbisRef, &((char *)buf)[total], size - total, 0, bitsPerSample/8, 1, &currentSection);
		if (numread > 0) {
			total += numread;
		}
	
		if (currentSection != lastSection) {
			break;
		}
		
    } while (total != size && numread != 0);

    return total/(channels * (bitsPerSample/8));
}

- (void)close
{
	ov_clear(&vorbisRef);
	
	[source close];
	[source release];
}

- (long)seek:(long)frame
{
	ov_pcm_seek(&vorbisRef, frame);
	
	return frame;
}

- (NSDictionary *)properties
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:channels], @"channels",
		[NSNumber numberWithInt:bitsPerSample], @"bitsPerSample",
		[NSNumber numberWithFloat:frequency], @"sampleRate",
		[NSNumber numberWithDouble:totalFrames], @"totalFrames",
		[NSNumber numberWithInt:bitrate], @"bitrate",
		[NSNumber numberWithBool:([source seekable] && seekable)], @"seekable",
		nil];
}


+ (NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:@"ogg",nil];
}

+ (NSArray *)mimeTypes
{
	return [NSArray arrayWithObjects:@"application/ogg", @"application/x-ogg", @"audio/x-vorbis+ogg", nil];
}

@end
