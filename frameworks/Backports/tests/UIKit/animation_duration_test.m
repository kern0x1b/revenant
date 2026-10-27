#import <Foundation/Foundation.h>
#import "RevenantAnimationDuration.h"
#import "check.h"

static void expect_duration(const char *name, NSTimeInterval value, NSTimeInterval expected)
{
    revenant_check(value == expected, name, [NSString stringWithFormat:@"%g is not %g", value, expected]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        expect_duration("empty stack reports zero", RevenantAnimationDurationInherited(), 0);
        expect_duration("default duration is the UIKit default of 0.2 s", RevenantAnimationDurationDefault, 0.2);

        RevenantAnimationDurationPush(1.5);
        expect_duration("push reports the pushed duration", RevenantAnimationDurationInherited(), 1.5);

        RevenantAnimationDurationPush(0.25);
        expect_duration("nested push reports the innermost duration", RevenantAnimationDurationInherited(), 0.25);

        RevenantAnimationDurationSetCurrent(0.5);
        expect_duration("set replaces the innermost duration", RevenantAnimationDurationInherited(), 0.5);

        if (!revenant_negative)
            RevenantAnimationDurationPop();
        expect_duration("pop restores the enclosing duration", RevenantAnimationDurationInherited(), 1.5);

        RevenantAnimationDurationPop();
        expect_duration("popping the outermost block leaves zero", RevenantAnimationDurationInherited(), 0);

        RevenantAnimationDurationPop();
        expect_duration("pop on an empty stack is a no-op", RevenantAnimationDurationInherited(), 0);

        RevenantAnimationDurationSetCurrent(3);
        expect_duration("set on an empty stack is a no-op", RevenantAnimationDurationInherited(), 0);

        RevenantAnimationDurationPush(5);
        __block NSTimeInterval seenOnOtherThread = -1;
        dispatch_semaphore_t finished = dispatch_semaphore_create(0);
        NSThread *thread = [[NSThread alloc] initWithBlock:^{
            seenOnOtherThread = RevenantAnimationDurationInherited();
            dispatch_semaphore_signal(finished);
        }];
        [thread start];
        dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
        expect_duration("another thread does not see this thread's duration", seenOnOtherThread, 0);
        RevenantAnimationDurationPop();
    }
    return revenant_finish();
}
