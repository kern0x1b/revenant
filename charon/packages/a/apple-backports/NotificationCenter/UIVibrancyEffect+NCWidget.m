#import <UIKit/UIKit.h>
#import <NotificationCenter/NotificationCenter.h>

@interface UIVibrancyEffect (CharonStyle13)
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect style:(UIVibrancyEffectStyle)style;
@end

@implementation UIVibrancyEffect (NCWidgetAdditions)

+ (UIVibrancyEffect *)widgetEffectForVibrancyStyle:(UIVibrancyEffectStyle)vibrancyStyle
{
    return [self effectForBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] style:vibrancyStyle];
}

+ (UIVibrancyEffect *)widgetPrimaryVibrancyEffect
{
    return [self effectForBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] style:UIVibrancyEffectStyleLabel];
}

+ (UIVibrancyEffect *)widgetSecondaryVibrancyEffect
{
    return [self effectForBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] style:UIVibrancyEffectStyleSecondaryLabel];
}

+ (UIVibrancyEffect *)notificationCenterVibrancyEffect
{
    return [self effectForBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] style:UIVibrancyEffectStyleLabel];
}

@end
