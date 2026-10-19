#import <Foundation/Foundation.h>

@implementation NSArray (CharonFirstObject)

- (id)firstObject
{
    return self.count ? [self objectAtIndex:0] : nil;
}

@end
