#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "RevenantSpringKeyframes.h"
#include <float.h>
#include <math.h>
#include "../RevenantSpring.h"

static const double revenant_spring_settled = 0.001;
static const NSUInteger revenant_spring_iterations = 20;
static const double revenant_spring_duration_tolerance = 1e-4;

static double revenant_spring_amplitude(double omega, double zeta, double velocity, double duration, double *derivative)
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

double revenant_spring_frequency(double duration, double dampingRatio, double velocity)
{
    double zeta = MIN(MAX(dampingRatio, FLT_EPSILON), 1.0);
    double omega = 2 * M_PI / duration;
    for (NSUInteger step = 0; step < revenant_spring_iterations; step++) {
        double derivative = 0;
        double value = revenant_spring_amplitude(omega, zeta, velocity, duration, &derivative);
        if (value < 0) {
            value = -value;
            derivative = -derivative;
        }
        if (derivative == 0)
            break;
        double next = omega - (value - revenant_spring_settled) / derivative;
        if (!isfinite(next) || next <= 0)
            return NAN;
        if (fabs(next - omega) < 1e-9)
            return next;
        omega = next;
    }
    return isfinite(omega) && omega > 0 ? omega : NAN;
}

double revenant_spring_progress(double omega, double dampingRatio, double velocity, double time)
{
    return revenant_spring_value(omega, MIN(MAX(dampingRatio, FLT_EPSILON), 1.0), velocity, time);
}

@interface RevenantSpringCompletion : NSObject <CAAnimationDelegate>
@property (nonatomic, copy) void (^completion)(BOOL finished);
@property (nonatomic) NSInteger running;
@property (nonatomic) BOOL interrupted;
@end

@implementation RevenantSpringCompletion

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

static void revenant_collect_layers(CALayer *layer, NSMutableArray *layers)
{
    [layers addObject:layer];
    for (CALayer *sublayer in layer.sublayers)
        revenant_collect_layers(sublayer, layers);
}

static NSArray *revenant_animated_layers(void)
{
    NSMutableArray *layers = [NSMutableArray array];
    for (UIWindow *window in [UIApplication sharedApplication].windows)
        revenant_collect_layers(window.layer, layers);
    return layers;
}

static NSSet *revenant_animations_of_layers(NSArray *layers)
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

typedef struct {
    double omega;
    double dampingRatio;
    double velocity;
} RevenantViewSpringContext;

static double revenant_view_spring_position(double time, void *context)
{
    RevenantViewSpringContext *spring = context;
    return revenant_spring_progress(spring->omega, spring->dampingRatio, spring->velocity, time);
}

@implementation UIView (RevenantSpringAnimation)

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    double omega = duration > 0 ? revenant_spring_frequency(duration, dampingRatio, velocity) : NAN;
    UIViewAnimationOptions curves = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionCurveLinear;
    UIViewAnimationOptions timing = isnan(omega) ? (options & curves) : UIViewAnimationOptionCurveEaseOut;
    NSSet *existing = isnan(omega) ? nil : revenant_animations_of_layers(revenant_animated_layers());
    RevenantSpringCompletion *shadow = [[RevenantSpringCompletion alloc] init];
    __block BOOL shadowed = NO;
    [UIView animateWithDuration:duration delay:delay options:(options & ~curves) | timing animations:animations completion:^(BOOL finished) {
        if (!shadowed && completion)
            completion(finished);
    }];
    if (!existing)
        return;
    NSMutableArray *replacements = [NSMutableArray array];
    for (CALayer *layer in revenant_animated_layers()) {
        for (NSString *key in layer.animationKeys) {
            CAAnimation *animation = [layer animationForKey:key];
            if (![animation isKindOfClass:[CABasicAnimation class]] || [existing containsObject:animation])
                continue;
            if (!animation.fromValue || fabs(animation.duration - duration) > duration * revenant_spring_duration_tolerance)
                continue;
            RevenantViewSpringContext context = {omega, dampingRatio, velocity};
            CAKeyframeAnimation *keyframes = revenant_spring_keyframes((CABasicAnimation *)animation, layer, animation.duration, revenant_view_spring_position, &context, YES);
            if (keyframes) {
                keyframes.beginTime = delay > 0 ? [layer convertTime:CACurrentMediaTime() fromLayer:nil] + delay : 0;
                [replacements addObject:[NSArray arrayWithObjects:layer, key, keyframes, nil]];
            }
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
