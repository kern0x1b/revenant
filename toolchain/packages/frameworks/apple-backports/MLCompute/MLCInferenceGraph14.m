#import "RevenantMLCompute.h"
#import "RevenantMLCGraph.h"

static NSError *RevenantMLCGraphError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"MLCompute" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

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
    MLCInferenceGraph *graph = [[self alloc] init];
    graph->_graphObjects = [graphObjects copy] ?: @[];
    return graph;
}

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
    for (MLCGraph *graph in [self revenant_mlc_everyGraph])
        for (MLCLayer *layer in graph.layers)
            if (![layers containsObject:layer])
                [layers addObject:layer];
    return layers;
}

- (NSArray<MLCTensor *> *)sourceTensorsForLayer:(MLCLayer *)layer
{
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray array];
    for (MLCGraph *graph in [self revenant_mlc_everyGraph])
        for (MLCTensor *tensor in [graph sourceTensorsForLayer:layer])
            if (![tensors containsObject:tensor])
                [tensors addObject:tensor];
    return tensors;
}

- (NSArray<MLCTensor *> *)resultTensorsForLayer:(MLCLayer *)layer
{
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray array];
    for (MLCGraph *graph in [self revenant_mlc_everyGraph])
        for (MLCTensor *tensor in [graph resultTensorsForLayer:layer])
            if (![tensors containsObject:tensor])
                [tensors addObject:tensor];
    return tensors;
}

- (NSArray<MLCGraph *> *)revenant_mlc_everyGraph
{
    return _graphObjects;
}

#pragma mark - the property

- (NSUInteger)deviceMemorySize
{
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
    return _compiledDevice;
}

#pragma mark - the bindings

- (BOOL)addInputs:(NSDictionary<NSString *, MLCTensor *> *)inputs
{
    [self revenant_mlc_take:inputs into:_inputs];
    return YES;
}

- (BOOL)addInputs:(NSDictionary<NSString *, MLCTensor *> *)inputs
       lossLabels:(NSDictionary<NSString *, MLCTensor *> *)lossLabels
 lossLabelWeights:(NSDictionary<NSString *, MLCTensor *> *)lossLabelWeights
{
    [self revenant_mlc_take:inputs into:_inputs];
    [self revenant_mlc_take:lossLabels into:_lossLabels];
    [self revenant_mlc_take:lossLabelWeights into:_lossLabelWeights];
    return YES;
}

- (BOOL)addOutputs:(NSDictionary<NSString *, MLCTensor *> *)outputs
{
    [self revenant_mlc_take:outputs into:_outputs];
    return YES;
}

- (BOOL)linkWithGraphs:(NSArray<MLCInferenceGraph *> *)graphs
{
    for (MLCInferenceGraph *graph in graphs) {
        if (graph && graph != self && ![_linked containsObject:graph])
            [_linked addObject:graph];
    }
    (void)_linked;
    return YES;
}

- (void)revenant_mlc_take:(NSDictionary<NSString *, MLCTensor *> *)tensors
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
    return [self revenant_mlc_executeWithInputsData:inputsData
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
    return [self revenant_mlc_executeWithInputsData:inputsData
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
    return [self revenant_mlc_executeWithInputsData:inputsData
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
    return [self revenant_mlc_executeWithInputsData:inputsData
                                       outputsData:outputsData
                                    lossLabelsData:lossLabelsData
                             lossLabelWeightsData:lossLabelWeightsData
                                         batchSize:batchSize
                                           options:options
                                 completionHandler:completionHandler];
}

- (BOOL)revenant_mlc_executeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
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
    BOOL done = [self revenant_mlc_computeWithInputsData:inputsData
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

- (BOOL)revenant_mlc_computeWithInputsData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
                             outputsData:(NSDictionary<NSString *, MLCTensorData *> *)outputsData
                          lossLabelsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelsData
                   lossLabelWeightsData:(NSDictionary<NSString *, MLCTensorData *> *)lossLabelWeightsData
                                 result:(MLCTensor **)result
                                  error:(NSError **)error
{
    if (![self revenant_mlc_bind:inputsData tensors:_inputs] || ![self revenant_mlc_bind:lossLabelsData tensors:_lossLabels] ||
        ![self revenant_mlc_bind:lossLabelWeightsData tensors:_lossLabelWeights]) {
        if (error) {
            *error = RevenantMLCGraphError(1, @"an input of the execute is not one the graph holds");
        }
        return NO;
    }
    NSArray<MLCLayer *> *layers = self.layers;
    if (layers.count == 0) {
        if (error) {
            *error = RevenantMLCGraphError(2, @"the graph has no layer to compute");
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
            if (![self revenant_mlc_giveStorageTo:computed]) {
                if (error) {
                    *error = RevenantMLCGraphError(3, @"a result of the graph has no storage of its own width");
                }
                return NO;
            }
            if (!RevenantMLCElementwise(layer, source, computed)) {
                if (error) {
                    *error = RevenantMLCGraphError(4, @"this port's engine carries no such layer");
                }
                return NO;
            }
        }
    }
    for (NSString *name in outputsData) {
        MLCTensor *tensor = _outputs[name];
        MLCTensorData *data = outputsData[name];
        if (!tensor || !data || !data.bytes ||
            ![tensor copyDataFromDeviceMemoryToBytes:data.bytes length:data.length synchronizeWithDevice:YES]) {
            if (error) {
                *error = RevenantMLCGraphError(5, @"an output of the execute is not one the graph holds");
            }
            return NO;
        }
    }
    if (result) {
        *result = computed;
    }
    return YES;
}

- (BOOL)revenant_mlc_giveStorageTo:(MLCTensor *)tensor
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
    free(zeros);
    return bound;
}

- (BOOL)revenant_mlc_bind:(NSDictionary<NSString *, MLCTensorData *> *)data
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
