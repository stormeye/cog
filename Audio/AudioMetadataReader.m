//
//  AudioMetadataReader.m
//  CogAudio
//
//  Created by Vincent Spader on 2/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "AudioMetadataReader.h"
#import "PluginController.h"

@implementation AudioMetadataReader

+ (NSDictionary *)metadataForURL:(NSURL *)url
{
    NSDictionary *pluginData = [[PluginController sharedPluginController] metadataForURL:url];
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:pluginData];
    NSImage *albumArt = [result objectForKey:@"albumArt"];
    if (nil == albumArt && [url isFileURL])
    {

        NSImage *img = [AudioMetadataReader getCachedAlbumArtFor:pluginData];
        if (nil == img)
        {
            img = [AudioMetadataReader getAlbumArtFromFileForURL:url metadata:result];
        }

        if (nil != img)
        {
            [result setValue:img forKey:@"albumArt"];
            [AudioMetadataReader cacheAlbumArtFor:result];
        }
    }
    return [NSDictionary dictionaryWithDictionary:result];
}

+ (NSImage *)getAlbumArtFromFileForURL:(NSURL *)url metadata:(NSDictionary *)metadata;
{
    // Try to load image from external file

    // If we find an appropriately-named image in this directory, it will
    // be tagged with the first image cache tag. Subsequent directory entries
    // may have a different tag, but an image search would result in the same
    // artwork.

    static NSString *lastImagePath = nil;
    static NSString *lastCacheTag = nil;

    NSImage *image = nil;
    NSString *imageCacheTag = [AudioMetadataReader makeCachedImageTagFor:metadata];

    NSString *path = [[url path] stringByDeletingLastPathComponent];

    if ([path isEqualToString:lastImagePath]) {
        // Use whatever image may have been stored with the initial tag for the path
        // (might be nil but no point scanning again)

        image = [NSImage imageNamed:lastCacheTag];
    } else {
        // Book-keeping...

        if (nil != lastImagePath)
            [lastImagePath release];

        lastImagePath = [path retain];

        if (nil != lastCacheTag)
            [lastCacheTag release];

        lastCacheTag = [imageCacheTag retain];

        // Gather list of candidate image files

        NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
        NSArray *imageFileNames = [fileNames pathsMatchingExtensions:[NSImage imageFileTypes]];

        NSEnumerator *imageEnumerator = [imageFileNames objectEnumerator];
        NSString *fileName;

        while (fileName = [imageEnumerator nextObject]) {
            if ([AudioMetadataReader isCoverFile:fileName]) {
                image = [[[NSImage alloc] initByReferencingFile:[path stringByAppendingPathComponent:fileName]] autorelease];
                [image setName:imageCacheTag];
                break;
            }
        }
    }

    return image;
}

+ (NSImage *)getCachedAlbumArtFor:(NSDictionary *)metadata
{
    return [NSImage imageNamed:[AudioMetadataReader makeCachedImageTagFor:metadata]];
}

+ (void)cacheAlbumArtFor:(NSDictionary *)metadata
{
    NSImage *albumArt = [metadata objectForKey:@"albumArt"];
    if (nil != albumArt)
    {
        [albumArt setName:[AudioMetadataReader makeCachedImageTagFor:metadata]];
    }
}

+ (NSString *)makeCachedImageTagFor:(NSDictionary *)metadata
{
    NSString *imageCacheTag = [NSString stringWithFormat:@"%@-%@-%@-%@", [metadata objectForKey:@"album"],
                                                                         [metadata objectForKey:@"artist"],
                                                                         [metadata objectForKey:@"genre"],
                                                                         [metadata objectForKey:@"year"]];
    return imageCacheTag;
}

+ (BOOL)isCoverFile:(NSString *)fileName
{
    NSEnumerator *coverEnumerator = [[AudioMetadataReader coverNames] objectEnumerator];
    NSString *coverFileName;

    while (coverFileName = [coverEnumerator nextObject]) {
        if ([[[[fileName lastPathComponent] stringByDeletingPathExtension] lowercaseString] hasSuffix:coverFileName]) {
            return true;
        }
    }
    return false;

}

+ (NSArray *)coverNames
{
    return [NSArray arrayWithObjects:@"cover", @"folder", @"album", @"front", nil];
}
@end
