// MPSNNFilterNode - the graph's virtual filter base, and the edges every node in a graph shares.
//
// ONE OBJECT FOR ONE RELEASE, and the release is 12.0. Not 11.0, which is where the header puts the class
// (MPSNNGraphNodes.h:338, MPS_CLASS_AVAILABLE_STARTING ios(11.0)) and where the class demonstrably is: it
// is in the arm64 shared cache of the 11.0 release's own inventory, with superclass NSObject and twelve
// instance selectors. What is not there at 11.0 is its EXPORT - `_OBJC_CLASS_$_MPSNNFilterNode` is in no
// image's export trie at 11.0 and first appears at 12.0, and `first_releases` reads the trie, so 12.0 is
// what backports.lua's measured_names()/releases_in() place this class at and therefore what
// `misplaced()` refuses to mix with an 11.0 name. Measured with dyld.load + dyld.exported_at over the held
// ladder (armv7 preferred), the class symbol and the metaclass symbol agreeing:
//
//   11.0  MPSNNFilterNode: exported by NO image          12.0: exported     16.0: exported
//
// THAT MEANS IT IS THE SUPERCLASS OF SEVEN CLASSES THAT ARRIVE EARLIER, which reads backwards and is
// Apple's own export history rather than a defect: MPSNNAdditionNode, MPSNNSubtractionNode,
// MPSNNMultiplicationNode, MPSNNDivisionNode, MPSNNConcatenationNode, MPSCNNPoolingAverageNode and
// MPSCNNPoolingMaxNode are all exported from 11.0 with this base unexported until 12.0. It costs nothing
// here because the hierarchy is not built by name at runtime: a subclass names its superclass as a
// link-time symbol, and a band that keeps an 11.0 object keeps this one too, so the reference resolves in
// the same dylib. The base's own initialiser is what an MPSNNGraph of this port calls, and it is here.
//
// WHAT THE CLASS IS. MPSNNGraphNodes.h:340 names it a virtual base class whose subclasses are the objects to make,
// and :341 marks -init NS_UNAVAILABLE, so the release never builds one by name.
// What this object carries is everything a node in a graph shares: the node's sources, its one result
// image position, the kernel it stands for, the device that kernel is made against, the shape its result
// takes, and the pairing a walk reads to go from a result image back to the filter that produced it.
//
// THE PAIRING IS A CLASS METHOD rather than a C function, and that is a band constraint. A C function
// shared by two backport files is the trap AGENTS.md names: a file whose exports a band's release already
// has is left out of that band, so the call is an undefined symbol in later bands only - backports-gate
// links one band and passes and only the all-band build shows it. An Objective-C message across the two
// objects is the route that rule asks for, and it is why +charon_mps_producers is declared in
// CharonMPSNN.h and implemented here while the walk that reads it is in MPSNNGraph11.m.
//
// WHAT THE -Wincomplete-implementation WARNING IS TURNED OFF FOR, and it is one list and one reason.
//
// MPSNNFilterNode's @interface in MPSNNGraphNodes.h:338-486 declares five methods this object does not
// implement, and every one of them is the training half of the graph:
//
//   -gradientFilterWithSource:                                  :404   returns MPSNNGradientFilterNode*
//   -gradientFilterWithSources:                                 :412   returns MPSNNGradientFilterNode*
//   -gradientFiltersWithSources:                                :420   returns MPSNNGradientFilterNode*
//   -gradientFiltersWithSource:                                 :428   returns MPSNNGradientFilterNode*
//   -trainingGraphWithSourceGradient:nodeHandler:               :466   MPS_AVAILABLE_STARTING ios(12.0)
//
// MPSNNGradientFilterNode is 12.0 by the same export ladder that places this class there, so implementing
// any of the five would put a 12.0 name in a 12.0 object that is otherwise this class - which is fine -
// but the gradient half is not built at all, so the five have nothing to return: MPSNNGradientFilterNode
// is `absent` in the registry and no object in this package defines it. Carrying the five would mean
// carrying that class, which is the 12.0 gradient object and a piece of work of its own; the registry
// rows for the five are `owed` with that reason.
//
// The suppression is push/pop around this one @implementation and names its five methods in the comment
// above, rather than a file-wide `#pragma clang diagnostic ignored` with no record of what it hides. The
// alternative that needs no pragma at all - defining the five - needs the class they return, and neither
// `@dynamic` nor a category on this class silences the warning (measured: clang answers "method definition
// for 'gamma' not found" and "property implementation must have its declaration in interface" for
// `@dynamic gamma;`).
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

