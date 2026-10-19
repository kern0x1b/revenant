#import <Foundation/Foundation.h>
#import "RevenantAVCapturePhoto.h"

static int checks, failures;

static void check(BOOL passed, NSString *what)
{
    checks++;
    if (!passed)
        failures++;
    printf("%s %s\n", passed ? "ok  " : "FAIL", what.UTF8String);
}

@interface RevenantTestCamera : NSObject
@property (atomic, getter=isFlashActive) BOOL flashActive;
@end

@implementation RevenantTestCamera
@end

static void wait_case(NSString *what, NSTimeInterval bound, NSTimeInterval change, NSTimeInterval earliest, NSTimeInterval latest)
{
    RevenantTestCamera *camera = [RevenantTestCamera new];
    __block int runs = 0;
    __block CFAbsoluteTime ran = 0;
    CFAbsoluteTime started = CFAbsoluteTimeGetCurrent();
    RevenantAfterFlashActiveChanges(camera, bound, ^{
        @synchronized (camera) {
            if (runs++ == 0)
                ran = CFAbsoluteTimeGetCurrent() - started;
        }
    });
    if (change >= 0) {
        [NSThread sleepForTimeInterval:change];
        camera.flashActive = YES;
        camera.flashActive = NO;
    }
    [NSThread sleepForTimeInterval:MAX(bound, change) + 0.3];
    int finalRuns;
    CFAbsoluteTime finalRan;
    @synchronized (camera) {
        finalRuns = runs;
        finalRan = ran;
    }
    check(finalRuns == 1 && finalRan >= earliest && finalRan < latest,
          [NSString stringWithFormat:@"%@: the block ran %d time(s), first after %.3f s (expected once, in [%.3f, %.3f) s)", what, finalRuns,
                                     finalRan, earliest, latest]);
    check(camera.observationInfo == NULL, [NSString stringWithFormat:@"%@: no observer is left on the camera", what]);
}

int main(void)
{
    @autoreleasepool {
        wait_case(@"flashActive changes at 0.02 s, bound 0.5 s", 0.5, 0.02, 0.02, 0.25);
        wait_case(@"flashActive never changes, bound 0.1 s (a bright scene with Auto)", 0.1, -1, 0.1, 0.35);
        wait_case(@"flashActive changes at 0.2 s, after the bound of 0.05 s", 0.05, 0.2, 0.05, 0.19);
        wait_case(@"flashActive changes at 0.035 s, bound 1/15 s", 1.0 / 15, 0.035, 0.035, 1.0 / 15);
        printf("%d checks, %d failed\n", checks, failures);
    }
    return failures ? 1 : 0;
}
