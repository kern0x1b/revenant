#import "CharonMPSNN.h"

@implementation MPSNNImageNode {
    id<MPSHandle> _handle;
    MPSImageFeatureChannelFormat _format;
    id<MPSImageAllocator> _imageAllocator;
    BOOL _exportFromGraph;
    MPSImage *_charonImage;
}

@synthesize handle = _handle;
@synthesize format = _format;
@synthesize imageAllocator = _imageAllocator;
@synthesize exportFromGraph = _exportFromGraph;

- (instancetype)initWithHandle:(id<MPSHandle>)handle
{
    if ((self = [super init])) {
        _handle = handle;
        _format = MPSImageFeatureChannelFormatNone;
        _imageAllocator = nil;
        _exportFromGraph = NO;
    }
    return self;
}

+ (instancetype)nodeWithHandle:(id<MPSHandle>)handle
{
    return [[self alloc] initWithHandle:handle];
}

+ (instancetype)exportedNodeWithHandle:(id<MPSHandle>)handle
{
    MPSNNImageNode *node = [[self alloc] initWithHandle:handle];
    node.exportFromGraph = YES;
    return node;
}

- (MPSImage *)charon_mps_image { return _charonImage; }
- (void)charon_mps_setImage:(MPSImage *)image { _charonImage = image; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p handle=%@ channels=%lu>", NSStringFromClass([self class]), (void *)self,
            _handle, (unsigned long)_charonImage.featureChannels];
}

@end


@implementation MPSImage (CharonMPSNN)

- (MPSImageDescriptor *)charon_mps_descriptor
{
    MPSImageDescriptor *descriptor = [MPSImageDescriptor new];
    descriptor.width = self.width;
    descriptor.height = self.height;
    descriptor.featureChannels = self.featureChannels;
    descriptor.numberOfImages = self.numberOfImages;
    descriptor.channelFormat = self.featureChannelFormat;
    return descriptor;
}

@end


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSNNDefaultPadding {
    MPSNNPaddingMethod _paddingMethod;
    NSString *_label;
}

static NSString *CharonMPSNNPaddingLabel(MPSNNPaddingMethod method)
{
    static NSString *const aligns[] = { @"AlignCentered", @"AlignTopLeft", @"AlignBottomRight" };
    static NSString *const remainders[] = { @"AddRemainderToTopLeft", @"AddRemainderToTopRight",
                                            @"AddRemainderToBottomLeft", @"AddRemainderToBottomRight" };
    static NSString *const sizes[] = { @"SizeValidOnly", @"SizeSame", @"SizeFull", @"Size_reserved" };
    NSString *label = [NSString stringWithFormat:@"%@, %@, %@, ",
                       aligns[method & MPSNNPaddingMethodAlignMask],
                       remainders[(method & MPSNNPaddingMethodAddRemainderToMask) >> 2],
                       sizes[(method >> 4) & 3]];
    if (method & (1UL << 15))
        label = [label stringByAppendingString:@"MPSNNPaddingMethod.Custom (inhibits node fusion)"];
    return label;
}

- (NSString *)label { return _label; }

+ (instancetype)paddingWithMethod:(MPSNNPaddingMethod)method
{
    if ((method & MPSNNPaddingMethodAlignMask) == MPSNNPaddingMethodAlign_reserved)
        return nil;
    MPSNNDefaultPadding *padding = [[self alloc] init];
    padding->_paddingMethod = method;
    padding->_label = CharonMPSNNPaddingLabel(method);
    return padding;
}

- (MPSNNPaddingMethod)paddingMethod { return _paddingMethod; }

