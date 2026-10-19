#import "CharonMPS.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

typedef struct {
    double learningRate;
    double gradientRescale;
    BOOL applyGradientClipping;
    double gradientClipMin;
    double gradientClipMax;
    MPSNNRegularizationType regularizationType;
    double regularizationScale;
} CharonMPSOptimizerSettings;

static inline double CharonMPSOptimizerGradient(double gradient, double value,
                                                CharonMPSOptimizerSettings settings)
{
    double g = gradient;
    if (settings.applyGradientClipping) {
        if (g < settings.gradientClipMin) g = settings.gradientClipMin;
        if (g > settings.gradientClipMax) g = settings.gradientClipMax;
    }
    g *= settings.gradientRescale;
    if (settings.regularizationType == MPSNNRegularizationTypeL1)
        g += settings.regularizationScale;
    else if (settings.regularizationType == MPSNNRegularizationTypeL2)
        g += settings.regularizationScale * value;
    return g;
}

static BOOL CharonMPSOptimizerVectors(MPSVector *const *vectors, NSUInteger count,
                                      CharonMPSVectorView *views, NSString *what)
{
    for (NSUInteger index = 0; index < count; index++) {
        if (!vectors[index]) {
            CharonMPSRefuse(@"%@: vector %lu of %lu is missing, so nothing was updated", what,
                            (unsigned long)index, (unsigned long)count);
            return NO;
        }
        views[index] = CharonMPSVectorViewOf(vectors[index]);
        if (!views[index].elementSize) {
            CharonMPSRefuse(@"%@: vector %lu's data type names no element size, so nothing was updated",
                            what, (unsigned long)index);
            return NO;
        }
    }
    for (NSUInteger index = 1; index < count; index++) {
        if (views[index].length != views[0].length || views[index].vectors != views[0].vectors) {
            CharonMPSRefuse(@"%@: the vectors hold %lux%lu and %lux%lu (vector x component) and an update "
                            @"is element-wise, so nothing was updated", what,
                            (unsigned long)views[0].vectors, (unsigned long)views[0].length,
                            (unsigned long)views[count - 1].vectors, (unsigned long)views[count - 1].length);
            return NO;
        }
    }
    return YES;
}


@implementation MPSNNOptimizerDescriptor {
    float _learningRate;
    float _gradientRescale;
    BOOL _applyGradientClipping;
    float _gradientClipMax;
    float _gradientClipMin;
    MPSNNRegularizationType _regularizationType;
    float _regularizationScale;
}

@synthesize learningRate = _learningRate;
@synthesize gradientRescale = _gradientRescale;
@synthesize applyGradientClipping = _applyGradientClipping;
@synthesize gradientClipMax = _gradientClipMax;
@synthesize gradientClipMin = _gradientClipMin;
@synthesize regularizationType = _regularizationType;
@synthesize regularizationScale = _regularizationScale;

- (instancetype)init
{
    if ((self = [super init])) {
        _learningRate = 1e-3f;
        _gradientRescale = 1.0f;
        _applyGradientClipping = NO;
        _regularizationType = MPSNNRegularizationTypeNone;
        _regularizationScale = 0.0f;
    }
    return self;
}

- (instancetype)initWithLearningRate:(float)learningRate
                     gradientRescale:(float)gradientRescale
                  regularizationType:(MPSNNRegularizationType)regularizationType
                 regularizationScale:(float)regularizationScale
{
    if ((self = [super init])) {
        _learningRate = learningRate;
        _gradientRescale = gradientRescale;
        _applyGradientClipping = NO;
        _regularizationType = regularizationType;
        _regularizationScale = regularizationScale;
    }
    return self;
}

- (instancetype)initWithLearningRate:(float)learningRate
                     gradientRescale:(float)gradientRescale
               applyGradientClipping:(BOOL)applyGradientClipping
                     gradientClipMax:(float)gradientClipMax
                     gradientClipMin:(float)gradientClipMin
                  regularizationType:(MPSNNRegularizationType)regularizationType
                 regularizationScale:(float)regularizationScale
{
    if ((self = [super init])) {
        _learningRate = learningRate;
        _gradientRescale = gradientRescale;
        _applyGradientClipping = applyGradientClipping;
        _gradientClipMax = gradientClipMax;
        _gradientClipMin = gradientClipMin;
        _regularizationType = regularizationType;
        _regularizationScale = regularizationScale;
    }
    return self;
}

+ (instancetype)optimizerDescriptorWithLearningRate:(float)learningRate
                                    gradientRescale:(float)gradientRescale
                                 regularizationType:(MPSNNRegularizationType)regularizationType
                                regularizationScale:(float)regularizationScale
{
    return [[self alloc] initWithLearningRate:learningRate
                              gradientRescale:gradientRescale
                           regularizationType:regularizationType
                          regularizationScale:regularizationScale];
}

