#import "RevenantCASpringAnimation.h"
#import "RevenantSpringKeyframes.h"
#import "RevenantSpringSolver.h"
#include <math.h>

static double revenant_spring_position_value(double time, void *context)
{
    return revenant_spring_position(*(RevenantSpringParameters *)context, time);
}

#ifdef REVENANT_HOST_BUILD

@implementation RevenantCASpringAnimation {
    CGFloat _mass;
    CGFloat _stiffness;
    CGFloat _damping;
    CGFloat _initialVelocity;
    BOOL _allowsOverdamping;
}

@synthesize mass = _mass;
@synthesize stiffness = _stiffness;
@synthesize damping = _damping;
@synthesize initialVelocity = _initialVelocity;
@synthesize allowsOverdamping = _allowsOverdamping;

static void revenant_spring_set_defaults(RevenantCASpringAnimation *spring)
{
    spring.mass = 1;
    spring.stiffness = 100;
    spring.damping = 10;
    spring.initialVelocity = 0;
    spring.allowsOverdamping = NO;
}

- (instancetype)init
{
    if ((self = [super init])) {
        revenant_spring_set_defaults(self);
    }
    return self;
}

- (instancetype)initWithKeyPath:(NSString *)keyPath
{
    if ((self = [super init])) {
        revenant_spring_set_defaults(self);
        self.keyPath = keyPath;
    }
    return self;
}

