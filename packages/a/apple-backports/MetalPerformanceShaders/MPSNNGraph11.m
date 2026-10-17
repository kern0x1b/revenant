// MPSNNGraph and the ten of its node classes that the export ladder places at iOS 11.0.
//
// ONE OF THREE OBJECTS, and the split is by what a client can BIND, which is what
// backports.lua's measured_names()/releases_in() measure. A class can be present in a release's ObjC
// inventory and its class symbol in no export trie of that release, and a client cannot link against what
// is not exported - so the release the gate places a name at is the first release that EXPORTS it, and
// that is what this file is named for. Measured with dyld.load + dyld.exported_at over the held ladder,
// armv7 preferred, taking the EARLIEST of the class symbol and the metaclass symbol as
// backports.lua:2368-2377 does:
//
//   MPSNNGraph11.m        11.0   MPSNNGraph MPSNNImageNode MPSNNDefaultPadding MPSNNAdditionNode
//                                MPSNNSubtractionNode MPSNNMultiplicationNode MPSNNDivisionNode
//                                MPSNNConcatenationNode MPSCNNPoolingAverageNode MPSCNNPoolingMaxNode
//   MPSNNFilterNode12.m   12.0   MPSNNFilterNode
//   MPSNNGraphNodes16.m   16.0   MPSNNStateNode MPSNNBinaryArithmeticNode MPSCNNPoolingNode
//
// All fourteen agree on class and metaclass, so the earliest is the class's own. `first-rung.lua` answers
// 11.0 for all fourteen and is right about the CLASSES and wrong about what a link needs: it reads the
// names file, which build.py:8 writes with `strings -a <cache> | grep -xF NAME`, so it finds a class that
// is in the cache and absent from its export trie. That is the difference this split rests on, and
// MPSNNFilterNode12.m and MPSNNGraphNodes16.m each carry their own measurement.
//
// WHAT THIS FILE IS. The graph itself, the padding policy, the elementwise filter nodes, the
// concatenation node, and the two concrete pooling nodes. Their BASES - MPSNNFilterNode,
// MPSNNBinaryArithmeticNode, MPSCNNPoolingNode - are in the two later objects, and each of those bases is
// the superclass of classes that arrive earlier, which is Apple's export history rather than a hierarchy
// built by name at runtime: a subclass names its superclass as a link-time symbol and a band that keeps
// this object keeps those too.
//
// WHAT THE RELEASE'S OWN HEADERS SAY, and this file follows them rather than the earlier form of it:
//
//   * Five of the six `+paddingFor...` methods the earlier form defined are declared by NO Apple header.
//     MPSNNDefaultPadding declares four methods, in the SDKs of both 16.4 and 26.2: +paddingWithMethod:,
//     -label, and the two +paddingForTensorflow... . The five that are gone -
//     +paddingForTensorflowMaxPooling, +paddingForTensorflowConvolution, +paddingForCaffePooling,
//     +paddingForCaffeConvolution and +paddingForMXNetPadding - answer nothing to a grep over either
//     SDK's MetalPerformanceShaders headers. The earlier comment claimed the header "names" six pre-rolled
//     policies. A public class method no release ever had is API the port would be inventing.
//   * +paddingForTensorflowAveragePooling (MPSNeuralNetworkTypes.h:497) and
//     +paddingForTensorflowAveragePoolingValidOnly (:500) carry ios(11.3), and -inverse (:455) carries
//     the same date, so none of the three is here.
//   * The size policies are the header's own DestSize and Offset, transcribed in CharonMPSNN.h one for
//     one, and the coefficient is the size BITS MINUS ONE (`:339-341` declares ValidOnly 0, Same 1<<4,
//     Full 2<<4 and `:397-401` wants -1, 0, 1).
//
// THE -Wincomplete-implementation PAIRS THAT REMAIN HERE are the two for the classes in this file that
// declare methods they do not carry: MPSNNDefaultPadding's two ios(11.3) +paddingForTensorflow... and
// MPSNNGraph's eight. Each is a push/ignored/pop around one @implementation with its own list of names,
// header lines and releases - not a file-wide `#pragma clang diagnostic ignored` with no record of what
// it hides. The other two pairs moved with their classes.
//
// WHY THE GRAPH RUNS AT ALL ON iOS 6: nothing here needs Metal. MPSNNGraph walks the node graph it was
// given, and each node's encode runs the kernel object the node holds - an MPSImageAdd, a pooling
// kernel - over host memory behind an MTLBuffer, which is the path every other MPS kernel in this
// package takes (facts/MetalPerformanceShaders/Cnn.md). The graph adds the walk, the shape arithmetic and
// the intermediate-image lifetime. It adds no arithmetic of its own that a kernel does not already do.
//
// NOT CLAIMED: a concatenation of two or more sources. MPSNNGraphNodes.h:2443-2446 pads EACH source out to
// a multiple of four channels, so two one-channel sources make an eight-channel destination, and
// MPSImage13.m holds one, two and four channels and refuses the rest. That limit is MPSImage's row.
//
// WHAT IS NOT CLAIMED HERE AND WHY is listed at each class, where the warning for it is turned off.

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
    // The header's own defaults, MPSNNGraphNodes.h:174/:182/:205: format None so that MPS picks, the
    // temporary image's allocator, and no export.
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

