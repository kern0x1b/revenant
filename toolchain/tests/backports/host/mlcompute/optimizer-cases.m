#import <objc/runtime.h>

#import "mlcompute-16.h"

@interface MLCAdamOptimizer (RevenantFifteen)
+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
                                  beta1:(float)beta1
                                  beta2:(float)beta2
                                epsilon:(float)epsilon
                            usesAMSGrad:(BOOL)usesAMSGrad
                               timeStep:(NSUInteger)timeStep;
@end

@interface MLCOptimizer (RevenantFifteen)
@property (readonly, nonatomic) MLCGradientClippingType gradientClippingType;
@property (readonly, nonatomic) float maximumClippingNorm;
@property (readonly, nonatomic) float customGlobalNorm;
@end

#define REVENANT_STRINGIFY_(token) #token
#define REVENANT_STRINGIFY(token) REVENANT_STRINGIFY_(token)

static NSString *nameHere(Class cls)
{
    return cls ? [NSString stringWithUTF8String:class_getName(cls)] : @"(nil)";
}

static void key(NSString *name, NSString *value)
{
    printf("%s\t%s\n", name.UTF8String, value.UTF8String);
}

static void number(NSString *name, double value)
{
    key(name, [NSString stringWithFormat:@"%g", value]);
}

static void flag(NSString *name, BOOL value)
{
    key(name, value ? @"YES" : @"NO");
}

static void named(NSString *name, const char *text)
{
    if (text == NULL) {
        key(name, @"(nil)");
        return;
    }
    NSString *value = [NSString stringWithUTF8String:text];
    if ([value hasPrefix:@"Revenant"])
        value = [value substringFromIndex:8];
    key(name, value);
}

static void numbers(NSString *name, MLCOptimizer *optimizer)
{
    number([name stringByAppendingString:@" learningRate"], (double)optimizer.learningRate);
    number([name stringByAppendingString:@" gradientRescale"], (double)optimizer.gradientRescale);
    flag([name stringByAppendingString:@" appliesGradientClipping"], optimizer.appliesGradientClipping);
    number([name stringByAppendingString:@" gradientClipMax"], (double)optimizer.gradientClipMax);
    number([name stringByAppendingString:@" gradientClipMin"], (double)optimizer.gradientClipMin);
    number([name stringByAppendingString:@" regularizationType"], (double)optimizer.regularizationType);
    number([name stringByAppendingString:@" regularizationScale"], (double)optimizer.regularizationScale);
    number([name stringByAppendingString:@" gradientClippingType"], (double)optimizer.gradientClippingType);
    number([name stringByAppendingString:@" maximumClippingNorm"], (double)optimizer.maximumClippingNorm);
    number([name stringByAppendingString:@" customGlobalNorm"], (double)optimizer.customGlobalNorm);
}

static void kinds(NSString *name, MLCOptimizer *optimizer)
{
    named([name stringByAppendingString:@" class"], class_getName([(id)optimizer class]));
    named([name stringByAppendingString:@" superclass"], class_getName(class_getSuperclass([(id)optimizer class])));
}

static void sgdNumbers(NSString *name, MLCSGDOptimizer *optimizer)
{
    number([name stringByAppendingString:@" momentumScale"], (double)optimizer.momentumScale);
    flag([name stringByAppendingString:@" usesNesterovMomentum"], optimizer.usesNesterovMomentum);
}

static void adamNumbers(NSString *name, float beta1, float beta2, float epsilon, BOOL amsgrad, NSUInteger timeStep)
{
    number([name stringByAppendingString:@" beta1"], (double)beta1);
    number([name stringByAppendingString:@" beta2"], (double)beta2);
    number([name stringByAppendingString:@" epsilon"], (double)epsilon);
    flag([name stringByAppendingString:@" usesAMSGrad"], amsgrad);
    number([name stringByAppendingString:@" timeStep"], (double)timeStep);
}

void revenant_mlcompute_optimizer_cases(void);

