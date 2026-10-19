// MPSNNStateNode, MPSNNBinaryArithmeticNode and MPSCNNPoolingNode - the three of this graph's node
// classes that the export ladder places at 16.0.
//
// ONE OBJECT FOR ONE RELEASE, and the release is 16.0. Each of the three is in the arm64 cache of the
// 11.0 release's own inventory - MPSNNStateNode with six instance selectors, MPSNNBinaryArithmeticNode and
// MPSCNNPoolingNode both with MPSNNFilterNode as their superclass - and each of the three is in NO image's
// export trie at 11.0 or at 12.0. What a client can bind is what backports.lua's
// measured_names()/releases_in() place a name at, and for these three that is 16.0. Measured with
// dyld.load + dyld.exported_at over the held ladder (armv7 preferred), class symbol and metaclass symbol
// agreeing for all three:
//
//   11.0  MPSNNStateNode: no image    12.0: no image    16.0: MPSNeuralNetwork
//   11.0  MPSNNBinaryArithmeticNode: no image    12.0: no image    16.0: exported
//   11.0  MPSCNNPoolingNode: no image    12.0: no image    16.0: exported
//
// ALL THREE ARE SUPERCLASSES OR BASES OF CLASSES THAT ARRIVE EARLIER, which is the same export history
// MPSNNFilterNode12.m records and costs nothing here: the hierarchy is not built by name at runtime, a
// subclass names its superclass as a link-time symbol, and a band that keeps an 11.0 object keeps this
// one too.
//
// WHY THESE THREE AND NOT OTHERS. The graph's fourteen classes land at three releases and this is the
// largest of the three groups:
//
//   11.0  MPSNNGraph MPSNNImageNode MPSNNDefaultPadding MPSNNAdditionNode MPSNNSubtractionNode
//         MPSNNMultiplicationNode MPSNNDivisionNode MPSNNConcatenationNode MPSCNNPoolingAverageNode
//         MPSCNNPoolingMaxNode                          -> MPSNNGraph11.m
//   12.0  MPSNNFilterNode                              -> MPSNNFilterNode12.m
//   16.0  MPSNNStateNode MPSNNBinaryArithmeticNode MPSCNNPoolingNode   -> this file
//
// The grouping is by the EARLIEST of the class symbol and the metaclass symbol, which is what
// backports.lua:2368-2377 does - "A name arrives with the first of its symbols" - and for all fourteen
// the two agree, so the earliest is the class's own. Grouping by the class symbol alone would have been
// luck rather than method.
//
// WHAT EACH IS:
//
//   MPSNNStateNode      the graph's state POSITION, of which this port's graph carries none -
//                       MPSNNGraph.h:183-184 has the source states be the MPSState objects the caller
//                       passes in. The class is still built, because it is the base of the 12.0 gradient
//                       half this object does not carry and a caller holding an MPSNNStateNode* needs the
//                       base to exist.
//   MPSNNBinaryArithmeticNode   the base of the four elementwise operations, over the two images
//                       MPSImageMath.h:34-37 names. Each subclass names one MPSImage kernel and nothing
//                       else; the four subclasses are in MPSNNGraph11.m.
//   MPSCNNPoolingNode   an abstract base that "does not correspond with any particular MPSCNNKernel"
//                       (MPSNNGraphNodes.h:1467-1471). The two 11.0 subclasses are in MPSNNGraph11.m.
//
// TWO METHODS OF MPSNNBinaryArithmeticNode'S OWN @interface (MPSNNGraphNodes.h:2136-2216) are NOT
// implemented here, and both are the training half: `-gradientClass` at :2158 and
// `-gradientFiltersWithSources:` at :2162, which carries MPS_AVAILABLE_STARTING ios(11.3) and returns
// MPSNNGradientFilterNode*. Their registry rows are `owed` with that reason.
//
// MPSCNNPoolingNode's four accessors the base declares at :1472-1475 carry ios(12.0) and are NOT here.
// release-split reads band points, and a 12.0 name in a 16.0 object is a second kind of mixed release
// that this object does not have and would not survive a review.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#import "CharonMPSNN.h"

@implementation MPSNNStateNode {
    id<MPSHandle> _handle;
    BOOL _exportFromGraph;
    MPSState *_charonState;
}

