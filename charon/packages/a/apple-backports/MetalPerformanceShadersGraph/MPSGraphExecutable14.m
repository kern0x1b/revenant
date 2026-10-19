// MPSGraphExecutable, from the header of MPSGraphExecutable.h in the SDK of iOS 16.4: a compiled graph
// and the ways to run it. An executable of this port is the graph itself, because the work is a walk
// over the operations and there is nothing to compile ahead of time.

#import "CharonMPSGraph.h"

@implementation MPSGraphExecutable {
    MPSGraph *_graph;
    MPSGraphDevice *_device;
    NSDictionary *_feeds;
    NSArray<MPSGraphTensor *> *_targetTensors;
    NSArray<MPSGraphOperation *> *_targetOperations;
    MPSGraphExecutableExecutionDescriptor *_executionDescriptor;
    BOOL _append;
    MPSGraphOptions _options;
    // What -specializeWithDevice:inputTypes:compilationDescriptor: was told, which is the whole of what a
    // specialization is on a walk: there is nothing compiled to specialize, and the header's own answer for a
    // call that has not specialized is to specialize for the shapes it is given, which the output types below
    // do from the targets the executable holds.
    BOOL _specialized;
    MPSGraphDevice *_specializedDevice;
    NSArray<MPSGraphType *> *_specializedInputTypes;
}

- (instancetype)initWithGraph:(MPSGraph *)graph
                        device:(MPSGraphDevice *)device
                        feeds:(NSDictionary *)feeds
                 targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
              targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
           executableDescriptor:(MPSGraphExecutableExecutionDescriptor *)executableDescriptor
{
    if ((self = [super init])) {
        _graph = graph;
        _device = device;
        _feeds = [feeds copy];
        _targetTensors = [targetTensors copy];
        _targetOperations = [targetOperations copy];
        _executionDescriptor = executableDescriptor;
        _append = NO;
        _options = MPSGraphOptionsDefault;
    }
    return self;
}

- (NSArray<MPSGraphTensor *> *)feedTensors
{
    return _feeds.allKeys;
}

- (NSArray<MPSGraphTensor *> *)targetTensors
{
    return _targetTensors;
}

- (MPSGraphDevice *)device
{
    return _device;
}

- (MPSGraphOptions)options
{
    return _options;
}

- (void)setOptions:(MPSGraphOptions)options
{
    _options = options;
}

- (BOOL)append
{
    return _append;
}

- (void)setAppend:(BOOL)append
{
    _append = append;
}

- (NSArray<MPSGraphTensorData *> *)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                                            inputsArray:(NSArray<MPSGraphTensorData *> *)inputsArray
                                           resultsArray:(NSArray<MPSGraphTensorData *> *)resultsArray
                                    executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)executionDescriptor
{
    (void)commandQueue;
    return [self charon_mps_walkInputs:inputsArray results:resultsArray executionDescriptor:executionDescriptor];
}

// The walk every run of this executable is, whether it came through a command queue or through a command
// buffer: the feeds the executable holds overlaid with the inputs given here, the graph's own walk over its
// operations, and the answer written into the tensor data the caller allocated. The descriptor's events are
// honoured at the end of it, and the walk is the graph's.
- (NSArray<MPSGraphTensorData *> *)charon_mps_walkInputs:(NSArray<MPSGraphTensorData *> *)inputsArray
                                                  results:(NSArray<MPSGraphTensorData *> *)resultsArray
                                       executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)executionDescriptor
{
    // The feeds are the graph's own, overlaid with the inputs given here, which is how a caller replaces
    // one placeholder's value between two runs of the same executable. The results are written into the
    // tensor data the caller allocated, so the answer is in a buffer the caller owns.
    NSMutableDictionary *feeds = [_feeds mutableCopy];
    // The inputs pair with the feed tensors in the order the placeholders were added to the graph, which
    // is the order the caller passed the inputs in. A dictionary's own key order is arbitrary, and
    // pairing by it gave the second operand to the first tensor, which every non-commutative
    // operation then read backwards.
    NSMutableArray<MPSGraphTensor *> *feedTensors = [NSMutableArray array];
    for (MPSGraphTensor *placeholder in _graph.placeholderTensors)
        if (_feeds[placeholder])
            [feedTensors addObject:placeholder];
    for (MPSGraphTensor *tensor in _feeds.allKeys)
        if (![feedTensors containsObject:tensor])
            [feedTensors addObject:tensor];
    for (NSUInteger i = 0; i < inputsArray.count && i < feedTensors.count; i++)
        feeds[feedTensors[i]] = inputsArray[i];
    NSDictionary *results = [_graph runWithFeeds:feeds
                                    targetTensors:_targetTensors
                                 targetOperations:_targetOperations];
    NSMutableArray *returned = [NSMutableArray array];
    for (NSUInteger i = 0; i < _targetTensors.count; i++) {
        MPSGraphTensorData *computed = results[_targetTensors[i]];
        MPSGraphTensorData *destination = i < resultsArray.count ? resultsArray[i] : computed;
        if (computed && destination && computed != destination)
            CharonMPSGraphWriteInto(_targetTensors[i], computed, destination);
        if (destination)
            [returned addObject:destination];
    }
    // The descriptor's shared events are honoured at both ends of the walk, the same as the graph's own run
    // forms do: the waits are checked before it and the signals written after it.
    if (executionDescriptor != nil) {
        [executionDescriptor charon_mps_applyEventsAtStage:MPSGraphExecutionStageCompleted
                                                        named:@"an executable execution descriptor"];
        // The same two handlers the graph's own descriptor has, called around this walk - see
        // CharonMPSGraphRunForm in MPSGraph14.m, which says why -waitUntilCompleted needs nothing here.
        // The results are the returned ARRAY - the executable's handler is declared over an array of tensor
        // data, where the graph's own is over a dictionary - and the error is nil, because this walk either
        // wrote every result or refused the one it could not copy.
        if (executionDescriptor.scheduledHandler)
            executionDescriptor.scheduledHandler(returned, nil);
        if (executionDescriptor.completionHandler)
            executionDescriptor.completionHandler(returned, nil);
    }
    return returned;
}

