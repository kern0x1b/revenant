#import <Foundation/Foundation.h>
#import <float.h>
#import <math.h>

#import "RevenantARKitPlaneExtent.h"

@implementation ARPlaneExtent
{
    float _rotationOnYAxis;
    float _width;
    float _height;
}

    @synthesize rotationOnYAxis = _rotationOnYAxis;
    @synthesize width = _width;
    @synthesize height = _height;

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    _rotationOnYAxis = 0.0f;
    _width = -1.0f;
    _height = -1.0f;
    return self;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeFloat:_rotationOnYAxis forKey:@"origin"];
    [coder encodeFloat:_width forKey:@"width"];
    [coder encodeFloat:_height forKey:@"height"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _rotationOnYAxis = [coder decodeFloatForKey:@"origin"];
    _width = [coder decodeFloatForKey:@"width"];
    _height = [coder decodeFloatForKey:@"height"];
    return self;
}

- (void)setRotationOnYAxis:(float)rotationOnYAxis { _rotationOnYAxis = rotationOnYAxis; }
- (void)setWidth:(float)width { _width = width; }
- (void)setHeight:(float)height { _height = height; }

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[ARPlaneExtent class]])
        return NO;
    ARPlaneExtent *other = object;
    return fabsf(_rotationOnYAxis - other->_rotationOnYAxis) < FLT_EPSILON &&
           fabsf(_width - other->_width) < FLT_EPSILON &&
           fabsf(_height - other->_height) < FLT_EPSILON;
}

- (id)copyWithZone:(NSZone *)zone
{
    ARPlaneExtent *copy = [[self class] allocWithZone:zone];
    copy->_rotationOnYAxis = _rotationOnYAxis;
    copy->_width = _width;
    copy->_height = _height;
    return copy;
}

@end
