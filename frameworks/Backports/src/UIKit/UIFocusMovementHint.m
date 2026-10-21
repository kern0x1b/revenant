#import <UIKit/UIKit.h>

@interface UIFocusMovementHint (RevenantInit)
- (instancetype)initRevenantWithMovementDirection:(CGVector)movementDirection perspectiveTransform:(CATransform3D)perspectiveTransform rotation:(CGVector)rotation translation:(CGVector)translation interactionTransform:(CATransform3D)interactionTransform;
@end

@implementation UIFocusMovementHint {
    CGVector _movementDirection;
    CATransform3D _perspectiveTransform;
    CGVector _rotation;
    CGVector _translation;
    CATransform3D _interactionTransform;
}

- (instancetype)initRevenantWithMovementDirection:(CGVector)movementDirection perspectiveTransform:(CATransform3D)perspectiveTransform rotation:(CGVector)rotation translation:(CGVector)translation interactionTransform:(CATransform3D)interactionTransform
{
    if ((self = [super init])) {
        _movementDirection = movementDirection;
        _perspectiveTransform = perspectiveTransform;
        _rotation = rotation;
        _translation = translation;
        _interactionTransform = interactionTransform;
    }
    return self;
}

- (CGVector)movementDirection
{
    return _movementDirection;
}

- (CATransform3D)perspectiveTransform
{
    return _perspectiveTransform;
}

- (CGVector)rotation
{
    return _rotation;
}

- (CGVector)translation
{
    return _translation;
}

- (CATransform3D)interactionTransform
{
    return _interactionTransform;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