- (MPSImageDescriptor *)destinationImageDescriptorForSourceImages:(NSArray<MPSImage *> *)sourceImages
                                                     sourceStates:(NSArray<MPSState *> *)sourceStates
                                                        forKernel:(MPSKernel *)kernel
                                             suggestedDescriptor:(MPSImageDescriptor *)inDescriptor
{
    MPSImage *source = sourceImages.firstObject;
    if (!source)
        return inDescriptor;
    MPSImageDescriptor *sourceDescriptor = [source charon_mps_descriptor];
    if (!sourceDescriptor)
        return inDescriptor;

    NSUInteger kernelWidth = 1, kernelHeight = 1, strideX = 1, strideY = 1;
    if ([kernel respondsToSelector:@selector(kernelWidth)]) kernelWidth = [(MPSCNNKernel *)kernel kernelWidth];
    if ([kernel respondsToSelector:@selector(kernelHeight)]) kernelHeight = [(MPSCNNKernel *)kernel kernelHeight];
    if ([kernel respondsToSelector:@selector(strideInPixelsX)]) strideX = [(MPSCNNKernel *)kernel strideInPixelsX];
    if ([kernel respondsToSelector:@selector(strideInPixelsY)]) strideY = [(MPSCNNKernel *)kernel strideInPixelsY];
    if (!kernelWidth) kernelWidth = 1;
    if (!kernelHeight) kernelHeight = 1;
    if (!strideX) strideX = 1;
    if (!strideY) strideY = 1;

    MPSNNPaddingMethod method = _paddingMethod;
    long destinationWidth = CharonMPSNNDestSize((long)sourceDescriptor.width, (long)strideX, (long)kernelWidth, method);
    long destinationHeight = CharonMPSNNDestSize((long)sourceDescriptor.height, (long)strideY, (long)kernelHeight, method);
    if (destinationWidth < 1) destinationWidth = 1;
    if (destinationHeight < 1) destinationHeight = 1;

    if ([kernel respondsToSelector:@selector(setOffset:)]) {
        MPSOffset offset;
        offset.x = (NSInteger)CharonMPSNNOffset((long)sourceDescriptor.width, (long)strideX, (long)kernelWidth, method);
        offset.y = (NSInteger)CharonMPSNNOffset((long)sourceDescriptor.height, (long)strideY, (long)kernelHeight, method);
        offset.z = 0;
        [(MPSCNNKernel *)kernel setOffset:offset];
    }

    MPSImageDescriptor *destination = [MPSImageDescriptor new];
    destination.channelFormat = sourceDescriptor.channelFormat;
    destination.cpuCacheMode = sourceDescriptor.cpuCacheMode;
    destination.storageMode = sourceDescriptor.storageMode;
    destination.usage = sourceDescriptor.usage;
    destination.featureChannels = sourceDescriptor.featureChannels;
    destination.numberOfImages = sourceDescriptor.numberOfImages;
    destination.width = (NSUInteger)destinationWidth;
    destination.height = (NSUInteger)destinationHeight;
    return destination;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super init])) {
        NSNumber *method = [aDecoder decodeObjectOfClass:[NSNumber class] forKey:@"paddingMethod"];
        _paddingMethod = method ? (MPSNNPaddingMethod)[method unsignedLongValue] : MPSNNPaddingMethodSizeValidOnly;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(_paddingMethod) forKey:@"paddingMethod"];
    if (_label)
        [aCoder encodeObject:_label forKey:@"label"];
}

@end

#pragma clang diagnostic pop


@implementation MPSNNAdditionNode
+ (Class)charon_mps_kernelClass { return [MPSImageAdd class]; }
@end

@implementation MPSNNSubtractionNode
+ (Class)charon_mps_kernelClass { return [MPSImageSubtract class]; }
@end

@implementation MPSNNMultiplicationNode
+ (Class)charon_mps_kernelClass { return [MPSImageMultiply class]; }
@end

@implementation MPSNNDivisionNode
+ (Class)charon_mps_kernelClass { return [MPSImageDivide class]; }
@end


@implementation MPSNNConcatenationNode {
    MPSKernel *_kernel;
}

+ (instancetype)nodeWithSources:(NSArray<MPSNNImageNode *> *)sourceNodes
{
    return [[self alloc] initWithSources:sourceNodes];
}

