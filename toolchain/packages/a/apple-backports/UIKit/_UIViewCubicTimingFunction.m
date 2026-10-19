#import "RevenantTimingParameters.h"
#import <objc/runtime.h>

@implementation RevenantViewCubicTimingFunction {
@private
    CGPoint _point1;
    CGPoint _point2;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Don't call %@.", NSStringFromSelector(_cmd)];
    return nil;
}

- (instancetype)initWithControlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2
{
    if ((self = [super init])) {
        _point1 = point1;
        _point2 = point2;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidUnarchiveOperationException format:@"%@ only supports keyed coding.", [self class]];
        return nil;
    }
    return [self initWithControlPoint1:[coder decodeCGPointForKey:@"point1"]
                         controlPoint2:[coder decodeCGPointForKey:@"point2"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeCGPoint:_point1 forKey:@"point1"];
    [coder encodeCGPoint:_point2 forKey:@"point2"];
}

- (CGPoint)controlPoint1
{
    return _point1;
}

- (CGPoint)controlPoint2
{
    return _point2;
}

- (CAMediaTimingFunction *)_mediaTimingFunction
{
    return [CAMediaTimingFunction functionWithControlPoints:_point1.x :_point1.y :_point2.x :_point2.y];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithControlPoint1:_point1 controlPoint2:_point2];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ point1 = %@ point2 = %@>", [self class],
                                      NSStringFromCGPoint(_point1), NSStringFromCGPoint(_point2)];
}

@end

static Class revenant_registered;

__attribute__((constructor)) static void revenant_register_uiviewcubict(void)
{
    revenant_registered = objc_getClass("_UIViewCubicTimingFunction");
    if (revenant_registered)
        return;
    Class made = objc_allocateClassPair([RevenantViewCubicTimingFunction class], "_UIViewCubicTimingFunction", 0);
    if (made)
        objc_registerClassPair(made);
    revenant_registered = made ? made : [RevenantViewCubicTimingFunction class];
}

Class revenant_cubic_timing_function_class(void)
{
    return revenant_registered ? revenant_registered : [RevenantViewCubicTimingFunction class];
}

id revenant_cubic_timing_function(CGPoint point1, CGPoint point2)
{
    return [[revenant_cubic_timing_function_class() alloc] initWithControlPoint1:point1 controlPoint2:point2];
}
