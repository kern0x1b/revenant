// MPSGraphExecutionDescriptor and MPSGraphExecutableExecutionDescriptor, from the headers of
// MPSGraphExecutionDescriptor.h and MPSGraphExecutable.h in the SDK of iOS 16.4. Both are plain
// descriptors: they keep what they are given and the run methods above read them, which is the whole of
// what a descriptor can be asked for.

#import "CharonMPSGraph.h"

// What a wait and a signal are, as this file's two descriptor classes both keep them, and what a run does
// with them. They are here and not in either @implementation because BOTH classes declare the two methods -
// MPSGraphExecutionDescriptor in MPSGraph.h and MPSGraphExecutableExecutionDescriptor in MPSGraphExecutable.h -
// and the storage is two arrays either way.
//
// Measured on this host's own MPSGraph: a fresh id<MTLSharedEvent>'s own signaledValue is 0, and naming the
// event in either descriptor does not change it, so the only thing a run can do with one is to write it at the
// stage the caller named - and the one stage the header names is MPSGraphExecutionStageCompleted (0), which is
// measured and not assumed.
static void CharonMPSGraphDescriptorWait(NSMutableArray *waited, id<MTLSharedEvent> event, uint64_t value,
                                         NSString *what)
{
    if (event == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ named a wait with no shared event, and there is nothing to wait on",
                         what];
    }
    [waited addObject:@[event, @(value)]];
}

static void CharonMPSGraphDescriptorSignal(NSMutableArray *signalled, id<MTLSharedEvent> event,
                                           MPSGraphExecutionStage stage, uint64_t value, NSString *what)
{
    if (event == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ named a signal with no shared event, and there is nothing to signal",
                         what];
    }
    [signalled addObject:@[event, @(stage), @(value)]];
}

static void CharonMPSGraphDescriptorApply(NSMutableArray *waited, NSMutableArray *signalled,
                                          MPSGraphExecutionStage stage, NSString *name)
{
    for (NSArray *pair in waited) {
        id<MTLSharedEvent> event = pair[0];
        uint64_t wanted = [pair[1] unsignedLongLongValue];
        if (event.signaledValue < wanted) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ waits for a shared event at %llu and the event is at %llu. This "
                               @"port walks the graph on the CPU, where there is no queue to block on, so it "
                               @"says so rather than running before the event it was told to wait for",
                             name, wanted, (unsigned long long)event.signaledValue];
        }
    }
    for (NSArray *triple in signalled) {
        if ([triple[1] unsignedLongLongValue] != (unsigned long long)stage)
            continue;
        id<MTLSharedEvent> event = triple[0];
        event.signaledValue = [triple[2] unsignedLongLongValue];
    }
}

@implementation MPSGraphExecutionDescriptor {
    MPSGraphOptions _options;
    NSUInteger _maximumCommandsPerBuffer;
    NSMutableArray *_waitedEvents;
    NSMutableArray *_signalledEvents;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _options = MPSGraphOptionsDefault;
        _maximumCommandsPerBuffer = 0;
        _waitedEvents = [NSMutableArray array];
        _signalledEvents = [NSMutableArray array];
    }
    return self;
}

- (MPSGraphOptions)options
{
    return _options;
}

- (void)setOptions:(MPSGraphOptions)options
{
    _options = options;
}

// The two shared-event methods, which MPSGraph.h declares on THIS class as well as on the executable's own
// descriptor, and which the runs of both take. The header says the executable blocks on these shared events before it
// schedules execution on the HW, that encoding is not included though it can still go on, and that it signals these events at execution stage and then carries on. See
// -charon_mps_applyEventsAtStage:named:, which is what a run calls.
- (void)waitForEvent:(id<MTLSharedEvent>)event value:(uint64_t)value
{
    CharonMPSGraphDescriptorWait(_waitedEvents, event, value, @"an execution descriptor");
}

- (void)signalEvent:(id<MTLSharedEvent>)event
   atExecutionEvent:(MPSGraphExecutionStage)executionStage
              value:(uint64_t)value
{
    CharonMPSGraphDescriptorSignal(_signalledEvents, event, executionStage, value, @"an execution descriptor");
}

- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name
{
    CharonMPSGraphDescriptorApply(_waitedEvents, _signalledEvents, stage, name);
}

