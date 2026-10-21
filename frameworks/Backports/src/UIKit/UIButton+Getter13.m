#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UIButton (RevenantGetter13)

- (BOOL)pointerInteractionEnabled
{
    return [self isPointerInteractionEnabled];
}

- (BOOL)hovered
{
    return [self isHovered];
}

@end
