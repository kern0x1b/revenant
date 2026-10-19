#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

CALayerCornerCurve const kCACornerCurveCircular = @"circular";
CALayerCornerCurve const kCACornerCurveContinuous = @"continuous";

static const char RevenantCornerCurveKey;
static const char RevenantSquircleMaskKey;
static const char RevenantSquircleShapeKey;

static CGPathRef revenant_squircle_path(CGRect rect, CGFloat radius)
{
    CGFloat a = MIN(1.34f * radius, MIN(rect.size.width, rect.size.height) / 2), k = 0.23f * a;
    CGFloat minX = CGRectGetMinX(rect), minY = CGRectGetMinY(rect), maxX = CGRectGetMaxX(rect), maxY = CGRectGetMaxY(rect);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, minX + a, minY);
    CGPathAddLineToPoint(path, NULL, maxX - a, minY);
    CGPathAddCurveToPoint(path, NULL, maxX - a + k, minY, maxX, minY + a - k, maxX, minY + a);
    CGPathAddLineToPoint(path, NULL, maxX, maxY - a);
    CGPathAddCurveToPoint(path, NULL, maxX, maxY - a + k, maxX - a + k, maxY, maxX - a, maxY);
    CGPathAddLineToPoint(path, NULL, minX + a, maxY);
    CGPathAddCurveToPoint(path, NULL, minX + a - k, maxY, minX, maxY - a + k, minX, maxY - a);
    CGPathAddLineToPoint(path, NULL, minX, minY + a);
    CGPathAddCurveToPoint(path, NULL, minX, minY + a - k, minX + a - k, minY, minX + a, minY);
    CGPathCloseSubpath(path);
    return path;
}

void revenant_layer_refresh_corner_curve(CALayer *layer)
{
    CAShapeLayer *ours = objc_getAssociatedObject(layer, &RevenantSquircleMaskKey);
    BOOL continuous = objc_getAssociatedObject(layer, &RevenantCornerCurveKey) != nil;
    BOOL wanted = continuous && layer.cornerRadius > 0 && layer.masksToBounds && (layer.mask == nil || layer.mask == ours);
    if (!wanted) {
        if (ours && layer.mask == ours)
            layer.mask = nil;
        return;
    }
    if (!ours) {
        ours = [CAShapeLayer layer];
        ours.fillColor = [UIColor blackColor].CGColor;
        objc_setAssociatedObject(layer, &RevenantSquircleMaskKey, ours, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSValue *shape = [NSValue valueWithCGRect:CGRectMake(layer.bounds.size.width, layer.bounds.size.height, layer.cornerRadius, 0)];
    if (layer.mask != ours || ![shape isEqual:objc_getAssociatedObject(ours, &RevenantSquircleShapeKey)]) {
        CGPathRef path = revenant_squircle_path(layer.bounds, layer.cornerRadius);
        ours.frame = layer.bounds;
        ours.path = path;
        CGPathRelease(path);
        objc_setAssociatedObject(ours, &RevenantSquircleShapeKey, shape, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (layer.mask != ours)
            layer.mask = ours;
    }
}

static void revenant_swap(SEL selector, IMP (^make)(IMP original))
{
    Method method = class_getInstanceMethod([CALayer class], selector);
    IMP original = method_getImplementation(method);
    method_setImplementation(method, make(original));
}

static void revenant_install_squircle_hooks(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_swap(@selector(layoutSublayers), ^IMP(IMP original) {
            return imp_implementationWithBlock(^(CALayer *self) {
                ((void (*)(CALayer *, SEL))original)(self, @selector(layoutSublayers));
                if (objc_getAssociatedObject(self, &RevenantCornerCurveKey))
                    revenant_layer_refresh_corner_curve(self);
            });
        });
        revenant_swap(@selector(setCornerRadius:), ^IMP(IMP original) {
            return imp_implementationWithBlock(^(CALayer *self, CGFloat radius) {
                ((void (*)(CALayer *, SEL, CGFloat))original)(self, @selector(setCornerRadius:), radius);
                if (objc_getAssociatedObject(self, &RevenantCornerCurveKey))
                    revenant_layer_refresh_corner_curve(self);
            });
        });
        revenant_swap(@selector(setMasksToBounds:), ^IMP(IMP original) {
            return imp_implementationWithBlock(^(CALayer *self, BOOL masks) {
                ((void (*)(CALayer *, SEL, BOOL))original)(self, @selector(setMasksToBounds:), masks);
                if (objc_getAssociatedObject(self, &RevenantCornerCurveKey))
                    revenant_layer_refresh_corner_curve(self);
            });
        });
        revenant_swap(@selector(setBounds:), ^IMP(IMP original) {
            return imp_implementationWithBlock(^(CALayer *self, CGRect bounds) {
                ((void (*)(CALayer *, SEL, CGRect))original)(self, @selector(setBounds:), bounds);
                if (objc_getAssociatedObject(self, &RevenantCornerCurveKey))
                    revenant_layer_refresh_corner_curve(self);
            });
        });
    });
}

@implementation CALayer (RevenantCornerCurve)

- (CALayerCornerCurve)cornerCurve
{
    return objc_getAssociatedObject(self, &RevenantCornerCurveKey) ?: kCACornerCurveCircular;
}

- (void)setCornerCurve:(CALayerCornerCurve)cornerCurve
{
    BOOL continuous = [cornerCurve isEqual:kCACornerCurveContinuous];
    objc_setAssociatedObject(self, &RevenantCornerCurveKey, continuous ? kCACornerCurveContinuous : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (continuous)
        revenant_install_squircle_hooks();
    revenant_layer_refresh_corner_curve(self);
}

@end
