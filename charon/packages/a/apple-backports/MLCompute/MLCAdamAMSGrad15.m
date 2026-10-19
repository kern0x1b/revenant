// The one factory of MLCAdamOptimizer whose availability the SDK of iOS 16.4 spells differently from
// every other annotation in MLCompute: `MLCOMPUTE_AVAILABLE_STARTING(macos(12.0), ios(15), tvos(15))`,
// with "ios(15)" and not "ios(15.0)" as MLCAdamWOptimizer and the three properties of MLCOptimizer beside
// it are spelled. It is an object of its own for that reason and not in MLCOptimizers15.m: an object
// carries the API of one release, and the band splitter reads these two spellings as two versions of it
// (modules/apple/backports.lua, misplaced()).
//
// Measured against this host's own MLCompute: the five arguments are the caller's, verbatim - 0.4, 0.5,
// 0.6, YES and 9 come back as 0.400000006, 0.5, 0.600000024, YES and 9 - and the descriptor's seven numbers
// come through with them.

#import "CharonMLCompute.h"

// A category and not a second @implementation of the class: MLCOptimizers14.m defines MLCAdamOptimizer, and
// a class implementation here emitted _OBJC_CLASS_$_MLCAdamOptimizer a second time (nm over both objects),
// with getters and ivars of its own beside the 14.0 ones. clang's note that a category implements a method
// its primary class also implements is the release split itself - the primary class, MLCOptimizers14.m,
// leaves this one factory out because it is 15.0's - and is silenced for that reason alone, as
// PHPickerConfiguration15.m and MPSImageThreshold13.m silence it.
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