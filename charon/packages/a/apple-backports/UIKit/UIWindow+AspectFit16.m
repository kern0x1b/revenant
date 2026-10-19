#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// UIWindow's safeAreaAspectFitLayoutGuide, iOS 16. A layout guide the window holds for the largest rectangle of a given width-to-height ratio
// that fits in its safe area, centred in it. Measured by tests/backports/host/layout-guides: with a ratio of 2 in a 1024 by 768 window the guide
// is 1024 by 512 at y 128, and the ratio defaults to 1. The guide's class on the host is a private one, _UIWindowSafeAreaAspectFitLayoutGuide;
// the port's is CharonAspectFitLayoutGuide, a named difference. The protocol UILayoutGuideAspectFitting has no registry row in this band, so
// the guide answers aspectRatio without declaring the protocol.
@interface CharonAspectFitLayoutGuide : UILayoutGuide {
@public
    CGFloat _aspectRatio;
    NSLayoutConstraint *_ratioConstraint;
}
- (void)charon_setRatioConstraint;
@end

@implementation CharonAspectFitLayoutGuide

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
        [self charon_setRatioConstraint];
}

- (void)charon_setRatioConstraint
{
    _ratioConstraint.active = NO;
    _ratioConstraint = [self.widthAnchor constraintEqualToAnchor:self.heightAnchor multiplier:_aspectRatio];
    _ratioConstraint.active = YES;
}

@end

static char charon_aspect_fit_guide_key;

@implementation UIWindow (CharonAspectFitLayoutGuide)

- (UILayoutGuide *)safeAreaAspectFitLayoutGuide
{
    CharonAspectFitLayoutGuide *guide = objc_getAssociatedObject(self, &charon_aspect_fit_guide_key);
    if (!guide) {
        guide = [[CharonAspectFitLayoutGuide alloc] init];
        [self addLayoutGuide:guide];
        UILayoutGuide *safe = self.safeAreaLayoutGuide;
        // The guide stays inside the safe area and is centred in it. Its size is the safe area's own, as far as the ratio allows: the two
        // size constraints at 750 yield to the ratio, which is required, and the bounds are required, so the fit is the largest that holds.
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
        [guide charon_setRatioConstraint];
        objc_setAssociatedObject(self, &charon_aspect_fit_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return guide;
}

@end
