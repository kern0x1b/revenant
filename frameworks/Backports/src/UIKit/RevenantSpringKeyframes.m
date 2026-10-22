#import "RevenantSpringKeyframes.h"
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
#include <math.h>
#include <string.h>

static const double RevenantSpringFramesPerSecond = 60;
static const NSUInteger RevenantSpringMaximumSamples = 4096;

static BOOL revenant_decompose(CATransform3D transform, double *components)
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

static id revenant_interpolate_transform(NSValue *from, NSValue *to, double progress)
{
    CATransform3D start, finish;
    [from getValue:&start];
    [to getValue:&finish];
    double first[5], second[5];
    if (revenant_decompose(start, first) && revenant_decompose(finish, second)) {
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

id revenant_spring_interpolate(id from, id to, double progress)
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
        return revenant_interpolate_transform(from, to, progress);
    static const char *const types[] = {@encode(CGPoint), @encode(CGSize), @encode(CGRect),
#if TARGET_OS_IPHONE
                                        @encode(UIEdgeInsets),
#endif
                                        @encode(CGVector)};
    static const NSUInteger counts[] = {2, 2, 4,
#if TARGET_OS_IPHONE
                                        4,
#endif
                                        2};
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

id revenant_spring_offset(id value, id delta, double scale)
{
    if ([delta isKindOfClass:[NSNumber class]] && (!value || [value isKindOfClass:[NSNumber class]])) {
        double start = value ? [value doubleValue] : 0;
        return [NSNumber numberWithDouble:start + [delta doubleValue] * scale];
    }
    if (![delta isKindOfClass:[NSValue class]])
        return nil;
    if (value && (![value isKindOfClass:[NSValue class]] || strcmp([value objCType], [delta objCType]) != 0))
        return nil;
    const char *type = [delta objCType];
    if (strcmp(type, @encode(CATransform3D)) == 0) {
        CATransform3D start, change, mixed;
        memset(&start, 0, sizeof(start));
        if (value)
            [value getValue:&start];
        [delta getValue:&change];
        CGFloat *left = (CGFloat *)&start, *right = (CGFloat *)&change;
        CGFloat *result = (CGFloat *)&mixed;
        for (NSUInteger index = 0; index < sizeof(CATransform3D) / sizeof(CGFloat); index++)
            result[index] = left[index] + right[index] * (CGFloat)scale;
        return [NSValue valueWithCATransform3D:mixed];
    }
    static const char *const types[] = {@encode(CGPoint), @encode(CGSize), @encode(CGRect),
#if TARGET_OS_IPHONE
                                        @encode(UIEdgeInsets),
#endif
                                        @encode(CGVector)};
    static const NSUInteger counts[] = {2, 2, 4,
#if TARGET_OS_IPHONE
                                        4,
#endif
                                        2};
    for (NSUInteger index = 0; index < sizeof(types) / sizeof(*types); index++) {
        if (strcmp(type, types[index]) != 0)
            continue;
        CGFloat start[4] = {0, 0, 0, 0}, change[4], mixed[4];
        if (value)
            [value getValue:start];
        [delta getValue:change];
        for (NSUInteger component = 0; component < counts[index]; component++)
            mixed[component] = start[component] + change[component] * (CGFloat)scale;
        return [NSValue valueWithBytes:mixed objCType:type];
    }
    return nil;
}

static id revenant_spring_zero(id like)
{
    return revenant_spring_offset(nil, like, 0);
}

CAKeyframeAnimation *revenant_spring_keyframes(CABasicAnimation *animation, CALayer *layer, NSTimeInterval duration,
                                               RevenantSpringProgress progress, void *context, BOOL snapToEnd)
{
    if (!animation.keyPath || !progress || !(duration > 0) || !isfinite(duration) || animation.cumulative || animation.valueFunction)
        return nil;
    id from = animation.fromValue, to = animation.toValue, by = animation.byValue;
    if (animation.additive) {
        if (!from && !to && !by)
            return nil;
        if (!from && !to)
            from = revenant_spring_zero(by);
        else if (!from)
            from = by ? revenant_spring_offset(to, by, -1) : revenant_spring_zero(to);
        else if (!to)
            to = by ? revenant_spring_offset(from, by, 1) : revenant_spring_zero(from);
        if (!to && by)
            to = by;
    } else {
        id current = nil;
        @try {
            current = [layer valueForKeyPath:animation.keyPath];
        } @catch (NSException *exception) {
            current = nil;
        }
        if (!from && !to && !by)
            return nil;
        if (!from)
            from = to && by ? revenant_spring_offset(to, by, -1) : current;
        if (!to)
            to = by ? revenant_spring_offset(from, by, 1) : current;
    }
    if (!from || !to || !revenant_spring_interpolate(from, to, 0))
        return nil;
    double intervals = ceil(duration * RevenantSpringFramesPerSecond);
    if (intervals < 1)
        intervals = 1;
    if (intervals > RevenantSpringMaximumSamples)
        intervals = RevenantSpringMaximumSamples;
    NSUInteger samples = (NSUInteger)intervals;
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:samples + 1];
    for (NSUInteger index = 0; index <= samples; index++) {
        double time = duration * (double)index / (double)samples;
        double position = progress(time, context);
        if (!isfinite(position))
            return nil;
        id value = revenant_spring_interpolate(from, to, position);
        if (!value)
            return nil;
        [values addObject:value];
    }
    if (snapToEnd)
        [values replaceObjectAtIndex:samples withObject:to];
    CAKeyframeAnimation *keyframes = [CAKeyframeAnimation animationWithKeyPath:animation.keyPath];
    keyframes.values = values;
    keyframes.calculationMode = kCAAnimationLinear;
    keyframes.duration = duration;
    keyframes.beginTime = animation.beginTime;
    keyframes.timeOffset = animation.timeOffset;
    keyframes.speed = animation.speed;
    keyframes.repeatCount = animation.repeatCount;
    keyframes.repeatDuration = animation.repeatDuration;
    keyframes.autoreverses = animation.autoreverses;
    keyframes.fillMode = animation.fillMode;
    keyframes.removedOnCompletion = animation.removedOnCompletion;
    keyframes.delegate = animation.delegate;
    keyframes.additive = animation.additive;
    return keyframes;
}