// An MPSImage's own shape, as a descriptor: the four properties MPSImage.h:402-417 declares, and the
// channel format the image already answers as its own featureChannelFormat (MPSImage.h:452).
//
// The format is read from that property rather than derived from the pixel formats, and an earlier form
// of this function switched over the pixel formats itself. That is a second copy of a table MPSImage
// already holds, and it was wrong for every image of more than one channel: the pixel format of a
// four-channel float image is RGBA32Float, which that switch did not name, so the descriptor came back
// with MPSImageFeatureChannelFormatNone, the destination image was allocated with no element size, and
// the concatenation case refused with "the destination's channel format names no element size". MPSImage
// is the image's own answer and does not need a second one.
- (MPSImageDescriptor *)charon_mps_descriptor
{
    MPSImageDescriptor *descriptor = [MPSImageDescriptor new];
    descriptor.width = self.width;
    descriptor.height = self.height;
    descriptor.featureChannels = self.featureChannels;
    descriptor.numberOfImages = self.numberOfImages;
    descriptor.channelFormat = self.featureChannelFormat;
    // MPSImage carries no cache mode, storage mode or usage of its own in this surface (MPSImage.h:402-452
    // names width, height, featureChannels, numberOfImages, textureType, pixelFormat, precision, usage and
    // featureChannelFormat), so the descriptor keeps the defaults its own class sets rather than a second
    // guess at what the image is.
    return descriptor;
}

@end


// The header's class declares four methods and this implements the two 11.0 ones,
// `+paddingWithMethod:` and `-label`, plus the two coding methods MPSNNPadding's own base list requires.
// It does NOT implement `+paddingForTensorflowAveragePooling` or `+paddingForTensorflowAveragePoolingValidOnly`
// (MPSNeuralNetworkTypes.h:497/:500), because both carry MPS_AVAILABLE_STARTING ios(11.3) and an 11.3 name
// here is the mixed release this object exists to avoid. Nor does it implement `-inverse`
// (MPSNeuralNetworkTypes.h:455), which carries the same ios(11.3); the registry row
// `-[MPSNNPadding inverse]` already says introduced 11.3.
//
// Nor does it implement any other `+paddingFor...`: an earlier form of this file carried six, and five of
// them - `+paddingForTensorflowMaxPooling`, `+paddingForTensorflowConvolution`, `+paddingForCaffePooling`,
// `+paddingForCaffeConvolution` and `+paddingForMXNetPadding` - are declared by NO Apple header. Checked
// in both SDKs on this machine, 16.4 and 26.2:
//
//   grep -rn 'paddingForCaffePooling\|paddingForMXNetPadding\|paddingForCaffeConvolution' \
//       .../MetalPerformanceShaders.framework/Frameworks/*/Headers/
//
// answers nothing in either. A public class method that no release ever had is API the port invented, and
// five of them is worse than one.
//
// So the -Wincomplete-implementation this suppresses is exactly two names, both ios(11.3):
//   +paddingForTensorflowAveragePooling            MPSNeuralNetworkTypes.h:497
//   +paddingForTensorflowAveragePoolingValidOnly   MPSNeuralNetworkTypes.h:500
// -inverse at :455 is a third ios(11.3) name and clang does not ask for it because the protocol declares
// it @optional; it is left out for the same reason and the registry row says why.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSNNDefaultPadding {
    MPSNNPaddingMethod _paddingMethod;
    NSString *_label;
}

