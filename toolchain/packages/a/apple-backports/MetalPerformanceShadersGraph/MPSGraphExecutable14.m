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

- (NSArray<MPSGraphTensorData *> *)charon_mps_walkInputs:(NSArray<MPSGraphTensorData *> *)inputsArray
                                                  results:(NSArray<MPSGraphTensorData *> *)resultsArray
                                       executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)executionDescriptor
{
    NSMutableDictionary *feeds = [_feeds mutableCopy];
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
    if (executionDescriptor != nil) {
        [executionDescriptor charon_mps_applyEventsAtStage:MPSGraphExecutionStageCompleted
                                                        named:@"an executable execution descriptor"];
        if (executionDescriptor.scheduledHandler)
            executionDescriptor.scheduledHandler(returned, nil);
        if (executionDescriptor.completionHandler)
            executionDescriptor.completionHandler(returned, nil);
    }
    return returned;
}

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
    (void)commandBuffer;
    return [self charon_mps_walkInputs:inputsArray results:resultsArray executionDescriptor:executionDescriptor];
}

@end
