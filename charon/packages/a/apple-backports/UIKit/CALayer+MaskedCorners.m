#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const CACornerMask CharonAllCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;

static const char CharonMaskedCornersKey;
static const char CharonMaskedCornersMaskKey;
static const char CharonMaskedCornersShapeKey;

static CGPathRef charon_masked_corners_path(CGRect rect, CGFloat radius, CACornerMask mask)
{
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:(UIRectCorner)mask cornerRadii:CGSizeMake(radius, radius)];
    return CGPathRetain(path.CGPath);
}

void charon_layer_refresh_masked_corners(CALayer *layer)
{
    NSNumber *stored = objc_getAssociatedObject(layer, &CharonMaskedCornersKey);
    CACornerMask mask = stored ? stored.unsignedIntegerValue : CharonAllCorners;
    CAShapeLayer *ours = objc_getAssociatedObject(layer, &CharonMaskedCornersMaskKey);
    BOOL wanted = mask != CharonAllCorners && layer.cornerRadius > 0 && layer.masksToBounds && (layer.mask == nil || layer.mask == ours);
    if (!wanted) {
        if (ours && layer.mask == ours)
            layer.mask = nil;
        return;
    }
    if (!ours) {
        ours = [CAShapeLayer layer];
        ours.fillColor = [UIColor blackColor].CGColor;
        objc_setAssociatedObject(layer, &CharonMaskedCornersMaskKey, ours, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray *shape = @[NSStringFromCGRect(layer.bounds), @(layer.cornerRadius), @(mask)];
    if (layer.mask != ours || ![shape isEqual:objc_getAssociatedObject(ours, &CharonMaskedCornersShapeKey)]) {
        CGPathRef path = charon_masked_corners_path(layer.bounds, layer.cornerRadius, mask);
        ours.frame = layer.bounds;
        ours.path = path;
        CGPathRelease(path);
        objc_setAssociatedObject(ours, &CharonMaskedCornersShapeKey, shape, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (layer.mask != ours)
            layer.mask = ours;
    }
}

static void charon_swap_masked_corners(SEL selector, IMP (^make)(IMP original))
{
    Method method = class_getInstanceMethod([CALayer class], selector);
    IMP original = method_getImplementation(method);
    method_setImplementation(method, make(original));
}

static void charon_install_masked_corners_hooks(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_swap_masked_corners(@selector(layoutSublayers), ^IMP(IMP original) {
            return imp_implementationWithBlock(^(CALayer *self) {
                ((void (*)(CALayer *, SEL))original)(self, @selector(layoutSublayers));
                if (objc_getAssociatedObject(self, &CharonMaskedCornersKey))
                    charon_layer_refresh_masked_corners(self);
            });
        });
        charon_swap_masked_corners(@selector(setCornerRadius:), ^IMP(IMP original) {
            return imp_implementationWithBlock(^(CALayer *self, CGFloat radius) {
                ((void (*)(CALayer *, SEL, CGFloat))original)(self, @selector(setCornerRadius:), radius);
                if (objc_getAssociatedObject(self, &CharonMaskedCornersKey))
                    charon_layer_refresh_masked_corners(self);
            });
        });
        charon_swap_masked_corners(@selector(setMasksToBounds:), ^IMP(IMP original) {
            return imp_implementationWithBlock(^(CALayer *self, BOOL masks) {
                ((void (*)(CALayer *, SEL, BOOL))original)(self, @selector(setMasksToBounds:), masks);
                if (objc_getAssociatedObject(self, &CharonMaskedCornersKey))
                    charon_layer_refresh_masked_corners(self);
            });
        });
        charon_swap_masked_corners(@selector(setBounds:), ^IMP(IMP original) {
            return imp_implementationWithBlock(^(CALayer *self, CGRect bounds) {
                ((void (*)(CALayer *, SEL, CGRect))original)(self, @selector(setBounds:), bounds);
                if (objc_getAssociatedObject(self, &CharonMaskedCornersKey))
                    charon_layer_refresh_masked_corners(self);
            });
        });
    });
}

@implementation CALayer (CharonMaskedCorners)

- (CACornerMask)maskedCorners
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonMaskedCornersKey);
    return stored ? stored.unsignedIntegerValue : CharonAllCorners;
}

- (void)setMaskedCorners:(CACornerMask)maskedCorners
{
    objc_setAssociatedObject(self, &CharonMaskedCornersKey, maskedCorners == CharonAllCorners ? nil : @(maskedCorners), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_install_masked_corners_hooks();
    charon_layer_refresh_masked_corners(self);
}

@end
