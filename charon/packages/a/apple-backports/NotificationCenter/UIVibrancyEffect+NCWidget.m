#import <UIKit/UIKit.h>
#import <NotificationCenter/NotificationCenter.h>

// The four factories that name the vibrancy a widget is drawn with. The port's own
// UIVibrancyEffect is real and comparable and keeps the style it was made with
// (UIKit/UIVisualEffect.m, and the +effectForBlurEffect:style: of UIVibrancyEffect+Style13.m), so
// each of these builds a real effect with the material the header's own wording asks for and the
// answer compares and reads back as the system's does:
//
//   - the primary one, for the widget's supporting text and glyphs: the light material Notification
//     Center itself is drawn with, with UIVibrancyEffectStyleLabel - the style UIVibrancyEffect.h
//     documents as "vibrancy for text labels";
//   - the secondary one, "where further diminution is required": the same material with
//     UIVibrancyEffectStyleSecondaryLabel, the fainter of the two label styles, which is exactly the
//     diminution the header asks for;
//   - the iOS 8 notification-center effect: the same material and the same label style, which is what
//     iOS 10 replaced it with;
//   - and the iOS 13 factory that replaced all three, which takes the style itself.
//
// The blur styles' values are read from UIBlurEffect.h of SDK 26.2: ExtraLight 0, Light 1, Dark 2.
// The mapping of a widget style to a material is reasoned from the header's own wording, not
// measured: the host's UIKit no longer declares these factories at all (the deprecation is
// ios(13.0, 14.0)), so there is no differential to hold them to. See facts/NotificationCenter/.

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
