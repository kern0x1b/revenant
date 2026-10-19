#import <UIKit/UIKit.h>

UIColor *revenant_system_colour(NSUInteger row);

@implementation UIColor (RevenantSystemPurpleColor)

+ (UIColor *)systemPurpleColor
{
    return revenant_system_colour(35);
}

@end
