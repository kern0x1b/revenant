#import "CharonSCN.h"

SCNParticleProperty const SCNParticlePropertyPosition = @"position";
SCNParticleProperty const SCNParticlePropertyAngle = @"angle";
SCNParticleProperty const SCNParticlePropertyRotationAxis = @"rotationAxis";
SCNParticleProperty const SCNParticlePropertyVelocity = @"velocity";
SCNParticleProperty const SCNParticlePropertyAngularVelocity = @"angularVelocity";
SCNParticleProperty const SCNParticlePropertyLife = @"life";
SCNParticleProperty const SCNParticlePropertyColor = @"color";
SCNParticleProperty const SCNParticlePropertyOpacity = @"opacity";
SCNParticleProperty const SCNParticlePropertySize = @"size";
SCNParticleProperty const SCNParticlePropertyFrame = @"frame";
SCNParticleProperty const SCNParticlePropertyFrameRate = @"frameRate";
SCNParticleProperty const SCNParticlePropertyBounce = @"bounce";
SCNParticleProperty const SCNParticlePropertyCharge = @"charge";
SCNParticleProperty const SCNParticlePropertyFriction = @"friction";
SCNParticleProperty const SCNParticlePropertyContactPoint = @"contactPoint";
SCNParticleProperty const SCNParticlePropertyContactNormal = @"contactNormal";

@implementation SCNParticleSystem

- (instancetype)init
{
    if ((self = [super init])) {
        _emissionDuration = 1;
        _loops = YES;
        _birthRate = 0;
        _particleAngleVariation = 0;
        _particleVelocity = 0;
        _particleLifeSpan = 1;
        _particleSize = 1;
        _particleColor = [UIColor whiteColor];
        _particleColorVariation = SCNVector4Make(0, 0, 0, 0);
        _blendMode = SCNParticleBlendModeAdditive;
        _sortingMode = SCNParticleSortingModeNone;
        _lightingEnabled = NO;
        _affectedByGravity = NO;
        _affectedByPhysicsFields = NO;
        _emittingDirection = SCNVector3Make(0, 1, 0);
        _spreadingAngle = 0;
        _speedFactor = 1;
        _stretchFactor = 0;
        _warmupDuration = 0;
    }
    return self;
}

+ (instancetype)particleSystem
{
    return [[self alloc] init];
}

