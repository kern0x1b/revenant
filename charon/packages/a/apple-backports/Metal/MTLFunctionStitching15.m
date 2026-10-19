#import "CharonMetal.h"

// The function-stitching family: the graph objects that describe how several functions are stitched
// into one.
//
// ONE OBJECT AT 16.0, which is what the ladder says and not what the headers' annotations say.
// Every type in MTLFunctionStitching.h is API_AVAILABLE(ios(15.0)), and so is
// MTLRenderPipelineFunctionsDescriptor in MTLRenderPipeline.h - the annotation says when a release
// ALLOWS the API. release-split puts the objects built from this file in the 16.0 band, and reports that as
// 'after 12.0, by 16.0, not a measured first release' - not a measured first export. The rows carry 16.0 for that
// reason and this comment said 15.0, which was wrong. MTLLinkedFunctions is
// NOT here: it is 14.0, and an object carrying both would be placed in neither band. MTLFunction-
// StitchingGraph, its nodes and MTLStitchedLibraryDescriptor are, so they are.
//
// These are PLAIN DATA CONTAINERS, and that is why they are carried rather than answered as absent:
// an input node is an argument index, a function node is a name, a list of argument nodes and a list
// of control dependencies, a graph is a name, a node list, an output node and an attribute list, and
// a stitched library descriptor is a list of graphs and a list of functions. None of them asks the
// device anything, and all of them work on a device with no GPU counter, no ray tracing and no
// tessellator. What the port cannot do is STITCH: it translates each kernel to its own object, so a
// graph it is given describes a function it will never produce. That is stated in the rows and it is
// a property of the port's output, not of these objects - which is the same distinction the owner drew
// for the hardware rows, applied here to the port's own limit.

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

// NSCopying, which MTLFunctionStitchingNode inherits: a copy of a node is a node with the same
// argument index, and NOT the same object, so a graph can be edited without editing the node it was
// built from.
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

// The output node is OPTIONAL in the header - it is the nullable property, and the return value of
// the output node is what the stitched function returns - so nil is kept as nil and is not replaced
// by a stand-in.
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

// MTLRenderPipelineFunctionsDescriptor, which the registry carries and this object did not implement:
// a row that says `implemented` with no @implementation behind it, which is a claim with nothing under
// it. The header gives it three nullable lists of functions - additional binary functions the vertex,
// fragment and tile functions may access - and NSCopying, and that is the whole of its shape.
//
// It is DATA: three settable lists on a plain object that asks no device anything, so it is carried
// like the graph objects rather than answered as absent. The port produces no binary functions - it
// translates each kernel to its own object, so a binary archive is not something it makes - which
// means the lists are empty in practice, and EMPTY IS AN HONEST ANSWER where the header makes them
// nullable. A caller that sets one gets it back.
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

// NSCopying, which the header declares on the class: a copy is a new descriptor carrying the same
// three lists, so editing the copy does not edit the original.
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
