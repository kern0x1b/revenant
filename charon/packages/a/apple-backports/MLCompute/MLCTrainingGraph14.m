// MLCTrainingGraph, the 14.0 surface of the training graph: the factory, the unavailable initialisers, the
// two properties, the bindings, the compile, the optimizer, the gradient members and the execute family.
//
// A training graph here is the graph objects it was made from, the loss layer and the optimizer it was given,
// the tensors the caller named as its inputs, its loss labels, its loss label weights and its outputs, the
// tensors whose gradient it was told to stop and the ones it was given optimizer data for. Every answer this
// file gives is a measurement off this host's own MLCompute, asked case by case of both sides by
// tests/backports/host/mlcompute/inference-cases.m, which compiles this object beside the framework's and
// compares the two runs. What is measured and what it says is in facts/MLCompute/Graph.md.
//
// **This port's engine carries a forward pass and no gradient and no optimizer update**, so this graph
// refuses every member that needs one of those, and says so: -compileWithOptions:device:, -compileOptimizer:,
// -linkWithGraphs: and the seven execute forms all answer NO. Over the binding the cases ask - a training
// graph over a graph object an inference graph has already compiled - that is what the host answers too, and
// it is measured there for all nine (facts/MLCompute/Graph.md, "The training graph over a compiled graph").
// Over a graph object nothing has compiled the host's answers are different, and they are named there as
// well: its compile is YES, its device memory size is twice its nodes' bytes, its gradient pass and its
// optimizer update are YES, and its forward pass RAISES an NSRangeException inside the host. There is
// therefore no binding in which this port could be held to those members by a case that does not stop the
// run, and the difference is stated rather than hidden.
//
// What the graph can answer, it answers the way the host does, and the rules are:
//
//   * **The layers, the sources and the results are the graph objects'.** Measured, as for the inference
//     graph: one layer, that layer's one source tensor and its one result tensor.
//   * **The gradient members answer before any pass has run**: -gradientTensorForInput: is nil for an input,
//     for the graph's own result and for a tensor the graph never saw; -sourceGradientTensorsForLayer:
//     answers one fresh tensor of the source's shape and float32 type for a layer the graph has and none for
//     a layer it has not; -resultGradientTensorsForLayer: answers none; -gradientDataForParameter:layer:
//     and -allocateUserGradientForTensor: answer nil.
//   * **-stopGradientForTensors:, -setTrainingTensorParameters: and -bindOptimizerData:deviceData:withTensor:
//     answer YES**, for a tensor the graph knows and for one it does not (measured).
//   * **deviceMemorySize is 0 until this graph's own compile has been asked, whatever that compile answered,
//     and is then the byte width of the tensors its own nodes produce** (measured, and the training graph's
//     own compile succeeding is what doubles it - which never happens here, because it answers NO).
//   * **The optimizer is the one the graph was made with**, and nil when it was made without one (measured).

#import "CharonMLCompute.h"

// The one member of this class this object does not implement, and why:
// -compileWithOptions:device:inputTensors:inputTensorsData: arrived in iOS 14.5 and is a category in
// MLCGraphConstants15.m, because an object carries the API of one release and backports.lua's misplaced()
// raises on a file that defines two. Scoped to this @implementation and to that one name, which is the
// arrangement facts/MetalPerformanceShaders/Graph.md records for the seventeen members of MPSNNGraph this
// port does not carry, and narrower than the file-wide form the MPS objects used to have. The two ways to
// have no suppression at all are both refused there and both are refused here: @dynamic does not silence
// -Wincomplete-implementation for a method, and carrying the form here would put a 14.5 name in a 14.0 object.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation MLCTrainingGraph {
    NSArray<MLCGraph *> *_graphObjects;
    NSMutableDictionary<NSString *, MLCTensor *> *_inputs;
    NSMutableDictionary<NSString *, MLCTensor *> *_lossLabels;
    NSMutableDictionary<NSString *, MLCTensor *> *_lossLabelWeights;
    NSMutableDictionary<NSString *, MLCTensor *> *_outputs;
    NSMutableArray<MLCTensor *> *_stopped;
    NSMutableArray<MLCTensorParameter *> *_parameters;
    MLCOptimizer *_optimizer;
    BOOL _compiled;
}

