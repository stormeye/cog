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

// TODO: use Cog's IO instead of ffmpeg's?
- (BOOL)open:(id<CogSource>)s
{	
    NSLog(@"We're OPEN!");
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
    
    formatCtx = NULL;
    if(avformat_open_input(&formatCtx, cStrUrl, NULL, NULL) < 0)  
    {
		NSLog(@"ERROR OPENING FILE");
		return NO;
	}
    
    if(avformat_find_stream_info(formatCtx, NULL) < 0)
    {
        NSLog(@"CAN'T FIND STREAM INFO!");
        return NO;
    }
    
    int streamId = -1;
    for (int i=0; i<formatCtx->nb_streams; i++) 
    {
        if (1 == formatCtx->streams[i]->codec->codec_type)
        {
            streamId = i;
            break;
        }
    }
    
    codecCtx = formatCtx->streams[streamId]->codec;
    codecCtx->request_sample_fmt = AV_SAMPLE_FMT_S32;
    AVCodec* codec = avcodec_find_decoder(codecCtx->codec_id);

    if(avcodec_open(codecCtx, codec) < 0) 
    {
        NSLog(@"CAN'T FIND PROPER CODEC");
        return NO;
    }

    lastDecodedFrame = avcodec_alloc_frame();
    avcodec_get_frame_defaults(lastDecodedFrame);
    lastReadPacket = malloc(sizeof(AVPacket));
    readNextPacket = YES;
    bytesConsumedFromDecodedFrame = 0;
    
	frequency = codecCtx->sample_rate;
	channels = codecCtx->channels;
    switch (codecCtx->sample_fmt)
    {
        case AV_SAMPLE_FMT_U8: bitsPerSample = 8; break;
        case AV_SAMPLE_FMT_S16: bitsPerSample = 16; break;
        case AV_SAMPLE_FMT_S32: bitsPerSample = 32; break;
        default: { NSLog(@"Unexpected sample format: %d", codecCtx->sample_fmt); return NO; }
    }
    totalFrames = codecCtx->sample_rate * (formatCtx->duration/1000000LL);
//    totalFrames = 0;
    
	[self willChangeValueForKey:@"properties"];
	[self didChangeValueForKey:@"properties"];
    
	return YES;
}

- (int)readAudio:(void *)buf frames:(UInt32)frames
{
    int frameSize = channels * (bitsPerSample / 8);
    int gotFrame = 0;
    int dataSize = 0;

    int bytesToRead = frames * frameSize;
    int bytesRead = 0;
    
    int8_t* targetBuf = (int8_t*) buf;
    memset(buf, 0, bytesToRead);

    while (bytesRead < bytesToRead) 
    {
        
        if(readNextPacket) 
        {
            // consume next chunk of encoded data from input stream
//            av_free_packet(lastReadPacket);
            if(av_read_frame(formatCtx, lastReadPacket) < 0)
            {
                NSLog(@"End of stream");
                break; // end of stream;
            }
            readNextPacket = NO; // we probably won't need to consume another chunk
                                 // until this one is fully decoded
        }
        
        // buffer size needed to hold decoded samples, in bytes
        dataSize = av_samples_get_buffer_size(NULL, codecCtx->channels,
                                              lastDecodedFrame->nb_samples,
                                              codecCtx->sample_fmt, 1);

        if (dataSize <= bytesConsumedFromDecodedFrame)  
        {
            // consumed all decoded samples - decode more
            avcodec_get_frame_defaults(lastDecodedFrame);
            int len = avcodec_decode_audio4(codecCtx, lastDecodedFrame, &gotFrame, lastReadPacket);
            if (len < 0 || (!gotFrame)) 
            {
                NSLog(@"Error decoding: len = %d, gotFrame = %d", len, gotFrame);
                break;
            } 
            else if (len >= lastReadPacket->size) 
            {
                // decoding consumed all the read packet - read another next time
                readNextPacket = YES;
            }
         
            bytesConsumedFromDecodedFrame = 0;
            dataSize = av_samples_get_buffer_size(NULL, codecCtx->channels,
                                                  lastDecodedFrame->nb_samples,
                                                  codecCtx->sample_fmt, 1);
        }
        
        // copy decoded samples to Cog's buffer
        int toConsume = min((dataSize - bytesConsumedFromDecodedFrame), (bytesToRead - bytesRead));
        memmove(targetBuf + bytesRead, (lastDecodedFrame->data[0] + bytesConsumedFromDecodedFrame), toConsume);
        bytesConsumedFromDecodedFrame += toConsume;
        bytesRead += toConsume;
    }

    return (bytesRead / frameSize);
}

- (void)close
{
    // TODO: figure out proper way to clean up (maybe just av_close_input_stream is sufficient?)
    //       uncommenting next two lines causes crashes :(
//    if (lastReadPacket) { av_free_packet(lastReadPacket); lastReadPacket = NULL; }
//    if (codecCtx) { av_free(codecCtx); codecCtx = NULL;}
    if (formatCtx) { av_close_input_stream(formatCtx); formatCtx = NULL; }

    [source close];
}

- (long)seek:(long)frame
{
    if (frame > totalFrames) { return -1; }
    int64_t ts = frame * (formatCtx->duration) / totalFrames; 
    avformat_seek_file(formatCtx, -1, ts - 1000, ts, ts, AVSEEK_FLAG_ANY);
    avcodec_flush_buffers(codecCtx);
    readNextPacket = YES; // so we immediately read next packet
    bytesConsumedFromDecodedFrame = AVCODEC_MAX_AUDIO_FRAME_SIZE; // so we immediately begin decoding next frame
    
    return frame;
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
