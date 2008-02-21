//
//  FileTreeController.m
//  Cog
//
//  Created by Vincent Spader on 2/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FileTreeWindowController.h"


@implementation FileTreeWindowController

- (id)init
{
	return [super initWithWindowNibName:@"FileTreePanel"];
}

- (void)awakeFromNib
{
	[outlineView setDoubleAction:@selector(addToPlaylist:)];
	[outlineView setTarget:self];
}
	
- (IBAction)addToPlaylist:(id)sender
{
	unsigned int index;
	NSIndexSet *selectedIndexes = [outlineView selectedRowIndexes];
	NSMutableArray *urls = [[NSMutableArray alloc] init];

	for (index = [selectedIndexes firstIndex];
		 index != NSNotFound; index = [selectedIndexes indexGreaterThanIndex: index])  
	{
		[urls addObject:[[outlineView itemAtRow:index] URL]];
	}
	
	[playlistLoader addURLs:urls sort:NO];
	[urls release];
}

- (void)keyDown:(NSEvent *)e
{
    unsigned int   modifiers = [e modifierFlags] & (NSCommandKeyMask | NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask);
    NSString       *characters = [e characters];
	unichar        c;
	
	if ([characters length] != 1) 
	{
		[super keyDown:e];
		
		return;
	}
	
	c = [characters characterAtIndex:0];

	if (modifiers == 0 && (c == NSEnterCharacter || c == NSCarriageReturnCharacter))
	{
		[self addToPlaylist:self];
	}
	else
	{
		[super keyDown:e];
	}
}


@end
