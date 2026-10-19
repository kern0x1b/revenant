#import <UIKit/UIKit.h>

UIColor *charon_system_colour(NSUInteger row);

@implementation UIColor (CharonSystemPurpleColor)

+ (UIColor *)systemPurpleColor
{
    return charon_system_colour(35);
}

@end
