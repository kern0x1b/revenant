#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char RevenantPointerInteractionKey;
static const char RevenantPointerStyleProviderKey;

@implementation UIButton (RevenantPointer)

- (BOOL)isPointerInteractionEnabled
{
    UIPointerInteraction *held = objc_getAssociatedObject(self, &RevenantPointerInteractionKey);
    return held.enabled;
}

- (void)setPointerInteractionEnabled:(BOOL)enabled
{
    UIPointerInteraction *held = objc_getAssociatedObject(self, &RevenantPointerInteractionKey);
    if (!held) {
        if (!enabled)
            return;
        held = [[UIPointerInteraction alloc] initWithDelegate:nil];
        objc_setAssociatedObject(self, &RevenantPointerInteractionKey, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self addInteraction:held];
    }
    held.enabled = enabled;
}

- (UIButtonPointerStyleProvider)pointerStyleProvider
{
    return objc_getAssociatedObject(self, &RevenantPointerStyleProviderKey);
}

- (void)setPointerStyleProvider:(UIButtonPointerStyleProvider)pointerStyleProvider
{
    objc_setAssociatedObject(self, &RevenantPointerStyleProviderKey, pointerStyleProvider, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (pointerStyleProvider)
        [self setPointerInteractionEnabled:YES];
}

@end
