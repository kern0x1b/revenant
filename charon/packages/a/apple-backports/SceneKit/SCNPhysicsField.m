#import "CharonSCN.h"

@implementation SCNPhysicsField

- (instancetype)init
{
    if ((self = [super init])) {
        _strength = 1;
        _falloffExponent = 0;
        _minimumDistance = 1e-6;
        _active = YES;
        _exclusive = NO;
        _halfExtent = SCNVector3Make(FLT_MAX, FLT_MAX, FLT_MAX);
        _usesEllipsoidalExtent = NO;
        _scope = SCNPhysicsFieldScopeInsideExtent;
        _categoryBitMask = NSUIntegerMax;
        _direction = SCNVector3Make(0, -1, 0);
    }
    return self;
}

@synthesize strength = _strength;
@synthesize falloffExponent = _falloffExponent;
@synthesize minimumDistance = _minimumDistance;
@synthesize active = _active;
@synthesize exclusive = _exclusive;
@synthesize halfExtent = _halfExtent;
@synthesize usesEllipsoidalExtent = _usesEllipsoidalExtent;
@synthesize scope = _scope;
@synthesize offset = _offset;
@synthesize direction = _direction;
@synthesize categoryBitMask = _categoryBitMask;

+ (SCNPhysicsField *)radialGravityField
{
    return [[SCNPhysicsRadialGravityField alloc] init];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        if ([coder containsValueForKey:@"strength"]) {
            _strength = [coder decodeDoubleForKey:@"strength"];
        }
        _falloffExponent = [coder decodeDoubleForKey:@"falloffExponent"];
        if ([coder containsValueForKey:@"minimumDistance"]) {
            _minimumDistance = [coder decodeDoubleForKey:@"minimumDistance"];
        }
        _active = [CharonSCNCoding decodeBool:coder forKey:@"active" default:YES];
        _exclusive = [CharonSCNCoding decodeBool:coder forKey:@"exclusive" default:NO];
        _usesEllipsoidalExtent = [CharonSCNCoding decodeBool:coder forKey:@"usesEllipsoidalExtent" default:NO];
        if ([coder containsValueForKey:@"scope"]) {
            _scope = [coder decodeIntegerForKey:@"scope"];
        }
        if ([coder containsValueForKey:@"categoryBitMask"]) {
            _categoryBitMask = (NSUInteger)[coder decodeInt64ForKey:@"categoryBitMask"];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_strength forKey:@"strength"];
    [coder encodeDouble:_falloffExponent forKey:@"falloffExponent"];
    [coder encodeDouble:_minimumDistance forKey:@"minimumDistance"];
    [coder encodeBool:_active forKey:@"active"];
    [coder encodeBool:_exclusive forKey:@"exclusive"];
    [coder encodeBool:_usesEllipsoidalExtent forKey:@"usesEllipsoidalExtent"];
    [coder encodeInteger:_scope forKey:@"scope"];
    [coder encodeInt64:(int64_t)_categoryBitMask forKey:@"categoryBitMask"];
}

- (id)copyWithZone:(NSZone *)zone
{
    typeof(self) copy = [[[self class] allocWithZone:zone] init];
    copy->_strength = _strength;
    copy->_falloffExponent = _falloffExponent;
    copy->_minimumDistance = _minimumDistance;
    copy->_active = _active;
    copy->_exclusive = _exclusive;
    copy->_halfExtent = _halfExtent;
    copy->_usesEllipsoidalExtent = _usesEllipsoidalExtent;
    copy->_scope = _scope;
    copy->_offset = _offset;
    copy->_direction = _direction;
    copy->_categoryBitMask = _categoryBitMask;
    return copy;
}

@end
