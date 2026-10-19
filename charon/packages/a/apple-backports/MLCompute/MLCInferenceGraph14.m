// MLCInferenceGraph, the 14.0 surface of the inference graph: the factory, the unavailable initialisers,
// the property, the bindings, the compile and the four execute forms.
//
// A graph here is the graph objects it was made from, the tensors the caller named as its inputs, its loss
// labels, its loss label weights and its outputs, and whether it has been compiled. Every answer this file
// gives is a measurement off this host's own MLCompute, and every one of them is asked case by case of both
// sides by tests/backports/host/mlcompute/inference-cases.m, which compiles this object beside the
// framework's and compares the two runs. What is measured and what it says is in facts/MLCompute/Graph.md;
// the rules that answer most of it are these:
//
//   * **The layers, the sources and the results are the graph objects'.** Measured: an inference graph made
//     of one graph with one ReLU node over a 2x3 tensor answers one layer, that layer's one source tensor and
//     its one result tensor, which are the very tensors the node made - the class inherits those three
//     members from MLCGraph and answers them over what it was given.
//   * **The device is nil until a compile, and is the device the compile was given.** Measured.
//   * **A compile needs a device the first time and not after that.** Measured: `compileWithOptions:nil` on
//     a graph nothing has compiled answers NO, and the same call on a graph that has compiled answers YES.
//   * **deviceMemorySize is 0 until THIS graph's compile has been asked, whatever that compile answered, and
//     is then the byte width of the tensors its own nodes produce.** Measured over the inference graph and
//     over a training graph in the same process: a training graph read before its own compile answers 0
//     after the inference graph beside it had compiled.
//   * **Every add and every link answers YES, whatever it is given.** Measured: a name the graph knows, one
//     it does not, an empty dictionary and nil, and for a link an empty list, the graph itself and another
//     graph. Linking does not add the other graph's layers to this one - measured, the layer count is one
//     before and after a link of a graph with a node of its own.
//   * **An execute computes the graph.** Measured: an execute over a ReLU node over -1, 2, -3 and 4 writes
//     0, 2, 0 and 4 into the buffer the caller named for the output and calls the completion handler with no
//     error. The two forms that carry loss label data answer NO on the host unless the loss label tensors
//     were declared with -addInputs:lossLabels:lossLabelWeights: first, so the cases declare them; that is
//     what the header's own comment asks a caller to do.

#import "CharonMLCompute.h"
#import "CharonMLCGraph.h"

// The error an execute this port refuses answers its completion handler with. It is the port's own and is
// named Charon*, so the gate weighs none of it against a release: the domain is MLCompute's own, and the
// message says which of the four refusals it was.
static NSError *CharonMLCGraphError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"MLCompute" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

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
@implementation MLCInferenceGraph {
    NSArray<MLCGraph *> *_graphObjects;
    NSMutableArray<MLCGraph *> *_linked;
    NSMutableDictionary<NSString *, MLCTensor *> *_inputs;
    NSMutableDictionary<NSString *, MLCTensor *> *_lossLabels;
    NSMutableDictionary<NSString *, MLCTensor *> *_lossLabelWeights;
    NSMutableDictionary<NSString *, MLCTensor *> *_outputs;
    MLCDevice *_compiledDevice;
    BOOL _compiled;
}

+ (instancetype)graphWithGraphObjects:(NSArray<MLCGraph *> *)graphObjects
{
    // A graph of the graph objects it is given, and nothing else. A nil array and an empty one are both a
    // graph with no layers (measured), and neither of them can be compiled - the host raises inside the
    // compile, which facts/MLCompute/Graph.md records and no case asks.
    MLCInferenceGraph *graph = [[self alloc] init];
    graph->_graphObjects = [graphObjects copy] ?: @[];
    return graph;
}

// The header marks both unavailable and the framework carries both: what they answer is a graph with no
// layer, no node and no device (measured), which is what -init gives.
+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _graphObjects = @[];
        _linked = [NSMutableArray array];
        _inputs = [NSMutableDictionary dictionary];
        _lossLabels = [NSMutableDictionary dictionary];
        _lossLabelWeights = [NSMutableDictionary dictionary];
        _outputs = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - the members MLCGraph declares, answered over the graph objects

