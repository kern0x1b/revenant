// The optimizer family of MPSNNOptimizers.h - MPSNNOptimizerDescriptor, MPSNNOptimizer,
// MPSNNOptimizerStochasticGradientDescent, MPSNNOptimizerRMSProp and MPSNNOptimizerAdam.
//
// One object for one release. `xmake l tools/cache-index/first-rung.lua MPSNNOptimizer
// MPSNNOptimizerDescriptor MPSNNOptimizerAdam MPSNNOptimizerRMSProp
// MPSNNOptimizerStochasticGradientDescent` answers 12.0 for all five, and every class in
// MPSNNOptimizers.h carries MPS_CLASS_AVAILABLE_STARTING(..., ios(12.0), ...) - or ios(12) for the
// one descriptor - so this file carries 12.0 API only. The 13.0 matrix encodes and the 14.0
// `useNesterovMomentum` spelling are members of the same selectors at a later release and are NOT
// here: tools/release-split.lua reads band points only, so a 13.0 symbol in this file would pass it
// and be wrong by a release.
//
// THE ARITHMETIC, IN THIS FILE'S NOTATION. MPSNNOptimizers.h states each update in full, at the lines
// cited below. w is the value, g the gradient, lr the learning rate, eps the epsilon, k the step count:
//
//   stochastic gradient descent (:250-268)
//       no Nesterov:         vel = mu * vel + lr * g;   w = w - vel
//       Nesterov:            vel = mu * vel + g;        w = w - lr * (g + mu * vel)
//       no momentum vector:  w = w - lr * g
//
//   RMSProp (:430-432)
//       acc = rho * acc + (1 - rho) * g^2
//       w   = w - lr * g / (sqrt(acc) + eps)
//
//   Adam (:436-438)
//       k    = k + 1
//       lr_k = lr * sqrt(1 - b2^k) / (1 - b1^k)
//       m    = b1 * m + (1 - b1) * g
//       v    = b2 * v + (1 - b2) * g^2
//       w    = w - lr_k * m / (sqrt(v) + eps)
//
// The bias correction is why the header carries timeStep at all (:525). The header increments it BEFORE it
// computes lr_k (:436), so the first update counts as step 1, which keeps (1 - b1^k) non-zero while m and v
// are still zero.
//
// THE GRADIENT IS PREPROCESSED BEFORE ANY OF IT, and that is the descriptor's whole job (:61-66). The order
// is: clip, then scale, then add the regularization gradient. For L1 the added term is regularizationScale
// times 1; for L2 it is regularizationScale times the weight (set out at :33-41). The weight is the original
// value, which is why the preprocessing takes it and not only the gradient.
//
// DEFAULTS, each from the property's own doc: learningRate 1e-3 (:66), gradientRescale 1.0 (:72),
// applyGradientClipping NO (:78), regularizationScale 0.0 (:94), regularizationType
// MPSNNRegularizationTypeNone (:100), SGD momentumScale 0.0 (:253), RMSProp decay 0.9 (:459) and
// epsilon 1e-8 (:466), Adam beta1 0.9 (:505), beta2 0.999 (:512), epsilon 1e-8 (:519). An
// Objective-C float ivar is zero, so each is set where the object is made.
//
// WHAT IS NOT HERE. The three optimizers also declare an encode that takes MPSCNNConvolutionGradientState
// and MPSCNNConvolutionWeightsAndBiasesState instead of vectors. Those are MPSCNNConvolution's own
// types and their contents are that class's business, not this file's, so the vectors' encodes are
// the ones implemented; the registry rows name that.

#import "CharonMPS.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// The seven values the descriptor carries, read once so that the three update walks below and the
// three initialisers take one struct instead of seven properties each. A C struct has no symbol of
// its own, which is what a band needs here: a file whose exports a later band's release already has
// is dropped from that band, so nothing in this file may have external linkage except its classes.
typedef struct {
    double learningRate;
    double gradientRescale;
    BOOL applyGradientClipping;
    double gradientClipMin;
    double gradientClipMax;
    MPSNNRegularizationType regularizationType;
    double regularizationScale;
} CharonMPSOptimizerSettings;

// The gradient, preprocessed, from the header's order above. `value` is the weight the gradient
// belongs to, which the L2 regularization term needs and which every update below already holds.
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

// One element-wise pass over a set of MPSVectors. Every update in this file is a walk over the
// elements of its vectors, so the addressing, the length agreement and the element size live here
// once. `vectors` is the caller's own list, `count` how many of them there are, and `what` names the
// kernel for the refusal. Returns NO without touching anything when the vectors do not agree, which
// is what the release asserts on.
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
        // An MPSVector holds `vectors` vectors of `length` components each, and an update walks both
        // axes, so both numbers have to agree across every vector in the set.
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
    // The defaults MPSNNOptimizers.h gives each property, in one place: 1e-3, 1.0, NO, 0.0 and None.
    // So a descriptor made with -init is the descriptor the header describes rather than a zeroed one,
    // which for this class is a difference of two orders of magnitude in the learning rate.
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
    // The no-clipping form, which MPSNNOptimizers.h:104-116 says is the one "no gradient clipping
    // would be applied" - so applyGradientClipping is NO here whatever the other initialiser sets,
    // and the two bounds keep -init's own values because nothing reads them without the flag.
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

