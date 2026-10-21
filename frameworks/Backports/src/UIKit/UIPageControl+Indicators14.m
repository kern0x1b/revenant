#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_images_key, revenant_preferred_key, revenant_continuous_key, revenant_background_key, revenant_layers_key;
static const char revenant_current_images_key, revenant_preferred_current_key, revenant_direction_key;

static IMP revenant_release_layout;
static IMP revenant_release_set_page;

static void revenant_check_page(UIPageControl *control, NSInteger page)
{
    if (page < 0 || page >= control.numberOfPages)
        [NSException raise:NSInternalInconsistencyException format:@"Page (%ld) must be within 0 and %ld.", (long)page, (long)control.numberOfPages];
}

static CGPoint revenant_dot_centre(UIPageControl *control, NSInteger page)
{
    NSInteger count = control.numberOfPages;
    CGFloat pitch = count > 1 ? ([control sizeForNumberOfPages:count].width - [control sizeForNumberOfPages:1].width) / (count - 1) : 0;
    CGRect bounds = control.bounds;
    CGFloat offset = (page - (count - 1) / 2.0) * pitch;
    switch (control.direction) {
    case UIPageControlDirectionRightToLeft:
        return CGPointMake(CGRectGetMidX(bounds) - offset, CGRectGetMidY(bounds));
    case UIPageControlDirectionTopToBottom:
        return CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds) + offset);
    case UIPageControlDirectionBottomToTop:
        return CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds) - offset);
    default:
        return CGPointMake(CGRectGetMidX(bounds) + offset, CGRectGetMidY(bounds));
    }
}

static void revenant_place_indicators(UIPageControl *control)
{
    NSArray *placed = objc_getAssociatedObject(control, &revenant_layers_key);
    for (CALayer *layer in placed)
        [layer removeFromSuperlayer];
    NSMutableArray *layers = [NSMutableArray array];
    for (NSInteger page = 0; page < control.numberOfPages; page++) {
        UIImage *image = (page == control.currentPage ? [control currentPageIndicatorImageForPage:page] ?: control.preferredCurrentPageIndicatorImage : nil) ?: [control indicatorImageForPage:page] ?: control.preferredIndicatorImage;
        if (!image)
            continue;
        CALayer *layer = [CALayer layer];
        layer.bounds = CGRectMake(0, 0, image.size.width, image.size.height);
        layer.position = revenant_dot_centre(control, page);
        layer.contents = (__bridge id)image.CGImage;
        layer.contentsScale = image.scale;
        [control.layer addSublayer:layer];
        [layers addObject:layer];
    }
    objc_setAssociatedObject(control, &revenant_layers_key, layers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void revenant_indicator_layout(UIPageControl *control, SEL selector)
{
    if (revenant_release_layout)
        ((void (*)(id, SEL))revenant_release_layout)(control, selector);
    revenant_place_indicators(control);
}

static void revenant_indicator_set_page(UIPageControl *control, SEL selector, NSInteger page)
{
    if (revenant_release_set_page)
        ((void (*)(id, SEL, NSInteger))revenant_release_set_page)(control, selector, page);
    if (objc_getAssociatedObject(control, &revenant_current_images_key) || objc_getAssociatedObject(control, &revenant_preferred_current_key))
        [control setNeedsLayout];
}

__attribute__((constructor)) static void revenant_install_indicator_layout(void)
{
    Method page = class_getInstanceMethod([UIPageControl class], @selector(setCurrentPage:));
    if (page)
        revenant_release_set_page = class_replaceMethod([UIPageControl class], @selector(setCurrentPage:), (IMP)revenant_indicator_set_page, method_getTypeEncoding(page));
    Method layout = class_getInstanceMethod([UIPageControl class], @selector(layoutSubviews));
    if (layout)
        revenant_release_layout = class_replaceMethod([UIPageControl class], @selector(layoutSubviews), (IMP)revenant_indicator_layout, method_getTypeEncoding(layout));
}

@implementation UIPageControl (RevenantIndicators14)

- (UIImage *)indicatorImageForPage:(NSInteger)page
{
    revenant_check_page(self, page);
    return [objc_getAssociatedObject(self, &revenant_images_key) objectForKey:@(page)];
}

- (void)setIndicatorImage:(UIImage *)image forPage:(NSInteger)page
{
    revenant_check_page(self, page);
    NSMutableDictionary *held = objc_getAssociatedObject(self, &revenant_images_key);
    if (!held) {
        held = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &revenant_images_key, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (image)
        held[@(page)] = image;
    else
        [held removeObjectForKey:@(page)];
    [self setNeedsLayout];
}

- (UIImage *)preferredIndicatorImage
{
    return objc_getAssociatedObject(self, &revenant_preferred_key);
}

- (void)setPreferredIndicatorImage:(UIImage *)preferredIndicatorImage
{
    objc_setAssociatedObject(self, &revenant_preferred_key, preferredIndicatorImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsLayout];
}

- (UIImage *)currentPageIndicatorImageForPage:(NSInteger)page
{
    revenant_check_page(self, page);
    return [objc_getAssociatedObject(self, &revenant_current_images_key) objectForKey:@(page)];
}

- (void)setCurrentPageIndicatorImage:(UIImage *)image forPage:(NSInteger)page
{
    revenant_check_page(self, page);
    NSMutableDictionary *held = objc_getAssociatedObject(self, &revenant_current_images_key);
    if (!held) {
        held = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &revenant_current_images_key, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (image)
        held[@(page)] = image;
    else
        [held removeObjectForKey:@(page)];
    [self setNeedsLayout];
}

- (UIImage *)preferredCurrentPageIndicatorImage
{
    return objc_getAssociatedObject(self, &revenant_preferred_current_key);
}

- (void)setPreferredCurrentPageIndicatorImage:(UIImage *)preferredCurrentPageIndicatorImage
{
    objc_setAssociatedObject(self, &revenant_preferred_current_key, preferredCurrentPageIndicatorImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsLayout];
}

- (UIPageControlDirection)direction
{
    return (UIPageControlDirection)[objc_getAssociatedObject(self, &revenant_direction_key) integerValue];
}

- (void)setDirection:(UIPageControlDirection)direction
{
    objc_setAssociatedObject(self, &revenant_direction_key, @(direction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsLayout];
}

- (BOOL)allowsContinuousInteraction
{
    NSNumber *held = objc_getAssociatedObject(self, &revenant_continuous_key);
    return held ? held.boolValue : YES;
}

- (void)setAllowsContinuousInteraction:(BOOL)allowsContinuousInteraction
{
    objc_setAssociatedObject(self, &revenant_continuous_key, @(allowsContinuousInteraction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIPageControlBackgroundStyle)backgroundStyle
{
    return (UIPageControlBackgroundStyle)[objc_getAssociatedObject(self, &revenant_background_key) integerValue];
}

- (void)setBackgroundStyle:(UIPageControlBackgroundStyle)backgroundStyle
{
    objc_setAssociatedObject(self, &revenant_background_key, @(backgroundStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIPageControlInteractionState)interactionState
{
    return UIPageControlInteractionStateNone;
}

@end
