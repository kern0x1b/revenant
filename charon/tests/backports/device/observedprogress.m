#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"

static NSString *image_of_method(Class class, SEL selector)
{
    Method method = class_getInstanceMethod(class, selector);
    if (!method)
        return @"<missing>";
    Dl_info info;
    if (!dladdr((void *)method_getImplementation(method), &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static void settle(void)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

static void near(UIProgressView *bar, float expected, const char *name)
{
    charon_check(fabsf(bar.progress - expected) < 0.0005f, name, [NSString stringWithFormat:@"%.4f, expected %.4f", bar.progress, expected]);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        (void)argc;
        (void)argv;
        for (NSString *name in @[@"observedProgress", @"setObservedProgress:"])
            charon_check([image_of_method([UIProgressView class], NSSelectorFromString(name)) isEqualToString:@"libUIKitBackports.dylib"],
                         [NSString stringWithFormat:@"-[UIProgressView %@] comes from the backports", name].UTF8String,
                         image_of_method([UIProgressView class], NSSelectorFromString(name)));

        UIProgressView *bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        charon_check(bar.observedProgress == nil, "a progress view observes nothing to start with", nil);
        near(bar, 0.0f, "and its progress is zero");

        NSProgress *progress = [NSProgress discreteProgressWithTotalUnitCount:10];
        progress.completedUnitCount = 2;
        bar.observedProgress = progress;
        settle();
        charon_check(bar.observedProgress == progress, "the progress it was given is the one it reads back", nil);
        near(bar, 0.2f, "setting an observed progress takes its fraction at once");

        progress.completedUnitCount = 7;
        settle();
        near(bar, 0.7f, "the bar follows the progress");

        bar.progress = 0.1f;
        near(bar, 0.1f, "the progress can still be set by hand");
        charon_check(bar.observedProgress == progress, "and the observation is not dropped by setting it", nil);

        progress.completedUnitCount = 10;
        settle();
        near(bar, 1.0f, "the next move of the progress wins over the hand set");

        bar.observedProgress = progress;
        settle();
        near(bar, 1.0f, "setting the same progress again changes nothing");

        NSProgress *other = [NSProgress discreteProgressWithTotalUnitCount:4];
        other.completedUnitCount = 1;
        bar.observedProgress = other;
        settle();
        near(bar, 0.25f, "a second observed progress replaces the first");

        progress.completedUnitCount = 5;
        settle();
        near(bar, 0.25f, "the first progress no longer moves the bar");

        other.completedUnitCount = 3;
        settle();
        near(bar, 0.75f, "the second one does");

        bar.observedProgress = nil;
        charon_check(bar.observedProgress == nil, "the observation can be cleared", nil);
        other.completedUnitCount = 4;
        settle();
        near(bar, 0.75f, "and the bar stops following once it is");

        bar.observedProgress = nil;
        charon_check(YES, "clearing an observation that is not there is quiet", nil);

        @autoreleasepool {
            UIProgressView *short_lived = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            short_lived.observedProgress = other;
        }
        other.completedUnitCount = 2;
        settle();
        charon_check(YES, "a progress view that goes away while observing takes its observation with it", nil);

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