- (instancetype)initWithSources:(NSArray<MPSNNImageNode *> *)sourceNodes
{
    if ((self = [super initWithDevice:nil]))
        for (MPSNNImageNode *node in sourceNodes)
            [self charon_mps_addSourceNode:node];
    return self;
}

- (MPSKernel *)charon_mps_kernel { return _kernel; }

- (MPSImageDescriptor *)charon_mps_destinationDescriptorForSource:(MPSImageDescriptor *)source
{
    NSUInteger channels = 0, width = 0, height = 0;
    for (NSUInteger index = 0; index < self.charon_mps_sourceNodes.count; index++) {
        MPSImage *image = [self charon_mps_sourceImageAtIndex:index];
        MPSImageDescriptor *descriptor = [image charon_mps_descriptor];
        if (!descriptor)
            continue;
        channels += (descriptor.featureChannels + 3) & ~(NSUInteger)3;
        if (descriptor.width > width) width = descriptor.width;
        if (descriptor.height > height) height = descriptor.height;
    }
    if (!channels || !width || !height)
        return nil;

    MPSImageDescriptor *destination = [MPSImageDescriptor new];
    destination.channelFormat = source.channelFormat;
    destination.cpuCacheMode = source.cpuCacheMode;
    destination.storageMode = source.storageMode;
    destination.usage = source.usage;
    destination.numberOfImages = source.numberOfImages;
    destination.width = width;
    destination.height = height;
    destination.featureChannels = channels;
    return destination;
}

- (void)charon_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    MPSImage *destination = [self charon_mps_destinationImage];
    if (!destination || !self.charon_mps_sourceNodes.count) {
        CharonMPSRefuse(@"%@: a concatenation node needs at least one source and a destination",
                        NSStringFromClass([self class]));
        return;
    }
    NSString *what = NSStringFromClass([self class]);
    NSUInteger offset = 0;
    for (NSUInteger index = 0; index < self.charon_mps_sourceNodes.count; index++) {
        MPSImage *source = [self charon_mps_sourceImageAtIndex:index];
        if (!source)
            continue;
        CharonMPSImageLayout inLayout = CharonMPSImageLayoutOf(source);
        CharonMPSImageLayout outLayout = CharonMPSImageLayoutOf(destination);

        size_t rowElements = (size_t)destination.width * outLayout.channels;
        size_t bytes = rowElements * destination.height * outLayout.elementSize;
        if (!bytes || !outLayout.elementSize) {
            CharonMPSRefuse(@"%@: the destination's channel format names no element size, so nothing was joined", what);
            continue;
        }
        unsigned char *row = calloc(bytes, 1);
        if (!row) {
            CharonMPSRefuse(@"%@: no memory for a %lux%lux%lu join, so nothing was joined", what,
                            (unsigned long)destination.width, (unsigned long)destination.height,
                            (unsigned long)outLayout.channels);
            continue;
        }
        MPSImageDescriptor *descriptor = [source charon_mps_descriptor];
        NSUInteger channels = descriptor ? descriptor.featureChannels : 0;
        if (channels && channels < 4) {
            for (NSUInteger y = 0; y < destination.height; y++)
                for (NSUInteger x = 0; x < destination.width; x++) {
                    char *cell = (char *)row + ((size_t)y * rowElements + (size_t)x * outLayout.channels
                                                + offset + 3) * outLayout.elementSize;
                    memset(cell, 0, outLayout.elementSize);
                    if (outLayout.elementSize == sizeof(float))
                        *(float *)cell = 1.0f;
                }
        }
        void *sourceBytes = CharonMPSImageReadRegion(source, &inLayout, CharonMPSImageResolvedRegion(source, MPSRectNoClip), what);
        if (sourceBytes) {
            if (CharonMPSImageConcatRows(&inLayout, &outLayout, offset, sourceBytes, row))
                CharonMPSImageWriteRegion(destination, &outLayout, CharonMPSImageResolvedRegion(destination, MPSRectNoClip), row, what);
            else
                CharonMPSRefuse(@"%@: source %lu holds %lux%lux%lu and the destination %lux%lux%lu, so it was not joined",
                                what, (unsigned long)index,
                                (unsigned long)inLayout.width, (unsigned long)inLayout.height, (unsigned long)inLayout.channels,
                                (unsigned long)outLayout.width, (unsigned long)outLayout.height, (unsigned long)outLayout.channels);
            free(sourceBytes);
        }
        free(row);
        offset += (channels + 3) & ~(NSUInteger)3;
    }
    [self.resultImage charon_mps_setImage:destination];
}

