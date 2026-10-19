// CharonMPS26.h - the names the 26.2 surface has and the SDK this package compiles against does not.
//
// The iPhoneOS 16.4 SDK is what this package compiles against, and MetalPerformanceShaders moved
// between it and 26.2. Where 26.2 declares a member that 16.4 does not, the member is transcribed here
// from the 26.2 headers, so that an application built against the 26.2 surface compiles at all. Each one
// is a name no header this build compiles against declares, and each is an R4 item.
//
// Transcribed is not the same as implemented, and the two are not confused here. Four of the members
// below are implemented and the rest are declarations only:
//
//   implemented   MPSGraphObject (MPSGraphObject15.m), and MPSCNNConvolutionDescriptor's
//                 charon_mps_neuronParameterC, charon_mps_setNeuronParameterC: and
//                 charon_mps_hasBatchNormalization (MPSCNNConvolutionDescriptor10.m)
//   declaration   MPSGraphFFTDescriptor, MPSGraphImToColOpDescriptor and
//                 MPSGraphExecutableSerializationDescriptor, which have no @implementation anywhere in
//                 this package and no registry row: an application that names one of them compiles and
//                 then has nothing to link against, which is a link error the reader will see at once
//                 and not a silent wrong answer. They are declared so the 26.2 surface is complete, not
//                 so it is answered.
//
// Transcribed from $SDK26/System/Library/Frameworks/MetalPerformanceShaders.framework/Frameworks,
// read on 2026-09-28. Nothing here is invented: it is what 26.2 says, copied.

#ifndef MPS_CHARON_26_H
#define MPS_CHARON_26_H

#import "CharonMPS.h"

// MPSCNNConvolutionDescriptor's third neuron parameter. 16.4 declares neuronType, neuronParameterA
// and neuronParameterB; 26.2 adds C, which the Power, Exponential and Logarithm formulas use.
@interface MPSCNNConvolutionDescriptor (CharonMPS26)
- (float)charon_mps_neuronParameterC;
- (void)charon_mps_setNeuronParameterC:(float)value;
- (BOOL)charon_mps_hasBatchNormalization;
@end

// MPSGraphObject arrived in iOS 17 and every class of the 26.2 surface descends from it; 16.4 has them
// descending from NSObject. This one is implemented. Three further 26.2 names are in no 16.4 header at
// all, and those three are declared only - see the list at the top of this file.
#if !defined(__MAC_OS_X_VERSION_MAX_ALLOWED) || __MAC_OS_X_VERSION_MAX_ALLOWED < 260000
@interface MPSGraphObject : NSObject
@end

// And the three descriptors the 26.2 headers declare that 16.4 does not, transcribed from
// MPSCNNConvolution.h and MPSGraphExecutable.h of 26.2. No implementation: a program that names one of
// them gets a link error naming this class, which is what a name this package does not answer should
// look like.
@interface MPSGraphFFTDescriptor : NSObject
@end

@interface MPSGraphImToColOpDescriptor : NSObject
@end

@interface MPSGraphExecutableSerializationDescriptor : NSObject
@end
#endif

#endif /* MPS_CHARON_26_H */
