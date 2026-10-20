#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

enum {
    RevenantCubicCurveDefault = 5,
    RevenantCubicCurveControlPoints = 6
};

@interface RevenantViewCubicTimingFunction : NSObject <NSCopying, NSCoding>
- (instancetype)initWithControlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2;
@property (nonatomic, readonly) CGPoint controlPoint1;
@property (nonatomic, readonly) CGPoint controlPoint2;
- (CAMediaTimingFunction *)_mediaTimingFunction;
@end

Class revenant_cubic_timing_function_class(void);
id revenant_cubic_timing_function(CGPoint point1, CGPoint point2);

@interface UICubicTimingParameters (RevenantTiming)
- (RevenantViewCubicTimingFunction *)timingFunction;
- (RevenantViewCubicTimingFunction *)effectiveTimingFunction;
@end

@interface UISpringTimingParameters (RevenantTiming)
- (BOOL)implicitDuration;
- (CGFloat)mass;
- (CGFloat)stiffness;
- (CGFloat)damping;
- (CGFloat)dampingRatio;
- (NSTimeInterval)settlingDuration;
@end

double revenant_spring_frequency(double duration, double dampingRatio, double velocity);
double revenant_spring_progress(double omega, double dampingRatio, double velocity, double time);

@interface UIViewPropertyAnimator (RevenantAnimator)
- (NSTimeInterval)internalDuration;
- (NSString *)_stateAsString;
@end