@end


@implementation MPSCNNPoolingAverageNode
+ (Class)charon_mps_kernelClass { return [MPSCNNPoolingAverage class]; }
@end

@implementation MPSCNNPoolingMaxNode
+ (Class)charon_mps_kernelClass { return [MPSCNNPoolingMax class]; }
@end


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSNNGraph {
    NSMutableArray<MPSNNFilterNode *> *_filters;
    NSMutableArray<MPSNNImageNode *> *_sources;
    NSMutableArray<MPSNNImageNode *> *_order;
    BOOL _outputStateIsTemporary;
    id<MPSImageAllocator> _destinationImageAllocator;
    MPSImageFeatureChannelFormat _format;
    BOOL _resultImageIsNeeded;
    BOOL _walked;
}

- (void)charon_mps_walkFrom:(MPSNNImageNode *)result
{
    [_filters removeAllObjects];
    [_sources removeAllObjects];
    [_order removeAllObjects];
    [self charon_mps_visit:result seen:[NSMutableSet set]];
    _walked = YES;
}

- (void)charon_mps_visit:(MPSNNImageNode *)node seen:(NSMutableSet *)seen
{
    if (!node || [seen containsObject:node])
        return;
    [seen addObject:node];
    MPSNNFilterNode *producer = [[MPSNNFilterNode charon_mps_producers] objectForKey:node];
    if (!producer) {
        [_sources addObject:node];
        return;
    }
    for (MPSNNImageNode *source in producer.charon_mps_sourceNodes)
        [self charon_mps_visit:source seen:seen];
    [_order addObject:node];
    [_filters addObject:producer];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                 resultImage:(MPSNNImageNode *)resultImage
         resultImageIsNeeded:(BOOL)resultIsNeeded
{
    if ((self = [super initWithDevice:device])) {
        _filters = [NSMutableArray array];
        _sources = [NSMutableArray array];
        _order = [NSMutableArray array];
        _format = MPSImageFeatureChannelFormatFloat16;
        _outputStateIsTemporary = NO;
        _destinationImageAllocator = nil;
        _resultImageIsNeeded = resultIsNeeded;
        if (resultImage)
            [self charon_mps_walkFrom:resultImage];
    }
    return self;
}

+ (instancetype)graphWithDevice:(id<MTLDevice>)device
                    resultImage:(MPSNNImageNode *)resultImage
            resultImageIsNeeded:(BOOL)resultIsNeeded
{
    return [[self alloc] initWithDevice:device resultImage:resultImage resultImageIsNeeded:resultIsNeeded];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (NSArray<id<MPSHandle>> *)sourceImageHandles
{
    NSMutableArray *handles = [NSMutableArray array];
    for (MPSNNImageNode *node in _sources) {
        id<MPSHandle> handle = node.handle;
        if (handle)
            [handles addObject:handle];
    }
    return handles;
}

- (NSArray<id<MPSHandle>> *)sourceStateHandles { return nil; }
- (NSArray<id<MPSHandle>> *)intermediateImageHandles { return nil; }
- (NSArray<id<MPSHandle>> *)resultStateHandles { return nil; }
- (id<MPSHandle>)resultHandle { return _order.lastObject.handle; }

@synthesize outputStateIsTemporary = _outputStateIsTemporary;
@synthesize destinationImageAllocator = _destinationImageAllocator;
@synthesize format = _format;
@synthesize resultImageIsNeeded = _resultImageIsNeeded;

- (void)reloadFromDataSources
{
    for (MPSNNFilterNode *filter in _filters)
        if ([filter respondsToSelector:@selector(reloadFromDataSource)])
            [(id)filter performSelector:@selector(reloadFromDataSource)];
}

- (MPSImage *)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                      sourceImages:(NSArray<MPSImage *> *)sourceImages
{
    if (!_walked) {
        CharonMPSRefuse(@"MPSNNGraph: the graph was built with no result image, so there is nothing to walk");
        return nil;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return nil;

    for (NSUInteger index = 0; index < _sources.count && index < sourceImages.count; index++)
        [_sources[index] charon_mps_setImage:sourceImages[index]];

    for (MPSNNFilterNode *filter in _filters) {
        [filter charon_mps_setDevice:self.device];
        NSMutableArray *bound = [NSMutableArray array];
        MPSImage *first = nil;
        for (MPSNNImageNode *sourceNode in filter.charon_mps_sourceNodes) {
            MPSImage *image = sourceNode.charon_mps_image;
            if (image)
                [bound addObject:image];
            if (!first)
                first = image;
        }
        [filter charon_mps_setSourceImages:bound];

        MPSImageDescriptor *sourceDescriptor = [first charon_mps_descriptor];
        if (!sourceDescriptor) {
            CharonMPSRefuse(@"%@: the node's source holds no image, so it was not run",
                            NSStringFromClass([filter class]));
            continue;
        }
        MPSImageDescriptor *destinationDescriptor = [filter charon_mps_destinationDescriptorForSource:sourceDescriptor];
        if (!destinationDescriptor) {
            CharonMPSRefuse(@"%@: the node has no shape to produce, so it was not run",
                            NSStringFromClass([filter class]));
            continue;
        }
        MPSImage *destination = [[MPSImage alloc] initWithDevice:self.device imageDescriptor:destinationDescriptor];
        [filter charon_mps_setDestinationImage:destination];
        [filter charon_mps_encodeToCommandBuffer:commandBuffer];
    }

    MPSNNImageNode *result = _order.lastObject;
    if (!_resultImageIsNeeded || !result)
        return nil;
    return result.charon_mps_image;
}

- (MPSImage *)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                      sourceImages:(NSArray<MPSImage *> *)sourceImages
                      sourceStates:(NSArray<MPSState *> *)sourceStates
                intermediateImages:(NSMutableArray<MPSImage *> *)intermediateImages
                 destinationStates:(NSMutableArray<MPSState *> *)destinationStates
{
    MPSImage *image = [self encodeToCommandBuffer:commandBuffer sourceImages:sourceImages];
    if (intermediateImages) {
        for (MPSNNImageNode *node in _order) {
            if (node.exportFromGraph && node.charon_mps_image)
                [intermediateImages addObject:node.charon_mps_image];
        }
    }
    (void)sourceStates;
    (void)destinationStates;
    return image;
}

- (MPSImage *)executeAsyncWithSourceImages:(NSArray<MPSImage *> *)sourceImages
                         completionHandler:(MPSNNGraphCompletionHandler)handler
{
    id<MTLDevice> device = self.device ? self.device : MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    if (!commandBuffer) {
        CharonMPSRefuse(@"MPSNNGraph: no command buffer could be made for the graph's device, so it was not run");
        if (handler)
            handler(nil, [NSError errorWithDomain:@"MPSNNGraph" code:1 userInfo:nil]);
        return nil;
    }
    MPSImage *image = [self encodeToCommandBuffer:commandBuffer sourceImages:sourceImages];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    if (handler)
        handler(image, commandBuffer.error);
    return image;
}

@end

#pragma clang diagnostic pop
