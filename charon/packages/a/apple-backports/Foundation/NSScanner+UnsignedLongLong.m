#import <Foundation/Foundation.h>
#include <limits.h>

@implementation NSScanner (CharonUnsignedLongLong)

- (BOOL)scanUnsignedLongLong:(unsigned long long *)result
{
    NSString *string = self.string;
    NSUInteger length = string.length, index = self.scanLocation;
    NSCharacterSet *skipped = self.charactersToBeSkipped;
    while (index < length && skipped && [skipped characterIsMember:[string characterAtIndex:index]])
        index++;
    if (index < length && [string characterAtIndex:index] == '+')
        index++;
    NSUInteger first = index;
    unsigned long long value = 0;
    BOOL overflow = NO;
    while (index < length) {
        unichar character = [string characterAtIndex:index];
        if (character < '0' || character > '9')
            break;
        unsigned long long digit = character - '0';
        if (value > (ULLONG_MAX - digit) / 10)
            overflow = YES;
        else
            value = value * 10 + digit;
        index++;
    }
    if (index == first)
        return NO;
    self.scanLocation = index;
    if (result)
        *result = overflow ? ULLONG_MAX : value;
    return YES;
}

@end
