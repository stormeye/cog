//
//  MonkeysFile.m
//  zyVorbis
//
//  Created by Vincent Spader on 1/30/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import "MonkeysAudioDecoder.h"

static int min(int a, int b) 
{
    if (a < b) { return a; } else { return b; }
}

@implementation MonkeysAudioDecoder

+ (void)initialize
{
    if(self == [MonkeysAudioDecoder class])
    {
        av_log_set_flags(AV_LOG_SKIP_REPEATED);
        avcodec_register_all();
        av_register_all();
        avformat_network_init();
    }
}

- (BOOL)open:(id<CogSource>)s
{	
	[self setSource:s];

    NSURL *srcUrl = [source url];
    NSString *urlString = NULL;
    if (YES == [srcUrl isFileURL]) 
    {
        urlString = [srcUrl path];
    } 
    else
    {
        urlString = [srcUrl absoluteString];
    }
    const char *cStrUrl = [urlString cStringUsingEncoding:NSUTF8StringEncoding];
    
    avFormatCtx = NULL;
    if(avformat_open_input(&avFormatCtx, cStrUrl, NULL, NULL) < 0)  
    {
		NSLog(@"ERROR OPENING FILE");
		return NO;
	}
    
    if(avformat_find_stream_info(avFormatCtx, NULL) < 0)
    {
        NSLog(@"CAN'T FIND STREAM INFO!");
        return NO;
    }
    
    int streamId = -1;
    for (int i=0; i<avFormatCtx->nb_streams; i++) 
    {
        if (1 == avFormatCtx->streams[i]->codec->codec_type)
        {
            streamId = i;
            break;
        }
    }
    
    codecCtx = avFormatCtx->streams[streamId]->codec;
    AVCodec* codec = avcodec_find_decoder(codecCtx->codec_id);

    if(avcodec_open(codecCtx, codec) < 0) 
    {
        NSLog(@"CAN'T FIND PROPER CODEC");
        return NO;
    }

	frequency = 44100;
	bitsPerSample = 16;
	channels = 2;
	totalFrames = -1;

	[self willChangeValueForKey:@"properties"];
	[self didChangeValueForKey:@"properties"];
	
    bufferSize = 0;
    bufferStart = 0;
    
	return YES;
}

- (int)readAudio:(void *)buf frames:(UInt32)frames
{
    AVPacket avPacket;
    int frameSize = channels * (bitsPerSample / 8);
    int bytesToWrite = frameSize * frames;
    int bytesWritten = 0;
    int8_t *targetBuf = (int8_t*) buf;
    int avcBufferSize = AVCODEC_MAX_AUDIO_FRAME_SIZE;
    while (bytesToWrite - bytesWritten > 0)
    {
        if (bufferSize > 0) 
        {
            int toCopy = min(bytesToWrite - bytesWritten, bufferSize);
            memmove((targetBuf + (bytesWritten)), (buffer + bufferStart), toCopy);
            bufferStart += toCopy;
            bufferSize -= toCopy;
            bytesWritten += toCopy;
        }
        
        if (0 == bufferSize) 
        {
            if(av_read_packet(avFormatCtx, &avPacket) < 0)
            {
                NSLog(@"End of stream");
                return (bytesWritten / frameSize); // end of stream;
            }
        
            if(avcodec_decode_audio3(codecCtx, (int16_t*) buffer, &avcBufferSize, &avPacket) < 0) 
            {
                NSLog(@"DECODE FAILED!");
                return bytesWritten / frameSize;
            }
            
            bufferStart = 0;
            bufferSize = avcBufferSize;
        }
    }
    
    return bytesWritten / frameSize;
}

- (void)close
{
    av_close_input_stream(avFormatCtx);
    [source close];
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
