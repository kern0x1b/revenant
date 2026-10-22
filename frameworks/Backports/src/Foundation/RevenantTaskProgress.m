#import "RevenantTaskProgress.h"

@protocol RevenantTaskControl <NSObject>
- (void)cancel;
- (void)suspend;
- (void)resume;
@end

NSProgress *revenant_task_progress_create(id task)
{
    NSProgress *progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    __weak id<RevenantTaskControl> weak = task;
    progress.cancellable = YES;
    progress.pausable = YES;
    [progress setCancellationHandler:^{
        [weak cancel];
    }];
    [progress setPausingHandler:^{
        [weak suspend];
    }];
    [progress setResumingHandler:^{
        [weak resume];
    }];
    return progress;
}

void revenant_task_progress_apply(NSProgress *progress, int64_t sent, int64_t received, int64_t expectedToSend, int64_t expectedToReceive, BOOL complete)
{
    int64_t completed = sent + received;
    progress.totalUnitCount = complete ? completed : (expectedToSend < 0 || expectedToReceive < 0 ? -1 : expectedToSend + expectedToReceive);
    progress.completedUnitCount = completed;
}
