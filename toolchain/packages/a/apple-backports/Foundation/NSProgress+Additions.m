#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NSProgressUserInfoKey const NSProgressEstimatedTimeRemainingKey = @"NSProgressEstimatedTimeRemainingKey";
NSProgressFileOperationKind const NSProgressFileOperationKindReceiving = @"NSProgressFileOperationKindReceiving";

static id charon_progress_value(NSProgress *progress, NSString *key)
{
    return [progress.userInfo objectForKey:key];
}

static void charon_progress_set(NSProgress *progress, NSString *key, id value)
{
    [progress setUserInfoObject:value forKey:key];
}

static id charon_progress_handler(NSProgress *progress, const char *name)
{
    Ivar ivar = class_getInstanceVariable([progress class], name);
    return ivar ? object_getIvar(progress, ivar) : nil;
}

@implementation NSProgress (CharonAdditions)

+ (NSProgress *)discreteProgressWithTotalUnitCount:(int64_t)unitCount
{
    NSProgress *progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    progress.totalUnitCount = unitCount;
    return progress;
}

+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount parent:(NSProgress *)parent pendingUnitCount:(int64_t)portionOfParentTotalUnitCount
{
    if (!parent)
        return [NSProgress discreteProgressWithTotalUnitCount:unitCount];
    [parent becomeCurrentWithPendingUnitCount:portionOfParentTotalUnitCount];
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:unitCount];
    [parent resignCurrent];
    return progress;
}

- (void)performAsCurrentWithPendingUnitCount:(int64_t)unitCount usingBlock:(void (^)(void))work
{
    [self becomeCurrentWithPendingUnitCount:unitCount];
    work();
    [self resignCurrent];
}

- (BOOL)isFinished
{
    int64_t total = self.totalUnitCount;
    int64_t completed = self.completedUnitCount;
    BOOL indeterminate = total < 0 || (total == 0 && completed == 0);
    return !indeterminate && completed >= total;
}

- (void (^)(void))cancellationHandler
{
    return charon_progress_handler(self, "_cancellationHandler");
}

- (void (^)(void))pausingHandler
{
    return charon_progress_handler(self, "_pausingHandler");
}

- (NSNumber *)estimatedTimeRemaining
{
    return charon_progress_value(self, NSProgressEstimatedTimeRemainingKey);
}

- (void)setEstimatedTimeRemaining:(NSNumber *)value
{
    charon_progress_set(self, NSProgressEstimatedTimeRemainingKey, [value copy]);
}

- (NSNumber *)throughput
{
    return charon_progress_value(self, NSProgressThroughputKey);
}

- (void)setThroughput:(NSNumber *)value
{
    charon_progress_set(self, NSProgressThroughputKey, [value copy]);
}

- (NSProgressFileOperationKind)fileOperationKind
{
    return charon_progress_value(self, NSProgressFileOperationKindKey);
}

- (void)setFileOperationKind:(NSProgressFileOperationKind)value
{
    charon_progress_set(self, NSProgressFileOperationKindKey, [value copy]);
}

- (NSURL *)fileURL
{
    return charon_progress_value(self, NSProgressFileURLKey);
}

- (void)setFileURL:(NSURL *)value
{
    charon_progress_set(self, NSProgressFileURLKey, [value copy]);
}

- (NSNumber *)fileTotalCount
{
    return charon_progress_value(self, NSProgressFileTotalCountKey);
}

- (void)setFileTotalCount:(NSNumber *)value
{
    charon_progress_set(self, NSProgressFileTotalCountKey, [value copy]);
}

- (NSNumber *)fileCompletedCount
{
    return charon_progress_value(self, NSProgressFileCompletedCountKey);
}

- (void)setFileCompletedCount:(NSNumber *)value
{
    charon_progress_set(self, NSProgressFileCompletedCountKey, [value copy]);
}

@end
