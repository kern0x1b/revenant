#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CharonMLCOptimizerState
{
@protected
    float _learningRate;
    float _gradientRescale;
    BOOL _appliesGradientClipping;
    MLCGradientClippingType _gradientClippingType;
    float _gradientClipMax;
    float _gradientClipMin;
    MLCRegularizationType _regularizationType;
    float _regularizationScale;
    float _maximumClippingNorm;
    float _customGlobalNorm;
    float _momentumScale;
    BOOL _usesNesterovMomentum;
    float _beta1;
    float _beta2;
    float _epsilon;
    BOOL _usesAMSGrad;
    NSUInteger _timeStep;
}
@synthesize learningRate = _learningRate;
@synthesize gradientRescale = _gradientRescale;
@synthesize appliesGradientClipping = _appliesGradientClipping;
@synthesize gradientClippingType = _gradientClippingType;
@synthesize gradientClipMax = _gradientClipMax;
@synthesize gradientClipMin = _gradientClipMin;
@synthesize regularizationType = _regularizationType;
@synthesize regularizationScale = _regularizationScale;
@synthesize maximumClippingNorm = _maximumClippingNorm;
@synthesize customGlobalNorm = _customGlobalNorm;
@synthesize momentumScale = _momentumScale;
@synthesize usesNesterovMomentum = _usesNesterovMomentum;
@synthesize beta1 = _beta1;
@synthesize beta2 = _beta2;
@synthesize epsilon = _epsilon;
@synthesize usesAMSGrad = _usesAMSGrad;
@synthesize timeStep = _timeStep;

- (instancetype)init
{
    if ((self = [super init])) {
        _beta1 = 0.9f;
        _beta2 = 0.999f;
        _epsilon = 1e-8f;
        _timeStep = 1;
#if defined(CHARON_MLC_PLANT)
#if CHARON_MLC_PLANT == 1
        _gradientClipMax = 0.0f;
        _gradientClipMin = 0.0f;
        _gradientClippingType = MLCGradientClippingTypeByNorm;
        _maximumClippingNorm = 0.0f;
        _customGlobalNorm = 0.0f;
        _momentumScale = 1.0f;
        _usesNesterovMomentum = YES;
        _beta1 = 0.0f;
        _beta2 = 0.0f;
        _epsilon = 0.0f;
        _usesAMSGrad = YES;
        _timeStep = 2;
#endif
#endif
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CharonMLCOptimizerState *copy = [[CharonMLCOptimizerState allocWithZone:zone] init];
    copy->_learningRate = _learningRate;
    copy->_gradientRescale = _gradientRescale;
    copy->_appliesGradientClipping = _appliesGradientClipping;
    copy->_gradientClippingType = _gradientClippingType;
    copy->_gradientClipMax = _gradientClipMax;
    copy->_gradientClipMin = _gradientClipMin;
    copy->_regularizationType = _regularizationType;
    copy->_regularizationScale = _regularizationScale;
    copy->_maximumClippingNorm = _maximumClippingNorm;
    copy->_customGlobalNorm = _customGlobalNorm;
    copy->_momentumScale = _momentumScale;
    copy->_usesNesterovMomentum = _usesNesterovMomentum;
    copy->_beta1 = _beta1;
    copy->_beta2 = _beta2;
    copy->_epsilon = _epsilon;
    copy->_usesAMSGrad = _usesAMSGrad;
    copy->_timeStep = _timeStep;
    return copy;
}


@end

@interface MLCOptimizer () {
    CharonMLCOptimizerState *_state;
}
@end

@implementation MLCOptimizer

- (CharonMLCOptimizerState *)charon_mlc_state
{
    if (!_state)
        _state = [[CharonMLCOptimizerState alloc] init];
    return _state;
}

- (void)charon_mlc_setState:(CharonMLCOptimizerState *)state
{
    _state = state;
}

- (void)charon_mlc_takeStateFrom:(MLCOptimizerDescriptor *)descriptor
{
    _state = [[CharonMLCOptimizerState alloc] init];
    if (!descriptor)
        return;
    _state.learningRate = descriptor.learningRate;
    _state.gradientRescale = descriptor.gradientRescale;
    _state.appliesGradientClipping = descriptor.appliesGradientClipping;
    _state.gradientClippingType = descriptor.gradientClippingType;
    _state.gradientClipMax = descriptor.gradientClipMax;
    _state.gradientClipMin = descriptor.gradientClipMin;
    _state.regularizationType = descriptor.regularizationType;
    _state.regularizationScale = descriptor.regularizationScale;
    _state.maximumClippingNorm = descriptor.maximumClippingNorm;
    _state.customGlobalNorm = descriptor.customGlobalNorm;
}

- (instancetype)init
{
    if ((self = [super init]))
        [self charon_mlc_takeStateFrom:nil];
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (float)learningRate
{
    return [self charon_mlc_state].learningRate;
}

- (void)setLearningRate:(float)learningRate
{
    [self charon_mlc_state].learningRate = learningRate;
}

- (float)gradientRescale
{
    return [self charon_mlc_state].gradientRescale;
}

- (BOOL)appliesGradientClipping
{
    return [self charon_mlc_state].appliesGradientClipping;
}

- (void)setAppliesGradientClipping:(BOOL)appliesGradientClipping
{
    [self charon_mlc_state].appliesGradientClipping = appliesGradientClipping;
}

- (float)gradientClipMax
{
    return [self charon_mlc_state].gradientClipMax;
}

- (float)gradientClipMin
{
    return [self charon_mlc_state].gradientClipMin;
}

- (float)regularizationScale
{
    return [self charon_mlc_state].regularizationScale;
}

- (MLCRegularizationType)regularizationType
{
    return [self charon_mlc_state].regularizationType;
}

+ (instancetype)charon_mlc_optimizerOfClass:(Class)cls copying:(MLCOptimizer *)other
{
    MLCOptimizer *copy = [cls allocWithZone:NSDefaultMallocZone()];
    CharonMLCOptimizerState *from = [other charon_mlc_state];
    CharonMLCOptimizerState *into = [CharonMLCOptimizerState new];
    into.learningRate = from.learningRate;
    into.gradientRescale = from.gradientRescale;
    into.appliesGradientClipping = from.appliesGradientClipping;
    into.gradientClippingType = from.gradientClippingType;
    into.gradientClipMax = from.gradientClipMax;
    into.gradientClipMin = from.gradientClipMin;
    into.regularizationType = from.regularizationType;
    into.regularizationScale = from.regularizationScale;
    into.maximumClippingNorm = from.maximumClippingNorm;
    into.customGlobalNorm = from.customGlobalNorm;
    into.momentumScale = from.momentumScale;
    into.usesNesterovMomentum = from.usesNesterovMomentum;
    into.beta1 = from.beta1;
    into.beta2 = from.beta2;
    into.epsilon = from.epsilon;
    into.usesAMSGrad = from.usesAMSGrad;
    into.timeStep = from.timeStep;
    [copy charon_mlc_setState:into];
    return copy;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] charon_mlc_optimizerOfClass:[self class] copying:self];
}

