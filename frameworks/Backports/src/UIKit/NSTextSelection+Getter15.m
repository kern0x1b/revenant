#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation NSTextSelection (RevenantGetter15)

- (BOOL)logical
{
    return [self isLogical];
}

- (BOOL)transient
{
    return [self isTransient];
}

@end
