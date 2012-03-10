//
//  SmartFolderNode.m
//  Cog
//
//  Created by Vincent Spader on 9/25/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "SmartFolderNode.h"
#import "DirectoryNode.h"
#import "FileNode.h"
#import "FileTreeDataSource.h"

#import "Logging.h"

@implementation SmartFolderNode

- (BOOL)isLeaf
{
	return NO;
}

- (void)updatePath
{
	NSDictionary *doc = [NSDictionary dictionaryWithContentsOfFile:[url path]];
	NSString *rawQuery = [doc objectForKey:@"RawQuery"];
	NSArray *searchPaths = [[doc objectForKey:@"SearchCriteria"] objectForKey:@"CurrentFolderPath"];
	
	// Ugh, Carbon from now on...
	MDQueryRef query = MDQueryCreate(kCFAllocatorDefault, (CFStringRef)rawQuery, NULL, NULL);
	
	MDQuerySetSearchScope(query, (CFArrayRef)searchPaths, 0);
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queryFinished:) name:(NSString*)kMDQueryDidFinishNotification object:(id)query];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queryUpdate:) name:(NSString*)kMDQueryDidUpdateNotification object:(id)query];

	DLog(@"Making query!");
	MDQueryExecute(query, kMDQueryWantsUpdates);
	
	//Note: This is asynchronous!
}

- (void)setSubpaths:(id)s
{
	[s retain];
	[subpaths release];
	subpaths = s;
}

- (unsigned int)countOfSubpaths
{
	return [[self subpaths] count];
}

- (PathNode *)objectInSubpathsAtIndex:(unsigned int)index
{
	return [[self subpaths] objectAtIndex:index];
}

- (void)queryFinished:(NSNotification *)notification
{
	DLog(@"Query finished!");
	MDQueryRef query = (MDQueryRef)[notification object];

	NSMutableArray *results = [NSMutableArray array];

	MDQueryDisableUpdates(query);
	int c = MDQueryGetResultCount(query);
	
	int i;
	for (i = 0; i < c; i++)
	{
		MDItemRef  item = (MDItemRef)MDQueryGetResultAtIndex(query, i);
		
		NSString *itemPath = (NSString*)MDItemCopyAttribute(item, kMDItemPath);

		[results addObject:itemPath];
		
		[itemPath release];
	}

	MDQueryEnableUpdates(query);
	
	DLog(@"Query update!");
	
	[self processPaths:[results sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
	
	[dataSource reloadPathNode:self];
}

- (void)queryUpdate:(NSNotification *)notification
{
	DLog(@"Query update!");
	[self queryFinished: notification];
}


@end

