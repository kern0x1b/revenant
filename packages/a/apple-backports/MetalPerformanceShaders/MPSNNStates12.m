// The two MPS states of the iOS 12 surface whose own superclass this package already carries:
// MPSCNNNormalizationMeanAndVarianceState and MPSRNNMatrixTrainingState, from MPSCNNBatchNormalization.h
// and MPSRNNLayer.h of the iPhoneOS 16.4 surface.
//
// ONE OBJECT FOR ONE RELEASE, and both classes are 12.0 by the ladder as well as by their headers -
// MPSCNNBatchNormalization.h:102 and MPSRNNLayer.h:1055 annotate ios(12.0), and the ladder says so too:
//
//   $ printf 'MPSCNNNormalizationMeanAndVarianceState\nMPSRNNMatrixTrainingState\n' \
//       | xmake l tools/cache-index/first-rung.lua
//   MPSCNNNormalizationMeanAndVarianceState   12.0
//   MPSRNNMatrixTrainingState                  12.0
//
// MPSNNPad, which the same surface annotates ios(12.1), is NOT here: no release is held between 12.0 and
// 16.0, so it reads 16.0 on the ladder and is MPSNNPad16.m's object. Their superclasses are carried:
// MPSState by MPSState11.m and MPSKernel by MPSKernel9.m.
//
// WHAT EACH ONE IS, in the headers' own words.
//
//   MPSCNNNormalizationMeanAndVarianceState is the pair of buffers a batch normalization gradient
//     accumulates: mean and variance, each an id<MTLBuffer>, from an initializer that takes them and a
//     class method that allocates them at numberOfFeatureChannels floats each. What FILLS them is the
//     gradient, which is ios(11.3) and another slice's object, so this one allocates and does not compute.
//
//   MPSRNNMatrixTrainingState declares NO member of its own - MPSRNNLayer.h's @interface is @end straight
//     after it (:1055-1056) - so the class exists so that a caller can name the state its training layer
//     hands back, and everything it can do is MPSState's.
//
// WHAT IS NOT CARRIED, and is named in the row rather than discovered later. Three classes of this
// surface are NOT here: MPSCNNYOLOLoss, MPSCNNYOLOSLossDescriptor and MPSRNNMatrixTrainingLayer. Each one
// declares a property whose TYPE is a class this package does not build - MPSCNNLoss, MPSCNNLossDescriptor
// and MPSRNNDescriptor respectively - and a class that reads a property of a class the library does not
// carry cannot be created at all: the runtime fails to make it and the failure takes the whole dylib with
// it. Those three rows say so, each naming the header line that names the missing type and the grep that
// shows nothing here declares it.
//
// WHAT IS NOT CLAIMED. No number in this file is a measurement of Apple's code - the release's own MPS
// cannot run on this host, which facts/MetalPerformanceShaders/Image9.md records. What is written here is
// transcribed from the two headers above; what has been checked is the armv7 build of this directory, that
// every object compiles for armv7 and that a partial link over all of them leaves no MPS class undefined,
// and the commands are in facts/MetalPerformanceShaders/Release12.md.

#import "CharonMPSCnn.h"

@implementation MPSCNNNormalizationMeanAndVarianceState {
    id<MTLBuffer> _mean;
    id<MTLBuffer> _variance;
}

// The initializer that takes the two buffers. Both are strong ivars, so storing one retains it and
// storing another releases the one held, and MPSState's own -init is what makes the state object.
- (instancetype)initWithMean:(id<MTLBuffer>)mean variance:(id<MTLBuffer>)variance
{
    if (!mean || !variance) {
        CharonMPSRefuse(@"MPSCNNNormalizationMeanAndVarianceState: -initWithMean:variance: was given no mean or no"
                        @" variance, so no state was made");
        return nil;
    }
    // MPSState.h marks -init NS_UNAVAILABLE - a state is a collection of resources and one with none is
    // nothing - so this chains to MPSState11.m's own -initWithResources:, which takes exactly these two
    // and puts both in the state's resource list, rather than to -init.
    NSArray *resources = [NSArray arrayWithObjects:mean, variance, nil];
    MPSCNNNormalizationMeanAndVarianceState *made = [super initWithResources:resources];
    if (made) {
        // Strong ivars: storing one retains it and the state holds them for its own lifetime, so the two
        // are not released while the state is still answering -mean and -variance.
        made->_mean = mean;
        made->_variance = variance;
    }
    return made;
}

- (id<MTLBuffer>)mean { return _mean; }
- (id<MTLBuffer>)variance { return _variance; }

// The class method: a state holding two buffers of numberOfFeatureChannels floats each. The two
// buffers go in MPSState's own resource list, which is what a state's resources are for
// (MPSState.h:60-64: "A MPSState is a collection of resources"), so the state answers -resource and
// -bufferSizeAtIndex: for them the way MPSState answers for any other state. One float per feature
// channel is the header's own shape - the mean and the variance are per channel, one value each.
+ (instancetype)temporaryStateWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                        numberOfFeatureChannels:(NSUInteger)numberOfFeatureChannels
{
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : nil;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!device || !numberOfFeatureChannels) {
        CharonMPSRefuse(@"MPSCNNNormalizationMeanAndVarianceState: no device or no feature channels, so no"
                        @" state was made");
        return nil;
    }
    // Shared storage, because this port's MTLBuffer is host memory the CPU reads and writes directly
    // (facts/Metal/RenderPath.md) and a mean and a variance are numbers the gradient writes and the
    // normalization reads back.
    id<MTLBuffer> mean = [device newBufferWithLength:numberOfFeatureChannels * sizeof(float)
                                             options:MTLResourceStorageModeShared];
    id<MTLBuffer> variance = [device newBufferWithLength:numberOfFeatureChannels * sizeof(float)
                                                options:MTLResourceStorageModeShared];
    if (!mean || !variance) {
        CharonMPSRefuse(@"MPSCNNNormalizationMeanAndVarianceState: the device made no %lu byte buffer, so no"
                        @" state was made",
                        (unsigned long)(numberOfFeatureChannels * sizeof(float)));
        return nil;
    }
    // A strong local: alive through the two appends below and released when this scope ends, which is
    // the whole of the ownership - the state itself is what the caller receives.
    MPSCNNNormalizationMeanAndVarianceState *state = [[self alloc] initWithMean:mean variance:variance];
    [state charon_mps_appendResource:mean];
    [state charon_mps_appendResource:variance];
    return state;
}

@end

// MPSRNNLayer.h declares no member on this class, so there is nothing of its own to write and the class
// is what the object holds: MPSState's initializers, its resource list and its encode, so that the state
// an MPSRNNMatrixTrainingLayer answers can be named by a caller.
@implementation MPSRNNMatrixTrainingState
@end
