#ifndef MPS_REVENANT_26_H
#define MPS_REVENANT_26_H

#import "RevenantMPS.h"

@interface MPSCNNConvolutionDescriptor (RevenantMPS26)
- (float)revenant_mps_neuronParameterC;
- (void)revenant_mps_setNeuronParameterC:(float)value;
- (BOOL)revenant_mps_hasBatchNormalization;
@end


#endif
