#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantHoverStyleKey;

@implementation UIView (RevenantHoverStyle17)

- (UIHoverStyle *)hoverStyle
{
    return objc_getAssociatedObject(self, &RevenantHoverStyleKey);
}

- (void)setHoverStyle:(UIHoverStyle *)hoverStyle
{
    objc_setAssociatedObject(self, &RevenantHoverStyleKey, hoverStyle, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
