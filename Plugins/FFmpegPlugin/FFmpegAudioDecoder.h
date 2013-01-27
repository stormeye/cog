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

@interface FFmpegAudioDecoder : NSObject <CogDecoder>
{
	
	int channels;
	int bitsPerSample;
	float frequency;
	long totalFrames;
    int bitrate;
    
@private
    id<CogSource> source;
    AVFormatContext *formatCtx;
    AVCodecContext *codecCtx;
    AVFrame *lastDecodedFrame;
    AVPacket *lastReadPacket;
    int bytesConsumedFromDecodedFrame;
    int bytesReadFromPacket;
    BOOL readNextPacket;
}

- (void)setSource:(id<CogSource>)s;
- (id<CogSource>)source;

@end
