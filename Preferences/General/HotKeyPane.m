//
//  HotKeyPane.m
//  Preferences
//
//  Created by Vincent Spader on 9/4/06.
//  Copyright 2006 Vincent Spader. All rights reserved.
//

#import "HotKeyPane.h"
#import "NDHotKeyEvent.h"

@implementation HotKeyPane

- (void)awakeFromNib
{
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object: [view window]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object: [view window]];
	
	[prevHotKeyControl updateStringValue];
	
	[nextHotKeyControl updateStringValue];
	
	[playHotKeyControl updateStringValue];
}

- (NSString *)title
{
	return NSLocalizedStringFromTableInBundle(@"Hot Keys", nil, [NSBundle bundleForClass:[self class]], @""); 
}

- (NSImage *)icon
{
	return [[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:@"hot_keys"]] autorelease];
}

/*- (void)windowDidBecomeKey:(id)notification
{
	if ([notification object] == [view window]) {
		[playHotKeyControl startObserving];
		[prevHotKeyControl startObserving];
		[nextHotKeyControl startObserving];
	}
}
*/
- (void)windowDidResignKey:(id)notification
{
	if ([notification object] == [view window]) {
		[playHotKeyControl stopObserving];
		[prevHotKeyControl stopObserving];
		[nextHotKeyControl stopObserving];
	}
}

- (IBAction) grabPlayHotKey:(id)sender
{
	[playHotKeyControl startObserving];
}

- (IBAction) grabPrevHotKey:(id)sender
{
	[prevHotKeyControl startObserving];
}

- (IBAction) grabNextHotKey:(id)sender
{
	[nextHotKeyControl startObserving];
}

- (IBAction) hotKeyChanged:(id)sender
{
	if (sender == playHotKeyControl) {
		[[NSUserDefaults standardUserDefaults] setInteger:[playHotKeyControl character] forKey:@"hotKeyPlayCharacter"];
		[[NSUserDefaults standardUserDefaults] setInteger:[playHotKeyControl modifierFlags] forKey:@"hotKeyPlayModifiers"];
		[[NSUserDefaults standardUserDefaults] setInteger:[playHotKeyControl keyCode] forKey:@"hotKeyPlayKeyCode"];
	}
	else if (sender == prevHotKeyControl) {
		[[NSUserDefaults standardUserDefaults] setInteger:[prevHotKeyControl character] forKey:@"hotKeyPreviousCharacter"];
		[[NSUserDefaults standardUserDefaults] setInteger:[prevHotKeyControl modifierFlags] forKey:@"hotKeyPreviousModifiers"];
		[[NSUserDefaults standardUserDefaults] setInteger:[prevHotKeyControl keyCode] forKey:@"hotKeyPreviousKeyCode"];
	}
	else if (sender == nextHotKeyControl) {
		[[NSUserDefaults standardUserDefaults] setInteger:[nextHotKeyControl character] forKey:@"hotKeyNextCharacter"];
		[[NSUserDefaults standardUserDefaults] setInteger:[nextHotKeyControl modifierFlags] forKey:@"hotKeyNextModifiers"];
		[[NSUserDefaults standardUserDefaults] setInteger:[nextHotKeyControl keyCode] forKey:@"hotKeyNextKeyCode"];
	}
	
	[sender stopObserving];
}

@end
