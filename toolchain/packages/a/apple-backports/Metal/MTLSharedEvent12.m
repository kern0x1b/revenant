#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface MTLSharedEventHandle (Revenant)
- (instancetype)initWithState:(RevenantMetalEventState *)state label:(NSString *)label;
- (RevenantMetalEventState *)revenantState;
@end


@implementation RevenantMetalEventState {
    uint64_t _signaledValue;
    NSCondition *_condition;
    NSMutableArray *_pending;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _condition = [[NSCondition alloc] init];
        _pending = [NSMutableArray array];
    }
    return self;
}

- (uint64_t)signaledValue
{
    [_condition lock];
    uint64_t value = _signaledValue;
    [_condition unlock];
    return value;
}

- (void)setSignaledValue:(uint64_t)value
{
    [_condition lock];
    _signaledValue = value;
    NSMutableArray *pending = [_pending copy];
    [_pending removeAllObjects];
    [_condition broadcast];
    [_condition unlock];
    for (NSDictionary *entry in pending) {
        if ([entry[@"value"] unsignedLongLongValue] > value)
            continue;
        MTLSharedEventNotificationBlock block = entry[@"block"];
        dispatch_queue_t queue = entry[@"queue"];
        uint64_t reached = value;
        dispatch_async(queue, ^{
            block(entry[@"event"], reached);
        });
    }
}

- (void)waitForValue:(uint64_t)value timeout:(NSTimeInterval)seconds
{
    NSDate *deadline = seconds > 0 ? [NSDate dateWithTimeIntervalSinceNow:seconds] : nil;
    [_condition lock];
    while (_signaledValue < value) {
        if (deadline && ![_condition waitUntilDate:deadline])
            break;
        if (!deadline)
            [_condition wait];
    }
    [_condition unlock];
}

- (void)notifyValue:(uint64_t)value queue:(dispatch_queue_t)queue block:(MTLSharedEventNotificationBlock)block
{
    [_condition lock];
    if (_signaledValue >= value) {
        uint64_t reached = _signaledValue;
        [_condition unlock];
        dispatch_async(queue, ^{
            block(nil, reached);
        });
        return;
    }
    [_pending addObject:@{@"value": @(value), @"block": [block copy], @"queue": queue}];
    [_condition unlock];
}

@end

@implementation RevenantMetalSharedEvent {
    __strong RevenantMetalEventState *_state;
}

@synthesize label;

- (instancetype)init
{
    if ((self = [super init])) {
        _state = [[RevenantMetalEventState alloc] init];
    }
    return self;
}

+ (instancetype)revenantEventWithState:(RevenantMetalEventState *)state
{
    RevenantMetalSharedEvent *event = [[RevenantMetalSharedEvent alloc] init];
    event->_state = state;
    return event;
}

- (RevenantMetalEventState *)state
{
    return _state;
}

- (id<MTLDevice>)device
{
    return nil;
}

- (uint64_t)signaledValue
{
    return _state.signaledValue;
}

- (void)setSignaledValue:(uint64_t)value
{
    _state.signaledValue = value;
}

- (BOOL)revenantWaitForValue:(uint64_t)value
{
    return [self revenantWaitForValue:value timeout:0.0];
}

- (BOOL)revenantWaitForValue:(uint64_t)value timeout:(NSTimeInterval)seconds
{
    [_state waitForValue:value timeout:seconds];
    return _state.signaledValue >= value;
}

- (void)notifyListener:(MTLSharedEventListener *)listener atValue:(uint64_t)value block:(MTLSharedEventNotificationBlock)block
{
    [_state notifyValue:value queue:listener.dispatchQueue block:block];
}

- (MTLSharedEventHandle *)newSharedEventHandle
{
    return [[MTLSharedEventHandle alloc] initWithState:_state label:self.label];
}

@end

@implementation MTLSharedEventHandle {
    __strong RevenantMetalEventState *_state;
    NSString *_label;
}

@synthesize label;

- (instancetype)initWithState:(RevenantMetalEventState *)state label:(NSString *)label
{
    if ((self = [super init])) {
        _state = state;
        _label = [label copy];
    }
    return self;
}

- (RevenantMetalEventState *)revenantState
{
    return _state;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[MTLSharedEventHandle alloc] initWithState:_state label:_label];
}

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSError *error = RevenantMetalError(18, @"a shared event handle names a value and a wait that exist in this process, and there is nothing of them to write into an archive; it is passed to another process, not archived");
    NSLog(@"Metal: %@", error.localizedDescription);
    [coder failWithError:error];
}

@end

@implementation MTLSharedEventListener {
    dispatch_queue_t _queue;
}

- (instancetype)init
{
    return [self initWithDispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)dispatchQueue
{
    if ((self = [super init])) {
        _queue = dispatchQueue;
    }
    return self;
}

- (dispatch_queue_t)dispatchQueue
{
    return _queue;
}

@end

@interface RevenantMetalDevice (SharedEvent)
@end

@implementation RevenantMetalDevice (SharedEvent)

- (id<MTLSharedEvent>)newSharedEvent
{
    return [[RevenantMetalSharedEvent alloc] init];
}

- (id<MTLSharedEvent>)newSharedEventWithHandle:(MTLSharedEventHandle *)sharedEventHandle
{
    if (![sharedEventHandle isKindOfClass:[MTLSharedEventHandle class]]) {
        NSLog(@"Metal: a shared event handle of class %@ is not one of this port's, so there is no event state in it to open",
              NSStringFromClass([sharedEventHandle class]));
        return nil;
    }
    return [RevenantMetalSharedEvent revenantEventWithState:[(MTLSharedEventHandle *)sharedEventHandle revenantState]];
}

@end
