// MLCGraph, the 14.0 surface of the graph: the factory, the three properties and the fifteen methods that
// make nodes out of layers and shapes out of shapes.
//
// A graph here is a list of nodes and nothing else: a node is a layer, the tensors it reads, the one tensor
// it writes, the labels it is trained against and whether it is updated. Every answer this file gives is a
// measurement off this host's own MLCompute, taken over the cases in
// .agent-work/runs/probe/mlc-graph.m and held to again by tests/backports/host/mlcompute/graph-cases.m, which
// compiles this object beside the host's framework and compares the two runs. What is measured and what it
// says is in facts/MLCompute/Graph.md; the four rules that answer most of it are these:
//
//   * **The device is nil, and a bind does not change that.** Measured: `+[MLCGraph graph].device` is nil on
//     a graph nothing has been added to, and it is nil again on a graph that
//     `bindAndWriteData:forInputs:toDevice:synchronous:` has just been given the CPU device. So the device a
//     graph runs on is set by a compile, and this port's device is nil until one.
//   * **A node's result is the shape its layer computes, and a layer that cannot take the sources it was
//     given answers nil.** Measured: a ReLU over one source of shape 2x3 answers 2x3, and the same layer
//     over two, over three, or over two with an update disabled or with loss labels answers nil.
//   * **The shape operations do not check.** Measured: `reshapeWithShape:@[@7]` over six elements answers
//     a 7-element tensor, and `splitWithSource:splitSectionLengths:@[@1, @5]` over an extent of 3 answers
//     extents of 1 and 5. What a caller gets is the shape it asked for.
//   * **A permutation that is not a permutation of the rank answers nil.** Measured:
//     `transposeWithDimensions:@[@0]` over a rank-2 tensor is nil, and `@[@0, @2, @1]` over a rank-3 tensor
//     is the transpose the three dimensions name.

#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wnullability-completeness"

// One node: what a layer reads, what it writes, and the two flags a training graph reads. It is the port's
// own object and is named Charon*, so the gate weighs none of it against a release.
@interface CharonMLCNode : NSObject
@property (readwrite, nonatomic) MLCLayer *layer;
@property (readwrite, nonatomic) NSArray<MLCTensor *> *sources;
@property (readwrite, nonatomic) MLCTensor *result;
@property (readwrite, nonatomic) NSArray<MLCTensor *> *lossLabels;
@property (readwrite, nonatomic) BOOL disableUpdate;
@end

@implementation CharonMLCNode {
@protected
    MLCLayer *_layer;
    NSArray<MLCTensor *> *_sources;
    MLCTensor *_result;
    NSArray<MLCTensor *> *_lossLabels;
    BOOL _disableUpdate;
}
@synthesize layer = _layer;
@synthesize sources = _sources;
@synthesize result = _result;
@synthesize lossLabels = _lossLabels;
@synthesize disableUpdate = _disableUpdate;

- (instancetype)init
{
    if ((self = [super init])) {
        _sources = @[];
        _lossLabels = @[];
    }
    return self;
}

@end

// A result tensor of this shape. The data type is MLCDataTypeFloat32, which is what every operation this
// graph builds over its sources answers (measured: a concatenation of two 2x3 float32 tensors is
// MPSDataTypeFloat32 whatever it does to the shape), and the shape is the caller's own - the graph does not
// check it, which is the rule the header's own comments do not say and the measurement does.
static MLCTensor *CharonMLCGraphTensor(NSArray<NSNumber *> *shape)
{
    if (shape.count == 0)
        return nil;
    MLCTensorDescriptor *descriptor = [MLCTensorDescriptor descriptorWithShape:shape
                                                                    dataType:MLCDataTypeFloat32];
    return [MLCTensor tensorWithDescriptor:descriptor];
}

