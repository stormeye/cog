//
//  HotKeyControl.m
//  General
//
//  Created by Zaphod Beeblebrox on 9/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "HotKeyControl.h"
#import "NDHotKeyEvent.h"

@implementation HotKeyControl

- (void)awakeFromNib
{
	observing = NO;
}

- (void)startObserving
{	
	observing = YES;
	[self setStringValue:NSLocalizedStringFromTableInBundle(@"Press Key...", nil, [NSBundle bundleForClass:[self class]], @"")];
    [self setRequiresModifierKeys:YES];
    [self setReadyForHotKeyEvent:YES];
}

- (void)stopObserving
{	
	observing = NO;
    [self setReadyForHotKeyEvent:NO]; // will have been set so automagically, but just in case.
	[self updateStringValue];
}	

- (BOOL)becomeFirstResponder
{
	[self startObserving];
	
	return YES;
}

- (BOOL)resignFirstResponder
{
	[self stopObserving];
	
	return YES;
}

- (BOOL)performKeyEquivalent:(NSEvent*)anEvent
{
	if (observing == YES)
	{
		return [super performKeyEquivalent:anEvent];
	}
	else
	{
		return NO;
	}
}

- (void)keyDown:(NSEvent *)theEvent
{
	if (observing == YES)
	{
		[super keyDown:theEvent];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[self startObserving];
}

- (void)updateStringValue
{
    NSUInteger mf = [self modifierFlags];
    UInt16 kc = [self keyCode];
    NDHotKeyEvent *event = [NDHotKeyEvent getHotKeyForKeyCode:kc modifierFlags:mf];
	NSString *str = [event stringValue];
    [self setStringValue:str];
}

- (void)setKeyCode:(UInt16)kc
{
    keyCode = kc;
}

- (void)setModifierFlags:(NSUInteger)mf
{
    modifierFlags = mf;
}
@end
