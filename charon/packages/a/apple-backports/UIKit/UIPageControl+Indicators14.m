#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_images_key, charon_preferred_key, charon_continuous_key, charon_background_key, charon_layers_key;

static IMP charon_release_layout;

static void charon_check_page(UIPageControl *control, NSInteger page)
{
    if (page < 0 || page >= control.numberOfPages)
        [NSException raise:NSInternalInconsistencyException format:@"Page (%ld) must be within 0 and %ld.", (long)page, (long)control.numberOfPages];
}

static CGPoint charon_dot_centre(UIPageControl *control, NSInteger page)
{
    NSInteger count = control.numberOfPages;
    CGFloat pitch = count > 1 ? ([control sizeForNumberOfPages:count].width - [control sizeForNumberOfPages:1].width) / (count - 1) : 0;
    CGRect bounds = control.bounds;
    return CGPointMake(CGRectGetMidX(bounds) + (page - (count - 1) / 2.0) * pitch, CGRectGetMidY(bounds));
}

static void charon_place_indicators(UIPageControl *control)
{
    NSArray *placed = objc_getAssociatedObject(control, &charon_layers_key);
    for (CALayer *layer in placed)
        [layer removeFromSuperlayer];
    NSMutableArray *layers = [NSMutableArray array];
    for (NSInteger page = 0; page < control.numberOfPages; page++) {
        UIImage *image = [control indicatorImageForPage:page] ?: control.preferredIndicatorImage;
        if (!image)
            continue;
        CALayer *layer = [CALayer layer];
        layer.bounds = CGRectMake(0, 0, image.size.width, image.size.height);
        layer.position = charon_dot_centre(control, page);
        layer.contents = (__bridge id)image.CGImage;
        layer.contentsScale = image.scale;
        [control.layer addSublayer:layer];
        [layers addObject:layer];
    }
    objc_setAssociatedObject(control, &charon_layers_key, layers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void charon_indicator_layout(UIPageControl *control, SEL selector)
{
    if (charon_release_layout)
        ((void (*)(id, SEL))charon_release_layout)(control, selector);
    charon_place_indicators(control);
}

__attribute__((constructor)) static void charon_install_indicator_layout(void)
{
    Method layout = class_getInstanceMethod([UIPageControl class], @selector(layoutSubviews));
    if (layout)
        charon_release_layout = class_replaceMethod([UIPageControl class], @selector(layoutSubviews), (IMP)charon_indicator_layout, method_getTypeEncoding(layout));
}

@implementation UIPageControl (CharonIndicators14)

- (UIImage *)indicatorImageForPage:(NSInteger)page
{
    charon_check_page(self, page);
    return [objc_getAssociatedObject(self, &charon_images_key) objectForKey:@(page)];
}

- (void)setIndicatorImage:(UIImage *)image forPage:(NSInteger)page
{
    charon_check_page(self, page);
    NSMutableDictionary *held = objc_getAssociatedObject(self, &charon_images_key);
    if (!held) {
        held = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &charon_images_key, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (image)
        held[@(page)] = image;
    else
        [held removeObjectForKey:@(page)];
    [self setNeedsLayout];
}

- (UIImage *)preferredIndicatorImage
{
    return objc_getAssociatedObject(self, &charon_preferred_key);
}

- (void)setPreferredIndicatorImage:(UIImage *)preferredIndicatorImage
{
    objc_setAssociatedObject(self, &charon_preferred_key, preferredIndicatorImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsLayout];
}

- (BOOL)allowsContinuousInteraction
{
    NSNumber *held = objc_getAssociatedObject(self, &charon_continuous_key);
    return held ? held.boolValue : YES;
}

- (void)setAllowsContinuousInteraction:(BOOL)allowsContinuousInteraction
{
    objc_setAssociatedObject(self, &charon_continuous_key, @(allowsContinuousInteraction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIPageControlBackgroundStyle)backgroundStyle
{
    return (UIPageControlBackgroundStyle)[objc_getAssociatedObject(self, &charon_background_key) integerValue];
}

- (void)setBackgroundStyle:(UIPageControlBackgroundStyle)backgroundStyle
{
    objc_setAssociatedObject(self, &charon_background_key, @(backgroundStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIPageControlInteractionState)interactionState
{
    return UIPageControlInteractionStateNone;
}

@end
