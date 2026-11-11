#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <execinfo.h>
#include <fcntl.h>
#include <math.h>
#include <pthread.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#import "../../src/UIKit/RevenantSpringSolver.h"
#import "../../src/UIKit/RevenantSpringKeyframes.h"

static NSString *const PROBE_LOG = @"/var/revenant/spring-probe.txt";
static NSMutableString *probeLog;
static int probeFailures;

static pthread_t probeMainThread;
static volatile int probeWatchArmed;
static volatile int probeWatchSerial;
static char probeWatchName[128];

static void probeStackHandler(int signalNumber)
{
    (void)signalNumber;
    int fd = open("/var/revenant/spring-probe-stack.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
        (void)write(fd, probeWatchName, strlen(probeWatchName));
        (void)write(fd, "\n", 1);
        void *frames[64];
        int count = backtrace(frames, 64);
        backtrace_symbols_fd(frames, count, fd);
        close(fd);
    }
    _exit(3);
}

static void *probeWatchdog(void *argument)
{
    int serial = (int)(intptr_t)argument;
    sleep(3);
    if (probeWatchArmed && probeWatchSerial == serial)
        pthread_kill(probeMainThread, SIGUSR1);
    return NULL;
}

static void probeWatchBegin(const char *name)
{
    strncpy(probeWatchName, name, sizeof(probeWatchName) - 1);
    probeMainThread = pthread_self();
    probeWatchSerial++;
    probeWatchArmed = 1;
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
    pthread_t thread;
    pthread_create(&thread, &attributes, probeWatchdog, (void *)(intptr_t)probeWatchSerial);
    pthread_attr_destroy(&attributes);
}

static void probeWatchEnd(void)
{
    probeWatchArmed = 0;
}

