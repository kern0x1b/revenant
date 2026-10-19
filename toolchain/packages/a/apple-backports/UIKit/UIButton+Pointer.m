#import "CharonMenus.h"
#import <objc/runtime.h>

static const char CharonPointerInteractionKey;
static const char CharonPointerStyleProviderKey;

@implementation UIButton (CharonPointer)

- (BOOL)isPointerInteractionEnabled
{
    UIPointerInteraction *held = objc_getAssociatedObject(self, &CharonPointerInteractionKey);
    return held.enabled;
}

- (void)setPointerInteractionEnabled:(BOOL)enabled
{
    UIPointerInteraction *held = objc_getAssociatedObject(self, &CharonPointerInteractionKey);
    if (!held) {
        if (!enabled)
            return;
        held = [[UIPointerInteraction alloc] initWithDelegate:nil];
        objc_setAssociatedObject(self, &CharonPointerInteractionKey, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self addInteraction:held];
    }
    held.enabled = enabled;
}

- (UIButtonPointerStyleProvider)pointerStyleProvider
{
    return objc_getAssociatedObject(self, &CharonPointerStyleProviderKey);
}

- (void)setPointerStyleProvider:(UIButtonPointerStyleProvider)pointerStyleProvider
{
    objc_setAssociatedObject(self, &CharonPointerStyleProviderKey, pointerStyleProvider, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (pointerStyleProvider)
        [self setPointerInteractionEnabled:YES];
}

@end
