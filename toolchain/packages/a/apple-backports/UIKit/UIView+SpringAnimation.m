#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <float.h>
#include <math.h>
#include <string.h>
#include "../CharonSpring.h"

static const double charon_spring_settled = 0.001;
static const NSUInteger charon_spring_iterations = 20;
static const double charon_spring_frames_per_second = 60;
static const NSUInteger charon_spring_maximum_samples = 600;
static const double charon_spring_duration_tolerance = 1e-4;

static double charon_spring_amplitude(double omega, double zeta, double velocity, double duration, double *derivative)
{
    if (zeta < 1) {
        double damped = omega * sqrt(1 - zeta * zeta);
        double decay = exp(-zeta * omega * duration);
        double amplitude = (zeta * omega - velocity) / damped;
        double value = decay * amplitude;
        if (derivative)
            *derivative = decay * (velocity / (omega * omega * sqrt(1 - zeta * zeta)) - zeta * duration * amplitude);
        return value;
    }
    double decay = exp(-omega * duration);
    double value = (1 + (omega - velocity) * duration) * decay;
    if (derivative)
        *derivative = -decay * duration * duration * (omega - velocity);
    return value;
}

double charon_spring_frequency(double duration, double dampingRatio, double velocity)
{
    double zeta = MIN(MAX(dampingRatio, FLT_EPSILON), 1.0);
    double omega = 2 * M_PI / duration;
    for (NSUInteger step = 0; step < charon_spring_iterations; step++) {
        double derivative = 0;
        double value = charon_spring_amplitude(omega, zeta, velocity, duration, &derivative);
        if (value < 0) {
            value = -value;
            derivative = -derivative;
        }
        if (derivative == 0)
            break;
        double next = omega - (value - charon_spring_settled) / derivative;
        if (!isfinite(next) || next <= 0)
            return NAN;
        if (fabs(next - omega) < 1e-9)
            return next;
        omega = next;
    }
    return isfinite(omega) && omega > 0 ? omega : NAN;
}

double charon_spring_progress(double omega, double dampingRatio, double velocity, double time)
{
    return charon_spring_value(omega, MIN(MAX(dampingRatio, FLT_EPSILON), 1.0), velocity, time);
}

static BOOL charon_decompose(CATransform3D transform, double *components)
{
    if (!CATransform3DIsAffine(transform))
        return NO;
    CGAffineTransform affine = CATransform3DGetAffineTransform(transform);
    double scaleX = sqrt(affine.a * affine.a + affine.b * affine.b);
    double scaleY = sqrt(affine.c * affine.c + affine.d * affine.d);
    double determinant = affine.a * affine.d - affine.b * affine.c;
    if (scaleX == 0 || scaleY == 0)
        return NO;
    double shear = (affine.a * affine.c + affine.b * affine.d) / (scaleX * scaleY);
    if (fabs(shear) > 1e-6)
        return NO;
    if (determinant < 0)
        scaleY = -scaleY;
    components[0] = atan2(affine.b, affine.a);
    components[1] = scaleX;
    components[2] = scaleY;
    components[3] = affine.tx;
    components[4] = affine.ty;
    return YES;
}

static id charon_interpolate_transform(NSValue *from, NSValue *to, double progress)
{
    CATransform3D start, finish;
    [from getValue:&start];
    [to getValue:&finish];
    double first[5], second[5];
    if (charon_decompose(start, first) && charon_decompose(finish, second)) {
        double turn = second[0] - first[0];
        while (turn > M_PI)
            turn -= 2 * M_PI;
        while (turn < -M_PI)
            turn += 2 * M_PI;
        double angle = first[0] + turn * progress;
        double scaleX = first[1] + (second[1] - first[1]) * progress;
        double scaleY = first[2] + (second[2] - first[2]) * progress;
        CGAffineTransform affine = CGAffineTransformMake((CGFloat)(cos(angle) * scaleX), (CGFloat)(sin(angle) * scaleX),
                                                         (CGFloat)(-sin(angle) * scaleY), (CGFloat)(cos(angle) * scaleY),
                                                         (CGFloat)(first[3] + (second[3] - first[3]) * progress),
                                                         (CGFloat)(first[4] + (second[4] - first[4]) * progress));
        return [NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(affine)];
    }
    CGFloat *left = (CGFloat *)&start, *right = (CGFloat *)&finish;
    CATransform3D mixed;
    CGFloat *result = (CGFloat *)&mixed;
    for (NSUInteger index = 0; index < sizeof(CATransform3D) / sizeof(CGFloat); index++)
        result[index] = left[index] + (right[index] - left[index]) * (CGFloat)progress;
    return [NSValue valueWithCATransform3D:mixed];
}

id charon_spring_interpolate(id from, id to, double progress)
{
    if ([from isKindOfClass:[NSNumber class]] && [to isKindOfClass:[NSNumber class]]) {
        double start = [from doubleValue], finish = [to doubleValue];
        return [NSNumber numberWithDouble:start + (finish - start) * progress];
    }
    if (![from isKindOfClass:[NSValue class]] || ![to isKindOfClass:[NSValue class]])
        return nil;
    const char *type = [from objCType];
    if (strcmp(type, [to objCType]) != 0)
        return nil;
    if (strcmp(type, @encode(CATransform3D)) == 0)
        return charon_interpolate_transform(from, to, progress);
    static const char *const types[] = {@encode(CGPoint), @encode(CGSize), @encode(CGRect), @encode(UIEdgeInsets), @encode(CGVector)};
    static const NSUInteger counts[] = {2, 2, 4, 4, 2};
    for (NSUInteger index = 0; index < sizeof(types) / sizeof(*types); index++) {
        if (strcmp(type, types[index]) != 0)
            continue;
        CGFloat start[4], finish[4], mixed[4];
        [from getValue:start];
        [to getValue:finish];
        for (NSUInteger component = 0; component < counts[index]; component++)
            mixed[component] = start[component] + (finish[component] - start[component]) * (CGFloat)progress;
        return [NSValue valueWithBytes:mixed objCType:type];
    }
    return nil;
}

