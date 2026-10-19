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

// A call of this application connecting is what activates the audio session,
// and the provider is told once it is active. A cellular call of the release
// has no provider and is none of the application's audio.
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

// What a fulfilled action does to the call it names. A failed action leaves
// the call as it was, except where the call only exists because the action was
// asked for - starting and answering - and there is nothing for it to be: the
// call ends as failed, which is what an application is told when it could not
// take the call it was asked to take.
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
        // The screen comes down as soon as the call is taken, not when it
        // ends: from here on it is a call in progress, which is the
        // application's own interface.
        [[CharonCallScreen shared] dismiss:call];
        call.charon_dateConnected = date;
        [call charon_setHasConnected:YES];
        [self callChanged:call];
        [self callConnected:call];
    } else if ([action isKindOfClass:[CXEndCallAction class]]) {
        // The user of this device ended the call, so there is no reason to
        // carry: a reason is what the provider reports when the call ended for
        // some cause of its own.
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
