#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
