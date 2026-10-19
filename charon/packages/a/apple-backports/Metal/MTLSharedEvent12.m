#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// The handle's two private members, declared beside the class: the SDK's own @interface for
// MTLSharedEventHandle has no room for a state, and the port's build is ARC, so there is no retain
// and no release to write.
@interface MTLSharedEventHandle (Charon)
- (instancetype)initWithState:(CharonMetalEventState *)state label:(NSString *)label;
- (CharonMetalEventState *)charonState;
@end


// A shared event is a signal value and the wait that blocks until it is reached. The port keeps the
// value and the wait as real state on the CPU: a fence on this device is not a piece of work in
// flight, since the port issues each command as it is encoded, so the value an encoder captures is
// the value the work it had encoded has already reached, and a wait for it returns at once. What a
// caller can still do with a real event is signal a value itself and wait for a value another thread
// signals, and both of those are what this implements.
//
// The value and the wait live in a state of their own, and a handle names that state rather than the
// event: -newSharedEventWithHandle: hands back a different object over the same value, which is what
// opening an event elsewhere is. What a handle cannot do here is cross a process, because the port
// runs one; that is the whole of what it cannot do, and -newSharedEventWithHandle: on a handle of
// another device's event is refused with a line in the log rather than silently opening nothing.

@implementation CharonMetalEventState {
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

@implementation CharonMetalSharedEvent {
    __strong CharonMetalEventState *_state;
}

@synthesize label;

- (instancetype)init
{
    if ((self = [super init])) {
        _state = [[CharonMetalEventState alloc] init];
    }
    return self;
}

// An event over a state that is not its own, which is what a handle names.
+ (instancetype)charonEventWithState:(CharonMetalEventState *)state
{
    CharonMetalSharedEvent *event = [[CharonMetalSharedEvent alloc] init];
    event->_state = state;
    return event;
}

- (CharonMetalEventState *)state
{
    return _state;
}

- (id<MTLDevice>)device
{
    // The device property of a shared event is nil when the event is shared across devices, and this
    // one is the port's own event on the port's own device: nil is what Metal answers for a shared
    // event, so the port answers the same.
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

- (BOOL)charonWaitForValue:(uint64_t)value
{
    return [self charonWaitForValue:value timeout:0.0];
}

// A wait of 0 seconds in the timeout means no timeout: a fence the port's own encoder never lowered
// is a value that will not come, and waiting for it is what the caller asked for.
- (BOOL)charonWaitForValue:(uint64_t)value timeout:(NSTimeInterval)seconds
{
    [_state waitForValue:value timeout:seconds];
    return _state.signaledValue >= value;
}

- (void)notifyListener:(MTLSharedEventListener *)listener atValue:(uint64_t)value block:(MTLSharedEventNotificationBlock)block
{
    [_state notifyValue:value queue:listener.dispatchQueue block:block];
}

// A handle names the state of this event, and nothing else: the value and the wait that go with it.
// What it cannot do is be opened in another process, because there is no other process to open it
// in; within this one, -newSharedEventWithHandle: hands back an event over the very same state.
- (MTLSharedEventHandle *)newSharedEventHandle
{
    return [[MTLSharedEventHandle alloc] initWithState:_state label:self.label];
}

@end

// The handle is the SDK's own class, and iOS 6 carries no class of this name, so the port carries it.
// Its one job is to name the state of an event, which is what -newSharedEventWithHandle: opens.
@implementation MTLSharedEventHandle {
    __strong CharonMetalEventState *_state;
    NSString *_label;
}

@synthesize label;

- (instancetype)initWithState:(CharonMetalEventState *)state label:(NSString *)label
{
    if ((self = [super init])) {
        _state = state;
        _label = [label copy];
    }
    return self;
}

- (CharonMetalEventState *)charonState
{
    return _state;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[MTLSharedEventHandle alloc] initWithState:_state label:_label];
}

// Apple's class of this name is NSSecureCoding. A handle here names a signal value and a condition
// that exist in this process, and there is nothing of them to write into an archive, so the class
// says it does not do secure coding and an encode is refused through the archive's own error rather
// than left to reach a method this class does not have.
+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSError *error = CharonMetalError(18, @"a shared event handle names a value and a wait that exist in this process, and there is nothing of them to write into an archive; it is passed to another process, not archived");
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
        // The port's backports build with ARC, and a dispatch object of a deployment this old is an
        // Objective-C object under it, so the queue is held by the ivar and needs no retain of its own.
        _queue = dispatchQueue;
    }
    return self;
}

- (dispatch_queue_t)dispatchQueue
{
    return _queue;
}

@end

@interface CharonMetalDevice (SharedEvent)
@end

@implementation CharonMetalDevice (SharedEvent)

- (id<MTLSharedEvent>)newSharedEvent
{
    return [[CharonMetalSharedEvent alloc] init];
}

- (id<MTLSharedEvent>)newSharedEventWithHandle:(MTLSharedEventHandle *)sharedEventHandle
{
    if (![sharedEventHandle isKindOfClass:[MTLSharedEventHandle class]]) {
        NSLog(@"Metal: a shared event handle of class %@ is not one of this port's, so there is no event state in it to open",
              NSStringFromClass([sharedEventHandle class]));
        return nil;
    }
    return [CharonMetalSharedEvent charonEventWithState:[(MTLSharedEventHandle *)sharedEventHandle charonState]];
}

@end
