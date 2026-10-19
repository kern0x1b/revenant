#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_style_key;

@implementation UIVibrancyEffect (RevenantStyle13)

+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect style:(UIVibrancyEffectStyle)style
{
    UIVibrancyEffect *effect = [self effectForBlurEffect:blurEffect];
    objc_setAssociatedObject(effect, &revenant_style_key, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return effect;
}

@end