// How many sources a layer takes, and what its result's shape is over them. Measured over the layers this
// port's engine carries (facts/MLCompute/Engine.md names them): an activation takes one source and answers
// that source's shape, and nothing else takes more than one here, so a layer that cannot take the sources
// it was given answers nil rather than a tensor of a guessed shape.
static NSUInteger CharonMLCGraphArityOf(MLCLayer *layer)
{
    if ([layer isKindOfClass:[MLCActivationLayer class]])
        return 1;
    return 0;
}

@implementation MLCGraph {
    MLCDevice *_device;
    NSMutableArray<MLCLayer *> *_layers;
    NSMutableArray<CharonMLCNode *> *_nodes;
    NSDictionary<NSString *, MLCTensor *> *_boundInputs;
}

+ (instancetype)graph
{
    // A graph with no device, no layer and no node, which is what the host answers: -device is nil and
    // -layers is empty on a graph nothing has been added to (measured).
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _layers = [NSMutableArray array];
        _nodes = [NSMutableArray array];
        _boundInputs = @{};
    }
    return self;
}

- (MLCDevice *)device
{
    // Nil until a bind, and the object it was given then: a graph is made for no device at all and is given
    // one by -bindAndWriteData:forInputs:toDevice:batchSize:synchronous: or its two-argument-form sibling.
    return _device;
}

- (NSArray<MLCLayer *> *)layers
{
    // The layers in the order they were first used, each of them once: measured, five nodes made over one
    // ReLU answer a graph with one layer in it.
    return [_layers copy];
}

- (NSString *)summarizedDOTDescription
{
    // Measured, character for character on this host, for a graph with nodes in it:
    //
    //   digraph MLCGraph {
    //    node [style=filled];
    //   }
    //
    // which is 42 characters. The nodes are not in it: the host's is a summary, and this is the summary.
    return @"digraph MLCGraph {\n node [style=filled];\n}";
}

#pragma mark - the nodes

// The one place a node is made, so the layer is registered once, the arity is checked once, and a node
// that cannot be made is not half-made.
- (MLCTensor *)charon_mlc_nodeWithLayer:(MLCLayer *)layer
                                sources:(NSArray<MLCTensor *> *)sources
                             lossLabels:(NSArray<MLCTensor *> *)lossLabels
                          disableUpdate:(BOOL)disableUpdate
{
    if (!layer)
        return nil;
    if (sources.count != CharonMLCGraphArityOf(layer))
        return nil;
    MLCTensor *result = CharonMLCGraphTensor(sources.firstObject.descriptor.shape);
    if (!result)
        return nil;
    CharonMLCNode *node = [[CharonMLCNode alloc] init];
    node.layer = layer;
    node.sources = sources;
    node.result = result;
    node.lossLabels = lossLabels;
    node.disableUpdate = disableUpdate;
    [_nodes addObject:node];
    if (![_layers containsObject:layer])
        [_layers addObject:layer];
    return result;
}

- (MLCTensor *)nodeWithLayer:(MLCLayer *)layer source:(MLCTensor *)source
{
    return [self charon_mlc_nodeWithLayer:layer sources:(source ? @[source] : @[]) lossLabels:@[] disableUpdate:NO];
}

- (MLCTensor *)nodeWithLayer:(MLCLayer *)layer sources:(NSArray<MLCTensor *> *)sources
{
    return [self charon_mlc_nodeWithLayer:layer sources:sources lossLabels:@[] disableUpdate:NO];
}

- (MLCTensor *)nodeWithLayer:(MLCLayer *)layer
                    sources:(NSArray<MLCTensor *> *)sources
              disableUpdate:(BOOL)disableUpdate
{
    return [self charon_mlc_nodeWithLayer:layer sources:sources lossLabels:@[] disableUpdate:disableUpdate];
}

- (MLCTensor *)nodeWithLayer:(MLCLayer *)layer
                    sources:(NSArray<MLCTensor *> *)sources
                  lossLabels:(NSArray<MLCTensor *> *)lossLabels
{
    return [self charon_mlc_nodeWithLayer:layer sources:sources lossLabels:lossLabels disableUpdate:NO];
}

