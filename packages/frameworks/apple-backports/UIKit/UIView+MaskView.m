#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char revenant_mask_view_key;

@implementation UIView (RevenantMaskView)

- (UIView *)maskView
{
    return objc_getAssociatedObject(self, &revenant_mask_view_key);
}

- (void)setMaskView:(UIView *)maskView
{
    UIView *current = objc_getAssociatedObject(self, &revenant_mask_view_key);
    if (maskView == current)
        return;
    if (maskView == self)
        [NSException raise:NSInvalidArgumentException format:@"Can't add self as subview"];
    if (current && self.layer.mask == current.layer)
        self.layer.mask = nil;
    objc_setAssociatedObject(self, &revenant_mask_view_key, maskView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (maskView) {
        [maskView removeFromSuperview];
        self.layer.mask = maskView.layer;
    }
}

@end
