// CharonMPSNN.h - the edges the graph's nodes share, under names of their own.
//
// Nothing here is a name an SDK header declares. The release reaches a node's sources, a node's kernel
// and a node's result through its own internal tables, and a graph in this port needs the same three edges
// under names of its own; MPSNNPadding is the one exception and it is a real protocol, declared by
// MPSNeuralNetworkTypes.h and CONFORMED to by MPSNNDefaultPadding, which is what emits its metadata.
//
// Every selector is prefixed, so a class the release also carries is not shadowed, and every function is
// static, so no backport file depends on another one's symbols - the same rule CharonMPSImage.h:6-8 gives
// and the same reason: a file whose exports a band's release already has is left out of that band, so a
// shared C function defined in a file that implements a class is an undefined symbol in later bands only.
//
// THE THREE FILES THIS HEADER IS SPREAD ACROSS, and why there are three:
//
//   MPSNNGraph11.m        MPSNNGraph and the ten classes the export ladder places at 11.0
//   MPSNNFilterNode12.m   MPSNNFilterNode, at 12.0
//   MPSNNGraphNodes16.m   MPSNNStateNode, MPSNNBinaryArithmeticNode and MPSCNNPoolingNode, at 16.0
//
// The split is by what a client can BIND, which is what backports.lua's measured_names()/releases_in()
// measure and what tools/cache-index/first-rung.lua does not: a class can be present in a release's ObjC
// inventory and its class symbol still in no export trie of that release, and a client cannot link against
// what is not exported. Measured with dyld.load + dyld.exported_at over the held ladder, armv7 preferred,
// and the placement is the EARLIEST of the class symbol and the metaclass symbol, which is what
// backports.lua:2368-2377 does:
//
//   11.0  MPSNNGraph MPSNNImageNode MPSNNDefaultPadding MPSNNAdditionNode MPSNNSubtractionNode
//         MPSNNMultiplicationNode MPSNNDivisionNode MPSNNConcatenationNode MPSCNNPoolingAverageNode
//         MPSCNNPoolingMaxNode
//   12.0  MPSNNFilterNode
//   16.0  MPSNNStateNode MPSNNBinaryArithmeticNode MPSCNNPoolingNode
//
// All fourteen agree on class and metaclass, so the earliest is the class's own.
//
// MPSNNFilterNode is the SUPERCLASS of seven of the other thirteen and lands in a LATER object than they
// do, which reads backwards and is Apple's own export history: the base is exported by no image until
// 12.0 and its subclasses from 11.0. That is fine here and it is not a hierarchy built at runtime: the
// subclasses reference the base as a link-time symbol, and a band that keeps the 11.0 object also keeps
// the 12.0 and 16.0 ones, so the reference resolves in the same dylib. It is the same way main's other MPS
// objects already reference CharonMPS classes across files.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPSNNImageNode (CharonMPSNN)
// The image the walk bound to this position. A node holds its position and the image currently there;
// the release keeps the same pair in its own node table and the graph walks the nodes, not the images.
- (MPSImage *)charon_mps_image;
- (void)charon_mps_setImage:(MPSImage *)image;
@end

@interface MPSNNStateNode (CharonMPSNN)
- (MPSState *)charon_mps_state;
- (void)charon_mps_setState:(MPSState *)state;
@end

// An MPSImage's own shape as a descriptor. MPSImage carries its shape as width, height, featureChannels
// and numberOfImages (MPSImage.h:402-417) and has no descriptor property of its own, and a graph has to
// size one node's result from the shape of the node it reads. So the descriptor is made here, in the one
// place that does it, from the four properties the image already answers - it is the shape, and not an
// object with a lifetime of its own.
@interface MPSImage (CharonMPSNN)
- (MPSImageDescriptor *)charon_mps_descriptor;
@end

@interface MPSNNFilterNode (CharonMPSNN)
// THIS PACKAGE'S OWN WAY INTO A NODE, because MPSNNFilterNode's -init is NS_UNAVAILABLE in the header
// (MPSNNGraphNodes.h:341) and the release refuses to build one by name. It is declared here rather than
// only defined in MPSNNFilterNode12.m because every subclass in MPSNNGraph11.m and MPSNNGraphNodes16.m
// reaches it with [super initWithDevice:] and those are different objects.
//
// THE DEVICE IS _Nullable AND nil IS A REAL STATE, not a stand-in. A caller wires the filters BEFORE the
// graph exists - MPSNNGraph.h:64-68, the constructor walks backwards from a result node - so a node is
// built when there is no graph and therefore no device to name. The device arrives with the walk, which
// calls -charon_mps_setDevice: before the first encode, and a node whose kernel is asked for before then
// gets one against MTLCreateSystemDefaultDevice(). Declaring the parameter nonnull would have said a node
// cannot be built without a device, which is the opposite of how a graph is assembled, and clang said so
// at all three [super initWithDevice:nil] calls in MPSNNGraph11.m and MPSNNGraphNodes16.m.
- (instancetype)initWithDevice:(nullable id<MTLDevice>)device;

