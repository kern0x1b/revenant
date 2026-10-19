#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_mask_key;

@implementation UIPanGestureRecognizer (CharonScrollTypes134)

- (UIScrollTypeMask)allowedScrollTypesMask
{
    return (UIScrollTypeMask)[objc_getAssociatedObject(self, &charon_mask_key) integerValue];
}

- (void)setAllowedScrollTypesMask:(UIScrollTypeMask)allowedScrollTypesMask
{
    if (allowedScrollTypesMask)
        charon_menus_say_once(@"scroll-types", @"UIPanGestureRecognizer.allowedScrollTypesMask: this release has no pointing device with a scroll wheel or trackpad, so the mask is kept and no scroll event ever reaches the recogniser");
    objc_setAssociatedObject(self, &charon_mask_key, @(allowedScrollTypesMask), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
