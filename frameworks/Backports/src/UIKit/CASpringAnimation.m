#import "RevenantCASpringAnimation.h"
#import "RevenantSpringKeyframes.h"
#import "RevenantSpringSolver.h"
#include <math.h>

#ifndef REVENANT_HOST_BUILD
#import <objc/runtime.h>

static double revenant_spring_position_value(double time, void *context);
#endif

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

- (instancetype)init
{
    if ((self = [super init])) {
        _mass = 1;
        _stiffness = 100;
        _damping = 10;
        _initialVelocity = 0;
        _allowsOverdamping = NO;
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

#ifndef REVENANT_HOST_BUILD

+ (Class)class
{
    Class proxy = objc_getClass("RevenantCASpringAnimation");
    if (self == proxy) {
        Class publicClass = objc_getClass("CASpringAnimation");
        return publicClass ?: self;
    }
    return self;
}

+ (id)alloc
{
    Class proxy = objc_getClass("RevenantCASpringAnimation");
    if (self == proxy) {
        Class publicClass = objc_getClass("CASpringAnimation");
        if (publicClass && publicClass != proxy)
            return [publicClass alloc];
    }
    return class_createInstance(self, 0);
}

+ (id)allocWithZone:(NSZone *)zone
{
    Class proxy = objc_getClass("RevenantCASpringAnimation");
    if (self == proxy) {
        Class publicClass = objc_getClass("CASpringAnimation");
        if (publicClass && publicClass != proxy)
            return [publicClass allocWithZone:zone];
    }
    return class_createInstance(self, 0);
}

+ (Class)superclass
{
    Class superclass = class_getSuperclass(self);
    Class proxy = objc_getClass("RevenantCASpringAnimation");
    while (superclass == proxy)
        superclass = class_getSuperclass(superclass);
    return superclass;
}

+ (BOOL)isSubclassOfClass:(Class)aClass
{
    Class proxy = objc_getClass("RevenantCASpringAnimation");
    if (self == proxy) {
        Class publicClass = objc_getClass("CASpringAnimation");
        if (publicClass && publicClass != proxy)
            return [publicClass isSubclassOfClass:aClass];
    }
    return [super isSubclassOfClass:aClass];
}

+ (BOOL)instancesRespondToSelector:(SEL)selector
{
    Class proxy = objc_getClass("RevenantCASpringAnimation");
    if (self == proxy) {
        Class publicClass = objc_getClass("CASpringAnimation");
        if (publicClass && publicClass != proxy)
            return [publicClass instancesRespondToSelector:selector];
    }
    return [super instancesRespondToSelector:selector];
}

- (Class)superclass
{
    Class superclass = class_getSuperclass(object_getClass(self));
    Class proxy = objc_getClass("RevenantCASpringAnimation");
    while (superclass == proxy)
        superclass = class_getSuperclass(superclass);
    return superclass;
}

- (void)runActionForKey:(NSString *)event object:(id)object arguments:(NSDictionary *)arguments
{
    if ([object isKindOfClass:[CALayer class]]) {
        Class springClass = objc_getClass("RevenantCASpringAnimation");
        if (springClass && [self isKindOfClass:springClass]) {
            RevenantSpringParameters parameters = [self revenant_parameters];
            NSTimeInterval duration = self.duration > 0 ? self.duration : self.settlingDuration;
            if (duration > 0 && isfinite(duration)) {
                CAKeyframeAnimation *keyframes = revenant_spring_keyframes(self, object, duration, revenant_spring_position_value, &parameters, NO);
                if (keyframes) {
                    [(CALayer *)object addAnimation:keyframes forKey:event];
                    return;
                }
            }
        }
    }
    [super runActionForKey:event object:object arguments:arguments];
}

static double revenant_spring_position_value(double time, void *context)
{
    return revenant_spring_position(*(RevenantSpringParameters *)context, time);
}

static CAKeyframeAnimation *revenant_spring_converted(CAAnimation *animation, CALayer *layer)
{
    Class springClass = objc_getClass("RevenantCASpringAnimation");
    if (!springClass || ![animation isKindOfClass:springClass])
        return nil;
    RevenantCASpringAnimation *spring = (RevenantCASpringAnimation *)animation;
    NSTimeInterval duration = spring.duration > 0 ? spring.duration : spring.settlingDuration;
    if (!(duration > 0) || !isfinite(duration))
        return nil;
    RevenantSpringParameters parameters = [spring revenant_parameters];
    return revenant_spring_keyframes(spring, layer, duration, revenant_spring_position_value, &parameters, NO);
}

static IMP revenant_original_add_animation;

static void revenant_add_animation(CALayer *self, SEL _cmd, CAAnimation *animation, NSString *key)
{
    CAKeyframeAnimation *keyframes = revenant_spring_converted(animation, self);
    ((void (*)(id, SEL, CAAnimation *, NSString *))revenant_original_add_animation)(self, _cmd, keyframes ?: animation, key);
}

__attribute__((constructor)) static void revenant_spring_install(void)
{
    Class proxy = objc_getClass("RevenantCASpringAnimation");
    if (proxy && !objc_getClass("CASpringAnimation")) {
        Class publicClass = objc_allocateClassPair(proxy, "CASpringAnimation", 0);
        if (publicClass)
            objc_registerClassPair(publicClass);
    }
    Method method = class_getInstanceMethod([CALayer class], @selector(addAnimation:forKey:));
    if (method && !revenant_original_add_animation)
        revenant_original_add_animation = method_setImplementation(method, (IMP)revenant_add_animation);
}

#endif

@end

#ifndef REVENANT_HOST_BUILD
__asm__(".globl _OBJC_CLASS_$_CASpringAnimation\n"
        ".set _OBJC_CLASS_$_CASpringAnimation, _OBJC_CLASS_$_RevenantCASpringAnimation\n"
        ".globl _OBJC_METACLASS_$_CASpringAnimation\n"
        ".set _OBJC_METACLASS_$_CASpringAnimation, _OBJC_METACLASS_$_RevenantCASpringAnimation\n");
#endif
