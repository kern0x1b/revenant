#import "CharonCallKit.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CXProvider {
    CXProviderConfiguration *_configuration;
    __weak id<CXProviderDelegate> _delegate;
    dispatch_queue_t _queue;
    NSMutableArray<CXTransaction *> *_pending;
    BOOL _invalidated;
    BOOL _begun;
}

@dynamic configuration, pendingTransactions;

- (instancetype)initWithConfiguration:(CXProviderConfiguration *)configuration
{
    if ((self = [super init])) {
        _configuration = [configuration copy];
        _queue = dispatch_get_main_queue();
        _pending = [NSMutableArray array];
        [[CharonCallBroker shared] addProvider:self];
    }
    return self;
}

- (void)dealloc
{
    [[CharonCallBroker shared] removeProvider:self];
}

- (BOOL)charon_isValid
{
    @synchronized (self) {
        return !_invalidated;
    }
}

- (dispatch_queue_t)charon_queue
{
    @synchronized (self) {
        return _queue;
    }
}

- (CXProviderConfiguration *)configuration
{
    @synchronized (self) {
        return _configuration;
    }
}

- (void)setConfiguration:(CXProviderConfiguration *)configuration
{
    @synchronized (self) {
        _configuration = [configuration copy];
    }
}

// A delegate is told the provider began once the provider is ready to be used.
// On a release with CallKit that is when the connection to callservicesd is
// up; here there is nothing to connect to, so it is the next turn of the
// delegate's queue, which keeps the order an application relies on: setting
// the delegate returns before providerDidBegin: is called.
- (void)setDelegate:(id<CXProviderDelegate>)delegate queue:(dispatch_queue_t)queue
{
    BOOL begin;
    dispatch_queue_t chosen = queue ?: dispatch_get_main_queue();
    @synchronized (self) {
        _delegate = delegate;
        _queue = chosen;
        begin = delegate != nil && !_begun && !_invalidated;
        _begun = _begun || begin;
    }
    if (!begin)
        return;
    dispatch_async(chosen, ^{
        id<CXProviderDelegate> held = delegate;
        if ([held respondsToSelector:@selector(providerDidBegin:)])
            [held providerDidBegin:self];
    });
}

- (id<CXProviderDelegate>)charon_delegate
{
    @synchronized (self) {
        return _delegate;
    }
}

- (void)reportNewIncomingCallWithUUID:(NSUUID *)UUID update:(CXCallUpdate *)update completion:(void (^)(NSError *))completion
{
    NSError *failure = nil;
    if (![self charon_isValid])
        failure = charon_callkit_error(CXErrorDomainIncomingCall, CXErrorCodeIncomingCallErrorUnknown);
    else if (!UUID)
        failure = charon_callkit_error(CXErrorDomainIncomingCall, CXErrorCodeIncomingCallErrorUnknown);
    CXCall *call = nil;
    if (!failure) {
        call = [[CXCall alloc] charon_initWithUUID:UUID outgoing:NO];
        call.charon_provider = self;
        call.charon_update = [update copy];
        if (![[CharonCallBroker shared] addCall:call]) {
            call = nil;
            failure = charon_callkit_error(CXErrorDomainIncomingCall, CXErrorCodeIncomingCallErrorCallUUIDAlreadyExists);
        }
    }
    if (call)
        [self charon_presentIncomingCall:call];
    if (!completion)
        return;
    dispatch_async([self charon_queue], ^{
        completion(failure);
    });
}

- (void)charon_presentIncomingCall:(CXCall *)call
{
    [[CharonCallScreen shared] present:call of:self];
}

- (void)charon_audioSessionActivated:(id)session
{
    id<CXProviderDelegate> delegate = [self charon_delegate];
    dispatch_queue_t queue = [self charon_queue];
    if (!delegate || !queue)
        return;
    dispatch_async(queue, ^{
        id<CXProviderDelegate> held = delegate;
        if ([held respondsToSelector:@selector(provider:didActivateAudioSession:)])
            [held provider:self didActivateAudioSession:session];
    });
}

- (void)charon_audioSessionDeactivated:(id)session
{
    id<CXProviderDelegate> delegate = [self charon_delegate];
    dispatch_queue_t queue = [self charon_queue];
    if (!delegate || !queue)
        return;
    dispatch_async(queue, ^{
        id<CXProviderDelegate> held = delegate;
        if ([held respondsToSelector:@selector(provider:didDeactivateAudioSession:)])
            [held provider:self didDeactivateAudioSession:session];
    });
}

- (void)reportCallWithUUID:(NSUUID *)UUID updated:(CXCallUpdate *)update
{
    CXCall *call = [[CharonCallBroker shared] callWithUUID:UUID];
    if (!call || call.charon_provider != self)
        return;
    CXCallUpdate *merged = [update copy];
    [merged charon_applyOver:call.charon_update];
    call.charon_update = merged;
    [[CharonCallBroker shared] callChanged:call];
}

- (void)reportCallWithUUID:(NSUUID *)UUID endedAtDate:(NSDate *)dateEnded reason:(CXCallEndedReason)endedReason
{
    CXCall *call = [[CharonCallBroker shared] callWithUUID:UUID];
    if (!call || call.charon_provider != self)
        return;
    call.charon_dateEnded = dateEnded ?: [NSDate date];
    call.charon_endedReason = endedReason;
    [[CharonCallBroker shared] removeCall:call];
}

