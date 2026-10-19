// MPSGraphOperation, from the header of MPSGraphOperation.h in the SDK of iOS 16.4: what an operation
// reads, what it writes, what it is called and which graph it belongs to. What it *does* is a kind the
// interpreter in MPSGraph14.m dispatches on.

#import "CharonMPSGraph.h"

@implementation MPSGraphOperation {
    MPSGraph *_graph;
    NSString *_name;
    NSArray<MPSGraphTensor *> *_inputTensors;
    NSArray<MPSGraphTensor *> *_outputTensors;
    NSArray<MPSGraphOperation *> *_controlDependencies;
    CharonMPSGraphOperationKind _kind;
    NSDictionary *_parameters;
}

- (instancetype)initWithGraph:(MPSGraph *)graph
                         kind:(CharonMPSGraphOperationKind)kind
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

- (CharonMPSGraphOperationKind)charon_mps_kind
{
    return _kind;
}

// What a constant operation carries, and what an operation with a second operand and a scalar carries:
// the operands themselves are already the operation's inputs, so only what is not a tensor is here.
- (NSDictionary *)charon_mps_parameters
{
    return _parameters;
}

- (void)charon_mps_setParameters:(NSDictionary *)parameters
{
    _parameters = [parameters copy];
}

- (void)charon_mps_setOutputTensors:(NSArray<MPSGraphTensor *> *)outputs
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