@synthesize handle = _handle;
@synthesize exportFromGraph = _exportFromGraph;

- (MPSState *)charon_mps_state { return _charonState; }
- (void)charon_mps_setState:(MPSState *)state { _charonState = state; }

@end


@implementation MPSNNBinaryArithmeticNode {
    MPSKernel *_kernel;
    float _primaryScale, _secondaryScale, _bias, _minimumValue, _maximumValue;
    NSUInteger _primaryStrideInPixelsX, _primaryStrideInPixelsY, _primaryStrideInFeatureChannels;
    NSUInteger _secondaryStrideInPixelsX, _secondaryStrideInPixelsY, _secondaryStrideInFeatureChannels;
}

@synthesize primaryScale = _primaryScale;
@synthesize secondaryScale = _secondaryScale;
@synthesize bias = _bias;
@synthesize minimumValue = _minimumValue;
@synthesize maximumValue = _maximumValue;
@synthesize primaryStrideInPixelsX = _primaryStrideInPixelsX;
@synthesize primaryStrideInPixelsY = _primaryStrideInPixelsY;
@synthesize primaryStrideInFeatureChannels = _primaryStrideInFeatureChannels;
@synthesize secondaryStrideInPixelsX = _secondaryStrideInPixelsX;
@synthesize secondaryStrideInPixelsY = _secondaryStrideInPixelsY;
@synthesize secondaryStrideInFeatureChannels = _secondaryStrideInFeatureChannels;

// The one line the four subclasses differ by, the same shape MPSImageArithmetic13.m uses for its own four:
// a class-level constant naming the operation, and one kernel object holding it. The subclasses are in
// MPSNNGraph11.m and this declaration is in CharonMPSNN.h, because a subclass's override has to be visible
// where the base's call is.
+ (Class)charon_mps_kernelClass { return [MPSImageAdd class]; }

- (instancetype)initWithLeftSource:(MPSNNImageNode *)left rightSource:(MPSNNImageNode *)right
{
    if ((self = [super initWithDevice:nil])) {
        // THE HEADER'S DEFAULTS, and the third thing the differential caught. MPSImageMath.h:31-32 gives the
        // default of primaryScale and secondaryScale as 1.0f, and the default of bias as 0.0f. MPSImageMath.h:34-37
        // applies all three in one expression, with each scale on its own input and the bias added last. An Objective-C float ivar is zero, and a zero scale answers zero however
        // correct the kernel underneath is - which is what this node did until the differential compared
        // it with the same addition run without a graph and got 11 22 33 44 against 0 0 0 0.
        _primaryScale = 1.0f;
        _secondaryScale = 1.0f;
        _bias = 0.0f;
        _minimumValue = -FLT_MAX;
        _maximumValue = FLT_MAX;
        [self charon_mps_addSourceNode:left];
        [self charon_mps_addSourceNode:right];
    }
    return self;
}

+ (instancetype)nodeWithLeftSource:(MPSNNImageNode *)left rightSource:(MPSNNImageNode *)right
{
    return [[self alloc] initWithLeftSource:left rightSource:right];
}

// MPSNNGraphNodes.h:2150, the 11.0 initialiser of the class. "A valid NSArray containing two sources"
// (:2139) is what +nodeWithSources: below refuses against, and this is the same rule one level down: an
// arithmetic node with one operand has no meaning, and an API in this port says so in the log instead of
// answering with a guess. An earlier form of this file had only the +method and left the -initializer
// declared and undefined, so a caller who had the initializer and not the convenience method got an
// unrecognized selector.
- (instancetype)initWithSources:(NSArray<MPSNNImageNode *> *)sourceNodes
{
    if (sourceNodes.count != 2) {
        CharonMPSRefuse(@"%@: an arithmetic node needs exactly two sources and was given %lu, so none was made",
                        NSStringFromClass([self class]), (unsigned long)sourceNodes.count);
        return nil;
    }
    return [self initWithLeftSource:sourceNodes[0] rightSource:sourceNodes[1]];
}

+ (instancetype)nodeWithSources:(NSArray<MPSNNImageNode *> *)sourceNodes
{
    return [[self alloc] initWithSources:sourceNodes];
}