- (void)reportOutgoingCallWithUUID:(NSUUID *)UUID startedConnectingAtDate:(NSDate *)dateStartedConnecting
{
    CXCall *call = [[CharonCallBroker shared] callWithUUID:UUID];
    if (!call || call.charon_provider != self || !call.isOutgoing)
        return;
    call.charon_dateStartedConnecting = dateStartedConnecting ?: [NSDate date];
    [[CharonCallBroker shared] callChanged:call];
}

- (void)reportOutgoingCallWithUUID:(NSUUID *)UUID connectedAtDate:(NSDate *)dateConnected
{
    CXCall *call = [[CharonCallBroker shared] callWithUUID:UUID];
    if (!call || call.charon_provider != self || !call.isOutgoing)
        return;
    BOOL first = !call.hasConnected;
    call.charon_dateConnected = dateConnected ?: [NSDate date];
    [call charon_setHasConnected:YES];
    [[CharonCallBroker shared] callChanged:call];
    if (first)
        [[CharonCallBroker shared] callConnected:call];
}

// Invalidating a provider ends every call it holds and drops every
// transaction it has not finished, and the delegate is told the provider
// reset, which is how an application learns its calls are gone.
- (void)invalidate
{
    NSArray<CXTransaction *> *dropped;
    id<CXProviderDelegate> delegate;
    dispatch_queue_t queue;
    @synchronized (self) {
        if (_invalidated)
            return;
        _invalidated = YES;
        dropped = [_pending copy];
        [_pending removeAllObjects];
        delegate = _delegate;
        queue = _queue;
    }
    for (CXTransaction *transaction in dropped) {
        for (CXAction *action in transaction.actions)
            [action fail];
    }
    for (CXCall *call in [[CharonCallBroker shared] callsOfProvider:self]) {
        call.charon_dateEnded = [NSDate date];
        call.charon_endedReason = CXCallEndedReasonFailed;
        [[CharonCallBroker shared] removeCall:call];
    }
    [[CharonCallBroker shared] removeProvider:self];
    if (!delegate || !queue)
        return;
    dispatch_async(queue, ^{
        id<CXProviderDelegate> held = delegate;
        [held providerDidReset:self];
    });
}

- (NSArray<CXTransaction *> *)pendingTransactions
{
    @synchronized (self) {
        return [_pending copy];
    }
}

- (NSArray<__kindof CXCallAction *> *)pendingCallActionsOfClass:(Class)callActionClass withCallUUID:(NSUUID *)callUUID
{
    NSMutableArray *found = [NSMutableArray array];
    for (CXTransaction *transaction in [self pendingTransactions]) {
        for (CXAction *action in transaction.actions) {
            if (action.isComplete || ![action isKindOfClass:callActionClass])
                continue;
            if ([action isKindOfClass:[CXCallAction class]] && [((CXCallAction *)action).callUUID isEqual:callUUID])
                [found addObject:action];
        }
    }
    return found;
}

- (void)charon_removeTransaction:(CXTransaction *)transaction
{
    @synchronized (self) {
        [_pending removeObjectIdenticalTo:transaction];
    }
}

- (void)charon_actionTimedOut:(CXAction *)action
{
    id<CXProviderDelegate> delegate = [self charon_delegate];
    dispatch_queue_t queue = [self charon_queue];
    if (!delegate || !queue)
        return;
    dispatch_async(queue, ^{
        id<CXProviderDelegate> held = delegate;
        if ([held respondsToSelector:@selector(provider:timedOutPerformingAction:)])
            [held provider:self timedOutPerformingAction:action];
    });
}

// A transaction reaches the delegate whole if it takes it - that is what
// executeTransaction: answering YES means - and action by action if it does
// not. An action whose perform method the delegate does not answer fails at
// once: nothing is going to perform it, and a call left waiting on it would
// never end.
- (void)charon_execute:(CXTransaction *)transaction
{
    id<CXProviderDelegate> delegate = [self charon_delegate];
    dispatch_queue_t queue = [self charon_queue];
    NSArray<CXAction *> *actions = transaction.actions;
    transaction.charon_provider = self;
    for (CXAction *action in actions)
        action.charon_provider = self;
    @synchronized (self) {
        [_pending addObject:transaction];
    }
    if (!delegate || !queue) {
        for (CXAction *action in actions)
            [action fail];
        return;
    }
    dispatch_async(queue, ^{
        id<CXProviderDelegate> held = delegate;
        BOOL taken = [held respondsToSelector:@selector(provider:executeTransaction:)] && [held provider:self executeTransaction:transaction];
        if (!taken) {
            for (CXAction *action in actions) {
                SEL perform = [action charon_performSelector];
                if (perform && [held respondsToSelector:perform]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [held performSelector:perform withObject:self withObject:action];
#pragma clang diagnostic pop
                } else {
                    [action fail];
                }
            }
        }
    });
    // Each action runs out on its own deadline, which it has carried since it
    // was made, so a transaction that starts a call and mutes it has ten
    // minutes for the one and five seconds for the other.
    for (CXAction *action in actions) {
        NSTimeInterval left = [action.timeoutDate timeIntervalSinceNow];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(left, 0.0) * NSEC_PER_SEC)), queue, ^{
            if (!action.isComplete)
                [action charon_timedOut];
        });
    }
}

@end
