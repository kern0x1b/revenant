#import "RevenantCallKit.h"

@implementation RevenantCallBroker {
    NSHashTable *_providers;
    NSHashTable *_observers;
    NSMutableArray<CXCall *> *_calls;
}

+ (instancetype)shared
{
    static RevenantCallBroker *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[RevenantCallBroker alloc] init];
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
            if ([provider revenant_isValid])
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
            [found addObject:[call revenant_snapshot]];
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
            if (call.revenant_provider == provider)
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
            if (call.revenant_provider != provider || call.hasEnded)
                continue;
            [groups addObject:call.revenant_groupedWith ?: call.UUID];
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
    CXProvider *provider = call.revenant_provider;
    [call revenant_setHasEnded:YES];
    @synchronized (self) {
        [_calls removeObjectIdenticalTo:call];
    }
    [self callChanged:call];
    [[RevenantCallScreen shared] dismiss:call];
    if (wasConnected && provider)
        [[RevenantCallAudio shared] callEndedFor:provider];
}

- (void)callConnected:(CXCall *)call
{
    if (call.revenant_provider)
        [[RevenantCallAudio shared] callConnectedFor:call.revenant_provider];
}

- (void)callChanged:(CXCall *)call
{
    CXCall *snapshot = [call revenant_snapshot];
    NSArray *observers;
    @synchronized (self) {
        observers = _observers.allObjects;
    }
    for (CXCallObserver *observer in observers)
        [observer revenant_callChanged:snapshot];
}

- (void)applyAction:(CXAction *)action
{
    if (![action isKindOfClass:[CXCallAction class]])
        return;
    CXCallAction *call_action = (CXCallAction *)action;
    CXCall *call = [self callWithUUID:call_action.callUUID];
    if (!call)
        return;
    NSDate *date = call_action.revenant_date ?: [NSDate date];
    if (!action.revenant_fulfilled) {
        if ([action isKindOfClass:[CXStartCallAction class]] || [action isKindOfClass:[CXAnswerCallAction class]]) {
            call.revenant_dateEnded = date;
            call.revenant_endedReason = CXCallEndedReasonFailed;
            [self removeCall:call];
        }
        return;
    }
    if ([action isKindOfClass:[CXStartCallAction class]]) {
        call.revenant_dateStartedConnecting = call.revenant_dateStartedConnecting ?: date;
        [self callChanged:call];
    } else if ([action isKindOfClass:[CXAnswerCallAction class]]) {
        [[RevenantCallScreen shared] dismiss:call];
        call.revenant_dateConnected = date;
        [call revenant_setHasConnected:YES];
        [self callChanged:call];
        [self callConnected:call];
    } else if ([action isKindOfClass:[CXEndCallAction class]]) {
        call.revenant_dateEnded = date;
        [self removeCall:call];
    } else if ([action isKindOfClass:[CXSetHeldCallAction class]]) {
        [call revenant_setOnHold:((CXSetHeldCallAction *)action).isOnHold];
        [self callChanged:call];
    } else if ([action isKindOfClass:[CXSetMutedCallAction class]]) {
        call.revenant_muted = ((CXSetMutedCallAction *)action).isMuted;
        [self callChanged:call];
    } else if ([action isKindOfClass:[CXSetGroupCallAction class]]) {
        call.revenant_groupedWith = ((CXSetGroupCallAction *)action).callUUIDToGroupWith;
        [self callChanged:call];
    }
}

@end
