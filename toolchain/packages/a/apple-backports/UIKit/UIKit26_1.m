#import "CharonUIKit26.h"
#import <objc/runtime.h>

@implementation UIPresentationController (CharonUIKit26_1)

static char CharonPresentationBackgroundEffectKey;

- (id)backgroundEffect { return objc_getAssociatedObject(self, &CharonPresentationBackgroundEffectKey); }
- (void)setBackgroundEffect:(id)effect
{
    objc_setAssociatedObject(self, &CharonPresentationBackgroundEffectKey, effect,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@interface UIColorEffect : UIVisualEffect
@end

@implementation UIColorEffect
@end

@implementation UIColorEffect (CharonUIKit26_1)
+ (UIColorEffect *)effectWithColor:(id)color
{
    return (UIColorEffect *)[[UIVisualEffect alloc] init];
}
@end