// The pairing a walk reads, and it is the whole of the walk: MPSNNGraph.h:64-68 says the constructor
// starts from the indicated result image, finds the filter node that produced it, then follows that node's
// dependencies in turn.
//
// It was the second defect the differential caught, and the defect was WHERE it looked rather than that it
// looked. The walk first searched the list of filters it was building for one whose .resultImage was the
// node being visited - which finds nothing, because the filter that produced that node is by definition
// not in the list yet. Every node then read as a graph input, the graph reported no filters at all, and
// -encodeToCommandBuffer: answered an image nothing had written: all zeros, over the right shape. The
// pairing is registered where the result node is made below, so the walk asks this table rather than the
// list it is filling.
+ (NSMapTable *)charon_mps_producers
{
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMapTable strongToStrongObjectsMapTable];
    });
    return table;
}

// MPSNNFilterNode's -init is NS_UNAVAILABLE in the header, so the release refuses to build one by name.
// Nothing below calls it: every real node reaches NSObject's own -init, which does not re-enter it.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    // This package's own way into a node. -init is unavailable in the header, so this is what a node of
    // this package is built with, and every subclass reaches it with [super initWithDevice:].
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
        // A filter always has exactly one result image position. The header says it is readonly and
        // nonnull (:350), so it is made on first use rather than in an initialiser a caller might not
        // reach - a node built with a result image already made keeps that one, which is what lets a
        // caller wire a graph by hand. The pairing a walk reads is registered here, where the node is
        // made, because the graph does not exist yet: a caller wires the filters first and builds the
        // graph from the last node.
        _resultImageNode = [[MPSNNImageNode alloc] initWithHandle:nil];
        [[[self class] charon_mps_producers] setObject:self forKey:_resultImageNode];
    }
    return _resultImageNode;
}

- (NSArray<MPSNNStateNode *> *)resultStates { return _resultStates; }

- (MPSNNStateNode *)resultState
{
    // "convenience method for resultStates[0]" (MPSNNGraphNodes.h:352), and nil when there are none.
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

// The shape of the result, from the shape of the source. What a padding policy decides is mainly the kernel's
// offset and the output's size (MPSNNGraphNodes.h:361-363). A node with no padding policy keeps its source's shape,
// which is what an elementwise node does - MPSNNArithmetic is a per-pixel operation and its header
// (MPSImageMath.h:34-37) names no spatial term at all.
//
// THE POLICY IS HANDED THE NODE'S OWN IMAGES, not the node. MPSNeuralNetworkTypes.h:449 names the first
// parameter "The list of source images to be used", and an earlier form of this method passed
// `@[ (MPSImage *)self ]` - the NODE - so the policy asked its first argument for its shape and sent
// -charon_mps_descriptor to an MPSNNFilterNode. Nothing caught it, because every case until the one that
// set a paddingPolicy left this branch untaken. It is measured, not reasoned: the host case
// tests/backports/host/mpsnn sets MPSNNPaddingMethodSizeSame on a pooling node and the port build died of
// "-[CharonMPSCNNPoolingAverageNode charon_mps_descriptor]: unrecognized selector sent to instance".
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

// One node's share of a graph encode. The base class carries no kernel, so it refuses once, in the log,
// and the walk carries on to the next node: the release asserts on a graph with an abstract node in it,
// and an API in this port never crashes its caller.
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
