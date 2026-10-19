#import "CharonMetal.h"

@implementation MTLFunctionStitchingAttributeAlwaysInline
@end

@implementation MTLFunctionStitchingInputNode

{
    NSUInteger _argumentIndex;
}

- (instancetype)initWithArgumentIndex:(NSUInteger)argument
{
    if ((self = [super init]))
        _argumentIndex = argument;
    return self;
}

- (NSUInteger)argumentIndex
{
    return _argumentIndex;
}

- (void)setArgumentIndex:(NSUInteger)argumentIndex
{
    _argumentIndex = argumentIndex;
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    return [[MTLFunctionStitchingInputNode alloc] initWithArgumentIndex:_argumentIndex];
}

@end

@implementation MTLFunctionStitchingFunctionNode

{
    NSString *_name;
    NSArray *_arguments;
    NSArray *_controlDependencies;
}

- (instancetype)initWithName:(NSString *)name
                   arguments:(NSArray *)arguments
         controlDependencies:(NSArray *)controlDependencies
{
    if ((self = [super init])) {
        _name = [name copy];
        _arguments = [arguments copy] ?: @[];
        _controlDependencies = [controlDependencies copy] ?: @[];
    }
    return self;
}

- (NSString *)name
{
    return _name;
}

- (void)setName:(NSString *)name
{
    _name = [name copy];
}

- (NSArray *)arguments
{
    return _arguments;
}

- (void)setArguments:(NSArray *)arguments
{
    _arguments = [arguments copy] ?: @[];
}

- (NSArray *)controlDependencies
{
    return _controlDependencies;
}

- (void)setControlDependencies:(NSArray *)controlDependencies
{
    _controlDependencies = [controlDependencies copy] ?: @[];
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    return [[MTLFunctionStitchingFunctionNode alloc] initWithName:_name
                                                        arguments:_arguments
                                              controlDependencies:_controlDependencies];
}

@end

@implementation MTLFunctionStitchingGraph

{
    NSString *_functionName;
    NSArray *_nodes;
    MTLFunctionStitchingFunctionNode *_outputNode;
    NSArray *_attributes;
}

- (instancetype)initWithFunctionName:(NSString *)functionName
                               nodes:(NSArray *)nodes
                          outputNode:(MTLFunctionStitchingFunctionNode *)outputNode
                          attributes:(NSArray *)attributes
{
    if ((self = [super init])) {
        _functionName = [functionName copy];
        _nodes = [nodes copy] ?: @[];
        _outputNode = outputNode;
        _attributes = [attributes copy] ?: @[];
    }
    return self;
}

- (NSString *)functionName
{
    return _functionName;
}

- (void)setFunctionName:(NSString *)functionName
{
    _functionName = [functionName copy];
}

- (NSArray *)nodes
{
    return _nodes;
}

- (void)setNodes:(NSArray *)nodes
{
    _nodes = [nodes copy] ?: @[];
}

- (MTLFunctionStitchingFunctionNode *)outputNode
{
    return _outputNode;
}

- (void)setOutputNode:(MTLFunctionStitchingFunctionNode *)outputNode
{
    _outputNode = outputNode;
}

- (NSArray *)attributes
{
    return _attributes;
}

- (void)setAttributes:(NSArray *)attributes
{
    _attributes = [attributes copy] ?: @[];
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    return [[MTLFunctionStitchingGraph alloc] initWithFunctionName:_functionName
                                                              nodes:_nodes
                                                         outputNode:_outputNode
                                                         attributes:_attributes];
}

@end

@implementation MTLStitchedLibraryDescriptor

{
    NSArray *_functions;
    NSArray *_functionGraphs;
}

- (NSArray<MTLFunctionStitchingGraph *> *)functionGraphs
{
    return _functionGraphs;
}

- (void)setFunctionGraphs:(NSArray<MTLFunctionStitchingGraph *> *)functionGraphs
{
    _functionGraphs = [functionGraphs copy] ?: @[];
}

- (NSArray<id<MTLFunction>> *)functions
{
    return _functions;
}

- (void)setFunctions:(NSArray<id<MTLFunction>> *)functions
{
    _functions = [functions copy] ?: @[];
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    MTLStitchedLibraryDescriptor *copy = [[MTLStitchedLibraryDescriptor alloc] init];
    copy.functionGraphs = _functionGraphs;
    copy.functions = _functions;
    return copy;
}

@end

@implementation MTLRenderPipelineFunctionsDescriptor

{
    NSArray *_vertexAdditionalBinaryFunctions;
    NSArray *_fragmentAdditionalBinaryFunctions;
    NSArray *_tileAdditionalBinaryFunctions;
}

- (NSArray *)vertexAdditionalBinaryFunctions
{
    return _vertexAdditionalBinaryFunctions;
}

- (void)setVertexAdditionalBinaryFunctions:(NSArray *)vertexAdditionalBinaryFunctions
{
    _vertexAdditionalBinaryFunctions = [vertexAdditionalBinaryFunctions copy];
}

- (NSArray *)fragmentAdditionalBinaryFunctions
{
    return _fragmentAdditionalBinaryFunctions;
}

- (void)setFragmentAdditionalBinaryFunctions:(NSArray *)fragmentAdditionalBinaryFunctions
{
    _fragmentAdditionalBinaryFunctions = [fragmentAdditionalBinaryFunctions copy];
}

- (NSArray *)tileAdditionalBinaryFunctions
{
    return _tileAdditionalBinaryFunctions;
}

- (void)setTileAdditionalBinaryFunctions:(NSArray *)tileAdditionalBinaryFunctions
{
    _tileAdditionalBinaryFunctions = [tileAdditionalBinaryFunctions copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    MTLRenderPipelineFunctionsDescriptor *copy = [[MTLRenderPipelineFunctionsDescriptor alloc] init];
    copy.vertexAdditionalBinaryFunctions = _vertexAdditionalBinaryFunctions;
    copy.fragmentAdditionalBinaryFunctions = _fragmentAdditionalBinaryFunctions;
    copy.tileAdditionalBinaryFunctions = _tileAdditionalBinaryFunctions;
    return copy;
}

@end
