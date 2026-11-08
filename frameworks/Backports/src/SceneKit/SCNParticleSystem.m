#include "../revenant_impl.h"
#import "RevenantSCN.h"

SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyPosition) = @"position";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyAngle) = @"angle";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyRotationAxis) = @"rotationAxis";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyVelocity) = @"velocity";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyAngularVelocity) = @"angularVelocity";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyLife) = @"life";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyColor) = @"color";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyOpacity) = @"opacity";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertySize) = @"size";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyFrame) = @"frame";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyFrameRate) = @"frameRate";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyBounce) = @"bounce";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyCharge) = @"charge";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyFriction) = @"friction";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyContactPoint) = @"contactPoint";
SCNParticleProperty const BACKPORT_IMPL(SCNParticlePropertyContactNormal) = @"contactNormal";

@implementation SCNParticleSystem {
    NSMutableDictionary<NSNumber *, NSMutableArray *> *_eventHandlers;
    NSMutableDictionary<NSNumber *, NSMutableArray *> *_modifiers;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _eventHandlers = [NSMutableDictionary dictionary];
        _modifiers = [NSMutableDictionary dictionary];
        _imageSequenceColumnCount = 1;
        _imageSequenceRowCount = 1;
        _particleIntensity = 1;
        _particleMass = 1;
        _particleBounce = 0.7f;
        _particleFriction = 1;
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

+ (instancetype)particleSystemNamed:(NSString *)name inDirectory:(NSString *)directory
{
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:nil inDirectory:directory];
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    if (!data) {
        return nil;
    }
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    unarchiver.requiresSecureCoding = YES;
    SCNParticleSystem *system = [unarchiver decodeObjectOfClass:[SCNParticleSystem class] forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    return system;
}

@synthesize emissionDuration = _emissionDuration;
@synthesize emissionDurationVariation = _emissionDurationVariation;
@synthesize idleDuration = _idleDuration;
@synthesize idleDurationVariation = _idleDurationVariation;
@synthesize loops = _loops;
@synthesize birthRate = _birthRate;
@synthesize birthRateVariation = _birthRateVariation;
@synthesize warmupDuration = _warmupDuration;
@synthesize emitterShape = _emitterShape;
@synthesize birthLocation = _birthLocation;
@synthesize birthDirection = _birthDirection;
@synthesize spreadingAngle = _spreadingAngle;
@synthesize emittingDirection = _emittingDirection;
@synthesize orientationDirection = _orientationDirection;
@synthesize acceleration = _acceleration;
@synthesize local = _local;
@synthesize particleAngle = _particleAngle;
@synthesize particleAngleVariation = _particleAngleVariation;
@synthesize particleVelocity = _particleVelocity;
@synthesize particleVelocityVariation = _particleVelocityVariation;
@synthesize particleAngularVelocity = _particleAngularVelocity;
@synthesize particleAngularVelocityVariation = _particleAngularVelocityVariation;
@synthesize particleLifeSpan = _particleLifeSpan;
@synthesize particleLifeSpanVariation = _particleLifeSpanVariation;
@synthesize systemSpawnedOnDying = _systemSpawnedOnDying;
@synthesize systemSpawnedOnCollision = _systemSpawnedOnCollision;
@synthesize systemSpawnedOnLiving = _systemSpawnedOnLiving;
@synthesize particleImage = _particleImage;
@synthesize imageSequenceColumnCount = _imageSequenceColumnCount;
@synthesize imageSequenceRowCount = _imageSequenceRowCount;
@synthesize imageSequenceInitialFrame = _imageSequenceInitialFrame;
@synthesize imageSequenceInitialFrameVariation = _imageSequenceInitialFrameVariation;
@synthesize imageSequenceFrameRate = _imageSequenceFrameRate;
@synthesize imageSequenceFrameRateVariation = _imageSequenceFrameRateVariation;
@synthesize imageSequenceAnimationMode = _imageSequenceAnimationMode;
@synthesize particleColor = _particleColor;
@synthesize particleColorVariation = _particleColorVariation;
@synthesize particleSize = _particleSize;
@synthesize particleSizeVariation = _particleSizeVariation;
@synthesize particleIntensity = _particleIntensity;
@synthesize particleIntensityVariation = _particleIntensityVariation;
@synthesize blendMode = _blendMode;
@synthesize blackPassEnabled = _blackPassEnabled;
@synthesize orientationMode = _orientationMode;
@synthesize sortingMode = _sortingMode;
@synthesize lightingEnabled = _lightingEnabled;
@synthesize affectedByGravity = _affectedByGravity;
@synthesize affectedByPhysicsFields = _affectedByPhysicsFields;
@synthesize particleDiesOnCollision = _particleDiesOnCollision;
@synthesize colliderNodes = _colliderNodes;
@synthesize particleMass = _particleMass;
@synthesize particleMassVariation = _particleMassVariation;
@synthesize particleBounce = _particleBounce;
@synthesize particleBounceVariation = _particleBounceVariation;
@synthesize particleFriction = _particleFriction;
@synthesize particleFrictionVariation = _particleFrictionVariation;
@synthesize particleCharge = _particleCharge;
@synthesize particleChargeVariation = _particleChargeVariation;
@synthesize dampingFactor = _dampingFactor;
@synthesize speedFactor = _speedFactor;
@synthesize stretchFactor = _stretchFactor;
@synthesize fresnelExponent = _fresnelExponent;
@synthesize writesToDepthBuffer = _writesToDepthBuffer;
@synthesize propertyControllers = _propertyControllers;

- (void)reset
{
}

- (void)handleEvent:(SCNParticleEvent)event forProperties:(NSArray<SCNParticleProperty> *)properties withBlock:(SCNParticleEventBlock)block
{
    NSNumber *key = @(event);
    NSMutableArray *handlers = _eventHandlers[key];
    if (!handlers) {
        handlers = [NSMutableArray array];
        _eventHandlers[key] = handlers;
    }
    [handlers addObject:@{@"properties": [properties copy], @"block": [block copy]}];
}

- (void)addModifierForProperties:(NSArray<SCNParticleProperty> *)properties atStage:(SCNParticleModifierStage)stage withBlock:(SCNParticleModifierBlock)block
{
    NSNumber *key = @(stage);
    NSMutableArray *modifiers = _modifiers[key];
    if (!modifiers) {
        modifiers = [NSMutableArray array];
        _modifiers[key] = modifiers;
    }
    [modifiers addObject:@{@"properties": [properties copy], @"block": [block copy]}];
}

- (void)removeModifiersOfStage:(SCNParticleModifierStage)stage
{
    [_modifiers removeObjectForKey:@(stage)];
}

- (void)removeAllModifiers
{
    [_modifiers removeAllObjects];
}

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
        _loops = [RevenantSCNCoding decodeBool:coder forKey:@"loops" default:YES];
        if ([coder containsValueForKey:@"birthRate"]) {
            _birthRate = [coder decodeDoubleForKey:@"birthRate"];
        }
        _warmupDuration = [coder decodeDoubleForKey:@"warmupDuration"];
        _emitterShape = [coder decodeObjectOfClass:[SCNGeometry class] forKey:@"emitterShape"];
        _spreadingAngle = [coder decodeDoubleForKey:@"spreadingAngle"];
        _emittingDirection = [coder containsValueForKey:@"emittingDirection"] ? [RevenantSCNCoding decodeVector3:coder forKey:@"emittingDirection"] : _emittingDirection;
        _acceleration = [RevenantSCNCoding decodeVector3:coder forKey:@"acceleration"];
        _particleAngleVariation = [coder decodeDoubleForKey:@"particleAngleVariation"];
        BOOL velocityFound = [coder containsValueForKey:@"particleVelocity"];
        if (velocityFound) {
            _particleVelocity = [coder decodeDoubleForKey:@"particleVelocity"];
        }
        [RevenantSCNCoding markFound:velocityFound forKey:@"particleVelocity" onObject:self];
        _particleVelocityVariation = [coder decodeDoubleForKey:@"particleVelocityVariation"];
        _particleAngularVelocity = [coder decodeDoubleForKey:@"particleAngularVelocity"];
        BOOL lifeSpanFound = [coder containsValueForKey:@"particleLifeSpan"];
        if (lifeSpanFound) {
            _particleLifeSpan = [coder decodeDoubleForKey:@"particleLifeSpan"];
        }
        [RevenantSCNCoding markFound:lifeSpanFound forKey:@"particleLifeSpan" onObject:self];
        _particleLifeSpanVariation = [coder decodeDoubleForKey:@"particleLifeSpanVariation"];
        NSString *imageName = [RevenantSCNCoding decodeFileReferenceName:coder forKey:@"particleImage"];
        _particleImage = imageName ?: [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSString class], [UIColor class], nil] forKey:@"particleImage"];
        UIColor *color = [RevenantSCNCoding decodeColor:coder forKey:@"particleColor"];
        if (color) {
            _particleColor = color;
        }
        _particleColorVariation = [RevenantSCNCoding decodeVector4:coder forKey:@"particleColorVariation"];
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
        _lightingEnabled = [RevenantSCNCoding decodeBool:coder forKey:@"lightingEnabled" default:NO];
        _affectedByGravity = [RevenantSCNCoding decodeBool:coder forKey:@"affectedByGravity" default:_affectedByGravity];
        _affectedByPhysicsFields = [RevenantSCNCoding decodeBool:coder forKey:@"affectedByPhysicsFields" default:_affectedByPhysicsFields];
        BOOL speedFactorFound = [coder containsValueForKey:@"speedFactor"];
        if (speedFactorFound) {
            _speedFactor = [coder decodeDoubleForKey:@"speedFactor"];
        }
        [RevenantSCNCoding markFound:speedFactorFound forKey:@"speedFactor" onObject:self];
        BOOL stretchFactorFound = [coder containsValueForKey:@"stretchFactor"];
        if (stretchFactorFound) {
            _stretchFactor = [coder decodeDoubleForKey:@"stretchFactor"];
        }
        [RevenantSCNCoding markFound:stretchFactorFound forKey:@"stretchFactor" onObject:self];
        _emissionDurationVariation = [coder decodeDoubleForKey:@"emissionDurationVariation"];
        _idleDuration = [coder decodeDoubleForKey:@"idleDuration"];
        _idleDurationVariation = [coder decodeDoubleForKey:@"idleDurationVariation"];
        _birthRateVariation = [coder decodeDoubleForKey:@"birthRateVariation"];
        _birthLocation = [coder decodeIntegerForKey:@"birthLocation"];
        _birthDirection = [coder decodeIntegerForKey:@"birthDirection"];
        _orientationDirection = [RevenantSCNCoding decodeVector3:coder forKey:@"orientationDirection"];
        _local = [coder decodeBoolForKey:@"local"];
        _particleAngle = [coder decodeDoubleForKey:@"particleAngle"];
        _particleAngularVelocityVariation = [coder decodeDoubleForKey:@"particleAngularVelocityVariation"];
        _systemSpawnedOnDying = [coder decodeObjectOfClass:[SCNParticleSystem class] forKey:@"systemSpawnedOnDying"];
        _systemSpawnedOnCollision = [coder decodeObjectOfClass:[SCNParticleSystem class] forKey:@"systemSpawnedOnCollision"];
        _systemSpawnedOnLiving = [coder decodeObjectOfClass:[SCNParticleSystem class] forKey:@"systemSpawnedOnLiving"];
        if ([coder containsValueForKey:@"imageSequenceColumnCount"]) {
            _imageSequenceColumnCount = (NSUInteger)[coder decodeIntegerForKey:@"imageSequenceColumnCount"];
        }
        if ([coder containsValueForKey:@"imageSequenceRowCount"]) {
            _imageSequenceRowCount = (NSUInteger)[coder decodeIntegerForKey:@"imageSequenceRowCount"];
        }
        _imageSequenceInitialFrame = [coder decodeDoubleForKey:@"imageSequenceInitialFrame"];
        _imageSequenceInitialFrameVariation = [coder decodeDoubleForKey:@"imageSequenceInitialFrameVariation"];
        _imageSequenceFrameRate = [coder decodeDoubleForKey:@"imageSequenceFrameRate"];
        _imageSequenceFrameRateVariation = [coder decodeDoubleForKey:@"imageSequenceFrameRateVariation"];
        _imageSequenceAnimationMode = [coder decodeIntegerForKey:@"imageSequenceAnimationMode"];
        if ([coder containsValueForKey:@"particleIntensity"]) {
            _particleIntensity = [coder decodeDoubleForKey:@"particleIntensity"];
        }
        _particleIntensityVariation = [coder decodeDoubleForKey:@"particleIntensityVariation"];
        _blackPassEnabled = [coder decodeBoolForKey:@"blackPassEnabled"];
        _particleDiesOnCollision = [coder decodeBoolForKey:@"particleDiesOnCollision"];
        NSArray *colliders = [RevenantSCNCoding decodeArrayOfClass:[SCNNode class] coder:coder forKey:@"colliderNodes"];
        _colliderNodes = colliders.count ? colliders : nil;
        if ([coder containsValueForKey:@"particleMass"]) {
            _particleMass = [coder decodeDoubleForKey:@"particleMass"];
        }
        _particleMassVariation = [coder decodeDoubleForKey:@"particleMassVariation"];
        if ([coder containsValueForKey:@"particleBounce"]) {
            _particleBounce = [coder decodeDoubleForKey:@"particleBounce"];
        }
        _particleBounceVariation = [coder decodeDoubleForKey:@"particleBounceVariation"];
        if ([coder containsValueForKey:@"particleFriction"]) {
            _particleFriction = [coder decodeDoubleForKey:@"particleFriction"];
        }
        _particleFrictionVariation = [coder decodeDoubleForKey:@"particleFrictionVariation"];
        _particleCharge = [coder decodeDoubleForKey:@"particleCharge"];
        _particleChargeVariation = [coder decodeDoubleForKey:@"particleChargeVariation"];
        _dampingFactor = [coder decodeDoubleForKey:@"dampingFactor"];
        _fresnelExponent = [coder decodeDoubleForKey:@"fresnelExponent"];
        _writesToDepthBuffer = [coder decodeBoolForKey:@"writesToDepthBuffer"];
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
    [RevenantSCNCoding encodeVector3:_emittingDirection coder:coder forKey:@"emittingDirection"];
    [RevenantSCNCoding encodeVector3:_acceleration coder:coder forKey:@"acceleration"];
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
    [coder encodeDouble:_emissionDurationVariation forKey:@"emissionDurationVariation"];
    [coder encodeDouble:_idleDuration forKey:@"idleDuration"];
    [coder encodeDouble:_idleDurationVariation forKey:@"idleDurationVariation"];
    [coder encodeDouble:_birthRateVariation forKey:@"birthRateVariation"];
    [coder encodeInteger:_birthLocation forKey:@"birthLocation"];
    [coder encodeInteger:_birthDirection forKey:@"birthDirection"];
    [RevenantSCNCoding encodeVector3:_orientationDirection coder:coder forKey:@"orientationDirection"];
    [coder encodeBool:_local forKey:@"local"];
    [coder encodeDouble:_particleAngle forKey:@"particleAngle"];
    [coder encodeDouble:_particleAngleVariation forKey:@"particleAngleVariation"];
    [coder encodeDouble:_particleAngularVelocity forKey:@"particleAngularVelocity"];
    [coder encodeDouble:_particleAngularVelocityVariation forKey:@"particleAngularVelocityVariation"];
    [coder encodeObject:_systemSpawnedOnDying forKey:@"systemSpawnedOnDying"];
    [coder encodeObject:_systemSpawnedOnCollision forKey:@"systemSpawnedOnCollision"];
    [coder encodeObject:_systemSpawnedOnLiving forKey:@"systemSpawnedOnLiving"];
    [coder encodeInteger:(NSInteger)_imageSequenceColumnCount forKey:@"imageSequenceColumnCount"];
    [coder encodeInteger:(NSInteger)_imageSequenceRowCount forKey:@"imageSequenceRowCount"];
    [coder encodeDouble:_imageSequenceInitialFrame forKey:@"imageSequenceInitialFrame"];
    [coder encodeDouble:_imageSequenceInitialFrameVariation forKey:@"imageSequenceInitialFrameVariation"];
    [coder encodeDouble:_imageSequenceFrameRate forKey:@"imageSequenceFrameRate"];
    [coder encodeDouble:_imageSequenceFrameRateVariation forKey:@"imageSequenceFrameRateVariation"];
    [coder encodeInteger:_imageSequenceAnimationMode forKey:@"imageSequenceAnimationMode"];
    [coder encodeDouble:_particleIntensity forKey:@"particleIntensity"];
    [coder encodeDouble:_particleIntensityVariation forKey:@"particleIntensityVariation"];
    [coder encodeBool:_blackPassEnabled forKey:@"blackPassEnabled"];
    [coder encodeBool:_particleDiesOnCollision forKey:@"particleDiesOnCollision"];
    [coder encodeObject:_colliderNodes forKey:@"colliderNodes"];
    [coder encodeDouble:_particleMass forKey:@"particleMass"];
    [coder encodeDouble:_particleMassVariation forKey:@"particleMassVariation"];
    [coder encodeDouble:_particleBounce forKey:@"particleBounce"];
    [coder encodeDouble:_particleBounceVariation forKey:@"particleBounceVariation"];
    [coder encodeDouble:_particleFriction forKey:@"particleFriction"];
    [coder encodeDouble:_particleFrictionVariation forKey:@"particleFrictionVariation"];
    [coder encodeDouble:_particleCharge forKey:@"particleCharge"];
    [coder encodeDouble:_particleChargeVariation forKey:@"particleChargeVariation"];
    [coder encodeDouble:_dampingFactor forKey:@"dampingFactor"];
    [coder encodeDouble:_fresnelExponent forKey:@"fresnelExponent"];
    [coder encodeBool:_writesToDepthBuffer forKey:@"writesToDepthBuffer"];
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
    copy->_emissionDurationVariation = _emissionDurationVariation;
    copy->_idleDuration = _idleDuration;
    copy->_idleDurationVariation = _idleDurationVariation;
    copy->_birthRateVariation = _birthRateVariation;
    copy->_birthLocation = _birthLocation;
    copy->_birthDirection = _birthDirection;
    copy->_orientationDirection = _orientationDirection;
    copy->_local = _local;
    copy->_particleAngle = _particleAngle;
    copy->_particleAngularVelocityVariation = _particleAngularVelocityVariation;
    copy->_systemSpawnedOnDying = _systemSpawnedOnDying;
    copy->_systemSpawnedOnCollision = _systemSpawnedOnCollision;
    copy->_systemSpawnedOnLiving = _systemSpawnedOnLiving;
    copy->_imageSequenceColumnCount = _imageSequenceColumnCount;
    copy->_imageSequenceRowCount = _imageSequenceRowCount;
    copy->_imageSequenceInitialFrame = _imageSequenceInitialFrame;
    copy->_imageSequenceInitialFrameVariation = _imageSequenceInitialFrameVariation;
    copy->_imageSequenceFrameRate = _imageSequenceFrameRate;
    copy->_imageSequenceFrameRateVariation = _imageSequenceFrameRateVariation;
    copy->_imageSequenceAnimationMode = _imageSequenceAnimationMode;
    copy->_particleIntensity = _particleIntensity;
    copy->_particleIntensityVariation = _particleIntensityVariation;
    copy->_blackPassEnabled = _blackPassEnabled;
    copy->_particleDiesOnCollision = _particleDiesOnCollision;
    copy->_colliderNodes = _colliderNodes;
    copy->_particleMass = _particleMass;
    copy->_particleMassVariation = _particleMassVariation;
    copy->_particleBounce = _particleBounce;
    copy->_particleBounceVariation = _particleBounceVariation;
    copy->_particleFriction = _particleFriction;
    copy->_particleFrictionVariation = _particleFrictionVariation;
    copy->_particleCharge = _particleCharge;
    copy->_particleChargeVariation = _particleChargeVariation;
    copy->_dampingFactor = _dampingFactor;
    copy->_fresnelExponent = _fresnelExponent;
    copy->_writesToDepthBuffer = _writesToDepthBuffer;
    copy->_propertyControllers = _propertyControllers;
    for (NSNumber *key in _eventHandlers) {
        copy->_eventHandlers[key] = [_eventHandlers[key] mutableCopy];
    }
    for (NSNumber *key in _modifiers) {
        copy->_modifiers[key] = [_modifiers[key] mutableCopy];
    }
    return copy;
}

@end
