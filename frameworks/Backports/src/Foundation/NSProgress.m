#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../revenant_alias.h"

REVENANT_ALIAS(NSProgress)

@interface RevenantProgressFrame : NSObject
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic) int64_t pendingUnitCount;
@property (nonatomic) BOOL childAttached;
@property (nonatomic, strong) RevenantProgressFrame *next;
@end
@implementation RevenantProgressFrame
@synthesize progress = _progress, pendingUnitCount = _pendingUnitCount, childAttached = _childAttached, next = _next;
@end

@interface RevenantProgressState : NSObject
@property (nonatomic) int64_t totalUnitCount;
@property (nonatomic) int64_t completedUnitCount;
@property (nonatomic) BOOL cancellable;
@property (nonatomic) BOOL pausable;
@property (nonatomic) BOOL cancelled;
@property (nonatomic) BOOL paused;
@property (nonatomic, copy) void (^cancellationHandler)(void);
@property (nonatomic, copy) void (^pausingHandler)(void);
@property (nonatomic, copy) void (^resumingHandler)(void);
@property (nonatomic, copy) NSProgressKind kind;
@property (nonatomic, copy) NSString *localizedDescription;
@property (nonatomic, copy) NSString *localizedAdditionalDescription;
@property (nonatomic, strong) NSMutableDictionary<NSProgressUserInfoKey, id> *userInfo;
@property (nonatomic, strong) NSMutableArray<RevenantProgressFrame *> *implicitChildFrames;
@end

@implementation RevenantProgressState
@synthesize totalUnitCount = _totalUnitCount, completedUnitCount = _completedUnitCount, cancellable = _cancellable, pausable = _pausable, cancelled = _cancelled, paused = _paused, cancellationHandler = _cancellationHandler, pausingHandler = _pausingHandler, resumingHandler = _resumingHandler, kind = _kind, localizedDescription = _localizedDescription, localizedAdditionalDescription = _localizedAdditionalDescription, userInfo = _userInfo, implicitChildFrames = _implicitChildFrames;

- (instancetype)init
{
    if ((self = [super init])) {
        _cancellable = YES;
        _userInfo = [NSMutableDictionary dictionary];
    }
    return self;
}
@end

static NSString *const RevenantProgressThreadKey = @"org.revenant.backports.NSProgress.current";
static const char RevenantProgressStateKey;

