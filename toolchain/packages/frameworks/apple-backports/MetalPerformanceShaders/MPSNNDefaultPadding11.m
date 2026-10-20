#import "RevenantMPSNN.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface RevenantMPSNNTensorflowAveragePoolingPadding : MPSNNDefaultPadding
@end

@implementation RevenantMPSNNTensorflowAveragePoolingPadding

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

@implementation MPSNNDefaultPadding (RevenantMPSNNTensorflowAveragePooling)

+ (instancetype)paddingForTensorflowAveragePooling
{
    static RevenantMPSNNTensorflowAveragePoolingPadding *policy;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        policy = [RevenantMPSNNTensorflowAveragePoolingPadding paddingWithMethod:(MPSNNPaddingMethodCustom |
                                                                              MPSNNPaddingMethodSizeSame |
                                                                              MPSNNPaddingMethodAlignCentered |
                                                                              MPSNNPaddingMethodAddRemainderToBottomRight)];
    });
    return policy;
}

@end
