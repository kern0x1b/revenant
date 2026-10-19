#import <Foundation/Foundation.h>

@implementation NSArray (RevenantFirstObject)

- (id)firstObject
{
    return self.count ? [self objectAtIndex:0] : nil;
}

@end
