#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantContainerFrameKey;

static UIView *revenant_container_view(id container)
{
    for (NSUInteger depth = 0; container && depth < 64; depth++) {
        if ([container isKindOfClass:[UIView class]])
            return container;
        container = [container respondsToSelector:@selector(accessibilityContainer)] ? [container accessibilityContainer] : nil;
    }
    return nil;
}

@implementation UIAccessibilityElement (RevenantContainerSpace10)

- (CGRect)accessibilityFrameInContainerSpace
{
    NSValue *stored = objc_getAssociatedObject(self, &RevenantContainerFrameKey);
    return stored ? stored.CGRectValue : CGRectZero;
}

- (void)setAccessibilityFrameInContainerSpace:(CGRect)frame
{
    objc_setAssociatedObject(self, &RevenantContainerFrameKey, [NSValue valueWithCGRect:frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIView *view = revenant_container_view(self.accessibilityContainer);
    if (view)
        self.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(frame, view);
}

@end
