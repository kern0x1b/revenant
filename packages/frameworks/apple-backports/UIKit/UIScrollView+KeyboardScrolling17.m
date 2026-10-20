#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantAllowsKeyboardScrollingKey;

@implementation UIScrollView (RevenantKeyboardScrolling17)

- (BOOL)allowsKeyboardScrolling
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantAllowsKeyboardScrollingKey);
    return stored ? stored.boolValue : YES;
}

- (void)setAllowsKeyboardScrolling:(BOOL)allowsKeyboardScrolling
{
    objc_setAssociatedObject(self, &RevenantAllowsKeyboardScrollingKey,
                            @(allowsKeyboardScrolling), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
