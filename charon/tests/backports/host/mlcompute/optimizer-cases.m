// Every case of the optimizer surface of MLCompute this port carries, each one printed as a key and what
// the code answers. Written once and run twice: beside the host's own MLCompute, which is where the
// answers were measured from, and beside the port's, which has to answer the same. A line is a case.
//
// An optimizer is a copy of a descriptor's numbers and its own, so the cases are the numbers: every
// property of every optimizer, over two descriptors - one whose every field is a value of its own and one
// that says nothing - plus the class and the superclass of what each factory answers, the base class's own
// +new and -init, a copy of one, and the 15.0 factory and class. facts/MLCompute/Optimizers.md carries what
// the same run measured, and this file is the run.

#import <objc/runtime.h>

#import "mlcompute-16.h"

// The 15.0 spellings the SDK this port compiles against does not declare: the AMSGrad factory of 14.0's
// MLCAdamOptimizer, which the SDK annotates "ios(15)", and the three properties of 15.0 and the whole of
// MLCAdamWOptimizer. Declared here as declarations with no implementation, so that the same call is made on
// both sides and the host's own framework answers it - which is what makes the case a comparison and not a
// reading of the port.
@interface MLCAdamOptimizer (CharonFifteen)
+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
                                  beta1:(float)beta1
                                  beta2:(float)beta2
                                epsilon:(float)epsilon
                            usesAMSGrad:(BOOL)usesAMSGrad
                               timeStep:(NSUInteger)timeStep;
@end

@interface MLCOptimizer (CharonFifteen)
@property (readonly, nonatomic) MLCGradientClippingType gradientClippingType;
@property (readonly, nonatomic) float maximumClippingNorm;
@property (readonly, nonatomic) float customGlobalNorm;
@end

// A class's name as THIS side spells it. run.sh renames every MLC name it finds in the port's sources with
// a #define, and a #define does not reach inside a string literal - so a name written out finds the
// framework's class on the port's side too, and the case compares the host with itself. Stringifying the
// token goes through the macro first, so the port's side asks for the port's own class and the host's side
// for the host's, which is what makes the case a comparison.
#define CHARON_STRINGIFY_(token) #token
#define CHARON_STRINGIFY(token) CHARON_STRINGIFY_(token)

static NSString *nameHere(Class cls)
{
    return cls ? [NSString stringWithUTF8String:class_getName(cls)] : @"(nil)";
}

// One case, one line: a value that cannot be printed as text is printed as the number it holds, and a nil
// says so in words rather than in an empty value.
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

// A class's name, with the port's own prefix taken off: the port's classes are the framework's names
// under a prefix of their own (run.sh renames every MLC name it finds in the port's sources), so a case
// that prints the name as it is would answer "CharonMLCSGDOptimizer" on one side and "MLCSGDOptimizer" on
// the other and be a difference where there is none. The prefix is the tree's, and it is written out here
// rather than derived, because a case that derived it would agree with whatever it was handed.
static void named(NSString *name, const char *text)
{
    if (text == NULL) {
        key(name, @"(nil)");
        return;
    }
    NSString *value = [NSString stringWithUTF8String:text];
    if ([value hasPrefix:@"Charon"])
        value = [value substringFromIndex:6];
    key(name, value);
}

// Every number an optimizer holds, in one place, so a diff of two runs is readable.
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

void charon_mlcompute_optimizer_cases(void);

void charon_mlcompute_optimizer_cases(void)
{
    @autoreleasepool {
        // A descriptor whose every field is a value of its own, so a number carried from it into an
        // optimizer is visible as that number and not as a default, and one that says nothing.
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

        // The factory without a number of the optimizer's own, over both descriptors: what each answers is
        // the descriptor's numbers and the measured defaults, and nothing else.
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

        // The factories that carry the optimizer's own numbers, which pass them through verbatim.
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

        // A nil descriptor: the seven numbers a descriptor carries are all zero and the subclass's own are
        // still its defaults, which is what separates this case from the empty descriptor above.
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

        // The base class's own +new and -init, which its header marks unavailable, which the framework
        // carries, and which a program cannot name - so the base class is reached through the superclass of
        // an optimizer a factory made. That is the port's own base class on the port's side: a name reached
        // with NSClassFromString would find the framework's class on both sides and compare the host with
        // itself, which is what CharonNewOf does and is why this case does not use it.
        Class base = class_getSuperclass([(id)sgd class]);
        named(@"base class", class_getName(base));
        MLCOptimizer *bare = CharonNew(base);
        numbers(@"base new", bare);
        kinds(@"base new", bare);
        flag(@"base new twice distinct", CharonNew(base) != CharonNew(base));

        // The device data class, whose only member its header also marks unavailable, reached by the name
        // THIS side spells it - see nameHere above - so that the port's side asks the port's own class.
        Class deviceData = NSClassFromString(@(CHARON_STRINGIFY(MLCTensorOptimizerDeviceData)));
        named(@"device data class", class_getName(deviceData));
        named(@"device data new", class_getName([CharonNew(deviceData) class]));

        // A copy carries every number of the original, which is what NSCopying means for a set of numbers,
        // and is an object of its own rather than the original.
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