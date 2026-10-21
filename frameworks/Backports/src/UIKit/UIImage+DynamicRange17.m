#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIImage (RevenantDynamicRange17)

- (BOOL)isHighDynamicRange
{
    return NO;
}

- (UIImage *)imageRestrictedToStandardDynamicRange
{
    return self;
}

@end
