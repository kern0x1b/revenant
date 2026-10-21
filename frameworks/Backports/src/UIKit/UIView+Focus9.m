#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIView (RevenantFocus9)

- (BOOL)isFocused
{
    return NO;
}

- (BOOL)focused
{
    return self.isFocused;
}

@end