+ (instancetype)optimizerDescriptorWithLearningRate:(float)learningRate
                                    gradientRescale:(float)gradientRescale
                              applyGradientClipping:(BOOL)applyGradientClipping
                                    gradientClipMax:(float)gradientClipMax
                                    gradientClipMin:(float)gradientClipMin
                                 regularizationType:(MPSNNRegularizationType)regularizationType
                                regularizationScale:(float)regularizationScale
{
    return [[self alloc] initWithLearningRate:learningRate
                              gradientRescale:gradientRescale
                        applyGradientClipping:applyGradientClipping
                              gradientClipMax:gradientClipMax
                              gradientClipMin:gradientClipMin
                           regularizationType:regularizationType
                          regularizationScale:regularizationScale];
}

@end



@implementation MPSNNOptimizer {
    float _learningRate;
    float _gradientRescale;
    BOOL _applyGradientClipping;
    float _gradientClipMax;
    float _gradientClipMin;
    float _regularizationScale;
    MPSNNRegularizationType _regularizationType;
}

@synthesize learningRate = _learningRate;
@synthesize gradientRescale = _gradientRescale;
@synthesize applyGradientClipping = _applyGradientClipping;
@synthesize gradientClipMax = _gradientClipMax;
@synthesize gradientClipMin = _gradientClipMin;
@synthesize regularizationScale = _regularizationScale;
@synthesize regularizationType = _regularizationType;

- (instancetype)charon_initWithDevice:(id<MTLDevice>)device
{
    MPSNNOptimizer *made = [super initWithDevice:device];
    if (made) {
        made->_learningRate = 1e-3f;
        made->_gradientRescale = 1.0f;
        made->_applyGradientClipping = NO;
        made->_regularizationType = MPSNNRegularizationTypeNone;
        made->_regularizationScale = 0.0f;
    }
    return made;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSNNOptimizer: -initWithDevice: is unavailable on the abstract base - use"
                    @" MPSNNOptimizerStochasticGradientDescent, MPSNNOptimizerRMSProp or"
                    @" MPSNNOptimizerAdam");
    return nil;
}

- (void)setLearningRate:(float)newLearningRate { _learningRate = newLearningRate; }

- (CharonMPSOptimizerSettings)charon_mps_settings
{
    CharonMPSOptimizerSettings settings;
    settings.learningRate = _learningRate;
    settings.gradientRescale = _gradientRescale;
    settings.applyGradientClipping = _applyGradientClipping;
    settings.gradientClipMin = _gradientClipMin;
    settings.gradientClipMax = _gradientClipMax;
    settings.regularizationType = _regularizationType;
    settings.regularizationScale = _regularizationScale;
    return settings;
}

- (void)charon_mps_applyDescriptor:(MPSNNOptimizerDescriptor *)optimizerDescriptor
{
    if (!optimizerDescriptor)
        return;
    [self setLearningRate:optimizerDescriptor.learningRate];
    _gradientRescale = optimizerDescriptor.gradientRescale;
    _applyGradientClipping = optimizerDescriptor.applyGradientClipping;
    _gradientClipMax = optimizerDescriptor.gradientClipMax;
    _gradientClipMin = optimizerDescriptor.gradientClipMin;
    _regularizationType = optimizerDescriptor.regularizationType;
    _regularizationScale = optimizerDescriptor.regularizationScale;
}

@end


@interface MPSNNOptimizer (CharonMPSNNOptimizers)
- (CharonMPSOptimizerSettings)charon_mps_settings;
- (void)charon_mps_applyDescriptor:(MPSNNOptimizerDescriptor *)optimizerDescriptor;
@end