// The kernel, made once and kept, so that two runs of one graph share it and the node carries no second
// copy of the arithmetic. It is made against the node's own device, which the graph sets before the
// first encode; a node asked for its kernel before the graph has run gets one against the system default
// device.
//
// NOT MPSGetPreferredDevice, and the reason is a band, not a preference: that function is defined in
// MPSCommandBuffer16.m, which is the 16.0 object, and a band that leaves a 16.0 file out of its library
// would leave this call without a definition - the trap AGENTS.md names under "A C function shared
// between backport files". MPSCommandBuffer16.m:9-16 answers MTLCreateSystemDefaultDevice() for every
// combination of MPSDeviceOptions anyway ("This port has one device and no removable or low-power choice
// among several, so the options have nothing to choose between"), so calling it here would be the same
// value by a route one band cannot take.
//
// The initialiser is sent to the CONCRETE class, whose own declaration it is: MPSImageMath.h:112/:132/
// :152/:172 declare -initWithDevice: on MPSImageAdd, MPSImageSubtract, MPSImageMultiply and
// MPSImageDivide, and MPSImageMath.h:92 marks only the BASE unavailable, to say it is never built
// directly. This is the same reach MPSImageArithmetic13.m uses to build its own four.
- (MPSKernel *)charon_mps_kernel
{
    if (!_kernel) {
        id<MTLDevice> device = [self charon_mps_device];
        if (!device)
            device = MTLCreateSystemDefaultDevice();
        _kernel = [[[self class] charon_mps_kernelClass] alloc];
        _kernel = [_kernel initWithDevice:device];
    }
    return _kernel;
}

// The whole class, MPSNNGraphNodes.h:144-145 (addition), :148-149 (difference) and :151-152 (product).
- (void)charon_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    MPSImage *primary = [self charon_mps_sourceImageAtIndex:0];
    MPSImage *secondary = [self charon_mps_sourceImageAtIndex:1];
    MPSImage *destination = [self charon_mps_destinationImage];
    if (!primary || !secondary || !destination) {
        CharonMPSRefuse(@"%@: an arithmetic node needs two sources and a destination and was not given all three",
                        NSStringFromClass([self class]));
        return;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    // The scales, the strides, the bias and the clamp are the kernel's own members, so they are handed
    // straight across and the operation runs where the rest of this package runs it - one walk, one
    // store, one place the arithmetic lives.
    // The kernel is made HERE, not in the initialiser: a node is built before the graph runs, and the
    // device the kernel is made against is the graph's, which does not exist yet at build time.
    [self charon_mps_kernel];
    MPSImageArithmetic *kernel = (MPSImageArithmetic *)_kernel;
    kernel.primaryScale = self.primaryScale;
    kernel.secondaryScale = self.secondaryScale;
    kernel.bias = self.bias;
    kernel.minimumValue = self.minimumValue;
    kernel.maximumValue = self.maximumValue;
    kernel.primaryStrideInPixels = MTLSizeMake(self.primaryStrideInPixelsX, self.primaryStrideInPixelsY,
                                               self.primaryStrideInFeatureChannels);
    kernel.secondaryStrideInPixels = MTLSizeMake(self.secondaryStrideInPixelsX, self.secondaryStrideInPixelsY,
                                                 self.secondaryStrideInFeatureChannels);
    [kernel encodeToCommandBuffer:commandBuffer
                     primaryImage:primary
                   secondaryImage:secondary
                destinationImage:destination];
    [self.resultImage charon_mps_setImage:destination];
}

@end


// The pooling base. Same shape as the arithmetic base above and for the same reason: it stands for a
// kernel this package already carries (MPSCNNPooling10.m), so the graph runs the kernel and the node
// carries the window the kernel walks. MPSCNNPooling.h's divisor is the window's AREA whatever of it lies
// outside the image, and facts/MetalPerformanceShaders/Cnn.md carries the measured table for that over a
// 3x3 source and a 2x2 window; this object does not restate that arithmetic, it hands the window to the
// kernel that has it.
@implementation MPSCNNPoolingNode {
    // Typed as the CONCRETE class rather than MPSKernel, because the initialiser this node sends is
    // declared on MPSCNNPoolingAverage (:488) and MPSCNNPoolingMax (:758) and marked unavailable only on
    // the MPSCNNPooling base (:71). Naming the base here would name the unavailable one.
    MPSCNNPooling *_kernel;
    NSUInteger _kernelWidth, _kernelHeight, _strideX, _strideY;
}