- (NSArray<MLCLayer *> *)layers
{
    NSMutableArray<MLCLayer *> *layers = [NSMutableArray array];
    for (MLCGraph *graph in [self charon_mlc_everyGraph])
        for (MLCLayer *layer in graph.layers)
            if (![layers containsObject:layer])
                [layers addObject:layer];
    return layers;
}

- (NSArray<MLCTensor *> *)sourceTensorsForLayer:(MLCLayer *)layer
{
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray array];
    for (MLCGraph *graph in [self charon_mlc_everyGraph])
        for (MLCTensor *tensor in [graph sourceTensorsForLayer:layer])
            if (![tensors containsObject:tensor])
                [tensors addObject:tensor];
    return tensors;
}

- (NSArray<MLCTensor *> *)resultTensorsForLayer:(MLCLayer *)layer
{
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray array];
    for (MLCGraph *graph in [self charon_mlc_everyGraph])
        for (MLCTensor *tensor in [graph resultTensorsForLayer:layer])
            if (![tensors containsObject:tensor])
                [tensors addObject:tensor];
    return tensors;
}

// Every graph this one is over: the graph objects it was made from, and nothing else. A linked graph shares
// its tensors with this one rather than joining it - measured, and the three members above answer exactly what
// they answered before the link, over a link of a graph with a node and a layer of its own - so the port keeps
// the linked graphs as what they are, a record of what this graph was linked to, and asks its own graph
// objects for the layers, the sources and the results.
- (NSArray<MLCGraph *> *)charon_mlc_everyGraph
{
    return _graphObjects;
}

#pragma mark - the property

- (NSUInteger)deviceMemorySize
{
    // Zero until this graph's own compile has been asked, whatever that compile answered, and from then the
    // byte width of the tensors this graph's own nodes produce - measured, and the caller's own bindings do
    // not move it. The sum over several nodes is the one rule of that measurement this port chooses and
    // names: a graph of several nodes raises inside the host before it can be asked, so the multi-node value
    // is unmeasured (facts/MLCompute/Graph.md).
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

- (MLCDevice *)device
{
    // The device the compile was given, and nil before one (measured).
    return _compiledDevice;
}

#pragma mark - the bindings

- (BOOL)addInputs:(NSDictionary<NSString *, MLCTensor *> *)inputs
{
    // YES for a name the graph knows, for one it does not, for an empty dictionary and for nil (measured):
    // what an input is named decides where its data comes from at the execute, not whether the graph can
    // be given one.
    [self charon_mlc_take:inputs into:_inputs];
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
    // As above (measured).
    [self charon_mlc_take:outputs into:_outputs];
    return YES;
}

- (BOOL)linkWithGraphs:(NSArray<MLCInferenceGraph *> *)graphs
{
    // YES for an empty list, for this graph itself and for another graph (measured), and the layers of this
    // graph do not grow: a linked graph shares the tensors its layers and this graph's layers have in common.
    for (MLCInferenceGraph *graph in graphs) {
        if (graph && graph != self && ![_linked containsObject:graph])
            [_linked addObject:graph];
    }
    (void)_linked;
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

#pragma mark - the compile

- (BOOL)compileWithOptions:(MLCGraphCompilationOptions)options device:(MLCDevice *)device
{
    // A device is what a first compile needs and a graph that has one does not (measured), and every compile
    // is what makes the device memory size an answer rather than a zero (measured, whatever it answered).
    (void)options;
    if (!_compiled && !device) {
        return NO;
    }
    _compiled = YES;
    _compiledDevice = _compiledDevice ?: device;
    return YES;
}

#pragma mark - the four execute forms

- (BOOL)executeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
                    batchSize:(NSUInteger)batchSize
                      options:(MLCExecutionOptions)options
            completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    return [self charon_mlc_executeWithInputsData:inputsData
                                       outputsData:nil
                                    lossLabelsData:nil
                             lossLabelWeightsData:nil
                                         batchSize:batchSize
                                           options:options
                                 completionHandler:completionHandler];
}

- (BOOL)executeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
                  outputsData:(NSDictionary<NSString *, MLCTensorData *> *)outputsData
                    batchSize:(NSUInteger)batchSize
                      options:(MLCExecutionOptions)options
            completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    return [self charon_mlc_executeWithInputsData:inputsData
                                       outputsData:outputsData
                                    lossLabelsData:nil
                             lossLabelWeightsData:nil
                                         batchSize:batchSize
                                           options:options
                                 completionHandler:completionHandler];
}

