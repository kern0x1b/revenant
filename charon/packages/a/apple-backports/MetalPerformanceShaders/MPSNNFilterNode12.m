#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#import "CharonMPSNN.h"

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

+ (NSMapTable *)charon_mps_producers
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
        [[[self class] charon_mps_producers] setObject:self forKey:_resultImageNode];
    }
    return _resultImageNode;
}

- (NSArray<MPSNNStateNode *> *)resultStates { return _resultStates; }

- (MPSNNStateNode *)resultState
{
    return _resultStates.count ? _resultStates[0] : nil;
}

- (NSArray<MPSNNImageNode *> *)charon_mps_sourceNodes { return _sourceNodes; }

- (void)charon_mps_setSourceNodes:(NSArray<MPSNNImageNode *> *)nodes
{
    [_sourceNodes removeAllObjects];
    [_sourceNodes addObjectsFromArray:nodes];
}

- (void)charon_mps_addSourceNode:(MPSNNImageNode *)node
{
    if (node)
        [_sourceNodes addObject:node];
}

- (MPSKernel *)charon_mps_kernel { return nil; }

- (MPSImage *)charon_mps_sourceImageAtIndex:(NSUInteger)index
{
    return index < _sourceImages.count ? _sourceImages[index] : nil;
}

- (void)charon_mps_setSourceImages:(NSArray<MPSImage *> *)images
{
    [_sourceImages removeAllObjects];
    [_sourceImages addObjectsFromArray:images];
}

- (MPSImage *)charon_mps_destinationImage { return _destinationImage; }
- (void)charon_mps_setDestinationImage:(MPSImage *)image { _destinationImage = image; }
- (void)charon_mps_setDevice:(id<MTLDevice>)device { _device = device; }
- (id<MTLDevice>)charon_mps_device { return _device; }

- (MPSImageDescriptor *)charon_mps_destinationDescriptorForSource:(MPSImageDescriptor *)source
{
    if (_paddingPolicy && [_paddingPolicy respondsToSelector:@selector(destinationImageDescriptorForSourceImages:sourceStates:forKernel:suggestedDescriptor:)]) {
        NSMutableArray<MPSImage *> *images = [NSMutableArray array];
        for (NSUInteger index = 0; index < self.charon_mps_sourceNodes.count; index++) {
            MPSImage *image = [self charon_mps_sourceImageAtIndex:index];
            if (image)
                [images addObject:image];
        }
        return [_paddingPolicy destinationImageDescriptorForSourceImages:images
                                                           sourceStates:nil
                                                              forKernel:[self charon_mps_kernel]
                                                   suggestedDescriptor:source];
    }
    return source;
}

- (void)charon_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    CharonMPSRefuse(@"%@: a virtual base node carries no kernel, so it was not run", NSStringFromClass([self class]));
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p sources=%lu>", NSStringFromClass([self class]), (void *)self,
            (unsigned long)_sourceNodes.count];
}

@end

#pragma clang diagnostic pop