// The node's sources, in the order its kernel reads them, and the one result image it produces.
- (NSArray<MPSNNImageNode *> *)charon_mps_sourceNodes;
- (void)charon_mps_setSourceNodes:(NSArray<MPSNNImageNode *> *)nodes;
// Add one source to a node that is being built, which is how every subclass in this header's users wires
// itself: the sources are the node's own edge to the nodes it reads, and there is no other way in.
- (void)charon_mps_addSourceNode:(MPSNNImageNode *)node;
// The kernel the node stands for, and the images bound to it for one encode.
- (MPSKernel *)charon_mps_kernel;
- (MPSImage *)charon_mps_sourceImageAtIndex:(NSUInteger)index;
- (void)charon_mps_setSourceImages:(NSArray<MPSImage *> *)images;
- (MPSImage *)charon_mps_destinationImage;
- (void)charon_mps_setDestinationImage:(MPSImage *)image;
// The shape the result takes, given the shape the source takes. The graph asks every node for this before
// any encode, because the intermediate images are allocated up front and a walk that discovered a shape
// halfway through would have nothing to allocate into.
- (MPSImageDescriptor *)charon_mps_destinationDescriptorForSource:(MPSImageDescriptor *)source;
// The device the node's kernel is made against. An MPSImageArithmetic initialiser takes one and the port's
// kernels do no Metal work with it, so it is the device the graph runs on and nothing else.
- (void)charon_mps_setDevice:(id<MTLDevice>)device;
- (id<MTLDevice>)charon_mps_device;
// Which filter produced a given result node. It is a class method and not a C function because the graph's
// walk (MPSNNGraph11.m) and the result-node maker (MPSNNFilterNode12.m) are in DIFFERENT objects and a C
// function shared across two backport files is the trap AGENTS.md names under "A C function shared
// between backport files"; an Objective-C message across them is the route that rule asks for.
+ (NSMapTable *)charon_mps_producers;
// This node's share of one encode. The base class has no kernel and says so once; a real node runs its
// own kernel here.
- (void)charon_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
@end

// The two node bases whose concrete subclasses sit in a DIFFERENT object, so each subclass's one-line
// difference has to be declared where the base is declared or the override is invisible at the call site.
@interface MPSNNBinaryArithmeticNode (CharonMPSNN)
+ (Class)charon_mps_kernelClass;
@end

@interface MPSCNNPoolingNode (CharonMPSNN)
+ (Class)charon_mps_kernelClass;
@end

// THE PADDING ARITHMETIC IS THE HEADER'S OWN, NOT A GUESS. MPSNeuralNetworkTypes.h:379-431 gives the two
// formulas in full, as the code a padding policy is expected to write. They are transcribed below one for
// one, including the `style * (filterWindowSize - 1)` term that separates the three size policies from
// each other and the `readSize = (destSize-1)*stride + filterWindowSize` term that is what makes the
// offset negative for a centred window. An offset invented here would move every kernel's output by a
// pixel, and the pooling table in Cnn.md is measured in whole pixels. The host case extracts that C block
// from the header itself, compiles it and compares it with the two functions below over every shape, so
// what it compares is the header's compiled code and not a restatement of it.
//
// The three size policies MPSNNPaddingMethodSize* names, as the coefficient the header's own DestSize
// formula takes. MPSNeuralNetworkTypes.h:397-401 gives `sourceSize += style * (filterWindowSize - 1)`
// with StyleValidOnly = -1, StyleSame = 0 and StyleFull = 1, and MPSNeuralNetworkTypes.h:339-341 puts the
// three policies in bits 4 and 5 as 0, 1<<4 and 2<<4. The coefficient is therefore the BITS MINUS ONE,
// and that subtraction is the whole of the translation: without it a ValidOnly window reads one wider
// than the source and a Full one reads three narrower.
//
// MEASURED, and by the header's own code rather than by a restatement of it: the host case extracts the C
// block from MPSNeuralNetworkTypes.h, compiles and runs it, and compares its DestSize and Offset with the
// two functions below over every shape from 1 to 32 sources, strides 1-4 and windows 1-5, in all three
// policies. This line was `bits` rather than `bits - 1` and every ValidOnly and Full shape disagreed.
static inline long CharonMPSNNDestSize(long sourceSize, long stride, long filterWindowSize, MPSNNPaddingMethod method)
{
    long style = (long)((method >> 4) & 0x3) - 1;
    long size = sourceSize + style * (filterWindowSize - 1);
    return (size + stride - 1) / stride;   // "sourceSize / stride, round up" - the header's own words
}

static inline long CharonMPSNNReadSize(long destinationSize, long stride, long filterWindowSize)
{
    return (destinationSize - 1) * stride + filterWindowSize;
}

// The offset in one dimension, MPSNeuralNetworkTypes.h:411-431 verbatim in structure: the correction
// from the window's left edge to its centre, the destination size that correction is measured against,
// the extent a walk must read to fill that destination, how much of that extent the source does not
// have, and how much of the shortfall lands on the left. The header's own centeringPolicy is 0, which
// pads the bottom right when the kernel size is even (:388), and that is the plain division by two
// below with no rounding correction.
static inline long CharonMPSNNOffset(long sourceSize, long stride, long filterWindowSize, MPSNNPaddingMethod method)
{
    long correction = filterWindowSize / 2;
    long destinationSize = CharonMPSNNDestSize(sourceSize, stride, filterWindowSize, method);
    long readSize = CharonMPSNNReadSize(destinationSize, stride, filterWindowSize);
    long extraSize = readSize - sourceSize;
    long leftExtraPixels = (extraSize + 0) / 2;   // centeringPolicy 0: the leftover goes bottom/right
    return correction - leftExtraPixels;
}

NS_ASSUME_NONNULL_END
