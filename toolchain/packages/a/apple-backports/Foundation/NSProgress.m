#import <Foundation/Foundation.h>

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
    NSMutableArray<CharonProgressFrame *> *_implicitChildFrames;
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

- (void)resume
{
}

#pragma mark - Description, kind, userInfo

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
