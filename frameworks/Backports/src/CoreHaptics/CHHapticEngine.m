#import "RevenantCoreHapticsPrivate.h"

@implementation CHHapticEngine
{
    BOOL _running;
    BOOL _playsHapticsOnly;
    BOOL _isMutedForAudio;
    BOOL _isMutedForHaptics;
    BOOL _autoShutdownEnabled;
    NSMutableSet *_players;
    NSMutableArray *_finishedHandlers;
    CHHapticEngineStoppedHandler _stoppedHandler;
    CHHapticEngineResetHandler _resetHandler;
}

@synthesize playsHapticsOnly = _playsHapticsOnly;
@synthesize isMutedForAudio = _isMutedForAudio;
@synthesize isMutedForHaptics = _isMutedForHaptics;
@synthesize autoShutdownEnabled = _autoShutdownEnabled;

+ (id<CHHapticDeviceCapability>)capabilitiesForHardware
{
    return [[RevenantHapticDeviceCapability alloc] init];
}

- (void)revenant_prepare
{
    _players = [NSMutableSet set];
    _finishedHandlers = [NSMutableArray array];
}

- (instancetype)initAndReturnError:(NSError **)outError
{
    if (!RevenantVibratorIsAvailable()) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeNotSupported);
        return nil;
    }
    self = [super init];
    if (self) {
        [self revenant_prepare];
        if (outError)
            *outError = nil;
    }
    return self;
}

- (instancetype)initWithAudioSession:(AVAudioSession *)audioSession error:(NSError **)error
{
    if (!RevenantVibratorIsAvailable()) {
        if (error)
            *error = revenant_corehaptics_error(CHHapticErrorCodeNotSupported);
        return nil;
    }
    self = [super init];
    if (self) {
        [self revenant_prepare];
        if (error)
            *error = nil;
    }
    return self;
}

- (NSTimeInterval)currentTime
{
    return [NSProcessInfo processInfo].systemUptime;
}

- (CHHapticEngineStoppedHandler)stoppedHandler
{
    @synchronized (self) {
        return _stoppedHandler;
    }
}

- (void)setStoppedHandler:(CHHapticEngineStoppedHandler)handler
{
    @synchronized (self) {
        _stoppedHandler = [handler copy];
    }
}

- (CHHapticEngineResetHandler)resetHandler
{
    @synchronized (self) {
        return _resetHandler;
    }
}

- (void)setResetHandler:(CHHapticEngineResetHandler)handler
{
    @synchronized (self) {
        _resetHandler = [handler copy];
    }
}

- (BOOL)revenant_isRunning
{
    @synchronized (self) {
        return _running;
    }
}

- (void)revenant_addPlayer:(id<CHHapticPatternPlayer>)player
{
    @synchronized (self) {
        [_players addObject:player];
    }
}

- (void)revenant_playerDidFinish:(id<CHHapticPatternPlayer>)player
{
    NSArray *handlers = nil;
    @synchronized (self) {
        [_players removeObject:player];
        if (_players.count == 0 && _finishedHandlers.count > 0) {
            handlers = [_finishedHandlers copy];
            [_finishedHandlers removeAllObjects];
        }
    }
    [self revenant_runFinishedHandlers:handlers];
}

- (void)revenant_runFinishedHandlers:(NSArray *)handlers
{
    for (CHHapticEngineFinishedHandler handler in handlers) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            CHHapticEngineFinishedAction action = handler(nil);
            if (action == CHHapticEngineFinishedActionStopEngine)
                [self stopWithCompletionHandler:nil];
        });
    }
}

- (void)notifyWhenPlayersFinished:(CHHapticEngineFinishedHandler)finishedHandler
{
    BOOL finished = NO;
    @synchronized (self) {
        if (!_running || _players.count == 0) {
            finished = YES;
        } else if (finishedHandler) {
            [_finishedHandlers addObject:[finishedHandler copy]];
        }
    }
    if (finished && finishedHandler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            CHHapticEngineFinishedAction action = finishedHandler(nil);
            if (action == CHHapticEngineFinishedActionStopEngine)
                [self stopWithCompletionHandler:nil];
        });
    }
}

- (BOOL)startAndReturnError:(NSError **)outError
{
    if (!RevenantVibratorIsAvailable()) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeNotSupported);
        return NO;
    }
    @synchronized (self) {
        _running = YES;
    }
    if (outError)
        *outError = nil;
    return YES;
}

- (void)startWithCompletionHandler:(CHHapticCompletionHandler)completionHandler
{
    NSError *error = nil;
    [self startAndReturnError:&error];
    if (completionHandler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completionHandler(error);
        });
    }
}

- (void)stopWithCompletionHandler:(CHHapticCompletionHandler)completionHandler
{
    NSArray *players;
    @synchronized (self) {
        _running = NO;
        players = [_players allObjects];
    }
    for (RevenantCHHapticPatternPlayer *player in players)
        [player revenant_cancel];
    RevenantVibratorStop();
    if (completionHandler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completionHandler(nil);
        });
    }
}

- (id<CHHapticPatternPlayer>)createPlayerWithPattern:(CHHapticPattern *)pattern error:(NSError **)outError
{
    if (![pattern isKindOfClass:[CHHapticPattern class]]) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternData);
        return nil;
    }
    RevenantCHHapticPatternPlayer *player = [[RevenantCHHapticPatternPlayer alloc] initWithEngine:self pattern:pattern];
    if (!player) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeResourceNotAvailable);
        return nil;
    }
    if (outError)
        *outError = nil;
    return player;
}

- (id<CHHapticAdvancedPatternPlayer>)createAdvancedPlayerWithPattern:(CHHapticPattern *)pattern error:(NSError **)outError
{
    if (outError)
        *outError = revenant_corehaptics_error(CHHapticErrorCodeOperationNotPermitted);
    return nil;
}

- (CHHapticAudioResourceID)registerAudioResource:(NSURL *)resourceURL options:(NSDictionary *)options error:(NSError **)outError
{
    if (outError)
        *outError = revenant_corehaptics_error(CHHapticErrorCodeOperationNotPermitted);
    return 0;
}

- (BOOL)unregisterAudioResource:(CHHapticAudioResourceID)resID error:(NSError **)outError
{
    if (outError)
        *outError = revenant_corehaptics_error(CHHapticErrorCodeOperationNotPermitted);
    return NO;
}

- (BOOL)playPatternFromURL:(NSURL *)fileURL error:(NSError **)outError
{
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&readError];
    if (!data) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeFileNotFound);
        return NO;
    }
    return [self playPatternFromData:data error:outError];
}

- (BOOL)playPatternFromData:(NSData *)data error:(NSError **)outError
{
    NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:data
                                                                          options:NSPropertyListImmutable
                                                                           format:NULL
                                                                            error:NULL];
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
        return NO;
    }
    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithDictionary:dictionary error:outError];
    if (!pattern)
        return NO;
    if (![self startAndReturnError:outError])
        return NO;
    id<CHHapticPatternPlayer> player = [self createPlayerWithPattern:pattern error:outError];
    if (!player)
        return NO;
    if (![player startAtTime:CHHapticTimeImmediate error:outError])
        return NO;
    return YES;
}

@end
