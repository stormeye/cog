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
#import <libavformat/avformat.h>

@interface MonkeysAudioDecoder : NSObject <CogDecoder>
{
	
	int channels;
	int bitsPerSample;
	float frequency;
	long totalFrames;
    
@private
    id<CogSource> source;
    AVFormatContext *avFormatCtx;
    AVCodecContext *codecCtx;
    int8_t buffer[AVCODEC_MAX_AUDIO_FRAME_SIZE];
    int bufferSize;
    int bufferStart;
}

- (void)setSource:(id<CogSource>)s;
- (id<CogSource>)source;

@end
