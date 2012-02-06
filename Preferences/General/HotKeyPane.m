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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object: [view window]];
	
    UInt16 prevKeyCode = [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyPreviousKeyCode"];
    NSUInteger prevModifiers = [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyPreviousModifiers"];
    
    [prevHotKeyControl setKeyCode:prevKeyCode];
	[prevHotKeyControl setModifierFlags:prevModifiers];	
	[prevHotKeyControl updateStringValue];
	
    UInt16 nextKeyCode = [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyNextKeyCode"];
    NSUInteger nextModifiers = [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyNextModifiers"];
    
    [nextHotKeyControl setKeyCode:nextKeyCode];
	[nextHotKeyControl setModifierFlags:nextModifiers];	
	[nextHotKeyControl updateStringValue];
    
    UInt16 playKeyCode = [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyPlayKeyCode"];
    NSUInteger playModifiers = [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyPlayModifiers"];
    
    [playHotKeyControl setKeyCode:playKeyCode];
	[playHotKeyControl setModifierFlags:playModifiers];	
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
		[[NSUserDefaults standardUserDefaults] setInteger:[playHotKeyControl modifierFlags] forKey:@"hotKeyPlayModifiers"];
		[[NSUserDefaults standardUserDefaults] setInteger:[playHotKeyControl keyCode] forKey:@"hotKeyPlayKeyCode"];
	}
	else if (sender == prevHotKeyControl) {
		[[NSUserDefaults standardUserDefaults] setInteger:[prevHotKeyControl modifierFlags] forKey:@"hotKeyPreviousModifiers"];
		[[NSUserDefaults standardUserDefaults] setInteger:[prevHotKeyControl keyCode] forKey:@"hotKeyPreviousKeyCode"];
	}
	else if (sender == nextHotKeyControl) {
		[[NSUserDefaults standardUserDefaults] setInteger:[nextHotKeyControl modifierFlags] forKey:@"hotKeyNextModifiers"];
		[[NSUserDefaults standardUserDefaults] setInteger:[nextHotKeyControl keyCode] forKey:@"hotKeyNextKeyCode"];
	}
	
	[sender stopObserving];
}

@end