- (instancetype)initWithPerceptualDuration:(CFTimeInterval)perceptualDuration bounce:(CGFloat)bounce
{
    if ((self = [self init])) {
        RevenantSpringParameters parameters;
        revenant_spring_perceptual(perceptualDuration, bounce, &parameters);
        self.mass = parameters.mass;
        self.stiffness = parameters.stiffness;
        self.damping = parameters.damping;
        self.initialVelocity = parameters.initialVelocity;
        self.allowsOverdamping = parameters.allowsOverdamping;
        self.duration = [self settlingDuration];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _mass = [coder containsValueForKey:@"mass"] ? [coder decodeDoubleForKey:@"mass"] : 1;
        _stiffness = [coder containsValueForKey:@"stiffness"] ? [coder decodeDoubleForKey:@"stiffness"] : 100;
        _damping = [coder containsValueForKey:@"damping"] ? [coder decodeDoubleForKey:@"damping"] : 10;
        _initialVelocity = [coder containsValueForKey:@"initialVelocity"] ? [coder decodeDoubleForKey:@"initialVelocity"] : 0;
        _allowsOverdamping = [coder containsValueForKey:@"allowsOverdamping"] ? [coder decodeBoolForKey:@"allowsOverdamping"] : NO;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeDouble:_mass forKey:@"mass"];
    [coder encodeDouble:_stiffness forKey:@"stiffness"];
    [coder encodeDouble:_damping forKey:@"damping"];
    [coder encodeDouble:_initialVelocity forKey:@"initialVelocity"];
    [coder encodeBool:_allowsOverdamping forKey:@"allowsOverdamping"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    RevenantCASpringAnimation *copy = [super copyWithZone:zone];
    copy->_mass = _mass;
    copy->_stiffness = _stiffness;
    copy->_damping = _damping;
    copy->_initialVelocity = _initialVelocity;
    copy->_allowsOverdamping = _allowsOverdamping;
    return copy;
}

- (RevenantSpringParameters)revenant_parameters
{
    RevenantSpringParameters parameters;
    parameters.mass = self.mass;
    parameters.stiffness = self.stiffness;
    parameters.damping = self.damping;
    parameters.initialVelocity = self.initialVelocity;
    parameters.allowsOverdamping = self.allowsOverdamping;
    return parameters;
}

- (CFTimeInterval)settlingDuration
{
    return revenant_spring_settling([self revenant_parameters]);
}

- (CFTimeInterval)perceptualDuration
{
    if (!(self.mass > 0) || !(self.stiffness > 0))
        return 0;
    return 2 * M_PI * sqrt(self.mass / self.stiffness);
}

- (CGFloat)bounce
{
    double zeta = self.damping / (2 * sqrt(self.mass * self.stiffness));
    return zeta <= 1 ? 1 - zeta : 1 / zeta - 1;
}

@end

#else

#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static const char RevenantAllowsOverdampingKey;
static IMP revenant_original_copy;
static IMP revenant_original_encode;
static IMP revenant_original_decode;
static IMP revenant_original_add_animation;

@interface CASpringAnimation (RevenantInternal)
@property CGFloat velocity;
- (RevenantSpringParameters)revenant_parameters;
@end

@implementation CASpringAnimation (Revenant)

- (CGFloat)initialVelocity
{
    return self.velocity;
}

- (void)setInitialVelocity:(CGFloat)value
{
    self.velocity = value;
}

- (BOOL)allowsOverdamping
{
    return [objc_getAssociatedObject(self, &RevenantAllowsOverdampingKey) boolValue];
}

- (void)setAllowsOverdamping:(BOOL)value
{
    objc_setAssociatedObject(self, &RevenantAllowsOverdampingKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithPerceptualDuration:(CFTimeInterval)perceptualDuration bounce:(CGFloat)bounce
{
    if ((self = [self init])) {
        RevenantSpringParameters parameters;
        revenant_spring_perceptual(perceptualDuration, bounce, &parameters);
        self.mass = parameters.mass;
        self.stiffness = parameters.stiffness;
        self.damping = parameters.damping;
        self.initialVelocity = parameters.initialVelocity;
        self.allowsOverdamping = parameters.allowsOverdamping;
        self.duration = self.settlingDuration;
    }
    return self;
}

- (RevenantSpringParameters)revenant_parameters
{
    RevenantSpringParameters parameters;
    parameters.mass = self.mass;
    parameters.stiffness = self.stiffness;
    parameters.damping = self.damping;
    parameters.initialVelocity = self.initialVelocity;
    parameters.allowsOverdamping = self.allowsOverdamping;
    return parameters;
}

- (CFTimeInterval)settlingDuration
{
    return revenant_spring_settling([self revenant_parameters]);
}

- (CFTimeInterval)perceptualDuration
{
    if (!(self.mass > 0) || !(self.stiffness > 0))
        return 0;
    return 2 * M_PI * sqrt(self.mass / self.stiffness);
}

- (CGFloat)bounce
{
    double zeta = self.damping / (2 * sqrt(self.mass * self.stiffness));
    return zeta <= 1 ? 1 - zeta : 1 / zeta - 1;
}

@end

static CAKeyframeAnimation *revenant_spring_converted(CAAnimation *animation, CALayer *layer)
{
    Class springClass = objc_getClass("CASpringAnimation");
    if (!springClass || ![animation isKindOfClass:springClass])
        return nil;
    CASpringAnimation *spring = (CASpringAnimation *)animation;
    NSTimeInterval duration = spring.duration > 0 ? spring.duration : spring.settlingDuration;
    if (!(duration > 0) || !isfinite(duration))
        return nil;
    RevenantSpringParameters parameters = [spring revenant_parameters];
    return revenant_spring_keyframes(spring, layer, duration, revenant_spring_position_value, &parameters, NO);
}

static id revenant_spring_copy(id self, SEL selector, NSZone *zone)
{
    id copy = ((id (*)(id, SEL, NSZone *))revenant_original_copy)(self, selector, zone);
    objc_setAssociatedObject(copy, &RevenantAllowsOverdampingKey,
                             objc_getAssociatedObject(self, &RevenantAllowsOverdampingKey), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return copy;
}

static void revenant_spring_encode(id self, SEL selector, NSCoder *coder)
{
    ((void (*)(id, SEL, NSCoder *))revenant_original_encode)(self, selector, coder);
    [coder encodeBool:[self allowsOverdamping] forKey:@"allowsOverdamping"];
}

static id revenant_spring_decode(id self, SEL selector, NSCoder *coder)
{
    id decoded = ((id (*)(id, SEL, NSCoder *))revenant_original_decode)(self, selector, coder);
    [decoded setAllowsOverdamping:[coder containsValueForKey:@"allowsOverdamping"] ? [coder decodeBoolForKey:@"allowsOverdamping"] : NO];
    return decoded;
}

static void revenant_add_animation(CALayer *self, SEL selector, CAAnimation *animation, NSString *key)
{
    CAKeyframeAnimation *keyframes = revenant_spring_converted(animation, self);
    ((void (*)(id, SEL, CAAnimation *, NSString *))revenant_original_add_animation)(self, selector, keyframes ?: animation, key);
}

__attribute__((constructor)) static void revenant_spring_install(void)
{
    Class system = objc_getClass("CASpringAnimation");
    if (system) {
        Method method = class_getInstanceMethod(system, @selector(copyWithZone:));
        if (method && !revenant_original_copy)
            revenant_original_copy = method_setImplementation(method, (IMP)revenant_spring_copy);
        method = class_getInstanceMethod(system, @selector(encodeWithCoder:));
        if (method && !revenant_original_encode)
            revenant_original_encode = method_setImplementation(method, (IMP)revenant_spring_encode);
        method = class_getInstanceMethod(system, @selector(initWithCoder:));
        if (method && !revenant_original_decode)
            revenant_original_decode = method_setImplementation(method, (IMP)revenant_spring_decode);
    }
    Method method = class_getInstanceMethod([CALayer class], @selector(addAnimation:forKey:));
    if (method && !revenant_original_add_animation)
        revenant_original_add_animation = method_setImplementation(method, (IMP)revenant_add_animation);
}

#pragma clang diagnostic pop

#endif
