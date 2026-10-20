#ifndef MPS_REVENANT_26_H
#define MPS_REVENANT_26_H

#import "RevenantMPS.h"

@interface MPSCNNConvolutionDescriptor (RevenantMPS26)
- (float)revenant_mps_neuronParameterC;
- (void)revenant_mps_setNeuronParameterC:(float)value;
- (BOOL)revenant_mps_hasBatchNormalization;
@end

#if !defined(__MAC_OS_X_VERSION_MAX_ALLOWED) || __MAC_OS_X_VERSION_MAX_ALLOWED < 260000
@interface MPSGraphObject : NSObject
@end

@interface MPSGraphFFTDescriptor : NSObject
@end

@interface MPSGraphImToColOpDescriptor : NSObject
@end

@interface MPSGraphExecutableSerializationDescriptor : NSObject
@end
#endif

#endif
