#import <UIKit/UIKit.h>

@implementation UIHoverGestureRecognizer (RevenantHover16)

- (CGFloat)zOffset
{
    return 0;
}

- (CGFloat)altitudeAngle
{
    return 0;
}

- (CGFloat)azimuthAngleInView:(UIView *)view
{
    return 0;
}

- (CGVector)azimuthUnitVectorInView:(UIView *)view
{
    return CGVectorMake(0, 0);
}

@end
