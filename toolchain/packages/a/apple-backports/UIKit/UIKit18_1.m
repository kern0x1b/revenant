#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation NSObject (RevenantUIKit18_AccessibilityTextInputResponder)

static char RevenantAccessibilityTextInputResponderKey;

- (id)accessibilityTextInputResponder
{
    return objc_getAssociatedObject(self, &RevenantAccessibilityTextInputResponderKey);
}
- (void)setAccessibilityTextInputResponder:(id)responder
{
    objc_setAssociatedObject(self, &RevenantAccessibilityTextInputResponderKey, responder,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char RevenantAccessibilityTextInputResponderBlockKey;

- (id)accessibilityTextInputResponderBlock
{
    return objc_getAssociatedObject(self, &RevenantAccessibilityTextInputResponderBlockKey);
}
- (void)setAccessibilityTextInputResponderBlock:(id)block
{
    objc_setAssociatedObject(self, &RevenantAccessibilityTextInputResponderBlockKey, [block copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
