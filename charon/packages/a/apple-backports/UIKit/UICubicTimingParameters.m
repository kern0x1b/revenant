#import "CharonTimingParameters.h"

@implementation UICubicTimingParameters {
@private
    NSInteger _curve;
    CharonViewCubicTimingFunction *_timingFunction;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _curve = CharonCubicCurveDefault;
        _timingFunction = [self effectiveTimingFunction];
    }
    return self;
}

- (instancetype)initWithAnimationCurve:(UIViewAnimationCurve)curve
{
    if ((self = [super init])) {
        _curve = curve;
        _timingFunction = [self effectiveTimingFunction];
    }
    return self;
}

- (instancetype)initWithControlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2
{
    if ((self = [super init])) {
        _curve = CharonCubicCurveControlPoints;
        _timingFunction = charon_cubic_timing_function(point1, point2);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidUnarchiveOperationException format:@"%@ only supports keyed coding.", [self class]];
        return nil;
    }
    if ((self = [super init])) {
        if ([coder decodeIntegerForKey:@"curveType"] == UITimingCurveTypeCubic) {
            _curve = CharonCubicCurveControlPoints;
            _timingFunction = [coder decodeObjectForKey:@"timingFunction"];
        } else {
            _curve = [coder decodeIntegerForKey:@"animationCurve"];
            _timingFunction = [self effectiveTimingFunction];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:self.timingCurveType forKey:@"curveType"];
    if (self.timingCurveType == UITimingCurveTypeCubic)
        [coder encodeObject:_timingFunction forKey:@"timingFunction"];
    else
        [coder encodeInteger:_curve forKey:@"animationCurve"];
}

- (UITimingCurveType)timingCurveType
{
    return _curve == CharonCubicCurveControlPoints ? UITimingCurveTypeCubic : UITimingCurveTypeBuiltin;
}

- (UICubicTimingParameters *)cubicTimingParameters
{
    return self;
}

- (UISpringTimingParameters *)springTimingParameters
{
    return nil;
}

- (UIViewAnimationCurve)animationCurve
{
    return (UIViewAnimationCurve)_curve;
}

- (void)_setAnimationCurve:(UIViewAnimationCurve)curve
{
    _curve = curve;
}

- (CharonViewCubicTimingFunction *)timingFunction
{
    return _timingFunction;
}

- (CGPoint)controlPoint1
{
    return _timingFunction ? _timingFunction.controlPoint1 : CGPointZero;
}

- (CGPoint)controlPoint2
{
    return _timingFunction ? _timingFunction.controlPoint2 : CGPointZero;
}

- (CharonViewCubicTimingFunction *)effectiveTimingFunction
{
    if (_timingFunction)
        return _timingFunction;
    NSString *name = nil;
    switch (_curve) {
        case UIViewAnimationCurveEaseInOut: name = kCAMediaTimingFunctionEaseInEaseOut; break;
        case UIViewAnimationCurveEaseIn: name = kCAMediaTimingFunctionEaseIn; break;
        case UIViewAnimationCurveEaseOut: name = kCAMediaTimingFunctionEaseOut; break;
        case UIViewAnimationCurveLinear: name = kCAMediaTimingFunctionLinear; break;
        case CharonCubicCurveDefault: name = kCAMediaTimingFunctionDefault; break;
        default:
            [NSException raise:NSInvalidArgumentException
                        format:@"Unknown/Unsupported UIViewAnimationCurve type %ld", (long)_curve];
            return nil;
    }
    CAMediaTimingFunction *function = [CAMediaTimingFunction functionWithName:name];
    float first[2] = {0, 0}, second[2] = {0, 0};
    [function getControlPointAtIndex:1 values:first];
    [function getControlPointAtIndex:2 values:second];
    return charon_cubic_timing_function(CGPointMake(first[0], first[1]), CGPointMake(second[0], second[1]));
}

- (id)copyWithZone:(NSZone *)zone
{
    if (self.timingCurveType == UITimingCurveTypeCubic)
        return [[[self class] allocWithZone:zone] initWithControlPoint1:self.controlPoint1 controlPoint2:self.controlPoint2];
    return [[[self class] allocWithZone:zone] initWithAnimationCurve:self.animationCurve];
}

- (NSString *)description
{
    if (self.timingCurveType == UITimingCurveTypeCubic)
        return [NSString stringWithFormat:@"<%@ (%p) timing function = %@>", [self class], self, _timingFunction];
    NSString *name;
    switch (_curve) {
        case UIViewAnimationCurveEaseInOut: name = @"EaseInOut"; break;
        case UIViewAnimationCurveEaseIn: name = @"EaseIn"; break;
        case UIViewAnimationCurveEaseOut: name = @"EaseOut"; break;
        case UIViewAnimationCurveLinear: name = @"linear"; break;
        case CharonCubicCurveDefault: name = @"CA Default"; break;
        default: name = @"unknown"; break;
    }
    return [NSString stringWithFormat:@"<%@ (%p) builtin type = %@>", [self class], self, name];
}

@end
