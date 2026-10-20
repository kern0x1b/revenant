#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#import "RevenantMPSNN.h"

@implementation MPSNNFilterNode {
    MPSNNImageNode *_resultImageNode;
    NSMutableArray<MPSNNStateNode *> *_resultStates;
    NSMutableArray<MPSNNImageNode *> *_sourceNodes;
    NSMutableArray<MPSImage *> *_sourceImages;
    id<MPSNNPadding> _paddingPolicy;
    NSString *_label;
    MPSImage *_destinationImage;
    id<MTLDevice> _device;
}

@synthesize paddingPolicy = _paddingPolicy;
@synthesize label = _label;

+ (NSMapTable *)revenant_mps_producers
{
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMapTable strongToStrongObjectsMapTable];
    });
    return table;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super init])) {
        _sourceNodes = [NSMutableArray array];
        _sourceImages = [NSMutableArray array];
        _resultStates = [NSMutableArray array];
        _device = device;
    }
    return self;
}

- (MPSNNImageNode *)resultImage
{
    if (!_resultImageNode) {
        _resultImageNode = [[MPSNNImageNode alloc] initWithHandle:nil];
        [[[self class] revenant_mps_producers] setObject:self forKey:_resultImageNode];
    }
    return _resultImageNode;
}

- (NSArray<MPSNNStateNode *> *)resultStates { return _resultStates; }

- (MPSNNStateNode *)resultState
{
    return _resultStates.count ? _resultStates[0] : nil;
}

- (NSArray<MPSNNImageNode *> *)revenant_mps_sourceNodes { return _sourceNodes; }

- (void)revenant_mps_setSourceNodes:(NSArray<MPSNNImageNode *> *)nodes
{
    [_sourceNodes removeAllObjects];
    [_sourceNodes addObjectsFromArray:nodes];
}

- (void)revenant_mps_addSourceNode:(MPSNNImageNode *)node
{
    if (node)
        [_sourceNodes addObject:node];
}

- (MPSKernel *)revenant_mps_kernel { return nil; }

- (MPSImage *)revenant_mps_sourceImageAtIndex:(NSUInteger)index
{
    return index < _sourceImages.count ? _sourceImages[index] : nil;
}

- (void)revenant_mps_setSourceImages:(NSArray<MPSImage *> *)images
{
    [_sourceImages removeAllObjects];
    [_sourceImages addObjectsFromArray:images];
}

- (MPSImage *)revenant_mps_destinationImage { return _destinationImage; }
- (void)revenant_mps_setDestinationImage:(MPSImage *)image { _destinationImage = image; }
- (void)revenant_mps_setDevice:(id<MTLDevice>)device { _device = device; }
- (id<MTLDevice>)revenant_mps_device { return _device; }

- (MPSImageDescriptor *)revenant_mps_destinationDescriptorForSource:(MPSImageDescriptor *)source
{
    if (_paddingPolicy && [_paddingPolicy respondsToSelector:@selector(destinationImageDescriptorForSourceImages:sourceStates:forKernel:suggestedDescriptor:)]) {
        NSMutableArray<MPSImage *> *images = [NSMutableArray array];
        for (NSUInteger index = 0; index < self.revenant_mps_sourceNodes.count; index++) {
            MPSImage *image = [self revenant_mps_sourceImageAtIndex:index];
            if (image)
                [images addObject:image];
        }
        return [_paddingPolicy destinationImageDescriptorForSourceImages:images
                                                           sourceStates:nil
                                                              forKernel:[self revenant_mps_kernel]
                                                   suggestedDescriptor:source];
    }
    return source;
}

- (void)revenant_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    RevenantMPSRefuse(@"%@: a virtual base node carries no kernel, so it was not run", NSStringFromClass([self class]));
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p sources=%lu>", NSStringFromClass([self class]), (void *)self,
            (unsigned long)_sourceNodes.count];
}

@end

#pragma clang diagnostic pop
