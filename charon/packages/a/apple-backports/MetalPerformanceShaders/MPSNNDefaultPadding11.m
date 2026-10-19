#import "CharonMPSNN.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

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
    if ([kernel respondsToSelector:@selector(setEdgeMode:)])
        [(MPSCNNKernel *)kernel setEdgeMode:MPSImageEdgeModeClamp];
    return inDescriptor;
}

@end

@implementation MPSNNDefaultPadding (CharonMPSNNTensorflowAveragePooling)

+ (instancetype)paddingForTensorflowAveragePooling
{
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
