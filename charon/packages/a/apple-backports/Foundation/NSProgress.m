#import <Foundation/Foundation.h>

// NSProgress arrived in iOS 6.0 with most of the surface iOS 7-9 later made public (facts/Foundation/NSProgress.md): the current
// thread's progress, +progressWithTotalUnitCount:, becomeCurrentWithPendingUnitCount:/resignCurrent, the two counts,
// fractionCompleted, cancelling and pausing with their handlers, userInfo and kind. Below 6.0 the class itself is missing, so this
// is the class the package's categories (NSProgress+Additions.m, +AddChild9.m, +FileOperationKind.m) already attach to on 6.0 and
// later; they attach to this one the same way. -addChild:withPendingUnitCount: and -isFinished are not implemented here on
// purpose: NSProgress+AddChild9.m and +Additions.m carry those (9.0), the same category for every band, so this class does not
// duplicate a selector two files would both define.
//
// Where a property's accessors come from a category on every band (estimatedTimeRemaining, throughput, fileOperationKind,
// fileURL, fileTotalCount, fileCompletedCount, and the getters of cancellationHandler/pausingHandler), this class says @dynamic
// and implements nothing: the accessor lives in the category file, once, for every band that lacks it, which is every band this
// class is compiled into.

// A frame of the current-progress stack (swift-corelibs-foundation's Progress.swift read for this mechanism, adapted to what iOS
// 6's own selectors are: currentProgress, becomeCurrentWithPendingUnitCount:, resignCurrent, initWithParent:userInfo:). One
// thread's stack is a chain of these, kept in the thread's dictionary; becomeCurrent pushes, resignCurrent pops.
@interface CharonProgressFrame : NSObject
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic) int64_t pendingUnitCount;
@property (nonatomic) BOOL childAttached;
@property (nonatomic, strong) CharonProgressFrame *next;
@end
@implementation CharonProgressFrame
@synthesize progress = _progress, pendingUnitCount = _pendingUnitCount, childAttached = _childAttached, next = _next;
@end

static NSString *const CharonProgressThreadKey = @"org.charon.apple-backports.NSProgress.current";

@implementation NSProgress {
    int64_t _totalUnitCount;
    int64_t _completedUnitCount;
    BOOL _cancellable;
    BOOL _pausable;
    BOOL _cancelled;
    BOOL _paused;
    void (^_cancellationHandler)(void);
    void (^_pausingHandler)(void);
    void (^_resumingHandler)(void);
    NSProgressKind _kind;
    NSString *_localizedDescription;
    NSString *_localizedAdditionalDescription;
    NSMutableDictionary<NSProgressUserInfoKey, id> *_userInfo;
    NSMutableArray<CharonProgressFrame *> *_implicitChildFrames; // one per attached implicit child, {progress = the child, pendingUnitCount = its portion}
}

@dynamic estimatedTimeRemaining, throughput, fileOperationKind, fileURL, fileTotalCount, fileCompletedCount;
@dynamic cancellationHandler, pausingHandler;

#pragma mark - The current-progress stack

+ (CharonProgressFrame *)charon_topFrame
{
    return [NSThread currentThread].threadDictionary[CharonProgressThreadKey];
}

+ (void)charon_setTopFrame:(CharonProgressFrame *)frame
{
    NSMutableDictionary *dictionary = [NSThread currentThread].threadDictionary;
    if (frame)
        dictionary[CharonProgressThreadKey] = frame;
    else
        [dictionary removeObjectForKey:CharonProgressThreadKey];
}

+ (NSProgress *)currentProgress
{
    return [self charon_topFrame].progress;
}

+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount
{
    NSProgress *progress = [[self alloc] initWithParent:[self currentProgress] userInfo:nil];
    progress.totalUnitCount = unitCount;
    return progress;
}

- (void)becomeCurrentWithPendingUnitCount:(int64_t)unitCount
{
    CharonProgressFrame *frame = [[CharonProgressFrame alloc] init];
    frame.progress = self;
    frame.pendingUnitCount = unitCount;
    frame.next = [NSProgress charon_topFrame];
    [NSProgress charon_setTopFrame:frame];
}

- (void)resignCurrent
{
    CharonProgressFrame *frame = [NSProgress charon_topFrame];
    NSAssert(frame && frame.progress == self, @"-resignCurrent was called without a matching -becomeCurrentWithPendingUnitCount:");
    if (!frame.childAttached)
        self.completedUnitCount += frame.pendingUnitCount;
    [NSProgress charon_setTopFrame:frame.next];
}

// The implicit child mechanism -initWithParent:userInfo: and +progressWithTotalUnitCount: use: at most one child per
// -becomeCurrentWithPendingUnitCount: call takes the portion offered; a later one made in the same scope is not attached to
// anything, same as swift-corelibs-foundation's _addImplicitChild.
// A child that attaches while self is already cancelled or paused is cascaded into immediately (matching the same push
// swift-corelibs-foundation's addChild does at attach time); one attached later, after self cancels or pauses, is reached
// instead by the cascade -cancel/-pause below run over every already-attached child. Together the two pushes cover both
// orders without a live link back from child to parent, which would need __weak - a runtime this class is also built
// without, on armv7-ios4.3.
- (void)charon_attachImplicitChild:(NSProgress *)child
{
    CharonProgressFrame *frame = [NSProgress charon_topFrame];
    if (!frame || frame.progress != self || frame.childAttached)
        return;
    frame.childAttached = YES;
    if (!_implicitChildFrames)
        _implicitChildFrames = [NSMutableArray array];
    CharonProgressFrame *held = [[CharonProgressFrame alloc] init];
    held.progress = child;
    held.pendingUnitCount = frame.pendingUnitCount;
    [_implicitChildFrames addObject:held];
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
        _userInfo = userInfoOrNil ? [userInfoOrNil mutableCopy] : [NSMutableDictionary dictionary];
        _cancellable = YES;
        _pausable = NO;
        // iOS 6's own -initWithParent:userInfo: does not raise for a parent that is not the current progress (facts, "Where iOS
        // 6 answers differently"; the newest release does); this attaches only when parentProgressOrNil is genuinely the top of
        // the calling thread's stack, and is a silent no-op (no portion consumed, no crash) otherwise - not reached by any
        // caller in this package, which only ever uses +progressWithTotalUnitCount:.
        if (parentProgressOrNil)
            [parentProgressOrNil charon_attachImplicitChild:self];
    }
    return self;
}

