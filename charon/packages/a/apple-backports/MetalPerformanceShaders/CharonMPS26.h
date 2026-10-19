#ifndef MPS_CHARON_26_H
#define MPS_CHARON_26_H

#import "CharonMPS.h"

@interface MPSCNNConvolutionDescriptor (CharonMPS26)
- (float)charon_mps_neuronParameterC;
- (void)charon_mps_setNeuronParameterC:(float)value;
- (BOOL)charon_mps_hasBatchNormalization;
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