// -specializeWithDevice:inputTypes:compilationDescriptor: - an executable of this port is the graph itself,
// because the work is a walk over the operations and there is nothing to compile ahead of time, so there is
// nothing to specialize either. What the call does is keep what it was told, because that is what a caller
// asks it for: the device and the input types it was given are recorded, and a later
// -getOutputTypesWithDevice:... answers from the targets the executable holds rather than from the
// specialization - which is what the header says that call does when no specialization has been done
// (the header says that without a specialization yet, calling this function specializes for the given input shapes).
- (void)specializeWithDevice:(MPSGraphDevice *)device
                  inputTypes:(NSArray<MPSGraphType *> *)inputTypes
       compilationDescriptor:(MPSGraphCompilationDescriptor *)compilationDescriptor
{
    _specializedDevice = device;
    _specializedInputTypes = [inputTypes copy];
    _specialized = YES;
    (void)compilationDescriptor;
}

- (NSArray<MPSGraphShapedType *> *)getOutputTypesWithDevice:(MPSGraphDevice *)device
                                                inputTypes:(NSArray<MPSGraphType *> *)inputTypes
                                     compilationDescriptor:(MPSGraphCompilationDescriptor *)compilationDescriptor
{
    (void)device;
    (void)inputTypes;
    (void)compilationDescriptor;
    NSMutableArray<MPSGraphShapedType *> *types = [NSMutableArray arrayWithCapacity:_targetTensors.count];
    for (MPSGraphTensor *tensor in _targetTensors)
        [types addObject:[[MPSGraphShapedType alloc] initWithShape:tensor.shape dataType:tensor.dataType]];
    return types;
}

// The async and the encode forms of the run, which are the same walk as the synchronous one above and differ
// only in what the release does with the GPU afterwards: this port's walk is over the host's memory on the
// CPU, so there is nothing to schedule and nothing to encode into, and the command queue is read for nothing.
- (NSArray<MPSGraphTensorData *> *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                                                   inputsArray:(NSArray<MPSGraphTensorData *> *)inputsArray
                                                  resultsArray:(NSArray<MPSGraphTensorData *> *)resultsArray
                                           executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)executionDescriptor
{
    return [self runWithMTLCommandQueue:commandQueue
                            inputsArray:inputsArray
                           resultsArray:resultsArray
                    executionDescriptor:executionDescriptor];
}

- (NSArray<MPSGraphTensorData *> *)encodeToCommandBuffer:(MPSCommandBuffer *)commandBuffer
                                             inputsArray:(NSArray<MPSGraphTensorData *> *)inputsArray
                                            resultsArray:(NSArray<MPSGraphTensorData *> *)resultsArray
                                     executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)executionDescriptor
{
    // The walk is the one the queue form does, and the queue is not part of it: the encode form takes MPSGraph's
    // OWN command buffer, which is not a Metal one, so there is no Metal queue in this form to hand over.
    (void)commandBuffer;
    return [self charon_mps_walkInputs:inputsArray results:resultsArray executionDescriptor:executionDescriptor];
}

@end