void revenant_mlcompute_optimizer_cases(void)
{
    @autoreleasepool {
        MLCOptimizerDescriptor *full = [MLCOptimizerDescriptor descriptorWithLearningRate:0.125f
                                                                            gradientRescale:0.25f
                                                                    appliesGradientClipping:YES
                                                                        gradientClipMax:3.5f
                                                                        gradientClipMin:-2.5f
                                                                     regularizationType:MLCRegularizationTypeL2
                                                                    regularizationScale:0.75f];
        MLCOptimizerDescriptor *empty = [MLCOptimizerDescriptor descriptorWithLearningRate:0.0f
                                                                            gradientRescale:0.0f
                                                                     regularizationType:MLCRegularizationTypeNone
                                                                    regularizationScale:0.0f];
        numbers(@"descriptor", full);
        numbers(@"descriptor empty", empty);

        MLCSGDOptimizer *sgd = [MLCSGDOptimizer optimizerWithDescriptor:full];
        numbers(@"sgd full", sgd);
        kinds(@"sgd full", sgd);
        sgdNumbers(@"sgd full", sgd);
        MLCSGDOptimizer *sgdEmpty = [MLCSGDOptimizer optimizerWithDescriptor:empty];
        numbers(@"sgd empty", sgdEmpty);
        sgdNumbers(@"sgd empty", sgdEmpty);

        MLCAdamOptimizer *adam = [MLCAdamOptimizer optimizerWithDescriptor:full];
        numbers(@"adam full", adam);
        kinds(@"adam full", adam);
        adamNumbers(@"adam full", adam.beta1, adam.beta2, adam.epsilon, adam.usesAMSGrad, adam.timeStep);
        MLCAdamOptimizer *adamEmpty = [MLCAdamOptimizer optimizerWithDescriptor:empty];
        numbers(@"adam empty", adamEmpty);
        adamNumbers(@"adam empty", adamEmpty.beta1, adamEmpty.beta2, adamEmpty.epsilon,
                    adamEmpty.usesAMSGrad, adamEmpty.timeStep);

        MLCAdamWOptimizer *adamW = [MLCAdamWOptimizer optimizerWithDescriptor:full];
        numbers(@"adamW full", adamW);
        kinds(@"adamW full", adamW);
        adamNumbers(@"adamW full", adamW.beta1, adamW.beta2, adamW.epsilon, adamW.usesAMSGrad, adamW.timeStep);

        MLCSGDOptimizer *sgdMomentum = [MLCSGDOptimizer optimizerWithDescriptor:full
                                                                    momentumScale:0.625f
                                                              usesNesterovMomentum:YES];
        sgdNumbers(@"sgd momentum", sgdMomentum);
        MLCAdamOptimizer *adamGiven = [MLCAdamOptimizer optimizerWithDescriptor:full
                                                                        beta1:0.1f
                                                                        beta2:0.2f
                                                                      epsilon:0.3f
                                                                     timeStep:7];
        adamNumbers(@"adam given", adamGiven.beta1, adamGiven.beta2, adamGiven.epsilon,
                    adamGiven.usesAMSGrad, adamGiven.timeStep);
        MLCAdamOptimizer *adamAMS = [MLCAdamOptimizer optimizerWithDescriptor:full
                                                                       beta1:0.4f
                                                                       beta2:0.5f
                                                                     epsilon:0.6f
                                                                 usesAMSGrad:YES
                                                                    timeStep:9];
        adamNumbers(@"adam amsgrad", adamAMS.beta1, adamAMS.beta2, adamAMS.epsilon,
                    adamAMS.usesAMSGrad, adamAMS.timeStep);
        MLCAdamWOptimizer *adamWGiven = [MLCAdamWOptimizer optimizerWithDescriptor:full
                                                                             beta1:0.7f
                                                                             beta2:0.8f
                                                                           epsilon:0.9f
                                                                       usesAMSGrad:YES
                                                                          timeStep:11];
        adamNumbers(@"adamW given", adamWGiven.beta1, adamWGiven.beta2, adamWGiven.epsilon,
                    adamWGiven.usesAMSGrad, adamWGiven.timeStep);

        MLCSGDOptimizer *sgdNil = [MLCSGDOptimizer optimizerWithDescriptor:nil];
        numbers(@"sgd nil", sgdNil);
        sgdNumbers(@"sgd nil", sgdNil);
        MLCAdamOptimizer *adamNil = [MLCAdamOptimizer optimizerWithDescriptor:nil];
        numbers(@"adam nil", adamNil);
        adamNumbers(@"adam nil", adamNil.beta1, adamNil.beta2, adamNil.epsilon,
                    adamNil.usesAMSGrad, adamNil.timeStep);
        MLCAdamWOptimizer *adamWNil = [MLCAdamWOptimizer optimizerWithDescriptor:nil];
        numbers(@"adamW nil", adamWNil);
        adamNumbers(@"adamW nil", adamWNil.beta1, adamWNil.beta2, adamWNil.epsilon,
                    adamWNil.usesAMSGrad, adamWNil.timeStep);

        Class base = class_getSuperclass([(id)sgd class]);
        named(@"base class", class_getName(base));
        MLCOptimizer *bare = RevenantNew(base);
        numbers(@"base new", bare);
        kinds(@"base new", bare);
        flag(@"base new twice distinct", RevenantNew(base) != RevenantNew(base));

        Class deviceData = NSClassFromString(@(REVENANT_STRINGIFY(MLCTensorOptimizerDeviceData)));
        named(@"device data class", class_getName(deviceData));
        named(@"device data new", class_getName([RevenantNew(deviceData) class]));

        MLCSGDOptimizer *sgdCopy = [sgdMomentum copy];
        numbers(@"sgd copy", sgdCopy);
        sgdNumbers(@"sgd copy", sgdCopy);
        named(@"sgd copy class", class_getName([(id)sgdCopy class]));
        MLCAdamWOptimizer *adamWCopy = [adamWGiven copy];
        adamNumbers(@"adamW copy", adamWCopy.beta1, adamWCopy.beta2, adamWCopy.epsilon,
                    adamWCopy.usesAMSGrad, adamWCopy.timeStep);
        named(@"adamW copy class", class_getName([(id)adamWCopy class]));
        flag(@"adamW copy distinct from its source", adamWCopy != adamWGiven);
    }
}
