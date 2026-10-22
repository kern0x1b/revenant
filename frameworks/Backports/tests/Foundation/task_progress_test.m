#import "check.h"
#import "RevenantTaskProgress.h"

@interface RevenantFakeTask : NSObject
@property (nonatomic) int cancelled, suspended, resumed;
- (void)cancel;
- (void)suspend;
- (void)resume;
@end

@implementation RevenantFakeTask
- (void)cancel { self.cancelled++; }
- (void)suspend { self.suspended++; }
- (void)resume { self.resumed++; }
@end

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    RevenantFakeTask *task = [[RevenantFakeTask alloc] init];
    NSProgress *progress = revenant_task_progress_create(task);
    revenant_check(progress.cancellable && progress.pausable, "the progress can be cancelled and paused", @"not");
    revenant_task_progress_apply(progress, 0, 250, 0, 1000, NO);
    revenant_check(progress.totalUnitCount == 1000 && progress.completedUnitCount == (revenant_negative ? 300 : 250), "an upload and download total counts both directions", [NSString stringWithFormat:@"%lld of %lld", progress.completedUnitCount, progress.totalUnitCount]);
    revenant_task_progress_apply(progress, 100, 250, 400, 1000, NO);
    revenant_check(progress.totalUnitCount == 1400 && progress.completedUnitCount == 350, "sent and received bytes add up", [NSString stringWithFormat:@"%lld of %lld", progress.completedUnitCount, progress.totalUnitCount]);
    revenant_task_progress_apply(progress, 0, 250, 0, -1, NO);
    revenant_check(progress.totalUnitCount == -1 && progress.indeterminate, "an unknown size is indeterminate", [NSString stringWithFormat:@"%lld", progress.totalUnitCount]);
    revenant_task_progress_apply(progress, 0, 640, 0, -1, YES);
    usleep(200000);
    revenant_check(progress.totalUnitCount == 640 && progress.completedUnitCount == 640 && progress.finished, "a completed task is whole", [NSString stringWithFormat:@"%lld of %lld", progress.completedUnitCount, progress.totalUnitCount]);
    [progress cancel];
    usleep(200000);
    revenant_check(task.cancelled == 1, "cancelling the progress cancels the task", [NSString stringWithFormat:@"%d", task.cancelled]);
    [progress pause];
    usleep(200000);
    revenant_check(task.suspended == 1, "pausing the progress suspends the task", [NSString stringWithFormat:@"%d", task.suspended]);
    [progress resume];
    usleep(200000);
    revenant_check(task.resumed == 1, "resuming the progress resumes the task", [NSString stringWithFormat:@"%d", task.resumed]);
    return revenant_finish();
}
