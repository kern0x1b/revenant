#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raises(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@|%@", exception.name, exception.reason];
    }
    return nil;
}

static void run_checks(void)
{
    for (NSString *name in @[@"UIFeedbackGenerator", @"UIImpactFeedbackGenerator", @"UINotificationFeedbackGenerator", @"UISelectionFeedbackGenerator"]) {
        Class cls = NSClassFromString(name);
        CHECK(cls != Nil, NAMED(@"%@ is there", name));
        if (cls)
            CHECK([image_of(cls) isEqualToString:@"libUIKitBackports.dylib"],
                  NAMED(@"%@ comes from the backports library (%@)", name, image_of(cls)));
    }

    UISelectionFeedbackGenerator *selection = [[UISelectionFeedbackGenerator alloc] init];
    CHECK(selection != nil && [selection isKindOfClass:[UIFeedbackGenerator class]] && [selection respondsToSelector:@selector(selectionChanged)]
          && [selection respondsToSelector:@selector(prepare)],
          "a selection generator is a feedback generator that answers to selectionChanged and prepare");
    CHECK_EQUAL(raises(^{ [selection prepare]; [selection selectionChanged]; [selection selectionChanged]; }), nil,
                "and both return without raising, plays nothing, as on a device with no Taptic Engine");

    UIImpactFeedbackGenerator *heavy = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    CHECK(heavy != nil, "an impact generator is built for a style it knows");
    CHECK([heavy respondsToSelector:@selector(impactOccurred)], "it answers to impactOccurred");
    CHECK([heavy respondsToSelector:@selector(prepare)], "it answers to prepare, which it inherits");
    CHECK(![heavy respondsToSelector:@selector(impactOccurredWithIntensity:)],
          "it does not answer to the iOS 13 intensity, which this port does not carry");
    CHECK_EQUAL(raises(^{ [heavy prepare]; }), nil, "prepare raises nothing");
    CHECK_EQUAL(raises(^{ [heavy impactOccurred]; }), nil, "a heavy impact raises nothing");

    for (NSNumber *style in @[@(UIImpactFeedbackStyleLight), @(UIImpactFeedbackStyleMedium)]) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style.integerValue];
        CHECK(generator != nil, NAMED(@"an impact generator is built for style %@", style));
        CHECK_EQUAL(raises(^{ [generator impactOccurred]; }), nil,
                    NAMED(@"an impact of style %@ raises nothing", style));
    }

    UIImpactFeedbackGenerator *nonsense = [[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyle)77];
    CHECK(nonsense != nil, "a style outside the three still builds a generator, as it does on iOS 10");
    CHECK_EQUAL(raises(^{ [nonsense impactOccurred]; }), nil,
                "and an impact on it raises nothing, it simply plays nothing");

    UINotificationFeedbackGenerator *notifications = [[UINotificationFeedbackGenerator alloc] init];
    CHECK(notifications != nil, "a notification generator is built");
    CHECK([notifications respondsToSelector:@selector(notificationOccurred:)], "it answers to notificationOccurred:");
    for (NSNumber *type in @[@(UINotificationFeedbackTypeSuccess), @(UINotificationFeedbackTypeWarning),
                             @(UINotificationFeedbackTypeError)]) {
        CHECK_EQUAL(raises(^{ [notifications notificationOccurred:type.integerValue]; }), nil,
                    NAMED(@"notification type %@ raises nothing", type));
    }

    UIFeedbackGenerator *base = [[UIFeedbackGenerator alloc] init];
    CHECK(base != nil, "the base generator is built");
    CHECK_EQUAL(raises(^{ [base prepare]; }), nil, "and preparing it raises nothing");
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        run_checks();
        printf("%s checks=%d failures=%d\n", charon_failures ? "FAIL" : "ok", charon_checks, charon_failures);
        return charon_failures;
    }
}
