#import <ModelIO/ModelIO.h>
#import <string.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// A material is a set of named properties, each of one semantic (what it means to a renderer) and of
// one type (how its value is written). A property's value is a string, a URL, a texture, a colour, a
// float or a vector, or a 4x4 matrix, and the type says which: a property written as a float read
// back as a float3 is three floats of it, which is what a renderer wants from a scalar.

@implementation MDLMaterialPropertyConnection {
    // Weak, which under this port's manual reference counting is the unsafe form: the connection
    // names the two properties rather than owning them, and the graph keeps them alive.
    __unsafe_unretained MDLMaterialProperty *_output, *_input;
    NSString *_name;
}

@synthesize name = _name;

- (instancetype)initWithOutput:(MDLMaterialProperty *)output input:(MDLMaterialProperty *)input
{
    if ((self = [super init])) {
        _output = output;
        _input = input;
    }
    return self;
}

- (MDLMaterialProperty *)output
{
    return _output;
}

- (MDLMaterialProperty *)input
{
    return _input;
}

- (void)dealloc
{
}

@end
@implementation MDLMaterialPropertyNode {
    NSArray<MDLMaterialProperty *> *_inputs, *_outputs;
    void (^_evaluationFunction)(MDLMaterialPropertyNode *);
    NSString *_name;
}

@synthesize name = _name;

- (instancetype)initWithInputs:(NSArray<MDLMaterialProperty *> *)inputs
                       outputs:(NSArray<MDLMaterialProperty *> *)outputs
            evaluationFunction:(void (^)(MDLMaterialPropertyNode *))function
{
    if ((self = [super init])) {
        _inputs = [inputs copy];
        _outputs = [outputs copy];
        _evaluationFunction = [function copy];
    }
    return self;
}

- (void)dealloc
{
}

- (NSArray<MDLMaterialProperty *> *)inputs
{
    return _inputs;
}

- (NSArray<MDLMaterialProperty *> *)outputs
{
    return _outputs;
}

- (void (^)(MDLMaterialPropertyNode *))evaluationFunction
{
    return _evaluationFunction;
}

- (void)setEvaluationFunction:(void (^)(MDLMaterialPropertyNode *))evaluationFunction
{
    if (_evaluationFunction != evaluationFunction) {
        _evaluationFunction = [evaluationFunction copy];
    }
}

@end
@implementation MDLMaterialPropertyGraph {
    NSArray<MDLMaterialPropertyNode *> *_nodes;
    NSArray<MDLMaterialPropertyConnection *> *_connections;
    NSString *_name;
}

@synthesize name = _name;

- (instancetype)initWithNodes:(NSArray<MDLMaterialPropertyNode *> *)nodes
                  connections:(NSArray<MDLMaterialPropertyConnection *> *)connections
{
    if ((self = [super initWithInputs:@[] outputs:@[] evaluationFunction:nil])) {
        _nodes = [nodes copy];
        _connections = [connections copy];
    }
    return self;
}

- (void)dealloc
{
}

- (NSArray<MDLMaterialPropertyNode *> *)nodes
{
    return _nodes;
}

- (NSArray<MDLMaterialPropertyConnection *> *)connections
{
    return _connections;
}

// The connections are the graph's own order, so every output of every node has been written by the
// time the evaluation returns, which is what a caller then reads.
- (void)evaluate
{
    for (MDLMaterialPropertyNode *node in _nodes)
        node.evaluationFunction(node);
    for (MDLMaterialPropertyConnection *connection in _connections)
        [connection.output setProperties:connection.input];
}

@end
