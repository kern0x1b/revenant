#import <UIKit/UIKit.h>

@implementation UIPointerAccessory {
@private
    UIPointerShape *_shape;
    UIPointerAccessoryPosition _position;
    BOOL _orientationMatchesAngle;
}

+ (instancetype)accessoryWithShape:(UIPointerShape *)shape position:(UIPointerAccessoryPosition)position
{
    UIPointerAccessory *accessory = [[self alloc] init];
    accessory->_shape = [shape copy];
    accessory->_position = position;
    return accessory;
}

static UIBezierPath *revenant_arrowPath(void)
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(8.5394097477840791, 8.11336884234737)];
    [path addCurveToPoint:CGPointMake(8.3344596283032359, 7.5003800696152672) controlPoint1:CGPointMake(8.5394097477840791, 7.8959596859043071) controlPoint2:CGPointMake(8.4478389417548545, 7.7240291300164543)];
    [path addLineToPoint:CGPointMake(4.9873474800114019, 0.60799684956560507)];
    [path addCurveToPoint:CGPointMake(4.2703288642878521, 0) controlPoint1:CGPointMake(4.7624712097726158, 0.1445372913341838) controlPoint2:CGPointMake(4.5550251287085226, 0)];
    [path addCurveToPoint:CGPointMake(3.5520622677726772, 0.60799684956560507) controlPoint1:CGPointMake(3.9856325998671811, 0) controlPoint2:CGPointMake(3.7781865188030892, 0.1445372913341838)];
    [path addLineToPoint:CGPointMake(0.20619810027246768, 7.5003800696152672)];
    [path addCurveToPoint:CGPointMake(0, 8.1189743704326673) controlPoint1:CGPointMake(0.09281878682084925, 7.7296346581017534) controlPoint2:CGPointMake(0, 7.9015652139896062)];
    [path addCurveToPoint:CGPointMake(0.77184668673893531, 8.7662306875493901) controlPoint1:CGPointMake(0, 8.5189115340153823) controlPoint2:CGPointMake(0.30462241517861549, 8.7662306875493901)];
    [path addLineToPoint:CGPointMake(7.7688110418367708, 8.7606251594640909)];
    [path addCurveToPoint:CGPointMake(8.5394097477840791, 8.11336884234737) controlPoint1:CGPointMake(8.2416408414823881, 8.7606251594640909) controlPoint2:CGPointMake(8.5394097477840791, 8.5133060059300849)];
    [path closePath];
    return path;
}

+ (instancetype)arrowAccessoryWithPosition:(UIPointerAccessoryPosition)position
{
    UIPointerAccessory *accessory = [self accessoryWithShape:[UIPointerShape shapeWithPath:revenant_arrowPath()] position:position];
    accessory->_orientationMatchesAngle = YES;
    return accessory;
}

- (UIPointerShape *)shape
{
    return _shape;
}

- (UIPointerAccessoryPosition)position
{
    return _position;
}

- (BOOL)orientationMatchesAngle
{
    return _orientationMatchesAngle;
}

- (void)setOrientationMatchesAngle:(BOOL)orientationMatchesAngle
{
    _orientationMatchesAngle = orientationMatchesAngle;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIPointerAccessory *copy = [[[self class] allocWithZone:zone] init];
    copy->_shape = [_shape copy];
    copy->_position = _position;
    return copy;
}

@end
