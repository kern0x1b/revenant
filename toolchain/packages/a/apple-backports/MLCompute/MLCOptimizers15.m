#import "RevenantMLCompute.h"

@interface MLCOptimizer (RevenantMLCOptimizer15)
@property (readonly, nonatomic) MLCGradientClippingType gradientClippingType;
@property (readonly, nonatomic) float maximumClippingNorm;
@property (readonly, nonatomic) float customGlobalNorm;
@end

@implementation MLCOptimizer (RevenantMLCOptimizer15)

- (MLCGradientClippingType)gradientClippingType
{
    return [self revenant_mlc_state].gradientClippingType;
}

- (float)maximumClippingNorm
{
    return [self revenant_mlc_state].maximumClippingNorm;
}

- (float)customGlobalNorm
{
    return [self revenant_mlc_state].customGlobalNorm;
}

@end

@implementation MLCAdamWOptimizer

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
{
    MLCAdamWOptimizer *optimizer = [self alloc];
    [optimizer revenant_mlc_takeStateFrom:optimizerDescriptor];
    return optimizer;
}

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
                                  beta1:(float)beta1
                                  beta2:(float)beta2
                                epsilon:(float)epsilon
                            usesAMSGrad:(BOOL)usesAMSGrad
                               timeStep:(NSUInteger)timeStep
{
    MLCAdamWOptimizer *optimizer = [self optimizerWithDescriptor:optimizerDescriptor];
    [optimizer revenant_mlc_state].beta1 = beta1;
    [optimizer revenant_mlc_state].beta2 = beta2;
    [optimizer revenant_mlc_state].epsilon = epsilon;
    [optimizer revenant_mlc_state].usesAMSGrad = usesAMSGrad;
    [optimizer revenant_mlc_state].timeStep = timeStep;
    return optimizer;
}

- (float)beta1
{
    return [self revenant_mlc_state].beta1;
}

- (float)beta2
{
    return [self revenant_mlc_state].beta2;
}

- (float)epsilon
{
    return [self revenant_mlc_state].epsilon;
}

- (BOOL)usesAMSGrad
{
    return [self revenant_mlc_state].usesAMSGrad;
}

- (NSUInteger)timeStep
{
    return [self revenant_mlc_state].timeStep;
}

@end
