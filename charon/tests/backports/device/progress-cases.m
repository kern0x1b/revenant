#import <Foundation/Foundation.h>
#import "progress-cases.h"

static NSString *progress_text(NSProgress *progress)
{
    return [NSString stringWithFormat:@"%.3f %lld/%lld", progress.fractionCompleted, progress.completedUnitCount, progress.totalUnitCount];
}

@interface ProgressObserver : NSObject
@property (nonatomic, strong) NSMutableArray *values;
@end

@implementation ProgressObserver
- (instancetype)init
{
    if ((self = [super init]))
        _values = [NSMutableArray array];
    return self;
}
- (void)observeValueForKeyPath:(NSString *)path ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [_values addObject:[NSString stringWithFormat:@"%.2f", [change[NSKeyValueChangeNewKey] doubleValue]]];
}
@end

void progress_run(ProgressRecorder record)
{
    NSProgress *parent = [NSProgress progressWithTotalUnitCount:100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount:10];
    [parent addChild:child withPendingUnitCount:50];
    child.completedUnitCount = 5;
    record(@"child.half", [NSString stringWithFormat:@"parent=%.3f child=%.3f", parent.fractionCompleted, child.fractionCompleted]);
    child.completedUnitCount = 10;
    record(@"child.done", [NSString stringWithFormat:@"parent=%.3f child=%.3f", parent.fractionCompleted, child.fractionCompleted]);

    NSProgress *root = [NSProgress progressWithTotalUnitCount:4];
    NSProgress *first = [NSProgress progressWithTotalUnitCount:2];
    NSProgress *second = [NSProgress progressWithTotalUnitCount:2];
    [root addChild:first withPendingUnitCount:2];
    [root addChild:second withPendingUnitCount:2];
    first.completedUnitCount = 2;
    record(@"two.first", [NSString stringWithFormat:@"%.3f", root.fractionCompleted]);
    second.completedUnitCount = 1;
    record(@"two.second", [NSString stringWithFormat:@"%.3f", root.fractionCompleted]);

    ProgressObserver *observer = [[ProgressObserver alloc] init];
    NSProgress *watched = [NSProgress progressWithTotalUnitCount:10];
    NSProgress *inner = [NSProgress progressWithTotalUnitCount:4];
    [watched addChild:inner withPendingUnitCount:10];
    [watched addObserver:observer forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:NULL];
    inner.completedUnitCount = 1;
    inner.completedUnitCount = 2;
    inner.completedUnitCount = 4;
    [watched removeObserver:observer forKeyPath:@"fractionCompleted"];
    record(@"observed", [observer.values componentsJoinedByString:@","]);

    NSProgress *late = [NSProgress progressWithTotalUnitCount:10];
    NSProgress *lateChild = [NSProgress progressWithTotalUnitCount:10];
    lateChild.completedUnitCount = 5;
    [late addChild:lateChild withPendingUnitCount:10];
    record(@"late", [NSString stringWithFormat:@"%.3f", late.fractionCompleted]);
    NSProgress *reparent = [NSProgress progressWithTotalUnitCount:10];
    @try {
        [reparent addChild:lateChild withPendingUnitCount:5];
        record(@"readded", @"no exception");
    } @catch (NSException *exception) {
        record(@"readded", exception.name);
    }

    NSProgress *nested = [NSProgress progressWithTotalUnitCount:10];
    NSProgress *middle = [NSProgress progressWithTotalUnitCount:10];
    NSProgress *leaf = [NSProgress progressWithTotalUnitCount:10];
    [nested addChild:middle withPendingUnitCount:10];
    [middle addChild:leaf withPendingUnitCount:10];
    leaf.completedUnitCount = 5;
    record(@"nested", [NSString stringWithFormat:@"nested=%.3f middle=%.3f leaf=%.3f", nested.fractionCompleted, middle.fractionCompleted, leaf.fractionCompleted]);
    leaf.completedUnitCount = 10;
    record(@"nested.done", [NSString stringWithFormat:@"nested=%.3f middle=%.3f", nested.fractionCompleted, middle.fractionCompleted]);

    NSProgress *cancelParent = [NSProgress progressWithTotalUnitCount:10];
    NSProgress *cancelChild = [NSProgress progressWithTotalUnitCount:10];
    cancelChild.cancellable = YES;
    [cancelParent addChild:cancelChild withPendingUnitCount:10];
    [cancelParent cancel];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    record(@"cancel.child", [NSString stringWithFormat:@"parent=%d child=%d", cancelParent.isCancelled, cancelChild.isCancelled]);

    NSProgress *pauseParent = [NSProgress progressWithTotalUnitCount:10];
    NSProgress *pauseChild = [NSProgress progressWithTotalUnitCount:10];
    pauseChild.pausable = YES;
    pauseParent.pausable = YES;
    [pauseParent addChild:pauseChild withPendingUnitCount:10];
    [pauseParent pause];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    record(@"pause.child", [NSString stringWithFormat:@"parent=%d child=%d", pauseParent.isPaused, pauseChild.isPaused]);

    __weak NSProgress *weakParent = nil;
    __weak NSProgress *weakChild = nil;
    @autoreleasepool {
        NSProgress *scopedParent = [NSProgress progressWithTotalUnitCount:10];
        NSProgress *scopedChild = [NSProgress progressWithTotalUnitCount:10];
        [scopedParent addChild:scopedChild withPendingUnitCount:10];
        scopedChild.completedUnitCount = 3;
        weakParent = scopedParent;
        weakChild = scopedChild;
    }
    record(@"released", [NSString stringWithFormat:@"parent=%d child=%d", weakParent == nil, weakChild == nil]);
}
