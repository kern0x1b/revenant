#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonAllowsKeyboardScrollingKey;

@implementation UIScrollView (CharonKeyboardScrolling17)

- (BOOL)allowsKeyboardScrolling
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonAllowsKeyboardScrollingKey);
    return stored ? stored.boolValue : YES;
}

- (void)setAllowsKeyboardScrolling:(BOOL)allowsKeyboardScrolling
{
    objc_setAssociatedObject(self, &CharonAllowsKeyboardScrollingKey,
                            @(allowsKeyboardScrolling), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
