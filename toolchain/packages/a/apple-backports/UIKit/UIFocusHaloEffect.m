#import <UIKit/UIKit.h>
#import <objc/message.h>

@implementation UIFocusHaloEffect {
    __weak UIView *_containerView;
    __weak UIView *_referenceView;
    UIFocusHaloEffectPosition _position;
}

+ (instancetype)revenant_halo
{
    return ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)(self, @selector(alloc)), @selector(init));
}

+ (instancetype)effectWithRect:(CGRect)rect
{
    return [self revenant_halo];
}

+ (instancetype)effectWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius curve:(CALayerCornerCurve)curve
{
    return [self revenant_halo];
}

+ (instancetype)effectWithPath:(UIBezierPath *)bezierPath
{
    return [self revenant_halo];
}

- (UIView *)containerView
{
    return _containerView;
}

- (void)setContainerView:(UIView *)containerView
{
    _containerView = containerView;
}

- (UIView *)referenceView
{
    return _referenceView;
}

- (void)setReferenceView:(UIView *)referenceView
{
    _referenceView = referenceView;
}

- (UIFocusHaloEffectPosition)position
{
    return _position;
}

- (void)setPosition:(UIFocusHaloEffectPosition)position
{
    _position = position;
}

@end
