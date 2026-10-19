#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

enum {
    CharonCubicCurveDefault = 5,
    CharonCubicCurveControlPoints = 6
};

@interface CharonViewCubicTimingFunction : NSObject <NSCopying, NSCoding>
- (instancetype)initWithControlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2;
@property (nonatomic, readonly) CGPoint controlPoint1;
@property (nonatomic, readonly) CGPoint controlPoint2;
- (CAMediaTimingFunction *)_mediaTimingFunction;
@end

Class charon_cubic_timing_function_class(void);
id charon_cubic_timing_function(CGPoint point1, CGPoint point2);

@interface UICubicTimingParameters (CharonTiming)
- (CharonViewCubicTimingFunction *)timingFunction;
- (CharonViewCubicTimingFunction *)effectiveTimingFunction;
@end

@interface UISpringTimingParameters (CharonTiming)
- (BOOL)implicitDuration;
- (CGFloat)mass;
- (CGFloat)stiffness;
- (CGFloat)damping;
- (CGFloat)dampingRatio;
- (NSTimeInterval)settlingDuration;
@end

double charon_spring_frequency(double duration, double dampingRatio, double velocity);
double charon_spring_progress(double omega, double dampingRatio, double velocity, double time);

@interface UIViewPropertyAnimator (CharonAnimator)
- (NSTimeInterval)internalDuration;
- (NSString *)_stateAsString;
@end
