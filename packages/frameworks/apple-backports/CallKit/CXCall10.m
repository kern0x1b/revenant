#import "RevenantCallKit.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation CXCall {
    NSUUID *_UUID;
    BOOL _outgoing;
    BOOL _onHold;
    BOOL _hasConnected;
    BOOL _hasEnded;
}

@dynamic UUID, outgoing, onHold, hasConnected, hasEnded;
@synthesize revenant_provider = _revenant_provider;
@synthesize revenant_update = _revenant_update;
@synthesize revenant_dateStartedConnecting = _revenant_dateStartedConnecting;
@synthesize revenant_dateConnected = _revenant_dateConnected;
@synthesize revenant_dateEnded = _revenant_dateEnded;
@synthesize revenant_endedReason = _revenant_endedReason;
@synthesize revenant_muted = _revenant_muted;
@synthesize revenant_groupedWith = _revenant_groupedWith;

- (instancetype)revenant_initWithUUID:(NSUUID *)UUID outgoing:(BOOL)outgoing
{
    if ((self = [super init])) {
        _UUID = [UUID copy];
        _outgoing = outgoing;
    }
    return self;
}

- (NSUUID *)UUID
{
    return _UUID;
}

- (BOOL)isOutgoing
{
    return _outgoing;
}

- (BOOL)isOnHold
{
    return _onHold;
}

- (BOOL)hasConnected
{
    return _hasConnected;
}

- (BOOL)hasEnded
{
    return _hasEnded;
}

- (void)revenant_setOnHold:(BOOL)onHold
{
    _onHold = onHold;
}

- (void)revenant_setHasConnected:(BOOL)hasConnected
{
    _hasConnected = hasConnected;
}

- (void)revenant_setHasEnded:(BOOL)hasEnded
{
    _hasEnded = hasEnded;
}

- (CXCall *)revenant_snapshot
{
    CXCall *copy = [[CXCall alloc] revenant_initWithUUID:_UUID outgoing:_outgoing];
    copy->_onHold = _onHold;
    copy->_hasConnected = _hasConnected;
    copy->_hasEnded = _hasEnded;
    copy.revenant_provider = _revenant_provider;
    copy.revenant_update = _revenant_update;
    copy.revenant_dateStartedConnecting = _revenant_dateStartedConnecting;
    copy.revenant_dateConnected = _revenant_dateConnected;
    copy.revenant_dateEnded = _revenant_dateEnded;
    copy.revenant_endedReason = _revenant_endedReason;
    copy.revenant_muted = _revenant_muted;
    copy.revenant_groupedWith = _revenant_groupedWith;
    return copy;
}

- (BOOL)isEqualToCall:(CXCall *)call
{
    if (![call isKindOfClass:[CXCall class]])
        return NO;
    return call == self || [call.UUID isEqual:_UUID];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[CXCall class]] && [self isEqualToCall:object];
}

- (NSUInteger)hash
{
    return _UUID.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p UUID=%@ outgoing=%@ onHold=%@ connected=%@ ended=%@>", NSStringFromClass([self class]), self,
                                      _UUID.UUIDString, _outgoing ? @"YES" : @"NO", _onHold ? @"YES" : @"NO",
                                      _hasConnected ? @"YES" : @"NO", _hasEnded ? @"YES" : @"NO"];
}

@end

@implementation CXCallObserver {
    __weak id<CXCallObserverDelegate> _delegate;
    dispatch_queue_t _queue;
}

- (instancetype)init
{
    if ((self = [super init])) {
        [[RevenantCallBroker shared] addObserver:self];
        [[RevenantCallTelephony shared] start];
    }
    return self;
}

- (void)dealloc
{
    [[RevenantCallBroker shared] removeObserver:self];
}

- (NSArray<CXCall *> *)calls
{
    return [[RevenantCallBroker shared] calls];
}

- (void)setDelegate:(id<CXCallObserverDelegate>)delegate queue:(dispatch_queue_t)queue
{
    @synchronized (self) {
        _delegate = delegate;
        _queue = queue ?: dispatch_get_main_queue();
    }
}

- (void)revenant_callChanged:(CXCall *)call
{
    id<CXCallObserverDelegate> delegate;
    dispatch_queue_t queue;
    @synchronized (self) {
        delegate = _delegate;
        queue = _queue;
    }
    if (!delegate || !queue)
        return;
    dispatch_async(queue, ^{
        id<CXCallObserverDelegate> held = delegate;
        [held callObserver:self callChanged:call];
    });
}

@end
