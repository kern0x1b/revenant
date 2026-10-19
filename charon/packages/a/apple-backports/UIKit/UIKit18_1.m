#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation NSObject (CharonUIKit18_AccessibilityTextInputResponder)

static char CharonAccessibilityTextInputResponderKey;

- (id)accessibilityTextInputResponder
{
    return objc_getAssociatedObject(self, &CharonAccessibilityTextInputResponderKey);
}
- (void)setAccessibilityTextInputResponder:(id)responder
{
    objc_setAssociatedObject(self, &CharonAccessibilityTextInputResponderKey, responder,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char CharonAccessibilityTextInputResponderBlockKey;

- (id)accessibilityTextInputResponderBlock
{
    return objc_getAssociatedObject(self, &CharonAccessibilityTextInputResponderBlockKey);
}
- (void)setAccessibilityTextInputResponderBlock:(id)block
{
    objc_setAssociatedObject(self, &CharonAccessibilityTextInputResponderBlockKey, [block copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
