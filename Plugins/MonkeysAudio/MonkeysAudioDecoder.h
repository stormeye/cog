//
//  MonkeysFile.h
//  zyVorbis
//
//  Created by Vincent Spader on 1/30/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import "Plugin.h"
#import <Cocoa/Cocoa.h>
#import <libavcodec/avcodec.h>

@interface MonkeysAudioDecoder : NSObject <CogDecoder>
{
	
	id<CogSource> source;
	
	int channels;
	int bitsPerSample;
	float frequency;
	long totalFrames;
}

- (void)setSource:(id<CogSource>)s;
- (id<CogSource>)source;

@end
