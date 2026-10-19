#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

/* The two properties answer on the port whether or not it implements them: the class is the SDK's
   own interface under another name, so the compiler synthesises what nobody wrote, and the answer
   is NO. Asking respondsToSelector: would prove nothing; every check below is behaviour. */

static Class flavor;

static NSString *state_of(id animator)
{
    UIViewAnimatingState state = ((UIViewAnimatingState (*)(id, SEL))objc_msgSend)(animator, @selector(state));
    switch (state) {
        case UIViewAnimatingStateInactive: return @"inactive";
        case UIViewAnimatingStateActive: return @"active";
        case UIViewAnimatingStateStopped: return @"stopped";
    }
    return [NSString stringWithFormat:@"%ld", (long)state];
}

static NSString *caught(void (^work)(void))
{
    @try {
        work();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing raised";
}

static NSString *yes_no(BOOL held)
{
    return held ? @"yes" : @"no";
}

static id animator(UIView **view, NSTimeInterval duration)
{
    UIView *made = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    if (view)
        *view = made;
    return [[flavor alloc] initWithDuration:duration curve:UIViewAnimationCurveEaseInOut animations:^{
        made.frame = CGRectMake(100, 0, 100, 100);
    }];
}

static BOOL scrubs(id animator)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(animator, @selector(scrubsLinearly));
}

static void set_scrubs(id animator, BOOL value)
{
    ((void (*)(id, SEL, BOOL))objc_msgSend)(animator, @selector(setScrubsLinearly:), value);
}

static NSString *progress(id animator)
{
    return [NSString stringWithFormat:@"%@, running %@, at %.2f", state_of(animator),
            yes_no(((BOOL (*)(id, SEL))objc_msgSend)(animator, @selector(isRunning))),
            ((CGFloat (*)(id, SEL))objc_msgSend)(animator, @selector(fractionComplete))];
}

static void set_pauses(id animator, BOOL value)
{
    ((void (*)(id, SEL, BOOL))objc_msgSend)(animator, @selector(setPausesOnCompletion:), value);
}

static void record(NSMutableArray *into, const char *step, NSString *value)
{
    [into addObject:@[@(step), value ?: @"nothing"]];
}

static void script(NSMutableArray *into)
{
    id fresh = animator(NULL, 1);
    record(into, "scrubs linearly to begin with", yes_no(scrubs(fresh)));
    record(into, "and does not pause on completion", yes_no(((BOOL (*)(id, SEL))objc_msgSend)(fresh, @selector(pausesOnCompletion))));

    record(into, "the flag can be set while the animator is inactive", caught(^{ set_scrubs(fresh, NO); }));
    record(into, "and it is what it was set to", yes_no(scrubs(fresh)));

    ((void (*)(id, SEL, CGFloat))objc_msgSend)(fresh, @selector(setFractionComplete:), 0.25);
    record(into, "scrubbing an animator built with animations", progress(fresh));

    id empty = [[flavor alloc] initWithDuration:1 curve:UIViewAnimationCurveEaseInOut animations:nil];
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(empty, @selector(setFractionComplete:), 0.25);
    record(into, "scrubbing an animator built without animations", progress(empty));

    id paused = animator(NULL, 1);
    ((void (*)(id, SEL))objc_msgSend)(paused, @selector(pauseAnimation));
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(paused, @selector(setFractionComplete:), 0.25);
    record(into, "scrubbing a paused animator", progress(paused));
    record(into, "the flag set on a scrubbed animator", caught(^{ set_scrubs(fresh, YES); }));
    record(into, "and the flag did not change", yes_no(scrubs(fresh)));

    id running = animator(NULL, 1);
    ((void (*)(id, SEL))objc_msgSend)(running, @selector(startAnimation));
    record(into, "a started animator", [NSString stringWithFormat:@"%@, running %@", state_of(running),
           yes_no(((BOOL (*)(id, SEL))objc_msgSend)(running, @selector(isRunning)))]);
    record(into, "the flag set while it runs", caught(^{ set_scrubs(running, NO); }));
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(running, @selector(setFractionComplete:), 0.5);
    record(into, "scrubbing a running animator",
           [NSString stringWithFormat:@"%@, running %@, at least halfway %@", state_of(running),
            yes_no(((BOOL (*)(id, SEL))objc_msgSend)(running, @selector(isRunning))),
            yes_no(((CGFloat (*)(id, SEL))objc_msgSend)(running, @selector(fractionComplete)) >= 0.5)]);
    ((void (*)(id, SEL))objc_msgSend)(running, @selector(pauseAnimation));
    record(into, "the flag set once it is paused", caught(^{ set_scrubs(running, YES); }));
    ((void (*)(id, SEL, BOOL))objc_msgSend)(running, @selector(stopAnimation:), YES);
    record(into, "the flag set once it is stopped", caught(^{ set_scrubs(running, NO); }));

    UIView *fading = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    id waiting = [[flavor alloc] initWithDuration:0.2 curve:UIViewAnimationCurveLinear animations:^{
        fading.alpha = 0;
    }];
    set_pauses(waiting, YES);
    __block NSInteger completions = 0, position = -1;
    ((void (*)(id, SEL, void (^)(UIViewAnimatingPosition)))objc_msgSend)(waiting, @selector(addCompletion:),
        ^(UIViewAnimatingPosition where) { completions++; position = where; });
    ((void (*)(id, SEL))objc_msgSend)(waiting, @selector(startAnimation));
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.7]];
    record(into, "an animator that pauses on completion, once its time has passed",
           [NSString stringWithFormat:@"%@, running %@", state_of(waiting),
            yes_no(((BOOL (*)(id, SEL))objc_msgSend)(waiting, @selector(isRunning)))]);
    record(into, "the animation itself ran", yes_no(fading.alpha == 0));
    record(into, "and the completions waited", [NSString stringWithFormat:@"%ld", (long)completions]);
    NSString *stopping = caught(^{ ((void (*)(id, SEL, BOOL))objc_msgSend)(waiting, @selector(stopAnimation:), NO); });
    record(into, "stopping it without finishing",
           [NSString stringWithFormat:@"%@; %@, completions %ld", stopping, state_of(waiting), (long)completions]);
    NSString *finishing = caught(^{
        ((void (*)(id, SEL, UIViewAnimatingPosition))objc_msgSend)(waiting, @selector(finishAnimationAtPosition:), UIViewAnimatingPositionEnd);
    });
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    record(into, "and finishing it by hand",
           [NSString stringWithFormat:@"%@; %@, completions %ld, position %ld", finishing, state_of(waiting), (long)completions, (long)position]);
}

int main(void)
{
    @autoreleasepool {
        NSMutableArray *system = [NSMutableArray array], *port = [NSMutableArray array];
        flavor = [UIViewPropertyAnimator class];
        script(system);

        Class ported = NSClassFromString(@"CharonHostUIViewPropertyAnimator");
        BOOL carried = ported != Nil;
        CHECK(carried, "the port carries an animator to ask");
        if (carried) {
            flavor = ported;
            script(port);
        }
        for (NSUInteger index = 0; index < system.count; index++) {
            NSArray *mine = index < port.count ? port[index] : nil;
            NSString *expected = system[index][1], *actual = mine ? mine[1] : @"nothing";
            printf("  %s: %s\n", [system[index][0] UTF8String], expected.UTF8String);
            charon_check([expected isEqual:actual], [system[index][0] UTF8String],
                         [NSString stringWithFormat:@"%@ != %@", actual, expected]);
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