+ (Class)charon_mps_kernelClass { return nil; }

- (instancetype)initWithSource:(MPSNNImageNode *)sourceNode
                  kernelWidth:(NSUInteger)kernelWidth
                 kernelHeight:(NSUInteger)kernelHeight
              strideInPixelsX:(NSUInteger)strideX
              strideInPixelsY:(NSUInteger)strideY
{
    if ((self = [super initWithDevice:nil])) {
        _kernelWidth = kernelWidth ? kernelWidth : 1;
        _kernelHeight = kernelHeight ? kernelHeight : 1;
        _strideX = strideX ? strideX : 1;
        _strideY = strideY ? strideY : 1;
        [self charon_mps_addSourceNode:sourceNode];
    }
    return self;
}

- (instancetype)initWithSource:(MPSNNImageNode *)sourceNode filterSize:(NSUInteger)size
{
    return [self initWithSource:sourceNode kernelWidth:size kernelHeight:size strideInPixelsX:size strideInPixelsY:size];
}

- (instancetype)initWithSource:(MPSNNImageNode *)sourceNode filterSize:(NSUInteger)size stride:(NSUInteger)stride
{
    return [self initWithSource:sourceNode kernelWidth:size kernelHeight:size strideInPixelsX:stride strideInPixelsY:stride];
}

+ (instancetype)nodeWithSource:(MPSNNImageNode *)sourceNode filterSize:(NSUInteger)size
{
    return [[self alloc] initWithSource:sourceNode filterSize:size];
}

+ (instancetype)nodeWithSource:(MPSNNImageNode *)sourceNode filterSize:(NSUInteger)size stride:(NSUInteger)stride
{
    return [[self alloc] initWithSource:sourceNode filterSize:size stride:stride];
}

- (MPSKernel *)charon_mps_kernel
{
    if (!_kernel) {
        Class kernelClass = [[self class] charon_mps_kernelClass];
        // The abstract base names no kernel, so a caller who built one gets the refusal and no image
        // rather than a window over nothing. MPSCNNPooling's own -initWithDevice: is unavailable for the
        // same reason the header gives at MPSCNNPooling.h: the base is not built directly.
        if (!kernelClass)
            return nil;
        id<MTLDevice> device = [self charon_mps_device];
        if (!device)
            device = MTLCreateSystemDefaultDevice();
        // The initialiser is sent to the CONCRETE class, whose own declaration it is:
        // MPSCNNPooling.h:488 declares it on MPSCNNPoolingAverage and :758 on MPSCNNPoolingMax as their
        // NS_DESIGNATED_INITIALIZER, and only the BASE at :71 marks it unavailable, to say the base is
        // never built directly. This is the same reach MPSImageArithmetic13.m and MPSImageWalk13.m use.
        _kernel = [kernelClass alloc];
        _kernel = [_kernel initWithDevice:device
                              kernelWidth:_kernelWidth
                             kernelHeight:_kernelHeight
                            strideInPixelsX:_strideX
                            strideInPixelsY:_strideY];
    }
    return _kernel;
}

- (void)charon_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    MPSImage *source = [self charon_mps_sourceImageAtIndex:0];
    MPSImage *destination = [self charon_mps_destinationImage];
    if (!source || !destination) {
        CharonMPSRefuse(@"%@: a pooling node needs a source and a destination and was not given both",
                        NSStringFromClass([self class]));
        return;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    MPSCNNPooling *kernel = (MPSCNNPooling *)[self charon_mps_kernel];
    if (!kernel) {
        CharonMPSRefuse(@"%@: no pooling kernel to run, so it was not run", NSStringFromClass([self class]));
        return;
    }
    // The window arithmetic is the kernel's own - MPSCNNPooling.h and the measured table in Cnn.md - so
    // the node passes its two images through and does not repeat a divisor here.
    [kernel encodeToCommandBuffer:commandBuffer sourceImage:source destinationImage:destination];
    [self.resultImage charon_mps_setImage:destination];
}

@end

#pragma clang diagnostic pop