@end

@implementation MLCSGDOptimizer

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
{
    MLCSGDOptimizer *optimizer = [self alloc];
    [optimizer charon_mlc_takeStateFrom:optimizerDescriptor];
    return optimizer;
}

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
                           momentumScale:(float)momentumScale
                     usesNesterovMomentum:(BOOL)usesNesterovMomentum
{
    MLCSGDOptimizer *optimizer = [self optimizerWithDescriptor:optimizerDescriptor];
    [optimizer charon_mlc_state].momentumScale = momentumScale;
    [optimizer charon_mlc_state].usesNesterovMomentum = usesNesterovMomentum;
    return optimizer;
}

- (float)momentumScale
{
    return [self charon_mlc_state].momentumScale;
}

- (BOOL)usesNesterovMomentum
{
    return [self charon_mlc_state].usesNesterovMomentum;
}

@end

@implementation MLCAdamOptimizer

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
{
    MLCAdamOptimizer *optimizer = [self alloc];
    [optimizer charon_mlc_takeStateFrom:optimizerDescriptor];
    return optimizer;
}

+ (instancetype)optimizerWithDescriptor:(MLCOptimizerDescriptor *)optimizerDescriptor
                                  beta1:(float)beta1
                                  beta2:(float)beta2
                                epsilon:(float)epsilon
                               timeStep:(NSUInteger)timeStep
{
    MLCAdamOptimizer *optimizer = [self optimizerWithDescriptor:optimizerDescriptor];
    [optimizer charon_mlc_state].beta1 = beta1;
    [optimizer charon_mlc_state].beta2 = beta2;
    [optimizer charon_mlc_state].epsilon = epsilon;
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
