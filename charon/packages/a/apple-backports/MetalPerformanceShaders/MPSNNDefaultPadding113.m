// +[MPSNNDefaultPadding paddingForTensorflowAveragePoolingValidOnly], the TensorFlow valid-only average-pooling
// policy, in its own 11.3 file. The header declares it at MPSNeuralNetworkTypes.h:503 with ios(11.3), and the
// release's arm64 shared cache of 11.0 does not carry the selector, so the 11.3 band is the measured one as
// well as the header's. It is a different band from MPSNNGraph11.m and from MPSNNDefaultPadding11.m, and so a
// different file: one file that carried both 11.0 and 11.3 names is the mixed release backports.lua refuses.
//
// WHAT THE RELEASE ANSWERS, measured on the macOS host against Apple's own MPSNNDefaultPadding with the same
// inputs (tests/backports/host/mps-cnn-descriptors/cases.m):
//   class             a subclass of MPSNNDefaultPadding (the release's own name for it is not carried here)
//   paddingMethod     0x400d: Custom | SizeValidOnly | AlignTopLeft | AddRemainderToBottomRight
//   label             the string below, which the release writes out in full
//   sharing           the same object on every call
//   destination       the suggested descriptor itself, and the kernel's edgeMode set to MPSImageEdgeModeClamp (1);
//                     the kernel's offset is not changed.
//
// The sizing is not computed here, for the same reason as in MPSNNDefaultPadding11.m. NOT MEASURED: the edge
// mode of a kernel without an edgeMode property, and the object inside a running MPSNNGraph.

#import "CharonMPSNN.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The release's own object for this policy is a subclass of MPSNNDefaultPadding; this is the port's.
@interface CharonMPSNNTensorflowAveragePoolingValidOnlyPadding : MPSNNDefaultPadding
@end

@implementation CharonMPSNNTensorflowAveragePoolingValidOnlyPadding

- (NSString *)label
{
    return @"AlignTopLeft, AddRemainderToBottomRight, SizeValidOnly, MPSNNPaddingMethod.CustomAllowForNodeFusion (ignored without MPSNNPaddingMethodCustom)  variant: MPSNNTensorFlowPoolingPaddingValidOnly";
}

- (MPSImageDescriptor *)destinationImageDescriptorForSourceImages:(NSArray<MPSImage *> *)sourceImages
                                                     sourceStates:(NSArray<MPSState *> *)sourceStates
                                                        forKernel:(MPSKernel *)kernel
                                             suggestedDescriptor:(MPSImageDescriptor *)inDescriptor
{
    // The policy's one side effect on the kernel, as for the same-size policy: clamped edges. The message is
    // sent only to a kernel that has the property.
    if ([kernel respondsToSelector:@selector(setEdgeMode:)])
        [(MPSCNNKernel *)kernel setEdgeMode:MPSImageEdgeModeClamp];
    return inDescriptor;
}

@end

@implementation MPSNNDefaultPadding (CharonMPSNNTensorflowAveragePoolingValidOnly)

+ (instancetype)paddingForTensorflowAveragePoolingValidOnly
{
    // The release answers the same object on every call, measured; one object is kept for the same reason.
    static CharonMPSNNTensorflowAveragePoolingValidOnlyPadding *policy;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        policy = [CharonMPSNNTensorflowAveragePoolingValidOnlyPadding paddingWithMethod:(MPSNNPaddingMethodCustom |
                                                                                        MPSNNPaddingMethodSizeValidOnly |
                                                                                        MPSNNPaddingMethodAlignTopLeft |
                                                                                        MPSNNPaddingMethodAddRemainderToBottomRight)];
    });
    return policy;
}

@end