// -label is declared @optional on MPSNNPadding (MPSNeuralNetworkTypes.h:373) as a METHOD, not as a
// property, so there is no declaration for @synthesize to point at and it is written out here. A policy
// made by +paddingWithMethod: answers the label the release writes for its method, built from the align,
// remainder and size fields and, for the custom bit, a suffix. Measured on the macOS host (facts/
// MetalPerformanceShaders/MPSNNDefaultPadding.md, "The label of +paddingWithMethod:"): for every one of the
// 64 combinations of the three fields the release answers "<align>, <remainder>, <size>, ", with the align
// value 3 (reserved) answered by nil, so the factory returns nil for it.
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
    // The bit the header calls MPSNNPaddingMethodExcludeEdges (1 << 15) is what the release's label names as
    // the custom policy that inhibits node fusion; the measured suffix has no trailing separator.
    if (method & (1UL << 15))
        label = [label stringByAppendingString:@"MPSNNPaddingMethod.Custom (inhibits node fusion)"];
    return label;
}

// The label is the one +paddingWithMethod: measured above; the TensorFlow subclasses write their own.
- (NSString *)label { return _label; }

+ (instancetype)paddingWithMethod:(MPSNNPaddingMethod)method
{
    // The align field value 3 is reserved, and the release answers nil for it.
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

    // The window and the stride are the kernel's own members, MPSCNNKernel.h:212-219, and a kernel that
    // has none walks a one by one window, which is what the release does for an elementwise node.
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

    // The kernel's offset, which is the other half of what a padding policy decides and the half a
    // caller reads back as the kernel's own -offset property.
    if ([kernel respondsToSelector:@selector(setOffset:)]) {
        MPSOffset offset;
        offset.x = (NSInteger)CharonMPSNNOffset((long)sourceDescriptor.width, (long)strideX, (long)kernelWidth, method);
        offset.y = (NSInteger)CharonMPSNNOffset((long)sourceDescriptor.height, (long)strideY, (long)kernelHeight, method);
        offset.z = 0;
        [(MPSCNNKernel *)kernel setOffset:offset];
    }

    // Built field by field rather than with -[MPSImageDescriptor copy]. Measured: that method as
    // MPSImage13.m writes it is `[[[MPSImageDescriptor allocWithZone:] init] copy]`, which calls itself
    // and dies of stack exhaustion - it is reachable from any caller of -copy on a descriptor and this
    // file is not where that defect is fixed (MPSImage13.m carries the 13.0 API, another object's).
    // So the descriptor is written here, from the source's own fields, and both this and the
    // concatenation below stop depending on a method that does not answer.
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

// NSSecureCoding, which MPSNNPadding's own base list names (MPSNeuralNetworkTypes.h:363). The key is this
// port's, exactly as MPSKernel9.m's `label` key is: the release's own archive keys for a padding policy
// are in no header, and an invented key means an archive this port can read and the release cannot, which
// is the tradeoff MPSKernel9.m:78-82 records and takes for the label. What is round-tripped is the one
// value that makes a policy a policy: the method whose bits the arithmetic above selects.
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


// The arithmetic nodes. Each stands for one of the four MPSImageArithmetic operations this package
// already carries (MPSImageArithmetic13.m), over the same two images and into the same destination, so
// the graph runs them through that kernel rather than repeating the operation here.
//
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


// The concatenation node. MPSNNGraphNodes.h:2438-2449 gives the layout: the channels of the first source fill the output from channel zero, the second source's channels come next, and so on. Each source is first rounded up to whole four-channel groups, so the channel counts M, N and O are multiples of four even when the MPSImage objects are not.
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
    // Every source contributes its own channels, each padded out to a multiple of four, and the sources
    // share the destination's height and width: a concatenation joins channels, not planes.
    //
    // THE SHAPE IS TAKEN FROM THE SOURCES AND NOT FROM `source`, which is the first finding the
    // concatenation case produced. `source` is the descriptor of whatever the node read FIRST, and a
    // concatenation node reads N images, so the walk's `first` is the first of them and its width and
    // height are the ones every source shares; taking the widest and tallest SOURCE rather than seeding
    // from `source` is what makes the answer independent of which source happened to be bound first.
    // Seeded from `source` it was already right, but only because `source` is that same first image -
    // and when no source was bound at all the seed was a zero descriptor, and the destination came back
    // 0x0 over eight channels with nothing in it. Measured, the case above.
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
    // No source bound: nothing to join, and the graph says so at the walk rather than this answering
    // with a zero-sized image a caller would read as an empty result.
    if (!channels || !width || !height)
        return nil;

    // Field by field, for the reason given in -destinationImageDescriptorForSourceImages: above.
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
    // Each source lands in the destination in its own padded channel block, which is the rule the header
    // states. The block boundaries are what the descriptor above computed, so a source of three channels
    // occupies four and the fourth is padding.
    //
    // WHAT GOES IN THE PADDING IS MEASURED AGAINST THE RELEASE, and the measurement corrected the comment
    // this line used to carry. That comment said writing a value there "would be an answer the release does
    // not give" and left the destination as allocated. The release's own MPSNNConcatenationNode, run on
    // this host over 1x1 float images (tests/backports/host/mpsnn, case concat, and the five widths it
    // sweeps), answers:
    //
    //   1 channel + 1 channel  -> 1x1x8 : 1 0 0 1 5 0 0 1
    //   2 + 2                  -> 1x1x8 : 1 2 0 1 5 6 0 1
    //   4 + 4                  -> 1x1x8 : 1 2 3 4 5 6 7 8
    //   1 + 4                  -> 1x1x8 : 1 0 0 1 5 6 7 8
    //   3 + 1                  -> 1x1x8 : 1 2 3 0 5 0 0 1
    //
    // So the release does write there: zeros, and a 1 in the block's fourth channel for a source of one or
    // two channels - and, by the last row, a zero for a source of three. That is why the rule below is
    // stated as it is and not as "the image is RGBA and the alpha is 1": the three-channel row does not
    // agree with that, and MPSImage13.m holds one, two and four channels and refuses the rest, so this
    // object never sees a three-channel source. MPSNNGraphNodes.h:2443-2446 states the COUNT of the
    // padding and says nothing about its value; this is where the value came from.
    NSString *what = NSStringFromClass([self class]);
    NSUInteger offset = 0;
    for (NSUInteger index = 0; index < self.charon_mps_sourceNodes.count; index++) {
        MPSImage *source = [self charon_mps_sourceImageAtIndex:index];
        if (!source)
            continue;
        // Through the same region read and write every MPSImage kernel in this package uses
        // (CharonMPSImage.h:69-75), so a concatenation is the same walk the other kernels are.
        CharonMPSImageLayout inLayout = CharonMPSImageLayoutOf(source);
        CharonMPSImageLayout outLayout = CharonMPSImageLayoutOf(destination);

        // THE BUFFER IS THE DESTINATION'S SIZE, and that is not a detail: CharonMPSImageReadRegion
        // allocates width * height * sourceChannels elements, and the join writes a row of
        // width * destinationChannels into it at a channel offset. With a source of one channel and a
        // destination of four, the buffer is a quarter of the row the write needs and the join walks off
        // the end of it - measured, as a SIGSEGV inside objc_storeStrong on the case above. So the
        // source is read into a buffer of the destination's own row width, and the source's channels
        // are scattered into it from there.
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
        // The measured padding, written into the same buffer the join builds so that the destination is
        // written once with the source's channels and the block's padding together. It is in the one place
        // that knows the block's offset: the release's MPSNNConcatenationNode answers zeros there and a 1
        // in the block's fourth channel for a source of one or two channels - and, by the three-channel row
        // above, a zero for a source of three, which is why this is stated per source and not as "the image
        // is RGBA". outLayout.channels is the destination's own, so the value is placed at the block's
        // index through it and the row is the destination's width, not the source's.
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


// The graph itself. MPSNNGraph walks backwards from the result node to find the nodes it needs, in the
// order the filters depend on each other, and -encodeToCommandBuffer: then walks them forwards.
//
// EIGHT METHODS OF ITS OWN @interface ARE NOT IMPLEMENTED HERE, and every one's date is in the list at
// the top of this file:
//   -readCountForSourceImageAtIndex:                        MPSNNGraph.h:363  ios(12.1)
//   -readCountForSourceStateAtIndex:                        MPSNNGraph.h:375  ios(12.1)
//   -initWithDevice:resultImages:resultsAreNeeded:          MPSNNGraph.h:98   ios(13.0)
//   +graphWithDevice:resultImages:resultsAreNeeded:         MPSNNGraph.h:103  ios(13.0)
//   -encodeBatchToCommandBuffer:sourceImages:sourceStates:intermediateImages:destinationStates:
//                                                          MPSNNGraph.h:264  ios(11.3)
//   -encodeBatchToCommandBuffer:sourceImages:sourceStates:  MPSNNGraph.h:299  no date of its own, and
//       its two arguments are NSArray<MPSImageBatch*>* and NSArray<MPSStateBatch*>*; MPSImageBatch and
//       MPSStateBatch are not in this object's surface and MPSImage's row records that they are not
//       carried at all.
//   -initWithDevice:resultImage:                             MPSNNGraph.h:112  ios(11.0, 11.3) DEPRECATED
//   +graphWithDevice:resultImage:                            MPSNNGraph.h:119  ios(11.0, 11.3) DEPRECATED
// The last two are the pre-11.3 spellings of the two initializers this object does implement, and
// MPSNNGraph.h:113 says to use those instead - "Without this information, too much or too little work may
// occur. Results may be undefined." - which is why the object implements the 11.3 spelling and not these.
//
// `-initWithCoder:device:` (MPSNNGraph.h:128, marked NS_DESIGNATED_INITIALIZER) is NOT overridden here.
// MPSKernel9.m:85 already implements it for every kernel in this package, and it is the right
// implementation for a graph: a graph decoded from an archive has no result node, so its -walkFrom: has
// nothing to start from and its -encodeToCommandBuffer: refuses with that one line rather than answering
// with an image nothing produced. An earlier form of this file overrode it to call the designated
// initializer with a nil result image, which is what -Wobjc-designated-initializers and -Wnonnull both
// objected to, and the override did nothing the inherited one does not.
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

// The walk, MPSNNGraph.h:64-71: the graph constructor starts at the indicated result image, finds the filter node
// that produced it, then follows that node's dependencies, and so on, to reveal the part of the graph needed for the image.
// Nodes not on the way back to a source are left out, which MPSNNGraph.h:60-61 also states: nodes not needed for the result image are ignored.
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
    // A node with no producing filter is a graph INPUT, which is what MPSNNGraphNodes.h:161-163 says the
    // caller's own image nodes are. It becomes a source in the order the walk first meets it, and that is
    // the order MPSNNGraph.sourceImageHandles reports and the order -encodeToCommandBuffer: expects the
    // caller's images in.
    if (!node || [seen containsObject:node])
        return;
    [seen addObject:node];
    // Which filter produced this node - the table, not the list being built, because the filter that
    // produced the node being visited is by definition not in that list yet.
    MPSNNFilterNode *producer = [[MPSNNFilterNode charon_mps_producers] objectForKey:node];
    if (!producer) {
        [_sources addObject:node];
        return;
    }
    // The dependencies first, so a filter is encoded after everything it reads. The visited set is what
    // makes a graph with a cycle terminate rather than recurse forever: MPSNNGraph.h:70-71 says the
    // result node may be interior to the graph, and a caller who wires one into a loop has built a graph
    // the release does not define, which this port refuses to walk rather than running forever.
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
        // MPSNNGraph.h:196: "Default: MPSImageFeatureChannelFormatFloat16", and :189 "Default: NO".
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

// MPSNNGraph.h:128 marks this NS_DESIGNATED_INITIALIZER of this class, and MPSKernel's own designated
// pair is -initWithDevice: (:117) and -initWithCoder:device: (:163), so -Wobjc-designated-initializers
// asks for it here and is right to. It reaches MPSKernel's, which decodes the label and sets the device,
// and it adds nothing of its own because there is nothing of its own to add: an archive written by
// MPSKernel9.m:97 carries a label and nothing else, and the release's own keys for a graph's nodes are in
// no header. So a graph decoded from an archive is a graph with no result node, its -walkFrom: has
// nothing to start from, and its -encodeToCommandBuffer: refuses in one line rather than answering with
// an image nothing produced. That is the whole of what this initializer says, and the comment at
// MPSNNGraph.h:120-127 makes the same point in its own terms: the device an archive will be decoded on cannot be known
// when the file is written, so a guess may be wrong.
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

// A graph of MPSNNFilterNodes over MPSImages produces no states of its own: MPSNNGraph.h:183-184 says the
// source states are the MPSState objects the caller passes in, and this port's nodes run kernels that
// take images, so there is nothing to report and nil is the honest answer rather than an empty array a
// caller would count.
- (NSArray<id<MPSHandle>> *)sourceStateHandles { return nil; }
- (NSArray<id<MPSHandle>> *)intermediateImageHandles { return nil; }
- (NSArray<id<MPSHandle>> *)resultStateHandles { return nil; }
- (id<MPSHandle>)resultHandle { return _order.lastObject.handle; }

@synthesize outputStateIsTemporary = _outputStateIsTemporary;
@synthesize destinationImageAllocator = _destinationImageAllocator;
@synthesize format = _format;
@synthesize resultImageIsNeeded = _resultImageIsNeeded;

// Every node with a data source is told to read it again, MPSNNGraph.h:213-217. A node with no data
// source does not answer the selector and is left as it is; the header says so at :217, where most nodes have
// no data source and so are not changed by the call.
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

    // Bind each graph input to the caller's image, in the order sourceImageHandles reports.
    for (NSUInteger index = 0; index < _sources.count && index < sourceImages.count; index++)
        [_sources[index] charon_mps_setImage:sourceImages[index]];

    // The walk, forwards. Each node's result image is allocated from the shape its padding policy gives
    // for the shape it reads, and each node runs its own kernel over it. A node with no kernel says so
    // once and the walk continues, so one abstract node in the middle does not take the graph with it.
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
        // The header says that with resultIsNeeded set to NO, the -encode call hands back nil for the last image,
        // and the computation for that image may be pruned away (MPSNNGraph.h:72).
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
    // The exported intermediates, MPSNNGraph.h:239-243: only the nodes tagged exportFromGraph, and only
    // when the caller asked for the list to receive them.
    if (intermediateImages) {
        for (MPSNNImageNode *node in _order) {
            if (node.exportFromGraph && node.charon_mps_image)
                [intermediateImages addObject:node.charon_mps_image];
        }
    }
    // A graph of this package's nodes produces no states, so there are none to put in either list; a
    // caller that passed a non-nil destinationStates gets it left empty rather than nil, which is what
    // "optional NSMutableArray to receive" means for a graph that has nothing to receive.
    (void)sourceStates;
    (void)destinationStates;
    return image;
}

// The header's description (MPSNNGraph.h:305-311): the call runs the graph's encoding synchronously in a private command buffer,
// commits that buffer to an internal queue, and returns, with the work done on the device that hosts the source
// images.
//
// THE COMMAND BUFFER COMES OFF A QUEUE, and that is the only place one exists: MTLDevice.h:507-518
// declares -newCommandQueue and -newCommandQueueWithMaxCommandBufferCount: and nothing else, and
// -commandBuffer belongs to MTLCommandQueue. An earlier form of this file asked the DEVICE for one with
// `[self.device newCommandBuffer]`, which is not a selector MTLDevice declares, and which does not
// compile - it was hidden behind a file-wide pragma that silenced every warning in the file, and the
// object had therefore never been built for armv7. The route below is the framework's own order: the
// graph's device, then a queue from it, then a buffer from the queue. The queue is made per call because
// MPSNNGraph.h:305 calls the command queue "MPS internal", and this port's MPSKernel9.m and the host case
// both hold no queue of their own.
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
    // The port's own kernels are synchronous and a result is in the image when -encodeToCommandBuffer:
    // returns, so the commit and the wait are a formality here; they are made anyway, because the
    // header's contract is that the data is not valid until this method's completion handler is called
    // and a caller is entitled to that.
    if (handler)
        handler(image, commandBuffer.error);
    return image;
}

@end

#pragma clang diagnostic pop
