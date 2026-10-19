#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_back_indicator_key;
static char charon_back_indicator_mask_key;
static char charon_bar_tint_key;

@implementation UINavigationBar (CharonBarAppearance)

- (UIImage *)backIndicatorImage
{
    return objc_getAssociatedObject(self, &charon_back_indicator_mask_key) ? objc_getAssociatedObject(self, &charon_back_indicator_key) : nil;
}

- (void)setBackIndicatorImage:(UIImage *)backIndicatorImage
{
    objc_setAssociatedObject(self, &charon_back_indicator_key, backIndicatorImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImage *)backIndicatorTransitionMaskImage
{
    return objc_getAssociatedObject(self, &charon_back_indicator_key) ? objc_getAssociatedObject(self, &charon_back_indicator_mask_key) : nil;
}

- (void)setBackIndicatorTransitionMaskImage:(UIImage *)backIndicatorTransitionMaskImage
{
    objc_setAssociatedObject(self, &charon_back_indicator_mask_key, backIndicatorTransitionMaskImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIColor *)barTintColor
{
    return objc_getAssociatedObject(self, &charon_bar_tint_key);
}

- (void)setBarTintColor:(UIColor *)barTintColor
{
    objc_setAssociatedObject(self, &charon_bar_tint_key, barTintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.tintColor = barTintColor;
}

@end
