// The 15.0 optimizer surface: MLCAdamWOptimizer with its two factories and its five numbers, the three
// properties MLCOptimizer gained in 15.0, and the one factory of 14.0's MLCAdamOptimizer whose
// availability the SDK of iOS 16.4 spells "ios(15)" where every other annotation in the framework spells
// "ios(15.0)" - which is why that one method is an object of its own, MLCAdamAMSGrad15.m, and not here.
//
// Every default is measured on this host's own MLCompute and not read out of a header comment; the probe
// and its output are .agent-work/runs/probe/mlc-optimizers.m and the same file's transcript.
//
// **MLCAdamWOptimizer's five numbers are MLCAdamOptimizer's, exactly.** Measured over a descriptor with
// every field a value of its own: an Adam and an AdamW made from the same descriptor answer beta1
// 0.899999976, beta2 0.999000013, epsilon 9.99999994e-09, no AMSGrad and time step 1 - the same ten
// digits on both sides. The two optimizers differ in what an update does with them (the weight decay is
// decoupled from the gradient in AdamW and is not in Adam), and that is the engine's business, not a
// number this class holds.

#import "CharonMLCompute.h"

// The 15.0 properties of the base class. Declared here because MLCOptimizers14.m cannot name them: the
// SDK annotates them ios(15.0) and this object is the one that carries them.
@interface MLCOptimizer (CharonMLCOptimizer15)
// Readonly, as the SDK declares them. A category that redeclares an SDK-readonly property readwrite
// answers -Wobjc-property-implementation three times over, and readwrite would be a promise the header
// does not make: an application cannot set them.
@property (readonly, nonatomic) MLCGradientClippingType gradientClippingType;
@property (readonly, nonatomic) float maximumClippingNorm;
@property (readonly, nonatomic) float customGlobalNorm;
@end

@implementation MLCOptimizer (CharonMLCOptimizer15)

- (MLCGradientClippingType)gradientClippingType
{
    return [self charon_mlc_state].gradientClippingType;
}

- (float)maximumClippingNorm
{
    return [self charon_mlc_state].maximumClippingNorm;
}

- (float)customGlobalNorm
{
    return [self charon_mlc_state].customGlobalNorm;
}

@end

@implementation MLCAdamWOptimizer

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
{
    MLCAdamWOptimizer *optimizer = [self alloc];
    [optimizer charon_mlc_takeStateFrom:optimizerDescriptor];
    return optimizer;
}

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
                                  beta1:(float)beta1
                                  beta2:(float)beta2
                                epsilon:(float)epsilon
                            usesAMSGrad:(BOOL)usesAMSGrad
                               timeStep:(NSUInteger)timeStep
{
    // The five are the caller's, verbatim: 0.7, 0.8, 0.9, YES and 11 come back as 0.699999988,
    // 0.800000012, 0.899999976, YES and 11 (measured).
    MLCAdamWOptimizer *optimizer = [self optimizerWithDescriptor:optimizerDescriptor];
    [optimizer charon_mlc_state].beta1 = beta1;
    [optimizer charon_mlc_state].beta2 = beta2;
    [optimizer charon_mlc_state].epsilon = epsilon;
    [optimizer charon_mlc_state].usesAMSGrad = usesAMSGrad;
    [optimizer charon_mlc_state].timeStep = timeStep;
    return optimizer;
}

- (float)beta1
{
    return [self charon_mlc_state].beta1;
}

- (float)beta2
{
    return [self charon_mlc_state].beta2;
}

- (float)epsilon
{
    return [self charon_mlc_state].epsilon;
}

- (BOOL)usesAMSGrad
{
    return [self charon_mlc_state].usesAMSGrad;
}

- (NSUInteger)timeStep
{
    return [self charon_mlc_state].timeStep;
}

@end