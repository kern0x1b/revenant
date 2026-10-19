#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_style_key;

@implementation UIVibrancyEffect (CharonStyle13)

+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect style:(UIVibrancyEffectStyle)style
{
    UIVibrancyEffect *effect = [self effectForBlurEffect:blurEffect];
    objc_setAssociatedObject(effect, &charon_style_key, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return effect;
}

@end
