#import "CharonMPSNN.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

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
    if ([kernel respondsToSelector:@selector(setEdgeMode:)])
        [(MPSCNNKernel *)kernel setEdgeMode:MPSImageEdgeModeClamp];
    return inDescriptor;
}

@end

@implementation MPSNNDefaultPadding (CharonMPSNNTensorflowAveragePoolingValidOnly)

+ (instancetype)paddingForTensorflowAveragePoolingValidOnly
{
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