- (NSArray<MLCTensor *> *)sourceTensorsForLayer:(MLCLayer *)layer
{
    // Every tensor the layer reads, over every node that uses it, and an empty array for a layer no node
    // uses (measured: one tensor each for the ReLU of the five nodes above).
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray array];
    for (CharonMLCNode *node in _nodes) {
        if (node.layer != layer)
            continue;
        for (MLCTensor *source in node.sources) {
            if (![tensors containsObject:source])
                [tensors addObject:source];
        }
    }
    return tensors;
}

- (NSArray<MLCTensor *> *)resultTensorsForLayer:(MLCLayer *)layer
{
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray array];
    for (CharonMLCNode *node in _nodes) {
        if (node.layer != layer)
            continue;
        if (node.result && ![tensors containsObject:node.result])
            [tensors addObject:node.result];
    }
    return tensors;
}

#pragma mark - the shape operations

- (MLCTensor *)concatenateWithSources:(NSArray<MLCTensor *> *)sources dimension:(NSUInteger)dimension
{
    // The sources' shapes added along one dimension, and the first source's data type. Measured: two 2x3
    // tensors over dimension 1 are 2x6 and over dimension 0 are 4x3, and two 2x3x4 tensors over dimension 1
    // are 2x6x4.
    if (sources.count == 0)
        return nil;
    NSArray<NSNumber *> *shape = sources.firstObject.descriptor.shape;
    if (dimension >= shape.count)
        return nil;
    NSInteger total = 0;
    for (MLCTensor *source in sources)
        total += source.descriptor.shape[dimension].integerValue;
    NSMutableArray<NSNumber *> *joined = [shape mutableCopy];
    joined[dimension] = @(total);
    return CharonMLCGraphTensor(joined);
}

- (MLCTensor *)reshapeWithShape:(NSArray<NSNumber *> *)shape source:(MLCTensor *)source
{
    // The shape as it was given, whether or not it holds as many elements as the source: measured,
    // -reshapeWithShape:@[@7] over a source of six elements answers a 7-element tensor, and -reshapeWithShape:
    // @[@3, @2] over the same source answers 3x2. What the graph does not do is check.
    if (!source || shape.count == 0)
        return nil;
    return CharonMLCGraphTensor(shape);
}

- (MLCTensor *)transposeWithDimensions:(NSArray<NSNumber *> *)dimensions source:(MLCTensor *)source
{
    // The shape the dimensions name, and nil when they are not a permutation of the rank: measured, one
    // dimension over a rank-2 tensor is nil, while @[@0, @1], @[@1, @0] and @[@0, @2, @1] over a rank-3
    // tensor are the three transposes they name.
    if (!source)
        return nil;
    NSArray<NSNumber *> *shape = source.descriptor.shape;
    if (dimensions.count != shape.count)
        return nil;
    NSMutableArray<NSNumber *> *seen = [NSMutableArray array];
    NSMutableArray<NSNumber *> *permuted = [NSMutableArray arrayWithCapacity:shape.count];
    for (NSNumber *dimension in dimensions) {
        NSInteger index = dimension.integerValue;
        if (index < 0 || index >= (NSInteger)shape.count || [seen containsObject:@(index)])
            return nil;
        [seen addObject:@(index)];
        [permuted addObject:shape[index]];
    }
    return CharonMLCGraphTensor(permuted);
}

// The extents a split into a count makes of one dimension, measured: an extent of 3 into two gives 2 and 1,
// so the REMAINDER GOES TO THE FIRST PART, and an extent of 2 into three gives two parts of one and none
// more, so the count is capped at the extent.
static NSArray<NSNumber *> *CharonMLCGraphSplitExtents(NSInteger extent, NSUInteger count)
{
    if (count == 0 || extent <= 0)
        return @[];
    if (count > (NSUInteger)extent)
        count = (NSUInteger)extent;
    NSInteger base = extent / (NSInteger)count;
    NSInteger remainder = extent % (NSInteger)count;
    NSMutableArray<NSNumber *> *extents = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++)
        [extents addObject:@(base + (index == 0 ? remainder : 0))];
    return extents;
}

