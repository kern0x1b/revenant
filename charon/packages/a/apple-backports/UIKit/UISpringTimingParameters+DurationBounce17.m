// UISpringTimingParameters+DurationBounce17.m - the two bounce-form initialisers iOS 17.0 added.
//
// A separate file from UISpringTimingParameters.m because a .m holds ONE release's API: that file is
// 13.0 (initWithDampingRatio:, initWithMass:stiffness:damping:initialVelocity:), and release-split.lua
// reads band points only, so one file holding both would pass it and only a reader would catch it.
//
// WHAT THE HOST ANSWERS, measured on the host's own UIKit under Mac Catalyst
// (facts/UIKit/UIKit17Absence.md, M6). The spring constants were read back off the parameters object
// rather than inferred, because the port's own settling solver does NOT reproduce them: an earlier
// version of this file derived the spring from the settling duration and was wrong by up to 358%, which
// is why the constants below are the measured ones.
//
//   mass       = 1, at every duration and every bounce
//   stiffness  = 4*pi^2 / duration^2          (measured 631.6547, 157.9137, 39.4784 at 0.25, 0.5, 1.0)
//   critical   = 2*sqrt(mass*stiffness) = 4*pi/duration
//   damping    = critical * f(bounce), with
//                  f(b) = 1 - b            for b >= 0   (b=1 -> 0, i.e. undamped, which never settles)
//                  f(b) = 1 / (1 + b)      for b <  0   (b=-0.5 -> 2, b=-1 -> infinity)
//   velocity   passes through exactly: (2,0) reads back (2,0)
//
// That reproduces every measured damping to within 0.00005 over fifteen (duration, bounce) samples, and
// the stiffness formula to 0.00003 over three durations - which is what makes these constants Apple's
// and not a fit. Nothing raises: bounce 2.0, bounce -1.5 and duration 0.0 all return a usable object,
// so this file clamps nothing and adds no precondition of its own.
//
// The negative branch is measured rather than assumed. The obvious guess, f(b) = 1 - b for every sign,
// is right for b >= 0 and wrong for b < 0: at b = -0.5 it predicts 1.5 * critical where the host answers
// 2.0. Samples at -0.1, -0.25, -0.5 and -0.75 give 1.1111, 1.3333, 2.0 and 4.0, which is 1/(1+b) to four
// places. At b = -1 that is infinite and the host reports damping = inf, which is what an over-damped
// spring at the boundary does.

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>

/* The spring a bounce-form parameters object carries, for one (duration, bounce).
   Written as the measured formulas rather than as a table of fitted numbers, because the formulas are
   what the measurements agree with to five decimal places and a table would only agree at the points it
   was built from. `duration` is the perceptual duration the caller passed and `bounce` runs from -1 to 1. */
static void charon_bounce_spring(NSTimeInterval duration, CGFloat bounce,
                                 CGFloat *mass, CGFloat *stiffness, CGFloat *damping)
{
    const double m = 1.0;
    // stiffness = 4*pi^2/duration^2, so a zero duration - which the host accepts and does not reject -
    // divides by zero. The host's own answer there is left to the caller below rather than guessed.
    const double s = duration > 0 ? 4.0 * M_PI * M_PI / (duration * duration) : INFINITY;
    const double critical = 2.0 * sqrt(m * s);
    double ratio;
    if (bounce >= 0)
        ratio = 1.0 - bounce;          // 1 at bounce 0 (critical), 0 at bounce 1 (undamped)
    else if (bounce > -1.0)
        ratio = 1.0 / (1.0 + bounce);  // 2 at bounce -0.5, diverging at bounce -1 (measured: inf)
    else
        ratio = INFINITY;              // measured: damping is inf at bounce -1
    if (mass) *mass = (CGFloat)m;
    if (stiffness) *stiffness = (CGFloat)s;
    if (damping) *damping = (CGFloat)(critical * ratio);
}

@implementation UISpringTimingParameters (CharonDurationBounce17)

- (instancetype)initWithDuration:(NSTimeInterval)duration bounce:(CGFloat)bounce
{
    return [self initWithDuration:duration bounce:bounce initialVelocity:CGVectorMake(0, 0)];
}

- (instancetype)initWithDuration:(NSTimeInterval)duration bounce:(CGFloat)bounce
                  initialVelocity:(CGVector)initialVelocity
{
    CGFloat mass, stiffness, damping;
    charon_bounce_spring(duration, bounce, &mass, &stiffness, &damping);
    // The velocity is the caller's own and the host passes it through untouched (measured: (2,0) reads
    // back (2,0)), so it goes to the 13.0 initialiser unchanged rather than being scaled by anything
    // here. A velocity the caller did not pass is the zero vector, which is what this file sends.
    return [self initWithMass:mass stiffness:stiffness damping:damping initialVelocity:initialVelocity];
}

@end