- (BOOL)executeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
               lossLabelsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelsData
         lossLabelWeightsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelWeightsData
                    batchSize:(NSUInteger)batchSize
                      options:(MLCExecutionOptions)options
            completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    return [self charon_mlc_executeWithInputsData:inputsData
                                       outputsData:nil
                                    lossLabelsData:lossLabelsData
                             lossLabelWeightsData:lossLabelWeightsData
                                         batchSize:batchSize
                                           options:options
                                 completionHandler:completionHandler];
}

- (BOOL)executeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
               lossLabelsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelsData
         lossLabelWeightsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelWeightsData
                  outputsData:(NSDictionary<NSString *, MLCTensorData *> *)outputsData
                    batchSize:(NSUInteger)batchSize
                      options:(MLCExecutionOptions)options
            completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    return [self charon_mlc_executeWithInputsData:inputsData
                                       outputsData:outputsData
                                    lossLabelsData:lossLabelsData
                             lossLabelWeightsData:lossLabelWeightsData
                                         batchSize:batchSize
                                           options:options
                                 completionHandler:completionHandler];
}

// The forward pass, which is the one thing here that computes: the data of the caller's inputs is written
// into the tensors the graph was given under those names, every layer of every graph is computed into its
// result tensors through the engine (CharonMLCElementwise, which is the port's own arithmetic and answers
// for one node - the activation, the one layer with no parameters and no shape of its own), and the results
// are written back into the data the caller named for the outputs.
//
// What a form carrying loss label data needs is that the loss label tensors were declared on the graph, and
// that is measured: over a graph that has declared them every form answers YES, and over one that has not the
// two of them answer NO (the probe named in the facts). A graph this port cannot compute is refused with NO
// and the handler is called with the error, which is the one answer the port has for it.
//
// The handler is called with the tensor of the last node computed, which is the tensor whose bytes the
// caller just read, and with the time the pass took. The framework's own first argument is not measured -
// tests/backports/host/mlcompute-engine/system.m, which reads the numbers out of an execute, asks the error
// and nothing else - so what the port passes is stated here rather than claimed to be the framework's.
- (BOOL)charon_mlc_executeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
                              outputsData:(NSDictionary<NSString *, MLCTensorData *> *)outputsData
                           lossLabelsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelsData
                    lossLabelWeightsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelWeightsData
                                batchSize:(NSUInteger)batchSize
                                  options:(MLCExecutionOptions)options
                        completionHandler:(MLCGraphCompletionHandler)completionHandler
{
    (void)batchSize;
    (void)options;
    NSError *error = nil;
    MLCTensor *computed = nil;
    NSDate *started = [NSDate date];
    BOOL done = [self charon_mlc_computeWithInputsData:inputsData
                                          outputsData:outputsData
                                       lossLabelsData:lossLabelsData
                                lossLabelWeightsData:lossLabelWeightsData
                                              result:&computed
                                               error:&error];
    if (completionHandler) {
        completionHandler(done ? computed : nil, error, -[started timeIntervalSinceNow]);
    }
    return done;
}

