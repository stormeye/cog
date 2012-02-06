//
//  HotKeyControl.h
//  General
//
//  Created by Zaphod Beeblebrox on 9/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NDHotKeyControl.h"

@interface HotKeyControl : NDHotKeyControl {
	BOOL observing;
}

- (void)startObserving;
- (void)stopObserving;

- (void)setModifierFlags:(NSUInteger)modifierFlags;
- (void)setKeyCode:(UInt16)keyCode;

- (void)updateStringValue;

@end
