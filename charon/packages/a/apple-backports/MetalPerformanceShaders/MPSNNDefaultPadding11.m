// +[MPSNNDefaultPadding paddingForTensorflowAveragePooling], the TensorFlow average-pooling policy, in its own
// 11.0 file. The header declares it at MPSNeuralNetworkTypes.h:500 with ios(11.3); the release's own
// arm64 shared cache of 11.0 carries the selector (tests/backports/host/mps-cnn-descriptors and the registry
// row say so), so the policy is placed in the 11.0 band by the measurement and not by the header's date. The
// 11.3 ValidOnly policy is in MPSNNDefaultPadding113.m, a different band, for the reason MPSNNGraph11.m gives.
//
// WHAT THE RELEASE ANSWERS, measured on the macOS host against Apple's own MPSNNDefaultPadding with the
// same inputs (tests/backports/host/mps-cnn-descriptors/cases.m):
//   class             a subclass of MPSNNDefaultPadding (the release's own name for it is not carried here)
//   paddingMethod     0x401c: Custom | SizeSame | AlignCentered | AddRemainderToBottomRight
//   label             the string below, which the release writes out in full
//   sharing           the same object on every call
//   destination       for any source and suggested descriptor it answers the suggested descriptor itself
//                     (the same object), and it sets the kernel's edgeMode to MPSImageEdgeModeClamp (1);
//                     the kernel's offset is not changed.
//
// The sizing is therefore not computed here: the policy's sizing is the suggested descriptor the graph
// already prepared, which is what the release's own object returns. NOT MEASURED: the edge mode of a kernel
// that has no edgeMode property (this class sends the message only when the kernel answers it), and any
// behaviour of the object inside a running MPSNNGraph; the graph is not run here.

#import "CharonMPSNN.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The release's own object for this policy is a subclass of MPSNNDefaultPadding; this is the port's.
@interface CharonMPSNNTensorflowAveragePoolingPadding : MPSNNDefaultPadding
@end

@implementation CharonMPSNNTensorflowAveragePoolingPadding

- (NSString *)label
{
    return @"AlignCentered, AddRemainderToBottomRight, SizeSame, MPSNNPaddingMethod.CustomAllowForNodeFusion (ignored without MPSNNPaddingMethodCustom)  variant: MPSNNTensorFlowPoolingPadding";
}

- (MPSImageDescriptor *)destinationImageDescriptorForSourceImages:(NSArray<MPSImage *> *)sourceImages
                                                     sourceStates:(NSArray<MPSState *> *)sourceStates
                                                        forKernel:(MPSKernel *)kernel
                                             suggestedDescriptor:(MPSImageDescriptor *)inDescriptor
{
    // The policy's one side effect on the kernel: clamped edges, which is what makes the average normalise
    // over the valid pixels only. The message is sent only to a kernel that has the property.
    if ([kernel respondsToSelector:@selector(setEdgeMode:)])
        [(MPSCNNKernel *)kernel setEdgeMode:MPSImageEdgeModeClamp];
    return inDescriptor;
}

@end

@implementation MPSNNDefaultPadding (CharonMPSNNTensorflowAveragePooling)

+ (instancetype)paddingForTensorflowAveragePooling
{
    // The release answers the same object on every call, measured; one object is kept for the same reason.
    static CharonMPSNNTensorflowAveragePoolingPadding *policy;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        policy = [CharonMPSNNTensorflowAveragePoolingPadding paddingWithMethod:(MPSNNPaddingMethodCustom |
                                                                              MPSNNPaddingMethodSizeSame |
                                                                              MPSNNPaddingMethodAlignCentered |
                                                                              MPSNNPaddingMethodAddRemainderToBottomRight)];
    });
    return policy;
}

@end
