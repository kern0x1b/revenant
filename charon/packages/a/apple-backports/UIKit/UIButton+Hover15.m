#import <UIKit/UIKit.h>

@implementation UIButton (CharonHover15)

// A button is hovered by a pointer, and the release has no pointing device.
- (BOOL)isHovered
{
    return NO;
}

@end