@synthesize emissionDuration = _emissionDuration;
@synthesize loops = _loops;
@synthesize birthRate = _birthRate;
@synthesize warmupDuration = _warmupDuration;
@synthesize emitterShape = _emitterShape;
@synthesize spreadingAngle = _spreadingAngle;
@synthesize emittingDirection = _emittingDirection;
@synthesize acceleration = _acceleration;
@synthesize particleAngleVariation = _particleAngleVariation;
@synthesize particleVelocity = _particleVelocity;
@synthesize particleVelocityVariation = _particleVelocityVariation;
@synthesize particleAngularVelocity = _particleAngularVelocity;
@synthesize particleLifeSpan = _particleLifeSpan;
@synthesize particleLifeSpanVariation = _particleLifeSpanVariation;
@synthesize particleImage = _particleImage;
@synthesize particleColor = _particleColor;
@synthesize particleColorVariation = _particleColorVariation;
@synthesize particleSize = _particleSize;
@synthesize particleSizeVariation = _particleSizeVariation;
@synthesize blendMode = _blendMode;
@synthesize orientationMode = _orientationMode;
@synthesize sortingMode = _sortingMode;
@synthesize lightingEnabled = _lightingEnabled;
@synthesize affectedByGravity = _affectedByGravity;
@synthesize affectedByPhysicsFields = _affectedByPhysicsFields;
@synthesize speedFactor = _speedFactor;
@synthesize stretchFactor = _stretchFactor;
@synthesize propertyControllers = _propertyControllers;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        if ([coder containsValueForKey:@"emissionDuration"]) {
            _emissionDuration = [coder decodeDoubleForKey:@"emissionDuration"];
        }
        _loops = [CharonSCNCoding decodeBool:coder forKey:@"loops" default:YES];
        if ([coder containsValueForKey:@"birthRate"]) {
            _birthRate = [coder decodeDoubleForKey:@"birthRate"];
        }
        _warmupDuration = [coder decodeDoubleForKey:@"warmupDuration"];
        _emitterShape = [coder decodeObjectOfClass:[SCNGeometry class] forKey:@"emitterShape"];
        _spreadingAngle = [coder decodeDoubleForKey:@"spreadingAngle"];
        _emittingDirection = [coder containsValueForKey:@"emittingDirection"] ? [CharonSCNCoding decodeVector3:coder forKey:@"emittingDirection"] : _emittingDirection;
        _acceleration = [CharonSCNCoding decodeVector3:coder forKey:@"acceleration"];
        _particleAngleVariation = [coder decodeDoubleForKey:@"particleAngleVariation"];
        BOOL velocityFound = [coder containsValueForKey:@"particleVelocity"];
        if (velocityFound) {
            _particleVelocity = [coder decodeDoubleForKey:@"particleVelocity"];
        }
        [CharonSCNCoding markFound:velocityFound forKey:@"particleVelocity" onObject:self];
        _particleVelocityVariation = [coder decodeDoubleForKey:@"particleVelocityVariation"];
        _particleAngularVelocity = [coder decodeDoubleForKey:@"particleAngularVelocity"];
        BOOL lifeSpanFound = [coder containsValueForKey:@"particleLifeSpan"];
        if (lifeSpanFound) {
            _particleLifeSpan = [coder decodeDoubleForKey:@"particleLifeSpan"];
        }
        [CharonSCNCoding markFound:lifeSpanFound forKey:@"particleLifeSpan" onObject:self];
        _particleLifeSpanVariation = [coder decodeDoubleForKey:@"particleLifeSpanVariation"];
        NSString *imageName = [CharonSCNCoding decodeFileReferenceName:coder forKey:@"particleImage"];
        _particleImage = imageName ?: [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSString class], [UIColor class], nil] forKey:@"particleImage"];
        UIColor *color = [CharonSCNCoding decodeColor:coder forKey:@"particleColor"];
        if (color) {
            _particleColor = color;
        }
        _particleColorVariation = [CharonSCNCoding decodeVector4:coder forKey:@"particleColorVariation"];
        if ([coder containsValueForKey:@"particleSize"]) {
            _particleSize = [coder decodeDoubleForKey:@"particleSize"];
        }
        _particleSizeVariation = [coder decodeDoubleForKey:@"particleSizeVariation"];
        if ([coder containsValueForKey:@"blendMode"]) {
            _blendMode = [coder decodeIntegerForKey:@"blendMode"];
        }
        _orientationMode = [coder decodeIntegerForKey:@"orientationMode"];
        if ([coder containsValueForKey:@"sortingMode"]) {
            _sortingMode = [coder decodeIntegerForKey:@"sortingMode"];
        }
        _lightingEnabled = [CharonSCNCoding decodeBool:coder forKey:@"lightingEnabled" default:NO];
        _affectedByGravity = [CharonSCNCoding decodeBool:coder forKey:@"affectedByGravity" default:_affectedByGravity];
        _affectedByPhysicsFields = [CharonSCNCoding decodeBool:coder forKey:@"affectedByPhysicsFields" default:_affectedByPhysicsFields];
        BOOL speedFactorFound = [coder containsValueForKey:@"speedFactor"];
        if (speedFactorFound) {
            _speedFactor = [coder decodeDoubleForKey:@"speedFactor"];
        }
        [CharonSCNCoding markFound:speedFactorFound forKey:@"speedFactor" onObject:self];
        BOOL stretchFactorFound = [coder containsValueForKey:@"stretchFactor"];
        if (stretchFactorFound) {
            _stretchFactor = [coder decodeDoubleForKey:@"stretchFactor"];
        }
        [CharonSCNCoding markFound:stretchFactorFound forKey:@"stretchFactor" onObject:self];
        _propertyControllers = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [SCNParticlePropertyController class], nil] forKey:@"propertyControllers"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_emissionDuration forKey:@"emissionDuration"];
    [coder encodeBool:_loops forKey:@"loops"];
    [coder encodeDouble:_birthRate forKey:@"birthRate"];
    [coder encodeDouble:_warmupDuration forKey:@"warmupDuration"];
    [coder encodeObject:_emitterShape forKey:@"emitterShape"];
    [coder encodeDouble:_spreadingAngle forKey:@"spreadingAngle"];
    [CharonSCNCoding encodeVector3:_emittingDirection coder:coder forKey:@"emittingDirection"];
    [CharonSCNCoding encodeVector3:_acceleration coder:coder forKey:@"acceleration"];
    [coder encodeDouble:_particleVelocity forKey:@"particleVelocity"];
    [coder encodeDouble:_particleVelocityVariation forKey:@"particleVelocityVariation"];
    [coder encodeDouble:_particleLifeSpan forKey:@"particleLifeSpan"];
    [coder encodeDouble:_particleLifeSpanVariation forKey:@"particleLifeSpanVariation"];
    [coder encodeDouble:_particleSize forKey:@"particleSize"];
    [coder encodeDouble:_particleSizeVariation forKey:@"particleSizeVariation"];
    [coder encodeInteger:_blendMode forKey:@"blendMode"];
    [coder encodeInteger:_orientationMode forKey:@"orientationMode"];
    [coder encodeInteger:_sortingMode forKey:@"sortingMode"];
    [coder encodeBool:_lightingEnabled forKey:@"lightingEnabled"];
    [coder encodeBool:_affectedByGravity forKey:@"affectedByGravity"];
    [coder encodeBool:_affectedByPhysicsFields forKey:@"affectedByPhysicsFields"];
    [coder encodeDouble:_speedFactor forKey:@"speedFactor"];
    [coder encodeDouble:_stretchFactor forKey:@"stretchFactor"];
    [coder encodeObject:_propertyControllers forKey:@"propertyControllers"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNParticleSystem *copy = [[SCNParticleSystem allocWithZone:zone] init];
    copy->_emissionDuration = _emissionDuration;
    copy->_loops = _loops;
    copy->_birthRate = _birthRate;
    copy->_warmupDuration = _warmupDuration;
    copy->_emitterShape = _emitterShape;
    copy->_spreadingAngle = _spreadingAngle;
    copy->_emittingDirection = _emittingDirection;
    copy->_acceleration = _acceleration;
    copy->_particleAngleVariation = _particleAngleVariation;
    copy->_particleVelocity = _particleVelocity;
    copy->_particleVelocityVariation = _particleVelocityVariation;
    copy->_particleAngularVelocity = _particleAngularVelocity;
    copy->_particleLifeSpan = _particleLifeSpan;
    copy->_particleLifeSpanVariation = _particleLifeSpanVariation;
    copy->_particleImage = _particleImage;
    copy->_particleColor = _particleColor;
    copy->_particleColorVariation = _particleColorVariation;
    copy->_particleSize = _particleSize;
    copy->_particleSizeVariation = _particleSizeVariation;
    copy->_blendMode = _blendMode;
    copy->_orientationMode = _orientationMode;
    copy->_sortingMode = _sortingMode;
    copy->_lightingEnabled = _lightingEnabled;
    copy->_affectedByGravity = _affectedByGravity;
    copy->_affectedByPhysicsFields = _affectedByPhysicsFields;
    copy->_speedFactor = _speedFactor;
    copy->_stretchFactor = _stretchFactor;
    copy->_propertyControllers = _propertyControllers;
    return copy;
}

@end
