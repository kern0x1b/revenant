#import <UIKit/UIKit.h>

UIColor *revenant_system_colour(NSUInteger row);

@implementation UIColor (RevenantSystemColors)

+ (UIColor *)systemRedColor
{
    return revenant_system_colour(27);
}

+ (UIColor *)systemGreenColor
{
    return revenant_system_colour(28);
}

+ (UIColor *)systemBlueColor
{
    return revenant_system_colour(29);
}

+ (UIColor *)systemOrangeColor
{
    return revenant_system_colour(30);
}

+ (UIColor *)systemYellowColor
{
    return revenant_system_colour(31);
}

+ (UIColor *)systemPinkColor
{
    return revenant_system_colour(32);
}

+ (UIColor *)systemTealColor
{
    return revenant_system_colour(33);
}

+ (UIColor *)systemGrayColor
{
    return revenant_system_colour(34);
}

@end