+ (instancetype)graphWithGraphObjects:(NSArray<MLCGraph *> *)graphObjects
                            lossLayer:(MLCLayer *)lossLayer
                            optimizer:(MLCOptimizer *)optimizer
{
    // The graph objects, the loss layer and the optimizer it was given. A nil array and an empty one are both
    // a graph with no layers (measured), and a nil loss layer and a nil optimizer are both kept as they were
    // given: the optimizer property answers nil for a graph made without one (measured).
    (void)lossLayer;
    MLCTrainingGraph *graph = [[self alloc] init];
    graph->_graphObjects = [graphObjects copy] ?: @[];
    graph->_optimizer = optimizer;
    return graph;
}

// The header marks both unavailable and the framework carries both: what they answer is a graph with no
// layer, no node, no optimizer and no device (measured), which is what -init gives.
+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _graphObjects = @[];
        _inputs = [NSMutableDictionary dictionary];
        _lossLabels = [NSMutableDictionary dictionary];
        _lossLabelWeights = [NSMutableDictionary dictionary];
        _outputs = [NSMutableDictionary dictionary];
        _stopped = [NSMutableArray array];
        _parameters = [NSMutableArray array];
    }
    return self;
}

#pragma mark - the members MLCGraph declares, answered over the graph objects

- (NSArray<MLCLayer *> *)layers
{
    NSMutableArray<MLCLayer *> *layers = [NSMutableArray array];
    for (MLCGraph *graph in _graphObjects)
        for (MLCLayer *layer in graph.layers)
            if (![layers containsObject:layer])
                [layers addObject:layer];
    return layers;
}

- (NSArray<MLCTensor *> *)sourceTensorsForLayer:(MLCLayer *)layer
{
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray array];
    for (MLCGraph *graph in _graphObjects)
        for (MLCTensor *tensor in [graph sourceTensorsForLayer:layer])
            if (![tensors containsObject:tensor])
                [tensors addObject:tensor];
    return tensors;
}

- (NSArray<MLCTensor *> *)resultTensorsForLayer:(MLCLayer *)layer
{
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray array];
    for (MLCGraph *graph in _graphObjects)
        for (MLCTensor *tensor in [graph resultTensorsForLayer:layer])
            if (![tensors containsObject:tensor])
                [tensors addObject:tensor];
    return tensors;
}

#pragma mark - the two properties

- (MLCOptimizer *)optimizer
{
    return _optimizer;
}

- (NSUInteger)deviceMemorySize
{
    // Zero until this graph's own compile has been asked, whatever that compile answered, and from then the
    // byte width of the tensors this graph's own nodes produce (measured). A training graph whose own compile
    // succeeds answers twice that - the forward pass and the gradient pass - and this port's compile never
    // succeeds, so the number this graph answers is the forward pass alone, which is what the host answers
    // over the binding the cases ask.
    if (!_compiled) {
        return 0;
    }
    NSUInteger bytes = 0;
    for (MLCLayer *layer in self.layers) {
        for (MLCTensor *tensor in [self resultTensorsForLayer:layer]) {
            bytes += tensor.descriptor.tensorAllocationSizeInBytes;
        }
    }
    return bytes;
}

#pragma mark - the bindings

- (BOOL)addInputs:(NSDictionary<NSString *, MLCTensor *> *)inputs
       lossLabels:(NSDictionary<NSString *, MLCTensor *> *)lossLabels
{
    [self charon_mlc_take:inputs into:_inputs];
    [self charon_mlc_take:lossLabels into:_lossLabels];
    return YES;
}

- (BOOL)addInputs:(NSDictionary<NSString *, MLCTensor *> *)inputs
       lossLabels:(NSDictionary<NSString *, MLCTensor *> *)lossLabels
 lossLabelWeights:(NSDictionary<NSString *, MLCTensor *> *)lossLabelWeights
{
    [self charon_mlc_take:inputs into:_inputs];
    [self charon_mlc_take:lossLabels into:_lossLabels];
    [self charon_mlc_take:lossLabelWeights into:_lossLabelWeights];
    return YES;
}

