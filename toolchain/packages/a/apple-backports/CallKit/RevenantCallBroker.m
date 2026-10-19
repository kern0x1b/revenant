#import "CharonCallKit.h"

@implementation CharonCallBroker {
    NSHashTable *_providers;
    NSHashTable *_observers;
    NSMutableArray<CXCall *> *_calls;
}

+ (instancetype)shared
{
    static CharonCallBroker *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonCallBroker alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _providers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality];
        _observers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality];
        _calls = [NSMutableArray array];
    }
    return self;
}

- (void)addProvider:(CXProvider *)provider
{
    @synchronized (self) {
        [_providers addObject:provider];
    }
}

- (void)removeProvider:(CXProvider *)provider
{
    @synchronized (self) {
        [_providers removeObject:provider];
    }
}

- (CXProvider *)anyProvider
{
    @synchronized (self) {
        for (CXProvider *provider in _providers) {
            if ([provider charon_isValid])
                return provider;
        }
    }
    return nil;
}

- (void)addObserver:(CXCallObserver *)observer
{
    @synchronized (self) {
        [_observers addObject:observer];
    }
}

- (void)removeObserver:(CXCallObserver *)observer
{
    @synchronized (self) {
        [_observers removeObject:observer];
    }
}

- (NSArray<CXCall *> *)calls
{
    NSMutableArray *found = [NSMutableArray array];
    @synchronized (self) {
        for (CXCall *call in _calls)
            [found addObject:[call charon_snapshot]];
    }
    return found;
}

- (CXCall *)callWithUUID:(NSUUID *)UUID
{
    if (!UUID)
        return nil;
    @synchronized (self) {
        for (CXCall *call in _calls) {
            if ([call.UUID isEqual:UUID])
                return call;
        }
    }
    return nil;
}

- (NSArray<CXCall *> *)callsOfProvider:(CXProvider *)provider
{
    NSMutableArray *found = [NSMutableArray array];
    @synchronized (self) {
        for (CXCall *call in _calls) {
            if (call.charon_provider == provider)
                [found addObject:call];
        }
    }
    return found;
}

- (NSUInteger)groupsOfProvider:(CXProvider *)provider
{
    NSMutableSet *groups = [NSMutableSet set];
    @synchronized (self) {
        for (CXCall *call in _calls) {
            if (call.charon_provider != provider || call.hasEnded)
                continue;
            [groups addObject:call.charon_groupedWith ?: call.UUID];
        }
    }
    return groups.count;
}

- (BOOL)addCall:(CXCall *)call
{
    @synchronized (self) {
        for (CXCall *held in _calls) {
            if ([held.UUID isEqual:call.UUID])
                return NO;
        }
        [_calls addObject:call];
    }
    [self callChanged:call];
    return YES;
}

- (void)removeCall:(CXCall *)call
{
    BOOL wasConnected = call.hasConnected;
    CXProvider *provider = call.charon_provider;
    [call charon_setHasEnded:YES];
    @synchronized (self) {
        [_calls removeObjectIdenticalTo:call];
    }
    [self callChanged:call];
    [[CharonCallScreen shared] dismiss:call];
    if (wasConnected && provider)
        [[CharonCallAudio shared] callEndedFor:provider];
}

- (void)callConnected:(CXCall *)call
{
    if (call.charon_provider)
        [[CharonCallAudio shared] callConnectedFor:call.charon_provider];
}

- (void)callChanged:(CXCall *)call
{
    CXCall *snapshot = [call charon_snapshot];
    NSArray *observers;
    @synchronized (self) {
        observers = _observers.allObjects;
    }
    for (CXCallObserver *observer in observers)
        [observer charon_callChanged:snapshot];
}

- (void)applyAction:(CXAction *)action
{
    if (![action isKindOfClass:[CXCallAction class]])
        return;
    CXCallAction *call_action = (CXCallAction *)action;
    CXCall *call = [self callWithUUID:call_action.callUUID];
    if (!call)
        return;
    NSDate *date = call_action.charon_date ?: [NSDate date];
    if (!action.charon_fulfilled) {
        if ([action isKindOfClass:[CXStartCallAction class]] || [action isKindOfClass:[CXAnswerCallAction class]]) {
            call.charon_dateEnded = date;
            call.charon_endedReason = CXCallEndedReasonFailed;
            [self removeCall:call];
        }
        return;
    }
    if ([action isKindOfClass:[CXStartCallAction class]]) {
        call.charon_dateStartedConnecting = call.charon_dateStartedConnecting ?: date;
        [self callChanged:call];
    } else if ([action isKindOfClass:[CXAnswerCallAction class]]) {
        [[CharonCallScreen shared] dismiss:call];
        call.charon_dateConnected = date;
        [call charon_setHasConnected:YES];
        [self callChanged:call];
        [self callConnected:call];
    } else if ([action isKindOfClass:[CXEndCallAction class]]) {
        call.charon_dateEnded = date;
        [self removeCall:call];
    } else if ([action isKindOfClass:[CXSetHeldCallAction class]]) {
        [call charon_setOnHold:((CXSetHeldCallAction *)action).isOnHold];
        [self callChanged:call];
    } else if ([action isKindOfClass:[CXSetMutedCallAction class]]) {
        call.charon_muted = ((CXSetMutedCallAction *)action).isMuted;
        [self callChanged:call];
    } else if ([action isKindOfClass:[CXSetGroupCallAction class]]) {
        call.charon_groupedWith = ((CXSetGroupCallAction *)action).callUUIDToGroupWith;
        [self callChanged:call];
    }
}

@end