@interface CharonSpringCompletion : NSObject <CAAnimationDelegate>
@property (nonatomic, copy) void (^completion)(BOOL finished);
@property (nonatomic) NSInteger running;
@property (nonatomic) BOOL interrupted;
@end

@implementation CharonSpringCompletion

@synthesize completion = _completion, running = _running, interrupted = _interrupted;

- (void)animationDidStart:(CAAnimation *)animation
{
    self.running++;
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished
{
    if (!finished)
        self.interrupted = YES;
    if (--self.running > 0)
        return;
    void (^completion)(BOOL finished) = self.completion;
    self.completion = nil;
    if (completion)
        completion(!self.interrupted);
}

@end

static void charon_collect_layers(CALayer *layer, NSMutableArray *layers)
{
    [layers addObject:layer];
    for (CALayer *sublayer in layer.sublayers)
        charon_collect_layers(sublayer, layers);
}

static NSArray *charon_animated_layers(void)
{
    NSMutableArray *layers = [NSMutableArray array];
    for (UIWindow *window in [UIApplication sharedApplication].windows)
        charon_collect_layers(window.layer, layers);
    return layers;
}

static NSSet *charon_animations_of_layers(NSArray *layers)
{
    NSMutableSet *found = [NSMutableSet set];
    for (CALayer *layer in layers) {
        for (NSString *key in layer.animationKeys) {
            CAAnimation *animation = [layer animationForKey:key];
            if (animation)
                [found addObject:animation];
        }
    }
    return found;
}

static CAKeyframeAnimation *charon_spring_keyframes(CABasicAnimation *animation, CALayer *layer, double omega, double dampingRatio, double velocity, NSTimeInterval delay)
{
    id from = animation.fromValue;
    id to = animation.toValue;
    if (!from)
        return nil;
    if (!to)
        to = [layer valueForKeyPath:animation.keyPath];
    if (!to || !charon_spring_interpolate(from, to, 0.5))
        return nil;
    NSUInteger samples = (NSUInteger)round(animation.duration * charon_spring_frames_per_second);
    samples = MAX(2u, MIN(samples, charon_spring_maximum_samples));
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:samples + 1];
    for (NSUInteger index = 0; index <= samples; index++) {
        double time = animation.duration * index / samples;
        [values addObject:charon_spring_interpolate(from, to, charon_spring_progress(omega, dampingRatio, velocity, time))];
    }
    [values replaceObjectAtIndex:values.count - 1 withObject:to];
    CAKeyframeAnimation *keyframes = [CAKeyframeAnimation animationWithKeyPath:animation.keyPath];
    keyframes.values = values;
    keyframes.calculationMode = kCAAnimationLinear;
    keyframes.duration = animation.duration;
    keyframes.beginTime = delay > 0 ? [layer convertTime:CACurrentMediaTime() fromLayer:nil] + delay : 0;
    keyframes.timeOffset = animation.timeOffset;
    keyframes.speed = animation.speed;
    keyframes.repeatCount = animation.repeatCount;
    keyframes.repeatDuration = animation.repeatDuration;
    keyframes.autoreverses = animation.autoreverses;
    keyframes.fillMode = animation.fillMode;
    keyframes.removedOnCompletion = animation.removedOnCompletion;
    return keyframes;
}

@implementation UIView (CharonSpringAnimation)

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    double omega = duration > 0 ? charon_spring_frequency(duration, dampingRatio, velocity) : NAN;
    UIViewAnimationOptions curves = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionCurveLinear;
    UIViewAnimationOptions timing = isnan(omega) ? (options & curves) : UIViewAnimationOptionCurveEaseOut;
    NSSet *existing = isnan(omega) ? nil : charon_animations_of_layers(charon_animated_layers());
    CharonSpringCompletion *shadow = [[CharonSpringCompletion alloc] init];
    __block BOOL shadowed = NO;
    [UIView animateWithDuration:duration delay:delay options:(options & ~curves) | timing animations:animations completion:^(BOOL finished) {
        if (!shadowed && completion)
            completion(finished);
    }];
    if (!existing)
        return;
    NSMutableArray *replacements = [NSMutableArray array];
    for (CALayer *layer in charon_animated_layers()) {
        for (NSString *key in layer.animationKeys) {
            CAAnimation *animation = [layer animationForKey:key];
            if (![animation isKindOfClass:[CABasicAnimation class]] || [existing containsObject:animation])
                continue;
            if (fabs(animation.duration - duration) > duration * charon_spring_duration_tolerance)
                continue;
            CAKeyframeAnimation *keyframes = charon_spring_keyframes((CABasicAnimation *)animation, layer, omega, dampingRatio, velocity, delay);
            if (keyframes)
                [replacements addObject:[NSArray arrayWithObjects:layer, key, keyframes, nil]];
        }
    }
    if (!replacements.count)
        return;
    shadowed = YES;
    shadow.completion = completion;
    for (NSArray *replacement in replacements) {
        CALayer *layer = [replacement objectAtIndex:0];
        NSString *key = [replacement objectAtIndex:1];
        CAKeyframeAnimation *keyframes = [replacement objectAtIndex:2];
        keyframes.delegate = shadow;
        [layer removeAnimationForKey:key];
        [layer addAnimation:keyframes forKey:key];
    }
}

@end
