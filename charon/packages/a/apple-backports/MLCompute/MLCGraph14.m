#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wnullability-completeness"

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

static MLCTensor *CharonMLCGraphTensor(NSArray<NSNumber *> *shape)
{
    if (shape.count == 0)
        return nil;
    MLCTensorDescriptor *descriptor = [MLCTensorDescriptor descriptorWithShape:shape
                                                                    dataType:MLCDataTypeFloat32];
    return [MLCTensor tensorWithDescriptor:descriptor];
}

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
    return _device;
}

- (NSArray<MLCLayer *> *)layers
{
    return [_layers copy];
}

- (NSString *)summarizedDOTDescription
{
    return @"digraph MLCGraph {\n node [style=filled];\n}";
}

#pragma mark - the nodes

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
    if (!source || shape.count == 0)
        return nil;
    return CharonMLCGraphTensor(shape);
}

- (MLCTensor *)transposeWithDimensions:(NSArray<NSNumber *> *)dimensions source:(MLCTensor *)source
{
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
    if (!source)
        return nil;
    return [self charon_mlc_splitWithSource:source extents:splitSectionLengths dimension:dimension];
}

#pragma mark - binding

- (BOOL)charon_mlc_bind:(NSDictionary<NSString *, MLCTensorData *> *)inputsData
             forInputs:(NSDictionary<NSString *, MLCTensor *> *)inputTensors
               toDevice:(MLCDevice *)device
{
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
