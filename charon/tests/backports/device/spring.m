#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <math.h>
#import "check.h"
#import "spring-cases.h"
#import "spring-expectations.h"

@interface CADisplayLinkTarget : NSObject
@property (nonatomic) NSInteger fired;
@end

@implementation CADisplayLinkTarget
@synthesize fired = _fired;
- (void)tick:(CADisplayLink *)link
{
    _fired++;
}
@end

static NSString *image_of_method(Class cls, SEL selector)
{
    Method method = class_getInstanceMethod(cls, selector);
    Dl_info info;
    if (!method || !dladdr((const void *)method_getImplementation(method), &info))
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static NSString *number(double value)
{
    if (isnan(value))
        return @"not a number";
    if (isinf(value))
        return value > 0 ? @"forever" : @"-forever";
    if (value >= (double)MAXFLOAT)
        return @"never";
    return [NSString stringWithFormat:@"%.9f", value];
}

static void check_spring(NSDictionary *expectations)
{
    for (NSString *name in @[@"initialVelocity", @"setInitialVelocity:", @"settlingDuration"])
        CHECK_EQUAL(image_of_method([CASpringAnimation class], NSSelectorFromString(name)), @"libUIKitBackports.dylib",
                    ([NSString stringWithFormat:@"-[CASpringAnimation %@] comes from the backports library", name].UTF8String));

    CASpringAnimation *alias = [CASpringAnimation animation];
    alias.initialVelocity = 7.5;
    CHECK(((CGFloat (*)(id, SEL))objc_msgSend)(alias, NSSelectorFromString(@"velocity")) == (CGFloat)7.5,
          "the initial velocity is the velocity the release already keeps");
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(alias, NSSelectorFromString(@"setVelocity:"), (CGFloat)-2.25);
    CHECK(alias.initialVelocity == (CGFloat)-2.25, "the velocity the release keeps is the initial velocity");

    for (unsigned index = 0; index < spring_case_count; index++) {
        struct spring_case example = spring_cases[index];
        NSString *expected = expectations[@(example.name)];
        if (!expected)
            continue;
        CASpringAnimation *spring = [CASpringAnimation animation];
        spring.mass = example.mass;
        spring.stiffness = example.stiffness;
        spring.damping = example.damping;
        spring.initialVelocity = example.velocity;
        if ((double)spring.mass != example.mass || (double)spring.stiffness != example.stiffness
            || (double)spring.damping != example.damping || (double)spring.initialVelocity != example.velocity) {
            charon_check(NO, example.name, @"the release does not keep the values the spring was given");
            continue;
        }
        double found = spring.settlingDuration, wanted = [expected doubleValue];
        BOOL same = [expected isEqual:@"never"] ? found >= (double)MAXFLOAT
                                                : fabs(found - wanted) <= 1e-5 * MAX(1.0, fabs(wanted));
        charon_check(same, example.name, [NSString stringWithFormat:@"%@ is not %@", number(found), expected]);
    }
}

static void check_display_link(void)
{
    for (NSString *name in @[@"targetTimestamp", @"preferredFramesPerSecond", @"setPreferredFramesPerSecond:"])
        CHECK_EQUAL(image_of_method([CADisplayLink class], NSSelectorFromString(name)), @"libUIKitBackports.dylib",
                    ([NSString stringWithFormat:@"-[CADisplayLink %@] comes from the backports library", name].UTF8String));

    CADisplayLinkTarget *target = [[CADisplayLinkTarget alloc] init];
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
    CHECK(link.frameInterval == 1, "a fresh link asks for every frame");
    CHECK(link.preferredFramesPerSecond == 0, "a fresh link asks for no rate of its own");
    CHECK(link.targetTimestamp == link.timestamp + link.duration * link.frameInterval,
          "the target timestamp is the timestamp plus a frame");

    link.preferredFramesPerSecond = 30;
    CHECK(link.frameInterval == 2 && link.preferredFramesPerSecond == 30, "30 frames a second is every second frame");
    link.preferredFramesPerSecond = 40;
    CHECK(link.frameInterval == 2 && link.preferredFramesPerSecond == 40, "40 frames a second rounds to every second frame and is kept");
    link.preferredFramesPerSecond = 15;
    CHECK(link.frameInterval == 4 && link.preferredFramesPerSecond == 15, "15 frames a second is every fourth frame");
    link.preferredFramesPerSecond = 120;
    CHECK(link.frameInterval == 1 && link.preferredFramesPerSecond == 120, "more than the display can draw is every frame, and is kept");
    link.preferredFramesPerSecond = 0;
    CHECK(link.frameInterval == 1 && link.preferredFramesPerSecond == 0, "no rate of its own is every frame again");
    link.frameInterval = 3;
    CHECK(link.preferredFramesPerSecond == 20, "every third frame reads back as 20 frames a second");
    link.frameInterval = 1;

    [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    CHECK(target.fired > 0, "the link fires");
    if (target.fired > 0) {
        CHECK(link.duration > 0, "a link that has fired knows the duration of a frame");
        CHECK(fabs(link.targetTimestamp - (link.timestamp + link.duration * link.frameInterval)) < 1e-9,
              "the target timestamp of a running link is a frame past its timestamp");
    }
    [link invalidate];
}

int main(void)
{
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *expectations = [NSJSONSerialization JSONObjectWithData:[@(spring_expectations) dataUsingEncoding:NSUTF8StringEncoding]
                                                                     options:0 error:&error];
        CHECK(expectations != nil, "the host's answers are readable");
        check_spring(expectations);
        check_display_link();
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
