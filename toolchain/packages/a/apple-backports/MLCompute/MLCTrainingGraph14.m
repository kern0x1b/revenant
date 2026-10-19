#import "RevenantMLCompute.h"

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
    (void)lossLayer;
    MLCTrainingGraph *graph = [[self alloc] init];
    graph->_graphObjects = [graphObjects copy] ?: @[];
    graph->_optimizer = optimizer;
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
    [self revenant_mlc_take:inputs into:_inputs];
    [self revenant_mlc_take:lossLabels into:_lossLabels];
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

#pragma mark - the compile and the optimizer

- (BOOL)compileWithOptions:(MLCGraphCompilationOptions)options device:(MLCDevice *)device
{
    (void)options;
    (void)device;
    _compiled = YES;
    return NO;
}

- (BOOL)compileOptimizer:(MLCOptimizer *)optimizer
{
    (void)optimizer;
    return NO;
}

- (BOOL)linkWithGraphs:(NSArray<MLCTrainingGraph *> *)graphs
{
    (void)graphs;
    return NO;
}

#pragma mark - the gradient members

- (MLCTensor *)gradientTensorForInput:(MLCTensor *)input
{
    (void)input;
    return nil;
}

- (NSArray<MLCTensor *> *)sourceGradientTensorsForLayer:(MLCLayer *)layer
{
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
    (void)layer;
    return @[];
}

- (NSData *)gradientDataForParameter:(MLCTensor *)parameter layer:(MLCLayer *)layer
{
    (void)parameter;
    (void)layer;
    return nil;
}

- (MLCTensor *)allocateUserGradientForTensor:(MLCTensor *)tensor
{
    (void)tensor;
    return nil;
}

- (BOOL)stopGradientForTensors:(NSArray<MLCTensor *> *)tensors
{
    for (MLCTensor *tensor in tensors) {
        if (tensor && ![_stopped containsObject:tensor])
            [_stopped addObject:tensor];
    }
    return YES;
}

- (BOOL)setTrainingTensorParameters:(NSArray<MLCTensorParameter *> *)parameters
{
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
    if (!tensor) {
        return NO;
    }
    return [tensor bindOptimizerData:data deviceData:deviceData];
}

- (void)synchronizeUpdates
{
}

#pragma mark - the execute family

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
