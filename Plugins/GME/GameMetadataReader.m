//
//  GameMetadataReader.m
//  GME
//
//  Created by Vincent Spader on 10/12/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "GameMetadataReader.h"

#import "GameDecoder.h"

#import <GME/gme.h>

#import "Logging.h"

@implementation GameMetadataReader

+ (NSArray *)fileTypes
{
	return [GameDecoder fileTypes];
}

+ (NSArray *)mimeTypes
{
	return [GameDecoder mimeTypes];
}

+ (NSDictionary *)metadataForURL:(NSURL *)url
{
	if (![url isFileURL])
		return nil;

	NSString *ext = [[[url path] pathExtension] lowercaseString];
	
	gme_type_t type = gme_identify_extension([ext UTF8String]);
	if (!type) 
	{
		DLog(@"No type!");
		return NO;
	}
	
	Music_Emu* emu;
	emu = gme_new_emu(type, gme_info_only);
	if (!emu)
	{
		DLog(@"No new emu!");
		return NO;
	}
	
	gme_err_t error;
	error = gme_load_file(emu, [[url path] UTF8String]);
	if (error) 
	{
		DLog(@"ERROR Loding file!");
		return NO;
	}
	
	int track_num;
	if ([[url fragment] length] == 0)
		track_num = 0;
	else
		track_num = [[url fragment] intValue];
	
	gme_info_t *info;
	error = gme_track_info( emu, &info, track_num );
	if (error)
	{
		DLog(@"Unable to get track info");
	}
	
	gme_delete(emu);

	NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithUTF8String: info->system], @"genre",
		[NSString stringWithUTF8String: info->game], @"album",
		[NSString stringWithUTF8String: info->song], @"title",
		[NSString stringWithUTF8String: info->author], @"artist",
		[NSNumber numberWithInt:track_num+1], @"track",
		nil];
    
    free(info);
    return result;
}

@end
