#import "CharonSCN.h"

SCNLightType const SCNLightTypeAmbient = @"ambient";
SCNLightType const SCNLightTypeOmni = @"omni";
SCNLightType const SCNLightTypeDirectional = @"directional";
SCNLightType const SCNLightTypeSpot = @"spot";

@implementation SCNLight

- (instancetype)init
{
    if ((self = [super init])) {
        _type = SCNLightTypeOmni;
        _color = [UIColor whiteColor];
        _intensity = 1000;
        _temperature = 6500;
        _castsShadow = NO;
        _shadowColor = [UIColor blackColor];
        _shadowRadius = 3;
        _categoryBitMask = NSUIntegerMax;
        _attenuationFalloffExponent = 2;
        _zNear = 1;
        _zFar = 100;
        _spotOuterAngle = 45;
    }
    return self;
}

+ (instancetype)light
{
    return [[self alloc] init];
}

@synthesize type = _type;
@synthesize color = _color;
@synthesize temperature = _temperature;
@synthesize intensity = _intensity;
@synthesize name = _name;
@synthesize castsShadow = _castsShadow;
@synthesize shadowColor = _shadowColor;
@synthesize shadowRadius = _shadowRadius;
@synthesize zNear = _zNear;
@synthesize zFar = _zFar;
@synthesize attenuationStartDistance = _attenuationStartDistance;
@synthesize attenuationEndDistance = _attenuationEndDistance;
@synthesize attenuationFalloffExponent = _attenuationFalloffExponent;
@synthesize spotInnerAngle = _spotInnerAngle;
@synthesize spotOuterAngle = _spotOuterAngle;
@synthesize gobo = _gobo;
@synthesize probeEnvironment = _probeEnvironment;
@synthesize categoryBitMask = _categoryBitMask;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        NSString *type = [coder decodeObjectOfClass:[NSString class] forKey:@"type"];
        if (type.length) {
            _type = type;
        }
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        UIColor *color = [CharonSCNCoding decodeColor:coder forKey:@"color"];
        if (color) {
            _color = color;
        }
        UIColor *shadowColor = [CharonSCNCoding decodeColor:coder forKey:@"shadowColor"];
        if (shadowColor) {
            _shadowColor = shadowColor;
        }
        if ([coder containsValueForKey:@"temperature"]) {
            _temperature = [coder decodeDoubleForKey:@"temperature"];
        }
        if ([coder containsValueForKey:@"intensity"]) {
            _intensity = [coder decodeDoubleForKey:@"intensity"];
        }
        _castsShadow = [CharonSCNCoding decodeBool:coder forKey:@"castsShadow" default:NO];
        if ([coder containsValueForKey:@"shadowRadius"]) {
            _shadowRadius = [coder decodeDoubleForKey:@"shadowRadius"];
        }
        if ([coder containsValueForKey:@"zNear"]) {
            _zNear = [coder decodeDoubleForKey:@"zNear"];
        }
        if ([coder containsValueForKey:@"zFar"]) {
            _zFar = [coder decodeDoubleForKey:@"zFar"];
        }
        _attenuationStartDistance = [coder decodeDoubleForKey:@"attenuationStartDistance"];
        _attenuationEndDistance = [coder decodeDoubleForKey:@"attenuationEndDistance"];
        if ([coder containsValueForKey:@"attenuationFalloffExponent"]) {
            _attenuationFalloffExponent = [coder decodeDoubleForKey:@"attenuationFalloffExponent"];
        }
        _spotInnerAngle = [coder decodeDoubleForKey:@"spotInnerAngle"];
        if ([coder containsValueForKey:@"spotOuterAngle"]) {
            _spotOuterAngle = [coder decodeDoubleForKey:@"spotOuterAngle"];
        }
        _gobo = [coder decodeObjectOfClass:[SCNMaterialProperty class] forKey:@"gobo"];
        _probeEnvironment = [coder decodeObjectOfClass:[SCNMaterialProperty class] forKey:@"probeEnvironment"];
        if ([coder containsValueForKey:@"lightCategoryBitMask"]) {
            _categoryBitMask = (NSUInteger)[coder decodeInt64ForKey:@"lightCategoryBitMask"];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_type forKey:@"type"];
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeDouble:_temperature forKey:@"temperature"];
    [coder encodeDouble:_intensity forKey:@"intensity"];
    [coder encodeBool:_castsShadow forKey:@"castsShadow"];
    [coder encodeDouble:_shadowRadius forKey:@"shadowRadius"];
    [coder encodeDouble:_zNear forKey:@"zNear"];
    [coder encodeDouble:_zFar forKey:@"zFar"];
    [coder encodeDouble:_attenuationStartDistance forKey:@"attenuationStartDistance"];
    [coder encodeDouble:_attenuationEndDistance forKey:@"attenuationEndDistance"];
    [coder encodeDouble:_attenuationFalloffExponent forKey:@"attenuationFalloffExponent"];
    [coder encodeDouble:_spotInnerAngle forKey:@"spotInnerAngle"];
    [coder encodeDouble:_spotOuterAngle forKey:@"spotOuterAngle"];
    [coder encodeInt64:(int64_t)_categoryBitMask forKey:@"lightCategoryBitMask"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNLight *copy = [[SCNLight allocWithZone:zone] init];
    copy->_type = _type;
    copy->_name = [_name copy];
    copy->_color = _color;
    copy->_shadowColor = _shadowColor;
    copy->_temperature = _temperature;
    copy->_intensity = _intensity;
    copy->_castsShadow = _castsShadow;
    copy->_shadowRadius = _shadowRadius;
    copy->_zNear = _zNear;
    copy->_zFar = _zFar;
    copy->_attenuationStartDistance = _attenuationStartDistance;
    copy->_attenuationEndDistance = _attenuationEndDistance;
    copy->_attenuationFalloffExponent = _attenuationFalloffExponent;
    copy->_spotInnerAngle = _spotInnerAngle;
    copy->_spotOuterAngle = _spotOuterAngle;
    copy->_gobo = _gobo;
    copy->_probeEnvironment = _probeEnvironment;
    copy->_categoryBitMask = _categoryBitMask;
    return copy;
}

@end
