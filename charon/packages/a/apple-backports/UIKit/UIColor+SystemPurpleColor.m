#import <UIKit/UIKit.h>

UIColor *charon_system_colour(NSUInteger row);

@implementation UIColor (CharonSystemPurpleColor)

// A row of UIColorDynamic.m: iOS 13 moved purple to (175, 82, 222) and gave its old value to indigo.
+ (UIColor *)systemPurpleColor
{
    return charon_system_colour(35);
}

@end