- (BOOL)addOutputs:(NSDictionary<NSString *, MLCTensor *> *)outputs
{
    // YES for a name the graph knows, for one it does not and for nil (measured).
    [self charon_mlc_take:outputs into:_outputs];
    return YES;
}

// The dictionary a binding named, merged over what the graph already holds: a later binding of a name
// replaces the tensor under it, which is what a second -addInputs: of the same name does.
- (void)charon_mlc_take:(NSDictionary<NSString *, MLCTensor *> *)tensors
                   into:(NSMutableDictionary<NSString *, MLCTensor *> *)bindings
{
    if (!tensors) {
        return;
    }
    for (NSString *name in tensors) {
        MLCTensor *tensor = tensors[name];
        if (name && tensor)
            bindings[name] = tensor;
    }
}

#pragma mark - the compile and the optimizer

- (BOOL)compileWithOptions:(MLCGraphCompilationOptions)options device:(MLCDevice *)device
{
    // NO, and this port says why: there is no gradient pass and no optimizer update behind this graph, so
    // there is nothing to compile - see the head of this file and the binding named in it. The compile is
    // still what makes the device memory size an answer rather than a zero (measured, whatever it answered).
    (void)options;
    (void)device;
    _compiled = YES;
    return NO;
}

- (BOOL)compileOptimizer:(MLCOptimizer *)optimizer
{
    // NO for the same reason: an optimizer update is one of the two passes this port does not have.
    (void)optimizer;
    return NO;
}

- (BOOL)linkWithGraphs:(NSArray<MLCTrainingGraph *> *)graphs
{
    // NO, measured for an empty list, for this graph itself and for another graph of its own kind: linking
    // training graphs needs a compiled training graph to link into, and there is none here.
    (void)graphs;
    return NO;
}

#pragma mark - the gradient members

- (MLCTensor *)gradientTensorForInput:(MLCTensor *)input
{
    // Nil, measured for an input the graph holds, for the graph's own result and for a tensor it never saw:
    // the gradient of a tensor is allocated by the gradient pass, and no pass has run.
    (void)input;
    return nil;
}

- (NSArray<MLCTensor *> *)sourceGradientTensorsForLayer:(MLCLayer *)layer
{
    // One fresh tensor of each source tensor's shape for a layer this graph has, and none for a layer it has
    // not (measured): the gradient of a source has the source's shape, and it is a tensor of its own rather
    // than the source itself (measured, by identity).
    NSMutableArray<MLCTensor *> *gradients = [NSMutableArray array];
    for (MLCTensor *source in [self sourceTensorsForLayer:layer]) {
        MLCTensorDescriptor *descriptor = [MLCTensorDescriptor descriptorWithShape:source.descriptor.shape
                                                                          dataType:source.descriptor.dataType];
        MLCTensor *gradient = [MLCTensor tensorWithDescriptor:descriptor];
        if (gradient)
            [gradients addObject:gradient];
    }
    return gradients;
}

- (NSArray<MLCTensor *> *)resultGradientTensorsForLayer:(MLCLayer *)layer
{
    // None, measured: the result of a layer is written by the forward pass, not by the gradient pass.
    (void)layer;
    return @[];
}

- (NSData *)gradientDataForParameter:(MLCTensor *)parameter layer:(MLCLayer *)layer
{
    // Nil, measured: the gradient data of a parameter is written by the gradient pass, and the header says
    // as much - it answers nil unless the graph is executed with separate forward and gradient passes.
    (void)parameter;
    (void)layer;
    return nil;
}

- (MLCTensor *)allocateUserGradientForTensor:(MLCTensor *)tensor
{
    // Nil, measured for a tensor the graph produced and for one it never saw: a user gradient is allocated by
    // the gradient pass, which is one of the two this port does not have.
    (void)tensor;
    return nil;
}

