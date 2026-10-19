#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface RevenantAspectFitLayoutGuide : UILayoutGuide {
@public
    CGFloat _aspectRatio;
    NSLayoutConstraint *_ratioConstraint;
}
- (void)revenant_setRatioConstraint;
@end

@implementation RevenantAspectFitLayoutGuide

- (instancetype)init
{
    if ((self = [super init]))
        _aspectRatio = 1.0;
    return self;
}

- (CGFloat)aspectRatio
{
    return _aspectRatio;
}

- (void)setAspectRatio:(CGFloat)aspectRatio
{
    _aspectRatio = aspectRatio;
    if (self.owningView)
        [self revenant_setRatioConstraint];
}

- (void)revenant_setRatioConstraint
{
    _ratioConstraint.active = NO;
    _ratioConstraint = [self.widthAnchor constraintEqualToAnchor:self.heightAnchor multiplier:_aspectRatio];
    _ratioConstraint.active = YES;
}

@end

static char revenant_aspect_fit_guide_key;

@implementation UIWindow (RevenantAspectFitLayoutGuide)

- (UILayoutGuide *)safeAreaAspectFitLayoutGuide
{
    RevenantAspectFitLayoutGuide *guide = objc_getAssociatedObject(self, &revenant_aspect_fit_guide_key);
    if (!guide) {
        guide = [[RevenantAspectFitLayoutGuide alloc] init];
        [self addLayoutGuide:guide];
        UILayoutGuide *safe = self.safeAreaLayoutGuide;
        NSLayoutConstraint *fitWidth = [guide.widthAnchor constraintEqualToAnchor:safe.widthAnchor];
        NSLayoutConstraint *fitHeight = [guide.heightAnchor constraintEqualToAnchor:safe.heightAnchor];
        fitWidth.priority = 750;
        fitHeight.priority = 750;
        [NSLayoutConstraint activateConstraints:@[
            [guide.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
            [guide.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
            [guide.widthAnchor constraintLessThanOrEqualToAnchor:safe.widthAnchor],
            [guide.heightAnchor constraintLessThanOrEqualToAnchor:safe.heightAnchor],
            fitWidth,
            fitHeight]];
        [guide revenant_setRatioConstraint];
        objc_setAssociatedObject(self, &revenant_aspect_fit_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return guide;
}

@end
