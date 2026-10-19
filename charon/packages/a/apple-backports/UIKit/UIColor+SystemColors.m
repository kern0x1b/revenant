#import <UIKit/UIKit.h>

// The dynamic rows of UIColorDynamic.m, measured on the newest release of the ladder.
UIColor *charon_system_colour(NSUInteger row);

@implementation UIColor (CharonSystemColors)

+ (UIColor *)systemRedColor
{
    return charon_system_colour(27);
}

+ (UIColor *)systemGreenColor
{
    return charon_system_colour(28);
}

+ (UIColor *)systemBlueColor
{
    return charon_system_colour(29);
}

+ (UIColor *)systemOrangeColor
{
    return charon_system_colour(30);
}

+ (UIColor *)systemYellowColor
{
    return charon_system_colour(31);
}

+ (UIColor *)systemPinkColor
{
    return charon_system_colour(32);
}

+ (UIColor *)systemTealColor
{
    return charon_system_colour(33);
}

+ (UIColor *)systemGrayColor
{
    return charon_system_colour(34);
}

@end
