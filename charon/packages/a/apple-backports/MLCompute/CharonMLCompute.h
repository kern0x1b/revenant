// What the port's MLCompute is made of, and what only it needs.
//
// The declarations an application compiles against are Apple's own, read from the SDK this port builds
// with: <MLCompute/MLCompute.h> gives the fifty-five classes, their selectors, their properties and the
// values of their enumerations exactly as the newest SDK spells them, and nothing here repeats them. A
// backport that retyped them would be a second, drifting copy of an interface Apple can change.
//
// What this header adds is the storage the implementations keep and the few helpers more than one of
// them needs. Everything in it is named Charon*, which is what tells the gate that a symbol is the port's
// own and neither an API it carries nor a class the release has (modules/apple/backports.lua,
// internal_symbol), so the registry is never asked about it and no stub is written for it.

#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// The number of dimensions a tensor of this port has, and the number MLCompute reports for
// +[MLCTensorDescriptor maxTensorDimensions] (measured on the host, facts/MLCompute/Values.md).
#define CHARON_MLC_MAX_DIMENSIONS 4

// The width in bytes of one element of a data type, or 0 for a data type this port has no storage for.
// The table is the host's own, read by asking for a descriptor of each type and looking at the size it
// answers (measured: 4, 2, 1, 8, 4, 1, 1 bytes for float32, float16, boolean, int64, int32, int8, uint8;
// nil for MLCDataTypeInvalid, for 2 and for MLCDataTypeCount, and one byte for the two values between
// the enumerated ones that are neither). A data type with no size has no tensor: the factories answer nil
// where the host answers nil, and the engine refuses to compute with one.
NSUInteger CharonMLCWidthOfDataType(MLCDataType dataType);

// The number of elements a shape holds, 0 for a shape with a zero or a nil in it.
NSUInteger CharonMLCElementCount(NSArray<NSNumber *> *shape);

// The shape array of a tensor of this shape, in the order MLCompute reports: the batch dimension first
// and the width last, each one the fastest-varying of the one before it reversed (measured: a descriptor
// made with +descriptorWithWidth:height:featureChannelCount:batchSize: of 5, 6, 7 and 8 answers
// 8, 7, 6, 5). The stride is in bytes and is the width of a data type times the product of the
// dimensions to its right.
NSArray<NSNumber *> *CharonMLCStrideOfShape(NSArray<NSNumber *> *shape, MLCDataType dataType);

// The number every created tensor and layer counts on, in the order the host counts: the first MLCTensor
// and the first MLCLayer of a process are 0 and every later one is one higher (measured).
NSUInteger CharonMLCNextTensorID(void);
NSUInteger CharonMLCNextLayerID(void);

// What an MLCOptimizer and its subclasses hold: the descriptor's numbers and the ones of the subclass,
// in one object. It is named Charon*, so the gate weighs none of it against a release and asks the
// registry about none of it, and the three seams below are the registered names an application never
// calls. They are declared here rather than in the object that defines them because three objects of
// this library read them: the 14.0 object that holds the state, the 15.0 object that adds AdamW, and the
// object that carries the one factory the SDK annotates "ios(15)".
@interface CharonMLCOptimizerState : NSObject
@property (readwrite, nonatomic) float learningRate;
@property (readwrite, nonatomic) float gradientRescale;
@property (readwrite, nonatomic) BOOL appliesGradientClipping;
@property (readwrite, nonatomic) MLCGradientClippingType gradientClippingType;
@property (readwrite, nonatomic) float gradientClipMax;
@property (readwrite, nonatomic) float gradientClipMin;
@property (readwrite, nonatomic) MLCRegularizationType regularizationType;
@property (readwrite, nonatomic) float regularizationScale;
@property (readwrite, nonatomic) float maximumClippingNorm;
@property (readwrite, nonatomic) float customGlobalNorm;
@property (readwrite, nonatomic) float momentumScale;
@property (readwrite, nonatomic) BOOL usesNesterovMomentum;
@property (readwrite, nonatomic) float beta1;
@property (readwrite, nonatomic) float beta2;
@property (readwrite, nonatomic) float epsilon;
@property (readwrite, nonatomic) BOOL usesAMSGrad;
@property (readwrite, nonatomic) NSUInteger timeStep;
@end

@interface MLCOptimizer (CharonMLCOptimizerState)
// The numbers this optimizer holds. An optimizer that has not been given any yet is given the measured
// defaults of the family, which is what the base class's own +new and -init answer on this host.
- (CharonMLCOptimizerState *)charon_mlc_state;
// Give this optimizer the descriptor's numbers, over the measured defaults of the family. A nil
// descriptor is the defaults and nothing else.
- (void)charon_mlc_takeStateFrom:(MLCOptimizerDescriptor *)descriptor;
// An optimizer of the given class holding a copy of another's numbers, which is what -copyWithZone:
// answers.
+ (instancetype)charon_mlc_optimizerOfClass:(Class)cls copying:(MLCOptimizer *)other;
// Give this optimizer these numbers, over whatever it held. Read by the copy above, which cannot write
// another's ivars and has to go through the accessor the factory below uses.
- (void)charon_mlc_setState:(CharonMLCOptimizerState *)state;
@end