// How each of the three concrete optimizers is built. MPSNNOptimizers.h:249 marks the base's
// -initWithDevice: NS_UNAVAILABLE - "You must use one of the sub-classes of MPSNNOptimizer" (:247)
// - so none of the three may call it: [super initWithDevice:] inside any of them resolves to that
// redeclaration and does not compile. The only initializer this base has left is MPSKernel's
// -initWithCoder:device: (MPSKernel.h:162), which decodes an archive and takes a nonnull coder none of
// these kernels has, so this internal one is how they reach MPSKernel's own -initWithDevice:
// (MPSKernel.h:117), which the header does not mark unavailable.
//
// This is not in the `init` family - the name does not begin with "init" in the family's own sense - so
// it must not assign to self, and it returns what the superclass made instead, which is the very object
// the caller's own allocation already is. The shape MPSImageReduceUnary has in CharonMPSReduce.h:35,
// for the same reason; MPSMatrixRandom's seam in CharonMPS.h stays in the init family because it takes
// the generator's identity, which this base has no counterpart for.
- (instancetype)charon_initWithDevice:(id<MTLDevice>)device
{
    MPSNNOptimizer *made = [super initWithDevice:device];
    if (made) {
        // The defaults each concrete optimizer starts from: the descriptor's own (:66, :72, :78, :94,
        // :100), with the momentum terms left to the concrete classes.
        made->_learningRate = 1e-3f;
        made->_gradientRescale = 1.0f;
        made->_applyGradientClipping = NO;
        made->_regularizationType = MPSNNRegularizationTypeNone;
        made->_regularizationScale = 0.0f;
    }
    return made;
}

// MPSNNOptimizers.h:247-249 - NS_UNAVAILABLE, and the comment above it says the base must not be
// instantiated. It declares no -encodeToCommandBuffer: of its own (:209-251 is seven properties, the
// unavailable initializer and the setter), so an object made here is a kernel that can update nothing,
// and the refusal names the three that can - the same answer MPSMatrixRandom13.m:23-27 and
// MPSImageReduceUnary16.m:86-105 give for their own bases.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSNNOptimizer: -initWithDevice: is unavailable on the abstract base - use"
                    @" MPSNNOptimizerStochasticGradientDescent, MPSNNOptimizerRMSProp or"
                    @" MPSNNOptimizerAdam");
    return nil;
}

// The base declares exactly this setter (:265) and learningRate is readonly (:243), so the rate is
// changed through it and nowhere else.
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

// Copy a descriptor's seven values onto a kernel. The descriptor is NOT retained: a kernel that
// outlived the descriptor would otherwise read state the caller had released, and the seven numbers
// are all a kernel needs from it. A descriptor that is nil leaves the kernel on its own defaults,
// which is what the release's own convenience initialisers do - they do not take one.
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
        // "Default value is 0.0" for momentumScale (:253), and the descriptor's own defaults for the
        // rest, which the base's internal initializer above already set.
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
        // The header's own third case, :263-264: with no momentum vector the update is plain gradient
        // descent, variable = variable - (learningRate * g). There is no state to write and so no
        // vector to walk one for.
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
            // The stored momentum and the applied momentum are different under Nesterov, which is why
            // these are two lines and not one: m[t] excludes the learning rate (:261) and the applied
            // step adds it back (:262).
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
        // "Default value is 0.9" (:459) and "default value is 1e-8" (:466).
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
    // MPSNNOptimizers.h:430-432. The sum of squares is the vector's whole state - RMSProp has no
    // momentum term - so s[t] is written back into the vector it was read from.
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
        // "Default value is 0.9" (:505), "Default value is 0.999" (:512), "default value is 1e-8"
        // (:519), and timeStep is "the number of times update has occurred" (:525) - zero before any
        // update, so that the first one runs with t == 1.
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

    // t is incremented once per ENCODE, not once per element: it is the number of updates, so a
    // vector of a thousand elements is one update. The header increments it before it computes lr[t]
    // (:436), so the step that counts is the one after the one already recorded.
    _timeStep += 1;
    double t = (double)_timeStep;
    double denominator = 1.0 - pow(_beta1, t);
    if (denominator == 0.0) {
        // beta1 of one makes the correction's denominator zero. This port says so rather than
        // answering with an infinity, and the step is not counted: nothing was updated.
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
            // Both moments are written back: the next update's m[t-1] and v[t-1] are exactly these.
            CharonMPSStore(CharonMPSVectorElement(&views[2], index, component), views[2].dataType, 0, momentum);
            CharonMPSStore(CharonMPSVectorElement(&views[3], index, component), views[3].dataType, 0, velocity);
            CharonMPSStore(CharonMPSVectorElement(&views[4], index, component), views[4].dataType, 0,
                           value - learningRate * momentum / (sqrt(velocity) + _epsilon));
        }
}

@end