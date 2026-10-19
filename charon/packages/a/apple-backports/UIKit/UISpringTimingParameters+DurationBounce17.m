#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>

static void charon_bounce_spring(NSTimeInterval duration, CGFloat bounce,
                                 CGFloat *mass, CGFloat *stiffness, CGFloat *damping)
{
    const double m = 1.0;
    const double s = duration > 0 ? 4.0 * M_PI * M_PI / (duration * duration) : INFINITY;
    const double critical = 2.0 * sqrt(m * s);
    double ratio;
    if (bounce >= 0)
        ratio = 1.0 - bounce;
    else if (bounce > -1.0)
        ratio = 1.0 / (1.0 + bounce);
    else
        ratio = INFINITY;
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
    return [self initWithMass:mass stiffness:stiffness damping:damping initialVelocity:initialVelocity];
}

@end
