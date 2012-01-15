//
//  BlankZeroFormatter.m
//  Cog
//
//  Created by Vincent Spader on 3/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "BlankZeroFormatter.h"


@implementation BlankZeroFormatter

- (NSString *) stringForObjectValue:(id)object
{
	NSString *result  = @"";
	int value;

	if(nil != object && NO != [object isKindOfClass:[NSNumber class]]) {
		value = [object intValue];
        
        if (value) {
            result = [NSString stringWithFormat:@"%i", value];
        }
	}
	
	return result;
}

- (BOOL) getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString  **)error
{
	if(NULL != object) {
		*object = [NSNumber numberWithInt:[string intValue]];

		return YES;
	}
	
	return NO;
}

- (NSAttributedString *) attributedStringForObjectValue:(id)object withDefaultAttributes:(NSDictionary *)attributes
{
	NSAttributedString		*result		= nil;
	
	result = [[NSAttributedString alloc] initWithString:[self stringForObjectValue:object] attributes:attributes];
	return [result autorelease];
}

@end