// The compute itself, and what it answers NO for: a graph with no layer to compute, a layer the engine does
// not carry, a node with no source or no result to compute from or into, and an input or an output the
// caller named data for that the graph does not hold. Everything else is computed in order.
- (BOOL)charon_mlc_computeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
                             outputsData:(NSDictionary<NSString *, MLCTensorData *> *)outputsData
                          lossLabelsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelsData
                   lossLabelWeightsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelWeightsData
                                 result:(MLCTensor **)result
                                  error:(NSError **)error
{
    // The data of the inputs and of the loss labels, into the tensors the graph holds under those names.
    if (![self charon_mlc_bind:inputsData tensors:_inputs] || ![self charon_mlc_bind:lossLabelsData tensors:_lossLabels] ||
        ![self charon_mlc_bind:lossLabelWeightsData tensors:_lossLabelWeights]) {
        if (error) {
            *error = CharonMLCGraphError(1, @"an input of the execute is not one the graph holds");
        }
        return NO;
    }
    NSArray<MLCLayer *> *layers = self.layers;
    if (layers.count == 0) {
        if (error) {
            *error = CharonMLCGraphError(2, @"the graph has no layer to compute");
        }
        return NO;
    }
    MLCTensor *computed = nil;
    for (MLCLayer *layer in layers) {
        NSArray<MLCTensor *> *sources = [self sourceTensorsForLayer:layer];
        NSArray<MLCTensor *> *results = [self resultTensorsForLayer:layer];
        NSUInteger count = MIN(sources.count, results.count);
        for (NSUInteger index = 0; index < count; index++) {
            MLCTensor *source = sources[index];
            computed = results[index];
            // The result needs storage of its own width before the engine writes into it: the tensors a
            // node made belong to the graph and nothing has bound data to them yet.
            if (![self charon_mlc_giveStorageTo:computed]) {
                if (error) {
                    *error = CharonMLCGraphError(3, @"a result of the graph has no storage of its own width");
                }
                return NO;
            }
            if (!CharonMLCElementwise(layer, source, computed)) {
                if (error) {
                    *error = CharonMLCGraphError(4, @"this port's engine carries no such layer");
                }
                return NO;
            }
        }
    }
    // The results back into the data the caller named for the outputs.
    for (NSString *name in outputsData) {
        MLCTensor *tensor = _outputs[name];
        MLCTensorData *data = outputsData[name];
        if (!tensor || !data || !data.bytes ||
            ![tensor copyDataFromDeviceMemoryToBytes:data.bytes length:data.length synchronizeWithDevice:YES]) {
            if (error) {
                *error = CharonMLCGraphError(5, @"an output of the execute is not one the graph holds");
            }
            return NO;
        }
    }
    if (result) {
        *result = computed;
    }
    return YES;
}

// The storage of a tensor's own width, over a buffer of zeros: the tensors a node made are the graph's, and
// the only public way a tensor is given memory is -bindAndWriteData:toDevice:, which copies the bytes in.
- (BOOL)charon_mlc_giveStorageTo:(MLCTensor *)tensor
{
    NSUInteger width = tensor.descriptor.tensorAllocationSizeInBytes;
    if (width == 0) {
        return tensor.data ? YES : NO;
    }
    void *zeros = calloc(1, width);
    if (!zeros) {
        return NO;
    }
    MLCTensorData *blank = [MLCTensorData dataWithBytesNoCopy:zeros length:width];
    BOOL bound = [tensor bindAndWriteData:blank toDevice:self.device];
    // The data object holds the pointer, not the bytes; the bind above is what copied them into the tensor.
    free(zeros);
    return bound;
}

// The caller's data written into the tensors the graph holds under the same names. What decides it is that
// every name the caller gave is one the graph holds and carries data - not that the graph's other inputs
// were named at all (measured for -bindAndWriteData:forInputs: on MLCGraph, which is the same question).
- (BOOL)charon_mlc_bind:(NSDictionary<NSString *, MLCTensorData *> *)data
               tensors:(NSDictionary<NSString *, MLCTensor *> *)tensors
{
    for (NSString *name in data) {
        MLCTensor *tensor = tensors[name];
        MLCTensorData *values = data[name];
        if (!tensor || !values || ![tensor bindAndWriteData:values toDevice:self.device])
            return NO;
    }
    return YES;
}

@end
#pragma clang diagnostic pop