static double probeSpringProgress(double time, void *context)
{
    return revenant_spring_position(*(RevenantSpringParameters *)context, time);
}

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
    [probeLog appendString:@"step: converting the spring to keyframes\n"];
    probeFlush();
    RevenantSpringParameters convertParameters = parameters;
    id probeCurrent = nil;
    @try {
        probeCurrent = [layer valueForKeyPath:@"position.x"];
    } @catch (NSException *exception) {
        [probeLog appendFormat:@"step: layer value raised %@\n", exception.name];
    }
    [probeLog appendFormat:@"step: layer value %@\n", probeCurrent];
    probeFlush();
    [probeLog appendFormat:@"step: sample %.6f\n", probeSpringProgress(spring.duration * 0.5, &convertParameters)];
    probeFlush();
    CABasicAnimation *probePlain = [CABasicAnimation animationWithKeyPath:@"position.x"];
    [probeLog appendFormat:@"step: plain class %@\n", NSStringFromClass(object_getClass(probePlain))];
    probeFlush();
    BOOL probePlainCumulative = probePlain.cumulative;
    [probeLog appendFormat:@"step: plain cumulative %d\n", probePlainCumulative];
    probeFlush();
    [probeLog appendString:@"step: reading cumulative\n"];
    probeFlush();
    Class probeProxyClass = object_getClass(spring);
    Class probeSuperClass = class_getSuperclass(probeProxyClass);
    Ivar probeMass = class_getInstanceVariable(probeProxyClass, "_mass");
    Ivar probeOverdamping = class_getInstanceVariable(probeProxyClass, "_allowsOverdamping");
    [probeLog appendFormat:@"layout: proxy %@ size %zu, superclass %@ size %zu, _mass offset %td, _allowsOverdamping offset %td\n",
                           NSStringFromClass(probeProxyClass), class_getInstanceSize(probeProxyClass),
                           NSStringFromClass(probeSuperClass), class_getInstanceSize(probeSuperClass),
                           probeMass ? ivar_getOffset(probeMass) : -1, probeOverdamping ? ivar_getOffset(probeOverdamping) : -1];
    probeFlush();
    Class probeBareClass = objc_allocateClassPair([CABasicAnimation class], "RevenantProbeBareSubclass", 0);
    objc_registerClassPair(probeBareClass);
    id probeBare = [[probeBareClass alloc] init];
    [probeLog appendFormat:@"bare subclass instance %@\n", NSStringFromClass(object_getClass(probeBare))];
    probeFlush();
    [probeLog appendString:@"read bare subclass beginTime\n"]; probeFlush(); (void)[probeBare beginTime];
    [probeLog appendString:@"read bare subclass beginTime done\n"]; probeFlush();
    Class probeAllocClass = objc_allocateClassPair([CABasicAnimation class], "RevenantProbeAllocSubclass", 0);
    objc_registerClassPair(probeAllocClass);
    id probeAllocated = [class_createInstance(probeAllocClass, 0) init];
    [probeLog appendFormat:@"class_createInstance subclass %@\n", NSStringFromClass(object_getClass(probeAllocated))]; probeFlush();
    [probeLog appendString:@"read class_createInstance beginTime\n"]; probeFlush(); (void)[probeAllocated beginTime];
    [probeLog appendString:@"read class_createInstance beginTime done\n"]; probeFlush();
    Class probeIvarClass = objc_allocateClassPair([CABasicAnimation class], "RevenantProbeIvarSubclass", 0);
    class_addIvar(probeIvarClass, "_a", sizeof(CGFloat), 2, @encode(CGFloat));
    class_addIvar(probeIvarClass, "_b", sizeof(CGFloat), 2, @encode(CGFloat));
    class_addIvar(probeIvarClass, "_c", sizeof(CGFloat), 2, @encode(CGFloat));
    class_addIvar(probeIvarClass, "_d", sizeof(CGFloat), 2, @encode(CGFloat));
    class_addIvar(probeIvarClass, "_e", sizeof(BOOL), 0, @encode(BOOL));
    objc_registerClassPair(probeIvarClass);
    id probeIvar = [[probeIvarClass alloc] init];
    [probeLog appendFormat:@"ivar subclass instance size %zu\n", class_getInstanceSize(probeIvarClass)]; probeFlush();
    [probeLog appendString:@"read ivar subclass beginTime\n"]; probeFlush(); (void)[probeIvar beginTime];
    [probeLog appendString:@"read ivar subclass beginTime done\n"]; probeFlush();
    Class probeSuperClass2 = objc_allocateClassPair([CABasicAnimation class], "RevenantProbeSuperSubclass", 0);
    objc_registerClassPair(probeSuperClass2);
    class_addMethod(probeSuperClass2, @selector(superclass), imp_implementationWithBlock(^Class(id receiver) { return class_getSuperclass(object_getClass(receiver)); }), "#@:");
    id probeSuper = [[probeSuperClass2 alloc] init];
    [probeLog appendFormat:@"superclass override instance %@\n", NSStringFromClass(object_getClass(probeSuper))]; probeFlush();
    [probeLog appendString:@"read superclass-override beginTime\n"]; probeFlush(); (void)[probeSuper beginTime];
    [probeLog appendString:@"read superclass-override beginTime done\n"]; probeFlush();
    CAKeyframeAnimation *probeKeyframes = [CAKeyframeAnimation animation];
    [probeLog appendString:@"read keyframe beginTime\n"]; probeFlush(); (void)probeKeyframes.beginTime;
    [probeLog appendString:@"read keyframe beginTime done\n"]; probeFlush();
    [probeLog appendString:@"read fresh spring beginTime\n"]; probeFlush();
    probeWatchBegin("fresh spring beginTime");
    (void)initialized.beginTime;
    probeWatchEnd();
    [probeLog appendString:@"read fresh spring beginTime done\n"]; probeFlush();
    [probeLog appendString:@"read beginTime\n"]; probeFlush(); (void)spring.beginTime;
    [probeLog appendString:@"read speed\n"]; probeFlush(); (void)spring.speed;
    [probeLog appendString:@"read repeatCount\n"]; probeFlush(); (void)spring.repeatCount;
    [probeLog appendString:@"read autoreverses\n"]; probeFlush(); (void)spring.autoreverses;
    [probeLog appendString:@"read removedOnCompletion\n"]; probeFlush(); (void)spring.removedOnCompletion;
    [probeLog appendString:@"read fillMode\n"]; probeFlush(); (void)spring.fillMode;
    [probeLog appendString:@"read timingFunction\n"]; probeFlush(); (void)spring.timingFunction;
    [probeLog appendString:@"read delegate\n"]; probeFlush(); (void)spring.delegate;
    [probeLog appendString:@"read additive\n"]; probeFlush(); (void)spring.additive;
    [probeLog appendString:@"read valueFunction\n"]; probeFlush(); (void)spring.valueFunction;
    [probeLog appendString:@"read cumulative\n"]; probeFlush(); (void)spring.cumulative;
    [probeLog appendString:@"read all done\n"]; probeFlush();
    NSMutableArray *probeValues = [NSMutableArray array];
    for (NSUInteger index = 0; index <= 87; index++) {
        double time = spring.duration * (double)index / 87.0;
        [probeValues addObject:@(100 * probeSpringProgress(time, &convertParameters))];
        if (index % 20 == 0) {
            [probeLog appendFormat:@"step: replica sample %lu\n", (unsigned long)index];
            probeFlush();
        }
    }
    [probeLog appendFormat:@"step: replica %lu values\n", (unsigned long)probeValues.count];
    probeFlush();
    CAKeyframeAnimation *probeKeys = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    [probeLog appendString:@"step: replica keyframe object created\n"];
    probeFlush();
    probeKeys.values = probeValues;
    probeKeys.duration = spring.duration;
    [probeLog appendString:@"step: replica keyframe values set\n"];
    probeFlush();
    CAKeyframeAnimation *converted = revenant_spring_keyframes(spring, layer, spring.duration, probeSpringProgress, &convertParameters, NO);
    [probeLog appendFormat:@"step: converted to %lu keyframes\n", (unsigned long)converted.values.count];
    probeFlush();
    [layer addAnimation:converted forKey:@"converted"];
    [probeLog appendString:@"step: converted keyframes added\n"];
    probeFlush();
    [layer addAnimation:spring forKey:@"spring"];
    [probeLog appendString:@"step: spring added\n"];
    probeFlush();
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

    CALayer *plainLayer = [CALayer layer];
    plainLayer.position = CGPointMake(0, 0);
    CAKeyframeAnimation *plainAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    plainAnimation.values = @[@0, @100];
    plainAnimation.duration = 0.5;
    [plainLayer addAnimation:plainAnimation forKey:@"plain"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:spring.duration + 0.5]];
    [probeLog appendFormat:@"presentation layers: spring %d plain %d\n", layer.presentationLayer != nil, plainLayer.presentationLayer != nil];
    [probeLog appendFormat:@"presentation of a plain keyframe animation: %@\n", [plainLayer.presentationLayer valueForKeyPath:@"position.x"]];
    [probeLog appendFormat:@"presentation of the spring (informational, detached layers have none): %@\n", [layer.presentationLayer valueForKeyPath:@"position.x"]];

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
    [probeLog appendFormat:@"perceptual: pd %.12g bounce %.12g duration %.12g settling %.12g mass %g k %g c %g\n", perceptual.perceptualDuration,
                           perceptual.bounce, perceptual.duration, perceptual.settlingDuration, perceptual.mass, perceptual.stiffness, perceptual.damping];
    probeReport(perceptual != nil && probeNear(perceptual.perceptualDuration, 0.5, 1e-6) && probeNear(perceptual.bounce, 0.25, 1e-6) &&
                probeNear(perceptual.duration, perceptual.settlingDuration, 1e-9), @"perceptual initializer", @"");
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    signal(SIGUSR1, probeStackHandler);
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
