#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "../revenant_alias.h"

static const void *RevenantBackdropEffectKey = &RevenantBackdropEffectKey;

static const double RevenantBackdropClearRadius = 4.0;

static const CGFloat RevenantBackdropMinimumSide = 100.0;

REVENANT_ALIAS_STATE(CABackdropLayer, CALayer,
    double _revenantScale;
    BOOL _revenantDisabled;
    NSString *_revenantGroupName;
    NSArray *_revenantFilters;
)

@implementation REVENANT_ALIAS_CLASS(CABackdropLayer) (RevenantBackport)

- (instancetype)init
{
    if ((self = [super init])) {
        _revenantScale = 1.0;
    }
    return self;
}

- (double)scale
{
    return _revenantScale;
}

- (void)setScale:(double)scale
{
    _revenantScale = scale;
}

- (BOOL)enabled
{
    return !_revenantDisabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _revenantDisabled = !enabled;
    [self revenant_syncEffect];
}

- (NSString *)groupName
{
    return _revenantGroupName;
}

- (void)setGroupName:(NSString *)groupName
{
    _revenantGroupName = [groupName copy];
}

- (NSArray *)filters
{
    return _revenantFilters;
}

- (void)setFilters:(NSArray *)filters
{
    _revenantFilters = [filters copy];
    [self revenant_syncEffect];
}

- (UIView *)revenant_host
{
    id owner = self.superlayer.delegate;
    return [owner isKindOfClass:[UIView class]] ? owner : nil;
}

- (BOOL)revenant_blurStyle:(UIBlurEffectStyle *)style
{
    for (id filter in _revenantFilters) {
        if ([[filter valueForKey:@"name"] isEqual:@"gaussianBlur"]) {
            NSNumber *radius = [filter valueForKey:@"inputRadius"];
            *style = [radius doubleValue] > RevenantBackdropClearRadius ? UIBlurEffectStyleExtraLight : UIBlurEffectStyleLight;
            return YES;
        }
    }
    return NO;
}

- (void)revenant_removeEffect
{
    UIView *host = [self revenant_host];
    UIView *effect = host ? objc_getAssociatedObject(host, RevenantBackdropEffectKey) : nil;
    [effect removeFromSuperview];
    if (host) {
        objc_setAssociatedObject(host, RevenantBackdropEffectKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)revenant_syncEffect
{
    UIView *host = [self revenant_host];
    if (!host) {
        return;
    }
    UIBlurEffectStyle style;
    CGSize size = self.bounds.size;
    if (_revenantDisabled || MIN(size.width, size.height) < RevenantBackdropMinimumSide || ![self revenant_blurStyle:&style]) {
        [self revenant_removeEffect];
        return;
    }
    UIVisualEffectView *effect = objc_getAssociatedObject(host, RevenantBackdropEffectKey);
    if (!effect) {
        effect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
        effect.userInteractionEnabled = NO;
        objc_setAssociatedObject(host, RevenantBackdropEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    effect.frame = self.frame;
    if (effect.superview != host) {
        [host insertSubview:effect atIndex:0];
    }
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self revenant_syncEffect];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self revenant_syncEffect];
}

- (void)layoutSublayers
{
    [super layoutSublayers];
    [self revenant_syncEffect];
}

- (void)removeFromSuperlayer
{
    [self revenant_removeEffect];
    [super removeFromSuperlayer];
}

@end
