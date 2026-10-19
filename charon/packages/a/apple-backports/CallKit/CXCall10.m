#import "CharonCallKit.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation CXCall {
    NSUUID *_UUID;
    BOOL _outgoing;
    BOOL _onHold;
    BOOL _hasConnected;
    BOOL _hasEnded;
}

@dynamic UUID, outgoing, onHold, hasConnected, hasEnded;
@synthesize charon_provider = _charon_provider;
@synthesize charon_update = _charon_update;
@synthesize charon_dateStartedConnecting = _charon_dateStartedConnecting;
@synthesize charon_dateConnected = _charon_dateConnected;
@synthesize charon_dateEnded = _charon_dateEnded;
@synthesize charon_endedReason = _charon_endedReason;
@synthesize charon_muted = _charon_muted;
@synthesize charon_groupedWith = _charon_groupedWith;

- (instancetype)charon_initWithUUID:(NSUUID *)UUID outgoing:(BOOL)outgoing
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

- (void)charon_setOnHold:(BOOL)onHold
{
    _onHold = onHold;
}

- (void)charon_setHasConnected:(BOOL)hasConnected
{
    _hasConnected = hasConnected;
}

- (void)charon_setHasEnded:(BOOL)hasEnded
{
    _hasEnded = hasEnded;
}

// The delegate of an observer is handed a call that does not change under it,
// so what it is given is a copy taken while the broker holds its lock.
- (CXCall *)charon_snapshot
{
    CXCall *copy = [[CXCall alloc] charon_initWithUUID:_UUID outgoing:_outgoing];
    copy->_onHold = _onHold;
    copy->_hasConnected = _hasConnected;
    copy->_hasEnded = _hasEnded;
    copy.charon_provider = _charon_provider;
    copy.charon_update = _charon_update;
    copy.charon_dateStartedConnecting = _charon_dateStartedConnecting;
    copy.charon_dateConnected = _charon_dateConnected;
    copy.charon_dateEnded = _charon_dateEnded;
    copy.charon_endedReason = _charon_endedReason;
    copy.charon_muted = _charon_muted;
    copy.charon_groupedWith = _charon_groupedWith;
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

// Making an observer is what starts the watch on the release's own calls: an
// application that never asks for one never loads CoreTelephony's call
// centre.
- (instancetype)init
{
    if ((self = [super init])) {
        [[CharonCallBroker shared] addObserver:self];
        [[CharonCallTelephony shared] start];
    }
    return self;
}

- (void)dealloc
{
    [[CharonCallBroker shared] removeObserver:self];
}

- (NSArray<CXCall *> *)calls
{
    return [[CharonCallBroker shared] calls];
}

- (void)setDelegate:(id<CXCallObserverDelegate>)delegate queue:(dispatch_queue_t)queue
{
    @synchronized (self) {
        _delegate = delegate;
        _queue = queue ?: dispatch_get_main_queue();
    }
}

- (void)charon_callChanged:(CXCall *)call
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
