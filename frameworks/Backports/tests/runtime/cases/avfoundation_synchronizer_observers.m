#import "../app/revenant_check.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

REVENANT_CASE(avfoundation_synchronizer_observers)
{
    BOOL flip = (BOOL)negative;
    __weak AVSampleBufferRenderSynchronizer *weakSynchronizer = nil;
    __block int periodicCount = 0;
    __block int boundaryCount = 0;
    int periodicAfterRemoval = 0;
    int boundaryAfterRemoval = 0;
    int periodicLater = 0;
    int boundaryLater = 0;

    @autoreleasepool {
        AVSampleBufferRenderSynchronizer *synchronizer = [[AVSampleBufferRenderSynchronizer alloc] init];
        weakSynchronizer = synchronizer;
        id periodic = [synchronizer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                                                 queue:dispatch_get_main_queue()
                                                            usingBlock:^(CMTime time) {
            periodicCount++;
        }];
        id boundary = [synchronizer addBoundaryTimeObserverForTimes:@[ [NSValue valueWithCMTime:CMTimeMake(3, 10)] ]
                                                              queue:dispatch_get_main_queue()
                                                         usingBlock:^{
            boundaryCount++;
        }];
        synchronizer.rate = 1.0f;
        spin(1.2);
        revenant_expect_true(@"a periodic observer fires while the synchronizer runs",
                             (periodicCount >= 3) != flip, [NSString stringWithFormat:@"%d calls", periodicCount]);
        revenant_expect_true(@"a boundary observer fires once at its time",
                             (boundaryCount == 1) != flip, [NSString stringWithFormat:@"%d calls", boundaryCount]);

        [synchronizer removeTimeObserver:periodic];
        [synchronizer removeTimeObserver:boundary];
        periodicAfterRemoval = periodicCount;
        boundaryAfterRemoval = boundaryCount;
        spin(0.6);
        periodicLater = periodicCount;
        boundaryLater = boundaryCount;
        revenant_expect_true(@"a removed periodic observer stops firing",
                             (periodicLater - periodicAfterRemoval <= 1) != flip,
                             [NSString stringWithFormat:@"%d then %d", periodicAfterRemoval, periodicLater]);
        revenant_expect_true(@"a removed boundary observer stays quiet",
                             (boundaryLater == boundaryAfterRemoval) != flip,
                             [NSString stringWithFormat:@"%d then %d", boundaryAfterRemoval, boundaryLater]);
        synchronizer.rate = 0.0f;
    }
    spin(0.3);
    revenant_expect_true(@"a synchronizer whose observers were removed is released",
                         (weakSynchronizer == nil) != flip, @"the synchronizer outlived its pool");
}
