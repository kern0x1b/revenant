#import "CharonTimingParameters.h"
#include <math.h>

/* A CGFloat is a float on the architectures this is built for and a double on the
   64-bit ones, and the archive carries whichever it is, as Apple's own does. */
#if CGFLOAT_IS_DOUBLE
#define charon_encode_scalar(coder, value, key) [(coder) encodeDouble:(value) forKey:(key)]
#define charon_decode_scalar(coder, key) ((CGFloat)[(coder) decodeDoubleForKey:(key)])
#else
#define charon_encode_scalar(coder, value, key) [(coder) encodeFloat:(value) forKey:(key)]
#define charon_decode_scalar(coder, key) ((CGFloat)[(coder) decodeFloatForKey:(key)])
#endif


/* How long the spring takes to come to rest, for one component of the initial
   velocity. Read off +[UIView _durationOfSpringAnimationWithMass:stiffness:damping:velocity:],
   which iOS 6 has not got. The damping ratio is clamped to at most one, so a
   spring damped past critical settles as a critically damped one does. */
static double charon_settling(double mass, double stiffness, double damping, double velocity)
{
    double zeta = damping / (2 * sqrt(mass * stiffness));
    zeta = MIN(MAX(zeta, 0.0), 1.0);
    if (zeta == 0)
        return INFINITY;
    double frequency = sqrt(stiffness / mass);
    if (zeta < 1) {
        double decay = frequency * zeta, damped = frequency * sqrt(1 - zeta * zeta);
        return MAX((-log(0.001) + log(1 + fabs((decay - velocity) / damped))) / decay, 0.0);
    }
    double reach = frequency - velocity;
    if (reach == 0)
        return NAN;
    double logarithm = log(fabs(0.001 * frequency * exp(-frequency / reach) / reach));
    double amplitude = -1.0 - logarithm;
    double fitted = 1.0 + (0.3361 * sqrt(amplitude / 2.0))
                        / (1.0 - 0.0042 * amplitude * exp(-0.0201 * sqrt(amplitude)));
    double corrected = logarithm + (-5.9506097239272915) * (1.0 - 1.0 / fitted);
    return -(frequency + reach * corrected) / (frequency * reach);
}

@implementation UISpringTimingParameters {
@private
    BOOL _implicitDuration;
    CGFloat _mass;
    CGFloat _stiffness;
    CGFloat _damping;
    CGFloat _dampingRatio;
    CGVector _initialVelocity;
}

- (instancetype)init
{
    if ((self = [super init])) {
        [self setMass:3];
        [self setStiffness:1000];
        [self setDamping:500];
    }
    return self;
}

- (instancetype)initWithMass:(CGFloat)mass stiffness:(CGFloat)stiffness damping:(CGFloat)damping
             initialVelocity:(CGVector)velocity
{
    if ((self = [super init])) {
        [self setMass:mass];
        [self setStiffness:stiffness];
        [self setDamping:damping];
        _initialVelocity = velocity;
    }
    return self;
}

- (instancetype)initWithDampingRatio:(CGFloat)ratio initialVelocity:(CGVector)velocity
{
    if ((self = [super init])) {
        _dampingRatio = ratio;
        _initialVelocity = velocity;
    }
    return self;
}

- (instancetype)initWithDampingRatio:(CGFloat)ratio
{
    return [self initWithDampingRatio:ratio initialVelocity:CGVectorMake(0, 0)];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidUnarchiveOperationException format:@"%@ only supports keyed coding.", [self class]];
        return nil;
    }
    if ((self = [super init])) {
        if ([coder decodeBoolForKey:@"implicitDuration"]) {
            [self setMass:charon_decode_scalar(coder, @"mass")];
            [self setStiffness:charon_decode_scalar(coder, @"stiffness")];
            [self setDamping:charon_decode_scalar(coder, @"damping")];
        } else {
            _dampingRatio = charon_decode_scalar(coder, @"dampingRatio");
        }
        _initialVelocity = [coder decodeCGVectorForKey:@"velocity"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_implicitDuration forKey:@"implicitDuration"];
    if (_implicitDuration) {
        charon_encode_scalar(coder, _mass, @"mass");
        charon_encode_scalar(coder, _stiffness, @"stiffness");
        charon_encode_scalar(coder, _damping, @"damping");
    } else {
        charon_encode_scalar(coder, _dampingRatio, @"dampingRatio");
    }
    [coder encodeCGVector:_initialVelocity forKey:@"velocity"];
}

- (UITimingCurveType)timingCurveType
{
    return UITimingCurveTypeSpring;
}

- (UICubicTimingParameters *)cubicTimingParameters
{
    return nil;
}

- (UISpringTimingParameters *)springTimingParameters
{
    return self;
}

- (CGVector)initialVelocity
{
    return _initialVelocity;
}

- (BOOL)implicitDuration
{
    return _implicitDuration;
}

- (CGFloat)mass
{
    return _mass;
}

- (CGFloat)stiffness
{
    return _stiffness;
}

- (CGFloat)damping
{
    return _damping;
}

- (CGFloat)dampingRatio
{
    if (!_implicitDuration)
        return _dampingRatio;
    CGFloat critical = 2 * sqrt(_mass * _stiffness);
    return critical != 0 ? _damping / critical : 0;
}

- (void)setMass:(CGFloat)mass
{
    _mass = mass;
    _implicitDuration = YES;
}

- (void)setStiffness:(CGFloat)stiffness
{
    _stiffness = stiffness;
    _implicitDuration = YES;
}

- (void)setDamping:(CGFloat)damping
{
    _damping = damping;
    _implicitDuration = YES;
}

- (NSTimeInterval)settlingDuration
{
    if (!_implicitDuration)
        return 0;
    double along = charon_settling(_mass, _stiffness, _damping, _initialVelocity.dx);
    double across = charon_settling(_mass, _stiffness, _damping, _initialVelocity.dy);
    return MAX(isnan(along) ? 0 : along, isnan(across) ? 0 : across);
}

- (id)copyWithZone:(NSZone *)zone
{
    if (_implicitDuration)
        return [[[self class] allocWithZone:zone] initWithMass:_mass stiffness:_stiffness damping:_damping
                                              initialVelocity:_initialVelocity];
    return [[[self class] allocWithZone:zone] initWithDampingRatio:_dampingRatio initialVelocity:_initialVelocity];
}

- (NSString *)description
{
    if (_implicitDuration)
        return [NSString stringWithFormat:@"<%@ (%p) mass=%.3f, stiffness=%.3f, damping=%.3f, velocity=(%.3f,%.3f)>",
                                          [self class], self, _mass, _stiffness, _damping,
                                          _initialVelocity.dx, _initialVelocity.dy];
    return [NSString stringWithFormat:@"<%@ (%p) dampingRatio=%.3f, velocity=(%.3f,%.3f)>",
                                      [self class], self, _dampingRatio, _initialVelocity.dx, _initialVelocity.dy];
}

@end