- (BOOL)stopGradientForTensors:(NSArray<MLCTensor *> *)tensors
{
    // YES, measured for a tensor the graph knows and for one it does not: what decides it is that the graph
    // was told, not that every tensor resolved.
    for (MLCTensor *tensor in tensors) {
        if (tensor && ![_stopped containsObject:tensor])
            [_stopped addObject:tensor];
    }
    return YES;
}

- (BOOL)setTrainingTensorParameters:(NSArray<MLCTensorParameter *> *)parameters
{
    // YES, measured over an empty list.
    for (MLCTensorParameter *parameter in parameters) {
        if (parameter && ![_parameters containsObject:parameter])
            [_parameters addObject:parameter];
    }
    return YES;
}

- (BOOL)bindOptimizerData:(NSArray<MLCTensorData *> *)data
               deviceData:(NSArray<MLCTensorOptimizerDeviceData *> *)deviceData
               withTensor:(MLCTensor *)tensor
{
    // YES, measured for a tensor the graph knows and for one it does not, and the data is bound to the
    // tensor it was given whether or not the graph holds it.
    if (!tensor) {
        return NO;
    }
    return [tensor bindOptimizerData:data deviceData:deviceData];
}

- (void)synchronizeUpdates
{
    // Nothing to bring back: the CPU device computes into the very memory a program reads, which is what
    // -[MLCTensor synchronizeData] answers and what facts/MLCompute/Tensors.md records. A case asks that the
    // call runs and returns, which is all a void member can be asked.
}

#pragma mark - the execute family

// Every execute form answers NO, for the reason the compile does: the forward pass, the gradient pass and the
// optimizer update are the engine's work and this port's engine carries the forward pass of an activation
// only. A refused execute queues nothing, so the completion handler is not called; what the framework's
// handler answers for a refused execute is not measured, and the cases pass none.
- (BOOL)executeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
               lossLabelsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelsData
         lossLabelWeightsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelWeightsData
                    batchSize:(NSUInteger)batchSize
                      options:(MLCExecutionOptions)options
            completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    (void)inputsData;
    (void)lossLabelsData;
    (void)lossLabelWeightsData;
    (void)batchSize;
    (void)options;
    (void)completionHandler;
    return NO;
}

- (BOOL)executeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
               lossLabelsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelsData
         lossLabelWeightsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelWeightsData
                  outputsData:(NSDictionary<NSString *, MLCTensorData *> *)outputsData
                    batchSize:(NSUInteger)batchSize
                      options:(MLCExecutionOptions)options
            completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    (void)outputsData;
    return [self executeWithInputsData:inputsData
                        lossLabelsData:lossLabelsData
                  lossLabelWeightsData:lossLabelWeightsData
                             batchSize:batchSize
                               options:options
                     completionHandler:completionHandler];
}

- (BOOL)executeForwardWithBatchSize:(NSUInteger)batchSize
                            options:(MLCExecutionOptions)options
                  completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    (void)batchSize;
    (void)options;
    (void)completionHandler;
    return NO;
}

- (BOOL)executeForwardWithBatchSize:(NSUInteger)batchSize
                            options:(MLCExecutionOptions)options
                        outputsData:(NSDictionary<NSString *, MLCTensorData *> *)outputsData
                  completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    (void)outputsData;
    return [self executeForwardWithBatchSize:batchSize options:options completionHandler:completionHandler];
}

- (BOOL)executeGradientWithBatchSize:(NSUInteger)batchSize
                             options:(MLCExecutionOptions)options
                   completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    (void)batchSize;
    (void)options;
    (void)completionHandler;
    return NO;
}

- (BOOL)executeGradientWithBatchSize:(NSUInteger)batchSize
                             options:(MLCExecutionOptions)options
                         outputsData:(NSDictionary<NSString *, MLCTensorData *> *)outputsData
                   completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    (void)outputsData;
    return [self executeGradientWithBatchSize:batchSize options:options completionHandler:completionHandler];
}

- (BOOL)executeOptimizerUpdateWithOptions:(MLCExecutionOptions)options
                        completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    (void)options;
    (void)completionHandler;
    return NO;
}

@end
#pragma clang diagnostic pop
