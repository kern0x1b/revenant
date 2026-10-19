#import "CharonMPSGraph.h"

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

- (void)waitForEvent:(id<MTLSharedEvent>)event value:(uint64_t)value
{
    CharonMPSGraphDescriptorWait(_waitedEvents, event, value, @"an executable execution descriptor");
}

- (void)signalEvent:(id<MTLSharedEvent>)event
   atExecutionEvent:(MPSGraphExecutionStage)executionStage
              value:(uint64_t)value
{
    CharonMPSGraphDescriptorSignal(_signalledEvents, event, executionStage, value,
                                   @"an executable execution descriptor");
}

- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name
{
    CharonMPSGraphDescriptorApply(_waitedEvents, _signalledEvents, stage, name);
}

- (id)copyWithZone:(NSZone *)zone
{
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
