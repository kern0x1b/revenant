#import "RevenantMPSGraph.h"

@implementation MPSGraphOperation {
    MPSGraph *_graph;
    NSString *_name;
    NSArray<MPSGraphTensor *> *_inputTensors;
    NSArray<MPSGraphTensor *> *_outputTensors;
    NSArray<MPSGraphOperation *> *_controlDependencies;
    RevenantMPSGraphOperationKind _kind;
    NSDictionary *_parameters;
}

- (instancetype)initWithGraph:(MPSGraph *)graph
                         kind:(RevenantMPSGraphOperationKind)kind
                         name:(NSString *)name
                        inputs:(NSArray<MPSGraphTensor *> *)inputs
                       outputs:(NSArray<MPSGraphTensor *> *)outputs
{
    if ((self = [super init])) {
        _graph = graph;
        _kind = kind;
        _name = [name copy] ?: @"";
        _inputTensors = [inputs copy];
        _outputTensors = [outputs copy];
        _controlDependencies = @[];
    }
    return self;
}

- (instancetype)init
{
    NSLog(@"MPSGraphOperation: -init makes an operation with no kind and no operands; make one through MPSGraph's operation methods");
    return nil;
}

- (NSArray<MPSGraphTensor *> *)inputTensors
{
    return _inputTensors;
}

- (NSArray<MPSGraphTensor *> *)outputTensors
{
    return _outputTensors;
}

- (NSArray<MPSGraphOperation *> *)controlDependencies
{
    return _controlDependencies;
}

- (MPSGraph *)graph
{
    return _graph;
}

- (NSString *)name
{
    return _name;
}

- (RevenantMPSGraphOperationKind)revenant_mps_kind
{
    return _kind;
}

- (NSDictionary *)revenant_mps_parameters
{
    return _parameters;
}

- (void)revenant_mps_setParameters:(NSDictionary *)parameters
{
    _parameters = [parameters copy];
}

- (void)revenant_mps_setOutputTensors:(NSArray<MPSGraphTensor *> *)outputs
{
    _outputTensors = [outputs copy];
}

- (void)forEachTensor:(void (^)(MPSGraphTensor *))block
{
    for (MPSGraphTensor *tensor in _inputTensors)
        block(tensor);
    for (MPSGraphTensor *tensor in _outputTensors)
        block(tensor);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