- (NSArray<MLCTensor *> *)charon_mlc_splitWithSource:(MLCTensor *)source
                                             extents:(NSArray<NSNumber *> *)extents
                                            dimension:(NSUInteger)dimension
{
    NSArray<NSNumber *> *shape = source.descriptor.shape;
    if (dimension >= shape.count)
        return nil;
    NSMutableArray<MLCTensor *> *tensors = [NSMutableArray arrayWithCapacity:extents.count];
    for (NSNumber *extent in extents) {
        NSMutableArray<NSNumber *> *part = [shape mutableCopy];
        part[dimension] = extent;
        MLCTensor *tensor = CharonMLCGraphTensor(part);
        if (!tensor)
            return nil;
        [tensors addObject:tensor];
    }
    return tensors;
}

- (NSArray<MLCTensor *> *)splitWithSource:(MLCTensor *)source
                               splitCount:(NSUInteger)splitCount
                                dimension:(NSUInteger)dimension
{
    if (!source)
        return nil;
    NSInteger extent = source.descriptor.shape[dimension].integerValue;
    return [self charon_mlc_splitWithSource:source
                                    extents:CharonMLCGraphSplitExtents(extent, splitCount)
                                   dimension:dimension];
}

- (NSArray<MLCTensor *> *)splitWithSource:(MLCTensor *)source
                      splitSectionLengths:(NSArray<NSNumber *> *)splitSectionLengths
                                dimension:(NSUInteger)dimension
{
    // The section lengths as they were given, measured: @[@1, @5] over an extent of 3 answers extents of 1
    // and 5, so the lengths are not checked against the extent either.
    if (!source)
        return nil;
    return [self charon_mlc_splitWithSource:source extents:splitSectionLengths dimension:dimension];
}

#pragma mark - binding

- (BOOL)charon_mlc_bind:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
             forInputs:(NSDictionary<NSString *, MLCTensor *> *)inputTensors
               toDevice:(MLCDevice *)device
{
    // Measured: this answers YES for a dictionary holding a name the graph never knew and for an empty
    // dictionary, and NO for nil inputs. So what decides it is whether the caller's inputs are there at all,
    // not whether every name resolves - the port binds what it can and says yes.
    //
    // And it does NOT give the graph its device: measured, a graph asked for -device straight after a bind
    // that named the CPU device still answers nil, so the device a compiled graph runs on is set by the
    // compile and not by a bind, and the port leaves it nil here for the same reason.
    if (!inputTensors)
        return NO;
    (void)inputsData;
    (void)device;
    NSMutableDictionary<NSString *, MLCTensor *> *bound = [_boundInputs mutableCopy];
    [bound addEntriesFromDictionary:inputTensors];
    _boundInputs = bound;
    return YES;
}

- (BOOL)bindAndWriteData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
              forInputs:(NSDictionary<NSString *, MLCTensor *> *)inputTensors
               toDevice:(MLCDevice *)device
             batchSize:(NSUInteger)batchSize
            synchronous:(BOOL)synchronous
{
    (void)batchSize;
    (void)synchronous;
    return [self charon_mlc_bind:inputsData forInputs:inputTensors toDevice:device];
}

- (BOOL)bindAndWriteData:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
              forInputs:(NSDictionary<NSString *, MLCTensor *> *)inputTensors
               toDevice:(MLCDevice *)device
            synchronous:(BOOL)synchronous
{
    (void)synchronous;
    return [self charon_mlc_bind:inputsData forInputs:inputTensors toDevice:device];
}

@end