#import "CharonTimingParameters.h"
#import <objc/runtime.h>

@implementation CharonViewCubicTimingFunction {
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

static Class charon_registered;

__attribute__((constructor)) static void charon_register_uiviewcubict(void)
{
    charon_registered = objc_getClass("_UIViewCubicTimingFunction");
    if (charon_registered)
        return;
    Class made = objc_allocateClassPair([CharonViewCubicTimingFunction class], "_UIViewCubicTimingFunction", 0);
    if (made)
        objc_registerClassPair(made);
    charon_registered = made ? made : [CharonViewCubicTimingFunction class];
}

Class charon_cubic_timing_function_class(void)
{
    return charon_registered ? charon_registered : [CharonViewCubicTimingFunction class];
}

id charon_cubic_timing_function(CGPoint point1, CGPoint point2)
{
    return [[charon_cubic_timing_function_class() alloc] initWithControlPoint1:point1 controlPoint2:point2];
}