@implementation MPSNNOptimizerStochasticGradientDescent {
    float _momentumScale;
    BOOL _useNestrovMomentum;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device learningRate:(float)learningRate
{
    MPSNNOptimizerStochasticGradientDescent *made = [super charon_initWithDevice:device];
    if (made) {
        [made setLearningRate:learningRate];
        made->_momentumScale = 0.0f;
        made->_useNestrovMomentum = NO;
    }
    return made;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  momentumScale:(float)momentumScale
             useNestrovMomentum:(BOOL)useNestrovMomentum
           optimizerDescriptor:(MPSNNOptimizerDescriptor *)optimizerDescriptor
{
    MPSNNOptimizerStochasticGradientDescent *made = [super charon_initWithDevice:device];
    if (made) {
        [made charon_mps_applyDescriptor:optimizerDescriptor];
        made->_momentumScale = momentumScale;
        made->_useNestrovMomentum = useNestrovMomentum;
    }
    return made;
}

- (float)momentumScale { return _momentumScale; }
- (BOOL)useNestrovMomentum { return _useNestrovMomentum; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
          inputGradientVector:(MPSVector *)inputGradientVector
            inputValuesVector:(MPSVector *)inputValuesVector
          inputMomentumVector:(MPSVector *)inputMomentumVector
           resultValuesVector:(MPSVector *)resultValuesVector
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was updated", what);
        return;
    }
    CharonMPSOptimizerSettings settings = [self charon_mps_settings];

    if (!inputMomentumVector) {
        MPSVector *vectors[3] = {inputGradientVector, inputValuesVector, resultValuesVector};
        CharonMPSVectorView views[3];
        if (!CharonMPSOptimizerVectors(vectors, 3, views, what))
            return;
        for (NSUInteger index = 0; index < views[0].vectors; index++)
            for (NSUInteger component = 0; component < views[0].length; component++) {
                double gradient = CharonMPSLoad(CharonMPSVectorElement(&views[0], index, component), views[0].dataType, 0);
                double value = CharonMPSLoad(CharonMPSVectorElement(&views[1], index, component), views[1].dataType, 0);
                double g = CharonMPSOptimizerGradient(gradient, value, settings);
                CharonMPSStore(CharonMPSVectorElement(&views[2], index, component), views[2].dataType, 0,
                               value - settings.learningRate * g);
            }
        return;
    }

    MPSVector *vectors[4] = {inputGradientVector, inputValuesVector, inputMomentumVector, resultValuesVector};
    CharonMPSVectorView views[4];
    if (!CharonMPSOptimizerVectors(vectors, 4, views, what))
        return;
    double momentumScale = _momentumScale;
    BOOL nesterov = _useNestrovMomentum;
    for (NSUInteger index = 0; index < views[0].vectors; index++)
        for (NSUInteger component = 0; component < views[0].length; component++) {
            double gradient = CharonMPSLoad(CharonMPSVectorElement(&views[0], index, component), views[0].dataType, 0);
            double value = CharonMPSLoad(CharonMPSVectorElement(&views[1], index, component), views[1].dataType, 0);
            double previous = CharonMPSLoad(CharonMPSVectorElement(&views[2], index, component), views[2].dataType, 0);
            double g = CharonMPSOptimizerGradient(gradient, value, settings);
            double momentum = nesterov
                ? momentumScale * previous + g
                : momentumScale * previous + settings.learningRate * g;
            double step = nesterov
                ? settings.learningRate * (g + momentum * momentumScale)
                : momentum;
            CharonMPSStore(CharonMPSVectorElement(&views[2], index, component), views[2].dataType, 0, momentum);
            CharonMPSStore(CharonMPSVectorElement(&views[3], index, component), views[3].dataType, 0,
                           value - step);
        }
}

@end


@implementation MPSNNOptimizerRMSProp {
    double _decay;
    float _epsilon;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device learningRate:(float)learningRate
{
    MPSNNOptimizerRMSProp *made = [super charon_initWithDevice:device];
    if (made) {
        [made setLearningRate:learningRate];
        made->_decay = 0.9;
        made->_epsilon = 1e-8f;
    }
    return made;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                        decay:(double)decay
                      epsilon:(float)epsilon
           optimizerDescriptor:(MPSNNOptimizerDescriptor *)optimizerDescriptor
{
    MPSNNOptimizerRMSProp *made = [super charon_initWithDevice:device];
    if (made) {
        [made charon_mps_applyDescriptor:optimizerDescriptor];
        made->_decay = decay;
        made->_epsilon = epsilon;
    }
    return made;
}

- (double)decay { return _decay; }
- (float)epsilon { return _epsilon; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
          inputGradientVector:(MPSVector *)inputGradientVector
            inputValuesVector:(MPSVector *)inputValuesVector
      inputSumOfSquaresVector:(MPSVector *)inputSumOfSquaresVector
           resultValuesVector:(MPSVector *)resultValuesVector
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was updated", what);
        return;
    }
    MPSVector *vectors[4] = {inputGradientVector, inputValuesVector, inputSumOfSquaresVector, resultValuesVector};
    CharonMPSVectorView views[4];
    if (!CharonMPSOptimizerVectors(vectors, 4, views, what))
        return;
    CharonMPSOptimizerSettings settings = [self charon_mps_settings];
    for (NSUInteger index = 0; index < views[0].vectors; index++)
        for (NSUInteger component = 0; component < views[0].length; component++) {
            double gradient = CharonMPSLoad(CharonMPSVectorElement(&views[0], index, component), views[0].dataType, 0);
            double value = CharonMPSLoad(CharonMPSVectorElement(&views[1], index, component), views[1].dataType, 0);
            double previous = CharonMPSLoad(CharonMPSVectorElement(&views[2], index, component), views[2].dataType, 0);
            double g = CharonMPSOptimizerGradient(gradient, value, settings);
            double sum = _decay * previous + (1.0 - _decay) * (g * g);
            CharonMPSStore(CharonMPSVectorElement(&views[2], index, component), views[2].dataType, 0, sum);
            CharonMPSStore(CharonMPSVectorElement(&views[3], index, component), views[3].dataType, 0,
                           value - settings.learningRate * g / (sqrt(sum) + _epsilon));
        }
}

@end


@implementation MPSNNOptimizerAdam {
    double _beta1;
    double _beta2;
    float _epsilon;
    NSUInteger _timeStep;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device learningRate:(float)learningRate
{
    MPSNNOptimizerAdam *made = [super charon_initWithDevice:device];
    if (made) {
        [made setLearningRate:learningRate];
        made->_beta1 = 0.9;
        made->_beta2 = 0.999;
        made->_epsilon = 1e-8f;
        made->_timeStep = 0;
    }
    return made;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                        beta1:(double)beta1
                        beta2:(double)beta2
                      epsilon:(float)epsilon
                     timeStep:(NSUInteger)timeStep
           optimizerDescriptor:(MPSNNOptimizerDescriptor *)optimizerDescriptor
{
    MPSNNOptimizerAdam *made = [super charon_initWithDevice:device];
    if (made) {
        [made charon_mps_applyDescriptor:optimizerDescriptor];
        made->_beta1 = beta1;
        made->_beta2 = beta2;
        made->_epsilon = epsilon;
        made->_timeStep = timeStep;
    }
    return made;
}

- (double)beta1 { return _beta1; }
- (double)beta2 { return _beta2; }
- (float)epsilon { return _epsilon; }
- (NSUInteger)timeStep { return _timeStep; }
- (void)setTimeStep:(NSUInteger)timeStep { _timeStep = timeStep; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
          inputGradientVector:(MPSVector *)inputGradientVector
            inputValuesVector:(MPSVector *)inputValuesVector
          inputMomentumVector:(MPSVector *)inputMomentumVector
          inputVelocityVector:(MPSVector *)inputVelocityVector
           resultValuesVector:(MPSVector *)resultValuesVector
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was updated", what);
        return;
    }
    MPSVector *vectors[5] = {inputGradientVector, inputValuesVector, inputMomentumVector,
                             inputVelocityVector, resultValuesVector};
    CharonMPSVectorView views[5];
    if (!CharonMPSOptimizerVectors(vectors, 5, views, what))
        return;

    _timeStep += 1;
    double t = (double)_timeStep;
    double denominator = 1.0 - pow(_beta1, t);
    if (denominator == 0.0) {
        CharonMPSRefuse(@"%@: beta1 is 1 and the bias correction 1 - beta1^t is zero, so nothing was "
                        @"updated", what);
        _timeStep -= 1;
        return;
    }
    CharonMPSOptimizerSettings settings = [self charon_mps_settings];
    double learningRate = settings.learningRate * sqrt(1.0 - pow(_beta2, t)) / denominator;

    for (NSUInteger index = 0; index < views[0].vectors; index++)
        for (NSUInteger component = 0; component < views[0].length; component++) {
            double gradient = CharonMPSLoad(CharonMPSVectorElement(&views[0], index, component), views[0].dataType, 0);
            double value = CharonMPSLoad(CharonMPSVectorElement(&views[1], index, component), views[1].dataType, 0);
            double previousMomentum = CharonMPSLoad(CharonMPSVectorElement(&views[2], index, component), views[2].dataType, 0);
            double previousVelocity = CharonMPSLoad(CharonMPSVectorElement(&views[3], index, component), views[3].dataType, 0);
            double g = CharonMPSOptimizerGradient(gradient, value, settings);
            double momentum = _beta1 * previousMomentum + (1.0 - _beta1) * g;
            double velocity = _beta2 * previousVelocity + (1.0 - _beta2) * (g * g);
            CharonMPSStore(CharonMPSVectorElement(&views[2], index, component), views[2].dataType, 0, momentum);
            CharonMPSStore(CharonMPSVectorElement(&views[3], index, component), views[3].dataType, 0, velocity);
            CharonMPSStore(CharonMPSVectorElement(&views[4], index, component), views[4].dataType, 0,
                           value - learningRate * momentum / (sqrt(velocity) + _epsilon));
        }
}

@end
