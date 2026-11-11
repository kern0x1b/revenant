#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>
#import "../../src/UIKit/RevenantSpringSolver.h"

static NSString *const PROBE_LOG = @"/var/revenant/spring-probe.txt";
static NSMutableString *probeLog;
static int probeFailures;

static void probeFlush(void)
{
    [probeLog writeToFile:PROBE_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void probeReport(BOOL ok, NSString *name, NSString *detail)
{
    [probeLog appendFormat:@"%@ %@ %@\n", ok ? @"PASS" : @"FAIL", name, detail ?: @""];
    if (!ok)
        probeFailures++;
    probeFlush();
}

static BOOL probeNear(double value, double expected, double tolerance)
{
    return fabs(value - expected) <= tolerance;
}

static void probeNativeMembers(Class nativeClass)
{
    unsigned int count = 0;
    Method *methods = class_copyMethodList(nativeClass, &count);
    NSMutableArray *names = [NSMutableArray array];
    for (unsigned int index = 0; index < count; index++)
        [names addObject:NSStringFromSelector(method_getName(methods[index]))];
    free(methods);
    [names sortUsingSelector:@selector(compare:)];
    [probeLog appendFormat:@"native instance methods (%u): %@\n", count, [names componentsJoinedByString:@" "]];
    probeReport(!class_getInstanceMethod(nativeClass, @selector(initialVelocity)), @"native lacks initialVelocity", @"");
    probeReport(!class_getInstanceMethod(nativeClass, @selector(settlingDuration)), @"native lacks settlingDuration", @"");
    probeReport(class_getInstanceMethod(nativeClass, @selector(_timeFunction:)) != NULL, @"native exposes _timeFunction:", @"");
}

static void probeNativeCurve(Class nativeClass)
{
    if (!nativeClass || !class_getInstanceMethod(nativeClass, @selector(_timeFunction:)))
        return;
    RevenantSpringParameters parameters = {1, 100, 10, 2, false};
    double duration = revenant_spring_settling(parameters);
    id native = [[nativeClass alloc] init];
    [native setValue:@(parameters.mass) forKey:@"mass"];
    [native setValue:@(parameters.stiffness) forKey:@"stiffness"];
    [native setValue:@(parameters.damping) forKey:@"damping"];
    [native setValue:@(parameters.initialVelocity) forKey:@"velocity"];
    [native setValue:@(duration) forKey:@"duration"];
    double worst = 0;
    for (int step = 0; step <= 100; step++) {
        double unit = step / 100.0;
        double measured = ((double (*)(id, SEL, double))objc_msgSend)(native, @selector(_timeFunction:), unit);
        double solved = revenant_spring_position(parameters, unit * duration);
        worst = fmax(worst, fabs(measured - solved));
    }
    [probeLog appendFormat:@"native _timeFunction: worst deviation from the iOS 9 curve (velocity 2 mapped to velocity): %.3g\n", worst];
    probeReport(worst <= 1e-9, @"native curve equals the iOS 9 curve", @"");
}

static void probeSpring(void)
{
    CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:@"position.x"];
    probeReport(spring != nil, @"animationWithKeyPath: returns an object", @"");
    if (!spring)
        return;
    probeReport([spring isKindOfClass:[CASpringAnimation class]], @"instance is a CASpringAnimation", NSStringFromClass(object_getClass(spring)));
    probeReport([spring respondsToSelector:@selector(initialVelocity)] && [spring respondsToSelector:@selector(settlingDuration)],
                @"animationWithKeyPath: instance responds to initialVelocity and settlingDuration", NSStringFromClass(object_getClass(spring)));
    CASpringAnimation *initialized = [[CASpringAnimation alloc] init];
    probeReport(initialized != nil && [initialized respondsToSelector:@selector(initialVelocity)] && [initialized respondsToSelector:@selector(settlingDuration)],
                @"alloc init instance responds to initialVelocity and settlingDuration", NSStringFromClass(object_getClass(initialized)));
    probeReport(probeNear(spring.mass, 1, 0) && probeNear(spring.stiffness, 100, 0) && probeNear(spring.damping, 10, 0) &&
                probeNear(spring.initialVelocity, 0, 0) && !spring.allowsOverdamping,
                @"defaults", [NSString stringWithFormat:@"m %g k %g c %g v %g", spring.mass, spring.stiffness, spring.damping, spring.initialVelocity]);

    spring.mass = 1;
    spring.stiffness = 100;
    spring.damping = 10;
    spring.initialVelocity = 2;
    spring.fromValue = @0;
    spring.toValue = @100;
    spring.fillMode = kCAFillModeForwards;
    spring.removedOnCompletion = NO;
    RevenantSpringParameters parameters = {1, 100, 10, 2, false};
    double expectedSettling = revenant_spring_settling(parameters);
    probeReport(probeNear(spring.settlingDuration, expectedSettling, 1e-6), @"settlingDuration",
                [NSString stringWithFormat:@"%.6f expected %.6f", spring.settlingDuration, expectedSettling]);
    spring.duration = spring.settlingDuration;
    probeReport(probeNear(spring.initialVelocity, 2, 0) && probeNear(spring.mass, 1, 0) && probeNear(spring.stiffness, 100, 0) &&
                probeNear(spring.damping, 10, 0), @"setters read back", @"");

    CALayer *layer = [CALayer layer];
    layer.position = CGPointMake(0, 0);
    [layer addAnimation:spring forKey:@"spring"];
    CAAnimation *added = [layer animationForKey:@"spring"];
    probeReport([added isKindOfClass:[CAKeyframeAnimation class]], @"added animation is converted to keyframes", NSStringFromClass(object_getClass(added)));
    CAKeyframeAnimation *frames = (CAKeyframeAnimation *)added;
    NSUInteger count = frames.values.count;
    double worst = 0;
    for (NSUInteger index = 0; index < count && count > 1; index++) {
        double time = spring.duration * (double)index / (double)(count - 1);
        double expected = 100 * revenant_spring_position(parameters, time);
        worst = fmax(worst, fabs([frames.values[index] doubleValue] - expected));
    }
    probeReport(count > 1 && worst <= 1e-6, @"keyframe values match the damped spring",
                [NSString stringWithFormat:@"samples %lu worst %.3g", (unsigned long)count, worst]);

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:spring.duration + 0.5]];
    id presentation = [layer.presentationLayer valueForKeyPath:@"position.x"];
    double final = presentation ? [presentation doubleValue] : NAN;
    probeReport(probeNear(final, 100, 1e-3), @"presentation final value", [NSString stringWithFormat:@"%.6f", final]);

    spring.allowsOverdamping = YES;
    CASpringAnimation *copied = [spring copy];
    probeReport([copied isKindOfClass:[CASpringAnimation class]] && copied != spring && probeNear(copied.initialVelocity, 2, 0) &&
                copied.allowsOverdamping, @"copy keeps the spring", @"");
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:spring];
    CASpringAnimation *decoded = archive ? [NSKeyedUnarchiver unarchiveObjectWithData:archive] : nil;
    probeReport([decoded isKindOfClass:[CASpringAnimation class]] && probeNear(decoded.mass, 1, 0) && probeNear(decoded.stiffness, 100, 0) &&
                probeNear(decoded.damping, 10, 0) && probeNear(decoded.initialVelocity, 2, 0) && decoded.allowsOverdamping,
                @"archive keeps the spring", @"");

    CASpringAnimation *perceptual = [[CASpringAnimation alloc] initWithPerceptualDuration:0.5 bounce:0.25];
    probeReport(perceptual != nil && probeNear(perceptual.perceptualDuration, 0.5, 1e-9) && probeNear(perceptual.bounce, 0.25, 1e-6) &&
                probeNear(perceptual.duration, perceptual.settlingDuration, 1e-9), @"perceptual initializer", @"");
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    @autoreleasepool {
        probeLog = [NSMutableString string];
        Class nativeClass = objc_getClass("CASpringAnimation");
        [probeLog appendFormat:@"system class: %@\n", nativeClass ? NSStringFromClass(nativeClass) : @"(none)"];
        [probeLog appendFormat:@"[CASpringAnimation class]: %@\n", NSStringFromClass([CASpringAnimation class])];
        probeFlush();
        @try {
            if (nativeClass)
                probeNativeMembers(nativeClass);
        } @catch (NSException *exception) {
            [probeLog appendFormat:@"FAIL native members raised %@: %@\n", exception.name, exception.reason];
            probeFailures++;
        }
        @try {
            probeNativeCurve(nativeClass);
        } @catch (NSException *exception) {
            [probeLog appendFormat:@"FAIL native curve raised %@: %@\n", exception.name, exception.reason];
            probeFailures++;
        }
        @try {
            probeSpring();
        } @catch (NSException *exception) {
            [probeLog appendFormat:@"FAIL spring raised %@: %@\n", exception.name, exception.reason];
            probeFailures++;
        }
        [probeLog appendFormat:@"verdict: %@ (%d failures)\n", probeFailures ? @"FAIL" : @"PASS", probeFailures];
        probeFlush();
        NSLog(@"%@", probeLog);
    }
    return 0;
}
