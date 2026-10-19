// MLCOptimizer and the two optimizers of 14.0 that are its own subclasses, MLCSGDOptimizer and
// MLCAdamOptimizer, with the factories the SDK of iOS 16.4 declares for them.
//
// An optimizer is a set of numbers and nothing else: what an update does with them is the engine's
// business, and the numbers themselves are read out of the descriptor the caller hands over. Measured
// against this host's own MLCompute, .agent-work/runs/probe/mlc-optimizers.m over a descriptor whose
// every field is a value of its own (learning rate 0.125, rescale 0.25, clipping on, clip max 3.5,
// clip min -2.5, L2, scale 0.75) and over one that says nothing: every one of learningRate,
// gradientRescale, appliesGradientClipping, gradientClipMax, gradientClipMin, regularizationType and
// regularizationScale comes out of the optimizer exactly as it went into the descriptor, and
// gradientClippingType, maximumClippingNorm and customGlobalNorm are MLCGradientClippingTypeByValue, 1
// and 1 whatever the descriptor said - which is what the 14.0 descriptor factory here already answers.
//
// What each optimizer adds is its own: MLCSGDOptimizer adds a momentum scale (0.0) and a nesterov
// flag (NO), MLCAdamOptimizer adds beta1 (0.9), beta2 (0.999), epsilon (1e-8), the AMSGrad flag (NO)
// and a time step (1). All six and all five measured on the same host, over both descriptors, and the
// factories that carry numbers pass them through verbatim: a SGD made with a momentum scale of 0.625 and
// nesterov YES answers 0.625 and YES, an Adam made with 0.1, 0.2, 0.3 and step 7 answers those four.

#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CharonMLCOptimizerState
{
    // Declared in CharonMLCompute.h, and the ivars spelled here rather than synthesised, because the
    // gate compiles with -Werror=objc-missing-property-synthesis.

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

// A fresh state carries what a subclass brings and NOTHING else: the two a SGD adds - a momentum scale of
// 0.0 and nesterov NO - and the five an Adam and an AdamW add - beta1 0.9, beta2 0.999, epsilon 1e-8, no
// AMSGrad and step 1 - all six and all five measured on the host's own MLCompute. Every other number is a
// zero here, and that is measured too: a factory given a nil descriptor answers a learning rate of 0, a
// clip max of 0, a clip min of 0, a clip type of MLCGradientClippingTypeByValue (which is 0) and both norms
// of 0, where an optimizer made from a descriptor that says nothing answers a clip max of 1, a clip min of
// -1 and both norms of 1. Those three and the clip type therefore come from the DESCRIPTOR and not from
// here, and a base class's own +new and -init - which answer an MLCOptimizer - answer all zeros.
- (instancetype)init
{
    if ((self = [super init])) {
        _beta1 = 0.9f;
        _beta2 = 0.999f;
        _epsilon = 1e-8f;
        _timeStep = 1;
#if defined(CHARON_MLC_PLANT)
        // THE RED CONTROL. Compiled only into tests/backports/host/mlcompute's planted build, never into the
        // library: every default of the family is one step off, which is what a default nobody measured looks
        // like - the momentum, the nesterov flag, the clipping bounds, the clip type, both norms, all five of
        // an Adam's and none of the two flags. It is here rather than in the case file because the case file
        // only proves the comparison can read two numbers, while a plant here proves it notices when the port
        // holds the wrong ones, and it reaches every optimizer of the three kinds through the one place they
        // are all made.
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

// A copy of the state object is another state object holding the same seventeen numbers, which is what
// the copy of an optimizer needs and what nothing else in the library asks for. It is a method of the
// state object's own @implementation and not of the optimizer's: sent to the wrong one it is
// doesNotRecognizeSelector, because NSObject does not implement -copy by itself.
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

// The one ivar the optimizer and its subclasses share. A class extension rather than a category,
// because a category cannot carry storage and all three kinds of optimizer read this one.

@interface MLCOptimizer () {
    CharonMLCOptimizerState *_state;
}
@end

@implementation MLCOptimizer

- (CharonMLCOptimizerState *)charon_mlc_state
{
    // An optimizer made with -init rather than through a factory has no state yet, and one is made here
    // with the measured defaults of the family - so a bare MLCOptimizer, which is what +new and -init
    // answer on this host (measured), reads as an SGD with no momentum.
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
    // The header marks it unavailable, and what the release answers when a program asks for it anyway is
    // an MLCOptimizer with every number at its default (measured: +new and -init both answer
    // MLCOptimizer, with a learning rate of 0, no clipping and a clip type of MLCGradientClippingTypeByValue).
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
    // The copy of an optimizer is an optimizer of its own class holding the same seventeen numbers, which
    // is what NSCopying means for a set of numbers and what the host answers: measured, an AdamW made with
    // beta1 0.7, beta2 0.8, epsilon 0.9, AMSGrad and step 11, copied, is an MLCAdamWOptimizer answering
    // those five again and the descriptor's seven besides, and a SGD made with a momentum scale of 0.625 and
    // nesterov YES, copied, answers 0.625 and YES.
    //
    // The seventeen are written out one by one from the original's state into the new one's. That is not
    // brevity, it is the only shape that is certainly right: -copy on a state the port owns reaches
    // -copyWithZone: through the copy protocol's dispatch, and a call that reads as one call reaches another
    // method entirely if a category anywhere answers -copy - which is what the port's own header for the
    // optimizer's storage makes possible.
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
    // The factory without a momentum: the descriptor's numbers and the family's own defaults of 0.0 and
    // NO, which is what the host answers over both a full descriptor and an empty one (measured).
    // +alloc and not +new: the base class's -init is NS_UNAVAILABLE in the header, so an
    // optimizer is made by allocating it and giving it its numbers, which is what the
    // measured answer of a bare +new on the base class is too.
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
    // The factory without beta1, beta2, epsilon or a step: the descriptor's numbers and the measured
    // defaults of 0.9, 0.999, 1e-8, no AMSGrad and step 1.
    // +alloc and not +new: the base class's -init is NS_UNAVAILABLE in the header, so an
    // optimizer is made by allocating it and giving it its numbers, which is what the
    // measured answer of a bare +new on the base class is too.
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
    // The four are the caller's, verbatim: 0.1, 0.2, 0.3 and 7 come back as 0.1, 0.2, 0.3 and 7
    // (measured). The AMSGrad flag is not one of this factory's arguments and stays NO.
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