static RevenantProgressState *revenant_progress_state(NSProgress *progress)
{
    @synchronized (progress) {
        RevenantProgressState *state = objc_getAssociatedObject(progress, &RevenantProgressStateKey);
        if (!state) {
            state = [[RevenantProgressState alloc] init];
            objc_setAssociatedObject(progress, &RevenantProgressStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return state;
    }
}

@implementation NSProgress (RevenantCore)

#pragma mark - The current-progress stack

+ (RevenantProgressFrame *)revenant_topFrame
{
    return [NSThread currentThread].threadDictionary[RevenantProgressThreadKey];
}

+ (void)revenant_setTopFrame:(RevenantProgressFrame *)frame
{
    NSMutableDictionary *dictionary = [NSThread currentThread].threadDictionary;
    if (frame)
        dictionary[RevenantProgressThreadKey] = frame;
    else
        [dictionary removeObjectForKey:RevenantProgressThreadKey];
}

+ (NSProgress *)currentProgress
{
    return [self revenant_topFrame].progress;
}

+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount
{
    NSProgress *progress = [[self alloc] initWithParent:[self currentProgress] userInfo:nil];
    progress.totalUnitCount = unitCount;
    return progress;
}

- (void)becomeCurrentWithPendingUnitCount:(int64_t)unitCount
{
    RevenantProgressFrame *frame = [[RevenantProgressFrame alloc] init];
    frame.progress = self;
    frame.pendingUnitCount = unitCount;
    frame.next = [NSProgress revenant_topFrame];
    [NSProgress revenant_setTopFrame:frame];
}

- (void)resignCurrent
{
    RevenantProgressFrame *frame = [NSProgress revenant_topFrame];
    NSAssert(frame && frame.progress == self, @"-resignCurrent was called without a matching -becomeCurrentWithPendingUnitCount:");
    if (!frame.childAttached)
        self.completedUnitCount += frame.pendingUnitCount;
    [NSProgress revenant_setTopFrame:frame.next];
}

- (void)revenant_attachImplicitChild:(NSProgress *)child
{
    RevenantProgressFrame *frame = [NSProgress revenant_topFrame];
    if (!frame || frame.progress != self || frame.childAttached)
        return;
    frame.childAttached = YES;
    RevenantProgressState *state = revenant_progress_state(self);
    if (!state.implicitChildFrames)
        state.implicitChildFrames = [NSMutableArray array];
    RevenantProgressFrame *held = [[RevenantProgressFrame alloc] init];
    held.progress = child;
    held.pendingUnitCount = frame.pendingUnitCount;
    [state.implicitChildFrames addObject:held];
    if (self.isCancelled)
        [child cancel];
    if (self.isPaused)
        [child pause];
}

#pragma mark - Life cycle

- (instancetype)init
{
    return [self initWithParent:nil userInfo:nil];
}

- (instancetype)initWithParent:(NSProgress *)parentProgressOrNil userInfo:(NSDictionary<NSProgressUserInfoKey, id> *)userInfoOrNil
{
    if ((self = [super init])) {
        RevenantProgressState *state = revenant_progress_state(self);
        state.userInfo = userInfoOrNil ? [userInfoOrNil mutableCopy] : [NSMutableDictionary dictionary];
        state.cancellable = YES;
        state.pausable = NO;
        if (parentProgressOrNil)
            [parentProgressOrNil revenant_attachImplicitChild:self];
    }
    return self;
}

#pragma mark - Counts and fraction

- (int64_t)totalUnitCount
{
    return revenant_progress_state(self).totalUnitCount;
}

- (void)setTotalUnitCount:(int64_t)totalUnitCount
{
    revenant_progress_state(self).totalUnitCount = totalUnitCount;
}

- (int64_t)completedUnitCount
{
    return revenant_progress_state(self).completedUnitCount;
}

- (void)setCompletedUnitCount:(int64_t)completedUnitCount
{
    revenant_progress_state(self).completedUnitCount = completedUnitCount;
}

- (double)fractionCompleted
{
    RevenantProgressState *state = revenant_progress_state(self);
    if (state.totalUnitCount <= 0)
        return NAN;
    double total = (double)state.totalUnitCount;
    double fraction = (double)state.completedUnitCount;
    for (RevenantProgressFrame *frame in state.implicitChildFrames) {
        double childFraction = frame.progress.fractionCompleted;
        if (isnan(childFraction) || childFraction < 0)
            childFraction = 0;
        else if (childFraction > 1)
            childFraction = 1;
        fraction += childFraction * (double)frame.pendingUnitCount;
    }
    return fraction / total;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingFractionCompleted
{
    return [NSSet setWithObjects:@"totalUnitCount", @"completedUnitCount", nil];
}

- (BOOL)isIndeterminate
{
    int64_t total = self.totalUnitCount;
    int64_t completed = self.completedUnitCount;
    return total < 0 || completed < 0 || (total == 0 && completed == 0);
}

#pragma mark - Cancelling and pausing

- (BOOL)isCancellable
{
    return revenant_progress_state(self).cancellable;
}

- (void)setCancellable:(BOOL)cancellable
{
    revenant_progress_state(self).cancellable = cancellable;
}

- (BOOL)isPausable
{
    return revenant_progress_state(self).pausable;
}

- (void)setPausable:(BOOL)pausable
{
    revenant_progress_state(self).pausable = pausable;
}

- (BOOL)isCancelled
{
    return revenant_progress_state(self).cancelled;
}

- (BOOL)isPaused
{
    return revenant_progress_state(self).paused;
}

- (void (^)(void))cancellationHandler
{
    return revenant_progress_state(self).cancellationHandler;
}

- (void)setCancellationHandler:(void (^)(void))cancellationHandler
{
    revenant_progress_state(self).cancellationHandler = cancellationHandler;
}

- (void (^)(void))pausingHandler
{
    return revenant_progress_state(self).pausingHandler;
}

- (void)setPausingHandler:(void (^)(void))pausingHandler
{
    revenant_progress_state(self).pausingHandler = pausingHandler;
}

- (void (^)(void))resumingHandler
{
    return revenant_progress_state(self).resumingHandler;
}

- (void)setResumingHandler:(void (^)(void))resumingHandler
{
    revenant_progress_state(self).resumingHandler = resumingHandler;
}

- (void)cancel
{
    RevenantProgressState *state = revenant_progress_state(self);
    if (!state.cancelled) {
        [self willChangeValueForKey:@"cancelled"];
        state.cancelled = YES;
        [self didChangeValueForKey:@"cancelled"];
        if (state.cancellationHandler)
            state.cancellationHandler();
    }
    for (RevenantProgressFrame *frame in state.implicitChildFrames)
        [frame.progress cancel];
}

- (void)pause
{
    RevenantProgressState *state = revenant_progress_state(self);
    if (!state.paused) {
        [self willChangeValueForKey:@"paused"];
        state.paused = YES;
        [self didChangeValueForKey:@"paused"];
        if (state.pausingHandler)
            state.pausingHandler();
    }
    for (RevenantProgressFrame *frame in state.implicitChildFrames)
        [frame.progress pause];
}

- (void)resume
{
    RevenantProgressState *state = revenant_progress_state(self);
    if (state.paused) {
        [self willChangeValueForKey:@"paused"];
        state.paused = NO;
        [self didChangeValueForKey:@"paused"];
        if (state.resumingHandler)
            state.resumingHandler();
    }
    for (RevenantProgressFrame *frame in state.implicitChildFrames)
        [frame.progress resume];
}

#pragma mark - Description, kind, userInfo

- (NSString *)localizedDescription
{
    return revenant_progress_state(self).localizedDescription ?: @"";
}

- (void)setLocalizedDescription:(NSString *)localizedDescription
{
    revenant_progress_state(self).localizedDescription = localizedDescription;
}

- (NSString *)localizedAdditionalDescription
{
    return revenant_progress_state(self).localizedAdditionalDescription ?: @"";
}

- (void)setLocalizedAdditionalDescription:(NSString *)localizedAdditionalDescription
{
    NSString *description = localizedAdditionalDescription;
    if (!description) {
        NSNumber *total = [self.userInfo objectForKey:NSProgressFileTotalCountKey];
        NSNumber *done = [self.userInfo objectForKey:NSProgressFileCompletedCountKey];
        if (total && done)
            description = [NSString stringWithFormat:@"%@ of %@", done, total];
    }
    revenant_progress_state(self).localizedAdditionalDescription = description;
}

- (NSProgressKind)kind
{
    return revenant_progress_state(self).kind;
}

- (void)setKind:(NSProgressKind)kind
{
    revenant_progress_state(self).kind = kind;
}

- (NSDictionary<NSProgressUserInfoKey, id> *)userInfo
{
    return [revenant_progress_state(self).userInfo copy];
}

- (void)setUserInfoObject:(id)objectOrNil forKey:(NSProgressUserInfoKey)key
{
    NSMutableDictionary *userInfo = revenant_progress_state(self).userInfo;
    [self willChangeValueForKey:@"userInfo"];
    if (objectOrNil)
        userInfo[key] = objectOrNil;
    else
        [userInfo removeObjectForKey:key];
    [self didChangeValueForKey:@"userInfo"];
}

@end