#pragma mark - Counts and fraction

- (int64_t)totalUnitCount
{
    return _totalUnitCount;
}

- (void)setTotalUnitCount:(int64_t)totalUnitCount
{
    _totalUnitCount = totalUnitCount;
}

- (int64_t)completedUnitCount
{
    return _completedUnitCount;
}

- (void)setCompletedUnitCount:(int64_t)completedUnitCount
{
    _completedUnitCount = completedUnitCount;
}

// iOS 6's own answer, measured (facts): NaN for a total of zero or less, not 0 (the newest release) and not 1 (swift-corelibs'
// "no work to do" case) - both read and neither used. A progress with attached implicit children (this class's own mechanism,
// not -addChild:withPendingUnitCount:, which the category carries with its own accounting) adds each unfinished child's
// fraction, clamped to [0, 1], scaled by the portion it was given; a child never removed once attached, so a progress that
// finishes keeps contributing 1.0 * its portion for the rest of the parent's life, same as completedUnitCount would if the
// parent counted it there - which, like the newest release's -addChild:withPendingUnitCount:, this class's completedUnitCount
// does not (measured nowhere; stated, not silently different).
- (double)fractionCompleted
{
    if (_totalUnitCount <= 0)
        return NAN;
    double total = (double)_totalUnitCount;
    double fraction = (double)_completedUnitCount;
    for (CharonProgressFrame *frame in _implicitChildFrames) {
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

// iOS 6's own answer (facts): only a negative total is indeterminate; a fresh progress (0 total, 0 completed) is not.
- (BOOL)isIndeterminate
{
    return _totalUnitCount < 0;
}

#pragma mark - Cancelling and pausing

- (BOOL)isCancellable
{
    return _cancellable;
}

- (void)setCancellable:(BOOL)cancellable
{
    _cancellable = cancellable;
}

- (BOOL)isPausable
{
    return _pausable;
}

- (void)setPausable:(BOOL)pausable
{
    _pausable = pausable;
}

- (BOOL)isCancelled
{
    return _cancelled;
}

- (BOOL)isPaused
{
    return _paused;
}

- (void)setCancellationHandler:(void (^)(void))cancellationHandler
{
    _cancellationHandler = [cancellationHandler copy];
}

- (void)setPausingHandler:(void (^)(void))pausingHandler
{
    _pausingHandler = [pausingHandler copy];
}

- (void (^)(void))resumingHandler
{
    return _resumingHandler;
}

- (void)setResumingHandler:(void (^)(void))resumingHandler
{
    _resumingHandler = [resumingHandler copy];
}

- (void)cancel
{
    if (!_cancelled) {
        [self willChangeValueForKey:@"cancelled"];
        _cancelled = YES;
        [self didChangeValueForKey:@"cancelled"];
        if (_cancellationHandler)
            _cancellationHandler();
    }
    for (CharonProgressFrame *frame in _implicitChildFrames)
        [frame.progress cancel];
}

- (void)pause
{
    if (!_paused) {
        [self willChangeValueForKey:@"paused"];
        _paused = YES;
        [self didChangeValueForKey:@"paused"];
        if (_pausingHandler)
            _pausingHandler();
    }
    for (CharonProgressFrame *frame in _implicitChildFrames)
        [frame.progress pause];
}

// The release has no way back from paused (facts): a real, honest no-op, not a crash and not a silent "resumed". A handler set
// through -setResumingHandler: is kept, and never called, for the same reason.
- (void)resume
{
}

#pragma mark - Description, kind, userInfo

// Empty by default on iOS 6 (facts, measured): the newest release composes a default from the counts and kind when nothing was
// set; a rule read off a handful of cases would be a guess (facts, "What the backport adds"), so an unset value answers "" here,
// what iOS 6 itself answers, and a value this was explicitly given comes back unchanged, as null_resettable promises.
- (NSString *)localizedDescription
{
    return _localizedDescription ?: @"";
}

- (void)setLocalizedDescription:(NSString *)localizedDescription
{
    _localizedDescription = [localizedDescription copy];
}

- (NSString *)localizedAdditionalDescription
{
    return _localizedAdditionalDescription ?: @"";
}

- (void)setLocalizedAdditionalDescription:(NSString *)localizedAdditionalDescription
{
    _localizedAdditionalDescription = [localizedAdditionalDescription copy];
}

- (NSProgressKind)kind
{
    return _kind;
}

- (void)setKind:(NSProgressKind)kind
{
    _kind = [kind copy];
}

- (NSDictionary<NSProgressUserInfoKey, id> *)userInfo
{
    return [_userInfo copy];
}

- (void)setUserInfoObject:(id)objectOrNil forKey:(NSProgressUserInfoKey)key
{
    [self willChangeValueForKey:@"userInfo"];
    if (objectOrNil)
        _userInfo[key] = objectOrNil;
    else
        [_userInfo removeObjectForKey:key];
    [self didChangeValueForKey:@"userInfo"];
}

@end
