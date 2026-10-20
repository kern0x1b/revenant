#import "RevenantMLCompute.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation MLCAdamOptimizer (RevenantMLCAdamAMSGrad15)

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
                                  beta1:(float)beta1
                                  beta2:(float)beta2
                                epsilon:(float)epsilon
                            usesAMSGrad:(BOOL)usesAMSGrad
                               timeStep:(NSUInteger)timeStep
{
    MLCAdamOptimizer *optimizer = [self optimizerWithDescriptor:optimizerDescriptor];
    [optimizer revenant_mlc_state].beta1 = beta1;
    [optimizer revenant_mlc_state].beta2 = beta2;
    [optimizer revenant_mlc_state].epsilon = epsilon;
    [optimizer revenant_mlc_state].usesAMSGrad = usesAMSGrad;
    [optimizer revenant_mlc_state].timeStep = timeStep;
    return optimizer;
}

@end