- (NSUInteger)maximumCommandsPerBuffer
{
    return _maximumCommandsPerBuffer;
}

- (void)setMaximumCommandsPerBuffer:(NSUInteger)maximumCommandsPerBuffer
{
    _maximumCommandsPerBuffer = maximumCommandsPerBuffer;
}

@end

@implementation MPSGraphExecutableExecutionDescriptor {
    MPSGraphExecutionDescriptor *_executionDescriptor;
    BOOL _waitForCompilationCompletion;
    // The shared events the caller named, in the order it named them. A wait is a pair and a signal a
    // triple, because a signal also carries the stage it happens at - and there is exactly one stage in the
    // header, MPSGraphExecutionStageCompleted (0), which is measured and not assumed: a fresh
    // id<MTLSharedEvent>'s own signaledValue is 0, and naming the event in this descriptor does not change it,
    // so the only thing a run can do with one is to write it at the stage the caller named.
    NSMutableArray *_waitedEvents;
    NSMutableArray *_signalledEvents;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _executionDescriptor = [[MPSGraphExecutionDescriptor alloc] init];
        _waitForCompilationCompletion = NO;
        _waitedEvents = [NSMutableArray array];
        _signalledEvents = [NSMutableArray array];
    }
    return self;
}

- (MPSGraphExecutionDescriptor *)executionDescriptor
{
    return _executionDescriptor;
}

- (void)setExecutionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    _executionDescriptor = executionDescriptor;
}

// -waitForEvent:value: - the header says the executable blocks on these shared events before it schedules execution on the HW,
// and the encoding part is not included, though encoding can still continue. That is a fact about a GPU this port does not have:
// the walk is over the host's memory on the CPU and there is nothing to schedule. So the event is KEPT and
// checked when the run reaches it, and a run whose event has not reached the value the caller named is refused
// rather than pretended: see -charon_mps_applyEventsAtStage:named:.
- (void)waitForEvent:(id<MTLSharedEvent>)event value:(uint64_t)value
{
    CharonMPSGraphDescriptorWait(_waitedEvents, event, value, @"an executable execution descriptor");
}

// -signalEvent:atExecutionEvent:value: - the header says the executable raises these shared events at an execution stage
// and then carries on at once. Measured: the event's own signaledValue is 0 until a run signals it, and the one
// stage the header names is MPSGraphExecutionStageCompleted, so a run writes the value into the event when it
// has finished its walk and then goes on.
- (void)signalEvent:(id<MTLSharedEvent>)event
   atExecutionEvent:(MPSGraphExecutionStage)executionStage
              value:(uint64_t)value
{
    CharonMPSGraphDescriptorSignal(_signalledEvents, event, executionStage, value,
                                   @"an executable execution descriptor");
}

// What a run does with the events the caller named: at the stage the caller named, every signal of that stage
// writes its value into its event, and every wait the caller named must be SATISFIED - an event whose
// signaledValue has already reached the value asked for is waited for and passed, and one that has not is
// refused, because this port's walk is on the CPU and there is no queue to block on: a refusal that says which
// event and which value is the answer, and a wait that returned early would be a silent wrong answer.
- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name
{
    CharonMPSGraphDescriptorApply(_waitedEvents, _signalledEvents, stage, name);
}

- (id)copyWithZone:(NSZone *)zone
{
    // The header's own class declaration says `NSObject<NSCopying>`, and this is the method that answers it.
    // A copy is ANOTHER descriptor carrying the same two values and not this object: both of them are
    // readwrite properties, so a caller that changes the copy's must not change this one's - which is the
    // difference from MPSGraphTensor's own -copyWithZone:, where `self` is right because a tensor's shape and
    // data type are never written after it is made.
    MPSGraphExecutableExecutionDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy.executionDescriptor = _executionDescriptor;
    copy.waitForCompilationCompletion = _waitForCompilationCompletion;
    copy->_waitedEvents = [_waitedEvents mutableCopy];
    copy->_signalledEvents = [_signalledEvents mutableCopy];
    return copy;
}

- (BOOL)waitForCompilationCompletion
{
    return _waitForCompilationCompletion;
}

- (void)setWaitForCompilationCompletion:(BOOL)waitForCompilationCompletion
{
    _waitForCompilationCompletion = waitForCompilationCompletion;
}

@end
