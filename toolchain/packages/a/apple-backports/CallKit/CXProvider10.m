#import "RevenantCallKit.h"

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
        [[RevenantCallBroker shared] addProvider:self];
    }
    return self;
}

- (void)dealloc
{
    [[RevenantCallBroker shared] removeProvider:self];
}

- (BOOL)revenant_isValid
{
    @synchronized (self) {
        return !_invalidated;
    }
}

- (dispatch_queue_t)revenant_queue
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

- (id<CXProviderDelegate>)revenant_delegate
{
    @synchronized (self) {
        return _delegate;
    }
}

- (void)reportNewIncomingCallWithUUID:(NSUUID *)UUID update:(CXCallUpdate *)update completion:(void (^)(NSError *))completion
{
    NSError *failure = nil;
    if (![self revenant_isValid])
        failure = revenant_callkit_error(CXErrorDomainIncomingCall, CXErrorCodeIncomingCallErrorUnknown);
    else if (!UUID)
        failure = revenant_callkit_error(CXErrorDomainIncomingCall, CXErrorCodeIncomingCallErrorUnknown);
    CXCall *call = nil;
    if (!failure) {
        call = [[CXCall alloc] revenant_initWithUUID:UUID outgoing:NO];
        call.revenant_provider = self;
        call.revenant_update = [update copy];
        if (![[RevenantCallBroker shared] addCall:call]) {
            call = nil;
            failure = revenant_callkit_error(CXErrorDomainIncomingCall, CXErrorCodeIncomingCallErrorCallUUIDAlreadyExists);
        }
    }
    if (call)
        [self revenant_presentIncomingCall:call];
    if (!completion)
        return;
    dispatch_async([self revenant_queue], ^{
        completion(failure);
    });
}

- (void)revenant_presentIncomingCall:(CXCall *)call
{
    [[RevenantCallScreen shared] present:call of:self];
}

- (void)revenant_audioSessionActivated:(id)session
{
    id<CXProviderDelegate> delegate = [self revenant_delegate];
    dispatch_queue_t queue = [self revenant_queue];
    if (!delegate || !queue)
        return;
    dispatch_async(queue, ^{
        id<CXProviderDelegate> held = delegate;
        if ([held respondsToSelector:@selector(provider:didActivateAudioSession:)])
            [held provider:self didActivateAudioSession:session];
    });
}

- (void)revenant_audioSessionDeactivated:(id)session
{
    id<CXProviderDelegate> delegate = [self revenant_delegate];
    dispatch_queue_t queue = [self revenant_queue];
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
    CXCall *call = [[RevenantCallBroker shared] callWithUUID:UUID];
    if (!call || call.revenant_provider != self)
        return;
    CXCallUpdate *merged = [update copy];
    [merged revenant_applyOver:call.revenant_update];
    call.revenant_update = merged;
    [[RevenantCallBroker shared] callChanged:call];
}

- (void)reportCallWithUUID:(NSUUID *)UUID endedAtDate:(NSDate *)dateEnded reason:(CXCallEndedReason)endedReason
{
    CXCall *call = [[RevenantCallBroker shared] callWithUUID:UUID];
    if (!call || call.revenant_provider != self)
        return;
    call.revenant_dateEnded = dateEnded ?: [NSDate date];
    call.revenant_endedReason = endedReason;
    [[RevenantCallBroker shared] removeCall:call];
}

- (void)reportOutgoingCallWithUUID:(NSUUID *)UUID startedConnectingAtDate:(NSDate *)dateStartedConnecting
{
    CXCall *call = [[RevenantCallBroker shared] callWithUUID:UUID];
    if (!call || call.revenant_provider != self || !call.isOutgoing)
        return;
    call.revenant_dateStartedConnecting = dateStartedConnecting ?: [NSDate date];
    [[RevenantCallBroker shared] callChanged:call];
}

- (void)reportOutgoingCallWithUUID:(NSUUID *)UUID connectedAtDate:(NSDate *)dateConnected
{
    CXCall *call = [[RevenantCallBroker shared] callWithUUID:UUID];
    if (!call || call.revenant_provider != self || !call.isOutgoing)
        return;
    BOOL first = !call.hasConnected;
    call.revenant_dateConnected = dateConnected ?: [NSDate date];
    [call revenant_setHasConnected:YES];
    [[RevenantCallBroker shared] callChanged:call];
    if (first)
        [[RevenantCallBroker shared] callConnected:call];
}

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
    for (CXCall *call in [[RevenantCallBroker shared] callsOfProvider:self]) {
        call.revenant_dateEnded = [NSDate date];
        call.revenant_endedReason = CXCallEndedReasonFailed;
        [[RevenantCallBroker shared] removeCall:call];
    }
    [[RevenantCallBroker shared] removeProvider:self];
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

- (void)revenant_removeTransaction:(CXTransaction *)transaction
{
    @synchronized (self) {
        [_pending removeObjectIdenticalTo:transaction];
    }
}

- (void)revenant_actionTimedOut:(CXAction *)action
{
    id<CXProviderDelegate> delegate = [self revenant_delegate];
    dispatch_queue_t queue = [self revenant_queue];
    if (!delegate || !queue)
        return;
    dispatch_async(queue, ^{
        id<CXProviderDelegate> held = delegate;
        if ([held respondsToSelector:@selector(provider:timedOutPerformingAction:)])
            [held provider:self timedOutPerformingAction:action];
    });
}

- (void)revenant_execute:(CXTransaction *)transaction
{
    id<CXProviderDelegate> delegate = [self revenant_delegate];
    dispatch_queue_t queue = [self revenant_queue];
    NSArray<CXAction *> *actions = transaction.actions;
    transaction.revenant_provider = self;
    for (CXAction *action in actions)
        action.revenant_provider = self;
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
                SEL perform = [action revenant_performSelector];
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
    for (CXAction *action in actions) {
        NSTimeInterval left = [action.timeoutDate timeIntervalSinceNow];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(left, 0.0) * NSEC_PER_SEC)), queue, ^{
            if (!action.isComplete)
                [action revenant_timedOut];
        });
    }
}

@end
