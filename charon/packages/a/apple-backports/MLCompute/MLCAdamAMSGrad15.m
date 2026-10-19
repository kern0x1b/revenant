#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation MLCAdamOptimizer (CharonMLCAdamAMSGrad15)

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
                                  beta1:(float)beta1
                                  beta2:(float)beta2
                                epsilon:(float)epsilon
                            usesAMSGrad:(BOOL)usesAMSGrad
                               timeStep:(NSUInteger)timeStep
{
    MLCAdamOptimizer *optimizer = [self optimizerWithDescriptor:optimizerDescriptor];
    [optimizer charon_mlc_state].beta1 = beta1;
    [optimizer charon_mlc_state].beta2 = beta2;
    [optimizer charon_mlc_state].epsilon = epsilon;
    [optimizer charon_mlc_state].usesAMSGrad = usesAMSGrad;
    [optimizer charon_mlc_state].timeStep = timeStep;
    return optimizer;
}

@end
