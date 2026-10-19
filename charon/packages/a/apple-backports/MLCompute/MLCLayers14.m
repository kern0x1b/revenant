// The thirty layer classes, with what each factory keeps, what it refuses and the name it gives the
// layer. The arithmetic behind them is in CharonMLCEngine.m, which reads the descriptors and the
// parameters these classes hold.
//
// Every default, every refusal and every name here was measured on the host's own MLCompute and is held
// to it by tests/backports/host/mlcompute (factories.m asks it, cases.m holds the port to it, engine.m
// asks what the framework computes); facts/MLCompute/Layers.md carries the tables and
// facts/MLCompute/Engine.md the arithmetic. What the measurement settled, and what is not in the
// headers:
//
//   - a layer's name is its class's own without MLC and Layer, with four shortened: Compare, Concat,
//     GramMatrix, FullyConnected, and Upsampling for the upsample layer;
//   - +[MLCConvolutionLayer layerWithWeights:biases:descriptor:] validates the weights against the
//     descriptor and keeps nothing at all when they do not match - no descriptor, no weights, no
//     biases and no parameter. A layer with no biases keeps none and has no biases parameter;
//   - the three normalizations want their parameters in the shape the framework's own per-channel
//     descriptor gives, which is 1, channels, 1, 1, and the layer normalization wants a one
//     dimensional beta and gamma. A momentum of 0.99 is what they answer when none is given;
//   - +[MLCSoftmaxLayer layerWithOperation:] reduces over dimension 1 unless another is given;
//   - +[MLCPaddingLayer layerWith...Padding:] reads its array as top, bottom, left, right;
//   - +[MLCSplitLayer layerWithSplitCount:dimension:] answers no section lengths at all, and the form
//     that takes lengths answers a count of how many there are;
//   - +[MLCSliceLayer sliceLayerWithStart:end:stride:] answers a stride of 1 for a nil one;
//   - +[MLCMultiheadAttentionLayer layerWithDescriptor:weights:biases:attentionBiases:] refused every
//     arrangement of weights tried - four matrices of the model's dimension, one of them, two of half
//     it, with and without biases, with the biases declared, three of them, a model of 8, a single head
//     - and answered a layer with nothing every time. This port keeps what it is given instead, and
//     facts/MLCompute/Layers.md names the divergence; a layer that could not be described would be a
//     class that exists but does nothing.

#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

// The two things the thirty layer factories need from their base, declared in MLCTensors14.m beside
// MLCLayer itself: an initialiser the base's header marks unavailable, and the name a factory gives a
// layer. Both are private to the port and named Charon* so the gate weighs neither against a release.
@interface MLCLayer (CharonFactory)
- (instancetype)charon_init;
- (instancetype)charon_label:(NSString *)name;
@end

// The private constructors the factories below reach, declared here because the compiler reads a
// class's own methods in the order they are written.
@interface MLCPaddingLayer (CharonPadding)
+ (instancetype)charon_layerWithType:(MLCPaddingType)type
                             padding:(NSArray<NSNumber *> *)padding
                       constantValue:(float)constantValue;
@end

@interface MLCInstanceNormalizationLayer (CharonNormalizing)
- (void)charon_setFeatureChannelCount:(NSUInteger)channels
                                  beta:(MLCTensor *)beta
                                 gamma:(MLCTensor *)gamma
                         varianceEpsilon:(float)epsilon
                               momentum:(float)momentum
                                   mean:(MLCTensor *)mean
                               variance:(MLCTensor *)variance;
@end

@interface MLCLSTMLayer (CharonGates)
+ (NSArray<MLCActivationDescriptor *> *)charon_defaultGates;
+ (instancetype)charon_layerWithDescriptor:(MLCLSTMDescriptor *)descriptor
                              inputWeights:(NSArray<MLCTensor *> *)inputWeights
                             hiddenWeights:(NSArray<MLCTensor *> *)hiddenWeights
                            peepholeWeights:(NSArray<MLCTensor *> *)peepholeWeights
                                     biases:(NSArray<MLCTensor *> *)biases
                             gateActivations:(NSArray<MLCActivationDescriptor *> *)gateActivations
                        outputResultActivation:(MLCActivationDescriptor *)outputResultActivation;
@end

// The parameter a layer makes for a tensor of its own, which is what the optimizer update writes. The
// framework's parameter is updatable and holds its tensor (measured for the convolution, the fully
// connected, the embedding, the three normalizations and the long short-term memory).
static MLCTensorParameter *CharonMLCParameter(MLCTensor *tensor)
{
    return tensor ? [MLCTensorParameter parameterWithTensor:tensor] : nil;
}

// The parameters of a list of tensors, one for each, and nil for a nil list.
static NSArray<MLCTensorParameter *> *CharonMLCParameters(NSArray<MLCTensor *> *tensors)
{
    if (!tensors) {
        return nil;
    }
    NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:tensors.count];
    for (MLCTensor *tensor in tensors) {
        [parameters addObject:CharonMLCParameter(tensor)];
    }
    return parameters;
}

#pragma mark - MLCSelectionLayer

@implementation MLCSelectionLayer

+ (instancetype)layer
{
    MLCSelectionLayer *layer = [[MLCSelectionLayer alloc] charon_init];
    [layer charon_label:@"Selection"];
    return layer;
}

@end

#pragma mark - MLCActivationLayer

@implementation MLCActivationLayer {
    MLCActivationDescriptor *_descriptor;
}

// The layers of the table in facts/MLCompute/Engine.md: the descriptor each carries, and the name the
// factory gives the layer, which is the same for all of them.
static MLCActivationLayer *CharonMLCActivation(MLCActivationDescriptor *descriptor)
{
    MLCActivationLayer *layer = [[MLCActivationLayer alloc] charon_init];
    layer->_descriptor = descriptor;
    [layer charon_label:@"Activation"];
    return layer;
}

+ (instancetype)layerWithDescriptor:(MLCActivationDescriptor *)descriptor
{
    return CharonMLCActivation(descriptor);
}

+ (MLCActivationLayer *)reluLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]);
}

+ (MLCActivationLayer *)relu6Layer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLUN a:0 b:6]);
}

+ (MLCActivationLayer *)leakyReLULayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU a:0.01]);
}

+ (instancetype)leakyReLULayerWithNegativeSlope:(float)negativeSlope
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU a:negativeSlope]);
}

+ (instancetype)linearLayerWithScale:(float)scale bias:(float)bias
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeLinear a:scale b:bias]);
}

+ (MLCActivationLayer *)sigmoidLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSigmoid]);
}

+ (MLCActivationLayer *)hardSigmoidLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardSigmoid]);
}

+ (MLCActivationLayer *)tanhLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeTanh]);
}

+ (MLCActivationLayer *)absoluteLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeAbsolute]);
}

+ (MLCActivationLayer *)softPlusLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftPlus]);
}

+ (instancetype)softPlusLayerWithBeta:(float)beta
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftPlus a:1.0f b:beta]);
}

+ (MLCActivationLayer *)softSignLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftSign]);
}

+ (MLCActivationLayer *)eluLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeELU]);
}

+ (instancetype)eluLayerWithA:(float)a
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeELU a:a]);
}

+ (instancetype)relunLayerWithA:(float)a b:(float)b
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLUN a:a b:b]);
}

+ (MLCActivationLayer *)logSigmoidLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeLogSigmoid]);
}

+ (MLCActivationLayer *)seluLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSELU]);
}

+ (MLCActivationLayer *)celuLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeCELU]);
}

+ (instancetype)celuLayerWithA:(float)a
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeCELU a:a]);
}

+ (MLCActivationLayer *)hardShrinkLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardShrink]);
}

+ (instancetype)hardShrinkLayerWithA:(float)a
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardShrink a:a]);
}

+ (MLCActivationLayer *)softShrinkLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftShrink]);
}

+ (instancetype)softShrinkLayerWithA:(float)a
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftShrink a:a]);
}

+ (MLCActivationLayer *)tanhShrinkLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeTanhShrink a:0]);
}

+ (instancetype)thresholdLayerWithThreshold:(float)threshold replacement:(float)replacement
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeThreshold a:threshold b:replacement]);
}

+ (MLCActivationLayer *)geluLayer
{
    // Measured against the host's own descriptor, in bits: a is 0x3f4c422a and b is 0x3d372713, and
    // 0.7978845608f and 0.044715f are the two values that are those floats. 0.797885f - the rounded
    // spelling - is 0x3f4c4231 and is not.
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeGELU a:0.7978845608f b:0.044715f]);
}

+ (MLCActivationLayer *)hardSwishLayer
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardSwish]);
}

+ (instancetype)clampLayerWithMinValue:(float)minValue maxValue:(float)maxValue
{
    return CharonMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeClamp a:minValue b:maxValue]);
}

- (MLCActivationDescriptor *)descriptor
{
    return _descriptor;
}

@end

#pragma mark - MLCArithmeticLayer

@implementation MLCArithmeticLayer {
    MLCArithmeticOperation _operation;
}

+ (instancetype)layerWithOperation:(MLCArithmeticOperation)operation
{
    MLCArithmeticLayer *layer = [[MLCArithmeticLayer alloc] charon_init];
    layer->_operation = operation;
    [layer charon_label:@"Arithmetic"];
    return layer;
}

- (MLCArithmeticOperation)operation
{
    return _operation;
}

@end

#pragma mark - MLCComparisonLayer

@implementation MLCComparisonLayer {
    MLCComparisonOperation _operation;
}

+ (instancetype)layerWithOperation:(MLCComparisonOperation)operation
{
    MLCComparisonLayer *layer = [[MLCComparisonLayer alloc] charon_init];
    layer->_operation = operation;
    [layer charon_label:@"Compare"];
    return layer;
}

- (MLCComparisonOperation)operation
{
    return _operation;
}

@end

#pragma mark - MLCConcatenationLayer

@implementation MLCConcatenationLayer {
    NSUInteger _dimension;
}

+ (instancetype)layer
{
    return [self layerWithDimension:1];
}

+ (instancetype)layerWithDimension:(NSUInteger)dimension
{
    MLCConcatenationLayer *layer = [[MLCConcatenationLayer alloc] charon_init];
    layer->_dimension = dimension;
    [layer charon_label:@"Concat"];
    return layer;
}

- (NSUInteger)dimension
{
    return _dimension;
}

@end

#pragma mark - MLCConvolutionLayer

@implementation MLCConvolutionLayer {
    MLCConvolutionDescriptor *_descriptor;
    MLCTensor *_weights;
    MLCTensor *_biases;
    MLCTensorParameter *_weightsParameter;
    MLCTensorParameter *_biasesParameter;
}

// The weights a convolution of this descriptor carries: one image of the output times the input
// channels, by the kernel height and width, which is what the framework's own weights descriptor gives
// and what the factory checks against (measured: anything else is refused whole).
static BOOL CharonMLCWeightsMatch(MLCConvolutionDescriptor *descriptor, MLCTensor *weights)
{
    if (!descriptor || !weights || !weights.descriptor) {
        return NO;
    }
    NSUInteger channels = descriptor.outputFeatureChannelCount * descriptor.inputFeatureChannelCount;
    NSArray *wanted = @[ @1, @(channels), @(descriptor.kernelHeight), @(descriptor.kernelWidth) ];
    return [weights.descriptor.shape isEqualToArray:wanted];
}

+ (instancetype)layerWithWeights:(MLCTensor *)weights
                           biases:(MLCTensor *)biases
                       descriptor:(MLCConvolutionDescriptor *)descriptor
{
    MLCConvolutionLayer *layer = [[MLCConvolutionLayer alloc] charon_init];
    [layer charon_label:@"Convolution"];
    if (!CharonMLCWeightsMatch(descriptor, weights)) {
        return layer;
    }
    layer->_descriptor = descriptor;
    layer->_weights = weights;
    layer->_weightsParameter = CharonMLCParameter(weights);
    // The biases, when there are any, are one per output channel, and their absence is not a failure:
    // a convolution without a bias is the common one and keeps no biases parameter (measured).
    if (biases && biases.descriptor) {
        layer->_biases = biases;
        layer->_biasesParameter = CharonMLCParameter(biases);
    }
    return layer;
}

- (MLCConvolutionDescriptor *)descriptor
{
    return _descriptor;
}

- (MLCTensor *)weights
{
    return _weights;
}

- (MLCTensor *)biases
{
    return _biases;
}

- (MLCTensorParameter *)weightsParameter
{
    return _weightsParameter;
}

- (MLCTensorParameter *)biasesParameter
{
    return _biasesParameter;
}

@end

#pragma mark - MLCFullyConnectedLayer

@implementation MLCFullyConnectedLayer {
    MLCConvolutionDescriptor *_descriptor;
    MLCTensor *_weights;
    MLCTensor *_biases;
    MLCTensorParameter *_weightsParameter;
    MLCTensorParameter *_biasesParameter;
}

// The fully connected layer does not check what it is given: the same mismatched weights a convolution
// refuses are kept here with the descriptor and a parameter (measured).
+ (instancetype)layerWithWeights:(MLCTensor *)weights
                           biases:(MLCTensor *)biases
                       descriptor:(MLCConvolutionDescriptor *)descriptor
{
    MLCFullyConnectedLayer *layer = [[MLCFullyConnectedLayer alloc] charon_init];
    [layer charon_label:@"FullyConnected"];
    layer->_descriptor = descriptor;
    layer->_weights = weights;
    layer->_weightsParameter = CharonMLCParameter(weights);
    if (biases) {
        layer->_biases = biases;
        layer->_biasesParameter = CharonMLCParameter(biases);
    }
    return layer;
}

- (MLCConvolutionDescriptor *)descriptor
{
    return _descriptor;
}

- (MLCTensor *)weights
{
    return _weights;
}

- (MLCTensor *)biases
{
    return _biases;
}

- (MLCTensorParameter *)weightsParameter
{
    return _weightsParameter;
}

- (MLCTensorParameter *)biasesParameter
{
    return _biasesParameter;
}

@end

#pragma mark - MLCPoolingLayer

@implementation MLCPoolingLayer {
    MLCPoolingDescriptor *_descriptor;
}

+ (instancetype)layerWithDescriptor:(MLCPoolingDescriptor *)descriptor
{
    MLCPoolingLayer *layer = [[MLCPoolingLayer alloc] charon_init];
    layer->_descriptor = descriptor;
    [layer charon_label:@"Pooling"];
    return layer;
}

- (MLCPoolingDescriptor *)descriptor
{
    return _descriptor;
}

@end

#pragma mark - MLCPaddingLayer

@implementation MLCPaddingLayer {
    MLCPaddingType _paddingType;
    NSUInteger _paddingTop;
    NSUInteger _paddingBottom;
    NSUInteger _paddingLeft;
    NSUInteger _paddingRight;
    float _constantValue;
}

+ (instancetype)layerWithZeroPadding:(NSArray<NSNumber *> *)padding
{
    return [self charon_layerWithType:MLCPaddingTypeZero padding:padding constantValue:0];
}

+ (instancetype)layerWithSymmetricPadding:(NSArray<NSNumber *> *)padding
{
    return [self charon_layerWithType:MLCPaddingTypeSymmetric padding:padding constantValue:0];
}

+ (instancetype)layerWithReflectionPadding:(NSArray<NSNumber *> *)padding
{
    return [self charon_layerWithType:MLCPaddingTypeReflect padding:padding constantValue:0];
}

+ (instancetype)layerWithConstantPadding:(NSArray<NSNumber *> *)padding constantValue:(float)constantValue
{
    return [self charon_layerWithType:MLCPaddingTypeConstant padding:padding constantValue:constantValue];
}

// The array is read as one or two pairs, and the two lengths the framework refuses it raises for. What
// it answers, measured for each length and for each of the three kinds, which behave alike:
//   one entry  v        top, bottom, left and right all v
//   two        a, b     left a and right b, and no padding above or below
//   four       a..d     top a, bottom b, left c, right d
//   none, or three      NSRangeException
// Every one of the three factories is measured to answer the same for the same array, so the reading is
// the layer's and not the kind's.
+ (instancetype)charon_layerWithType:(MLCPaddingType)type
                            padding:(NSArray<NSNumber *> *)padding
                      constantValue:(float)constantValue
{
    if (padding.count == 0 || padding.count == 3) {
        [NSException raise:NSRangeException format:@"*** -[__NSArrayM objectAtIndex:]: index 3 beyond bounds [0 .. %d]",
                           (int)(padding.count > 0 ? padding.count - 1 : 0)];
    }
    MLCPaddingLayer *paddingLayer = [[MLCPaddingLayer alloc] charon_init];
    [paddingLayer charon_label:@"Padding"];
    paddingLayer->_paddingType = type;
    NSUInteger top = 0, bottom = 0, left = 0, right = 0;
    if (padding.count == 1) {
        top = bottom = left = right = padding[0].unsignedIntegerValue;
    } else if (padding.count == 2) {
        left = padding[0].unsignedIntegerValue;
        right = padding[1].unsignedIntegerValue;
    } else {
        top = padding[0].unsignedIntegerValue;
        bottom = padding[1].unsignedIntegerValue;
        left = padding[2].unsignedIntegerValue;
        right = padding[3].unsignedIntegerValue;
    }
    paddingLayer->_paddingTop = top;
    paddingLayer->_paddingBottom = bottom;
    paddingLayer->_paddingLeft = left;
    paddingLayer->_paddingRight = right;
    paddingLayer->_constantValue = constantValue;
    return paddingLayer;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCPaddingLayer *copy = [MLCPaddingLayer charon_layerWithType:_paddingType
                                                                  padding:@[ @(_paddingTop), @(_paddingBottom), @(_paddingLeft), @(_paddingRight) ]
                                                            constantValue:_constantValue];
    copy.label = self.label;
    return copy;
}

- (MLCPaddingType)paddingType
{
    return _paddingType;
}

- (NSUInteger)paddingTop
{
    return _paddingTop;
}

- (NSUInteger)paddingBottom
{
    return _paddingBottom;
}

- (NSUInteger)paddingLeft
{
    return _paddingLeft;
}

- (NSUInteger)paddingRight
{
    return _paddingRight;
}

- (float)constantValue
{
    return _constantValue;
}

@end

#pragma mark - MLCSoftmaxLayer

@implementation MLCSoftmaxLayer {
    MLCSoftmaxOperation _operation;
    NSUInteger _dimension;
}

+ (instancetype)layerWithOperation:(MLCSoftmaxOperation)operation
{
    return [self layerWithOperation:operation dimension:1];
}

+ (instancetype)layerWithOperation:(MLCSoftmaxOperation)operation dimension:(NSUInteger)dimension
{
    MLCSoftmaxLayer *layer = [[MLCSoftmaxLayer alloc] charon_init];
    layer->_operation = operation;
    layer->_dimension = dimension;
    [layer charon_label:@"Softmax"];
    return layer;
}

- (MLCSoftmaxOperation)operation
{
    return _operation;
}

- (NSUInteger)dimension
{
    return _dimension;
}

@end

#pragma mark - MLCReductionLayer

@implementation MLCReductionLayer {
    MLCReductionType _reductionType;
    NSUInteger _dimension;
    NSArray<NSNumber *> *_dimensions;
}

+ (instancetype)layerWithReductionType:(MLCReductionType)reductionType dimension:(NSUInteger)dimension
{
    return [self layerWithReductionType:reductionType dimensions:@[ @(dimension) ]];
}

+ (instancetype)layerWithReductionType:(MLCReductionType)reductionType dimensions:(NSArray<NSNumber *> *)dimensions
{
    MLCReductionLayer *layer = [[MLCReductionLayer alloc] charon_init];
    layer->_reductionType = reductionType;
    layer->_dimensions = [dimensions copy];
    layer->_dimension = dimensions.count ? dimensions.firstObject.unsignedIntegerValue : 0;
    [layer charon_label:@"Reduction"];
    return layer;
}

- (MLCReductionType)reductionType
{
    return _reductionType;
}

- (NSUInteger)dimension
{
    return _dimension;
}

- (NSArray<NSNumber *> *)dimensions
{
    return _dimensions;
}

@end

#pragma mark - MLCReshapeLayer, MLCTransposeLayer, MLCSliceLayer, MLCSplitLayer, MLCUpsampleLayer, MLCGatherLayer, MLCScatterLayer

@implementation MLCReshapeLayer {
    NSArray<NSNumber *> *_shape;
}

+ (instancetype)layerWithShape:(NSArray<NSNumber *> *)shape
{
    MLCReshapeLayer *layer = [[MLCReshapeLayer alloc] charon_init];
    layer->_shape = [shape copy];
    [layer charon_label:@"Reshape"];
    return layer;
}

- (NSArray<NSNumber *> *)shape
{
    return _shape;
}

@end

@implementation MLCTransposeLayer {
    NSArray<NSNumber *> *_dimensions;
}

+ (instancetype)layerWithDimensions:(NSArray<NSNumber *> *)dimensions
{
    MLCTransposeLayer *layer = [[MLCTransposeLayer alloc] charon_init];
    layer->_dimensions = [dimensions copy];
    [layer charon_label:@"Transpose"];
    return layer;
}

- (NSArray<NSNumber *> *)dimensions
{
    return _dimensions;
}

@end

@implementation MLCSliceLayer {
    NSArray<NSNumber *> *_start;
    NSArray<NSNumber *> *_end;
    NSArray<NSNumber *> *_stride;
}

+ (instancetype)sliceLayerWithStart:(NSArray<NSNumber *> *)start
                                end:(NSArray<NSNumber *> *)end
                             stride:(NSArray<NSNumber *> *)stride
{
    MLCSliceLayer *layer = [[MLCSliceLayer alloc] charon_init];
    layer->_start = [start copy];
    layer->_end = [end copy];
    // A nil stride is a stride of one, and a shorter one is one for every entry it does not name
    // (measured: a nil stride answers 1).
    NSUInteger count = MAX(MAX(start.count, end.count), stride.count);
    NSMutableArray *every = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) {
        [every addObject:@(index < stride.count ? stride[index].unsignedIntegerValue : 1)];
    }
    layer->_stride = every;
    [layer charon_label:@"Slice"];
    return layer;
}

- (NSArray<NSNumber *> *)start
{
    return _start;
}

- (NSArray<NSNumber *> *)end
{
    return _end;
}

- (NSArray<NSNumber *> *)stride
{
    return _stride;
}

@end

@implementation MLCSplitLayer {
    NSUInteger _dimension;
    NSUInteger _splitCount;
    NSArray<NSNumber *> *_splitSectionLengths;
}

+ (instancetype)layerWithSplitCount:(NSUInteger)splitCount dimension:(NSUInteger)dimension
{
    MLCSplitLayer *layer = [[MLCSplitLayer alloc] charon_init];
    layer->_dimension = dimension;
    layer->_splitCount = splitCount;
    [layer charon_label:@"Split"];
    return layer;
}

+ (instancetype)layerWithSplitSectionLengths:(NSArray<NSNumber *> *)splitSectionLengths dimension:(NSUInteger)dimension
{
    MLCSplitLayer *layer = [self layerWithSplitCount:splitSectionLengths.count dimension:dimension];
    layer->_splitSectionLengths = [splitSectionLengths copy];
    return layer;
}

- (NSUInteger)dimension
{
    return _dimension;
}

- (NSUInteger)splitCount
{
    return _splitCount;
}

- (NSArray<NSNumber *> *)splitSectionLengths
{
    return _splitSectionLengths;
}

@end

@implementation MLCUpsampleLayer {
    NSArray<NSNumber *> *_shape;
    MLCSampleMode _sampleMode;
    BOOL _alignsCorners;
}

+ (instancetype)layerWithShape:(NSArray<NSNumber *> *)shape
{
    return [self layerWithShape:shape sampleMode:MLCSampleModeNearest alignsCorners:NO];
}

+ (instancetype)layerWithShape:(NSArray<NSNumber *> *)shape
                    sampleMode:(MLCSampleMode)sampleMode
                 alignsCorners:(BOOL)alignsCorners
{
    MLCUpsampleLayer *layer = [[MLCUpsampleLayer alloc] charon_init];
    layer->_shape = [shape copy];
    layer->_sampleMode = sampleMode;
    layer->_alignsCorners = alignsCorners;
    [layer charon_label:@"Upsampling"];
    return layer;
}

- (NSArray<NSNumber *> *)shape
{
    return _shape;
}

- (MLCSampleMode)sampleMode
{
    return _sampleMode;
}

- (BOOL)alignsCorners
{
    return _alignsCorners;
}

@end

@implementation MLCGatherLayer {
    NSUInteger _dimension;
}

+ (instancetype)layerWithDimension:(NSUInteger)dimension
{
    MLCGatherLayer *layer = [[MLCGatherLayer alloc] charon_init];
    layer->_dimension = dimension;
    [layer charon_label:@"Gather"];
    return layer;
}

- (NSUInteger)dimension
{
    return _dimension;
}

@end

@implementation MLCScatterLayer {
    NSUInteger _dimension;
    MLCReductionType _reductionType;
}

+ (instancetype)layerWithDimension:(NSUInteger)dimension reductionType:(MLCReductionType)reductionType
{
    // The reduction has to be one of the two the header names; anything else answers no layer at all
    // (measured for a reduction of mean).
    if (reductionType != MLCReductionTypeNone && reductionType != MLCReductionTypeSum) {
        return nil;
    }
    MLCScatterLayer *layer = [[MLCScatterLayer alloc] charon_init];
    layer->_dimension = dimension;
    layer->_reductionType = reductionType;
    [layer charon_label:@"Scatter"];
    return layer;
}

- (NSUInteger)dimension
{
    return _dimension;
}

- (MLCReductionType)reductionType
{
    return _reductionType;
}

@end

#pragma mark - MLCDropoutLayer, MLCGramMatrixLayer

@implementation MLCDropoutLayer {
    float _rate;
    NSUInteger _seed;
}

+ (instancetype)layerWithRate:(float)rate seed:(NSUInteger)seed
{
    MLCDropoutLayer *layer = [[MLCDropoutLayer alloc] charon_init];
    layer->_rate = rate;
    layer->_seed = seed;
    [layer charon_label:@"Dropout"];
    return layer;
}

- (float)rate
{
    return _rate;
}

- (NSUInteger)seed
{
    return _seed;
}

@end

@implementation MLCGramMatrixLayer {
    float _scale;
}

+ (instancetype)layerWithScale:(float)scale
{
    MLCGramMatrixLayer *layer = [[MLCGramMatrixLayer alloc] charon_init];
    layer->_scale = scale;
    [layer charon_label:@"GramMatrix"];
    return layer;
}

- (float)scale
{
    return _scale;
}

@end

#pragma mark - MLCMatMulLayer, MLCEmbeddingLayer

@implementation MLCMatMulLayer {
    MLCMatMulDescriptor *_descriptor;
}

+ (instancetype)layerWithDescriptor:(MLCMatMulDescriptor *)descriptor
{
    MLCMatMulLayer *layer = [[MLCMatMulLayer alloc] charon_init];
    layer->_descriptor = descriptor;
    [layer charon_label:@"MatMul"];
    return layer;
}

- (MLCMatMulDescriptor *)descriptor
{
    return _descriptor;
}

@end

@implementation MLCEmbeddingLayer {
    MLCEmbeddingDescriptor *_descriptor;
    MLCTensor *_weights;
    MLCTensorParameter *_weightsParameter;
}

+ (instancetype)layerWithDescriptor:(MLCEmbeddingDescriptor *)descriptor weights:(MLCTensor *)weights
{
    // The weights are not checked, exactly as the fully connected layer does not check its own
    // (measured with a weight tensor of the wrong size: the descriptor and the weights are both kept).
    MLCEmbeddingLayer *layer = [[MLCEmbeddingLayer alloc] charon_init];
    layer->_descriptor = descriptor;
    layer->_weights = weights;
    layer->_weightsParameter = CharonMLCParameter(weights);
    [layer charon_label:@"Embedding"];
    return layer;
}

- (MLCEmbeddingDescriptor *)descriptor
{
    return _descriptor;
}

- (MLCTensor *)weights
{
    return _weights;
}

- (MLCTensorParameter *)weightsParameter
{
    return _weightsParameter;
}

@end

#pragma mark - the three normalizations and the layer normalization

// The parameters of a normalization, which the framework only keeps when each is of the shape its own
// descriptors give: 1, channels, 1, 1 for the batch, instance and group normalizations, and one
// dimension for the layer normalization.
static BOOL CharonMLCPerChannel(MLCTensor *tensor, NSUInteger channels)
{
    if (!tensor || !tensor.descriptor) {
        return NO;
    }
    NSArray *wanted = @[ @1, @(channels), @1, @1 ];
    return [tensor.descriptor.shape isEqualToArray:wanted];
}

static BOOL CharonMLCNormalized(MLCTensor *tensor, NSArray<NSNumber *> *shape)
{
    if (!tensor || !tensor.descriptor) {
        return NO;
    }
    return [tensor.descriptor.shape isEqualToArray:shape];
}

@implementation MLCBatchNormalizationLayer {
    NSUInteger _featureChannelCount;
    MLCTensor *_mean;
    MLCTensor *_variance;
    MLCTensor *_beta;
    MLCTensor *_gamma;
    MLCTensorParameter *_betaParameter;
    MLCTensorParameter *_gammaParameter;
    float _varianceEpsilon;
    float _momentum;
}

+ (instancetype)layerWithFeatureChannelCount:(NSUInteger)featureChannelCount
                                        mean:(MLCTensor *)mean
                                    variance:(MLCTensor *)variance
                                        beta:(MLCTensor *)beta
                                       gamma:(MLCTensor *)gamma
                               varianceEpsilon:(float)varianceEpsilon
{
    return [self layerWithFeatureChannelCount:featureChannelCount
                                        mean:mean
                                    variance:variance
                                        beta:beta
                                       gamma:gamma
                               varianceEpsilon:varianceEpsilon
                                     momentum:0.99f];
}

+ (instancetype)layerWithFeatureChannelCount:(NSUInteger)featureChannelCount
                                        mean:(MLCTensor *)mean
                                    variance:(MLCTensor *)variance
                                        beta:(MLCTensor *)beta
                                       gamma:(MLCTensor *)gamma
                               varianceEpsilon:(float)varianceEpsilon
                                     momentum:(float)momentum
{
    MLCBatchNormalizationLayer *layer = [[MLCBatchNormalizationLayer alloc] charon_init];
    if (!CharonMLCPerChannel(mean, featureChannelCount) || !CharonMLCPerChannel(variance, featureChannelCount)) {
        return layer;
    }
    layer->_featureChannelCount = featureChannelCount;
    layer->_mean = mean;
    layer->_variance = variance;
    layer->_varianceEpsilon = varianceEpsilon;
    layer->_momentum = momentum;
    if (beta && CharonMLCPerChannel(beta, featureChannelCount)) {
        layer->_beta = beta;
        layer->_betaParameter = CharonMLCParameter(beta);
    }
    if (gamma && CharonMLCPerChannel(gamma, featureChannelCount)) {
        layer->_gamma = gamma;
        layer->_gammaParameter = CharonMLCParameter(gamma);
    }
    return layer;
}

- (NSUInteger)featureChannelCount
{
    return _featureChannelCount;
}

- (MLCTensor *)mean
{
    return _mean;
}

- (MLCTensor *)variance
{
    return _variance;
}

- (MLCTensor *)beta
{
    return _beta;
}

- (MLCTensor *)gamma
{
    return _gamma;
}

- (MLCTensorParameter *)betaParameter
{
    return _betaParameter;
}

- (MLCTensorParameter *)gammaParameter
{
    return _gammaParameter;
}

- (float)varianceEpsilon
{
    return _varianceEpsilon;
}

- (float)momentum
{
    return _momentum;
}

@end

@implementation MLCInstanceNormalizationLayer {
    NSUInteger _featureChannelCount;
    MLCTensor *_mean;
    MLCTensor *_variance;
    MLCTensor *_beta;
    MLCTensor *_gamma;
    MLCTensorParameter *_betaParameter;
    MLCTensorParameter *_gammaParameter;
    float _varianceEpsilon;
    float _momentum;
}

+ (instancetype)layerWithFeatureChannelCount:(NSUInteger)featureChannelCount
                                        mean:(MLCTensor *)mean
                                    variance:(MLCTensor *)variance
                                        beta:(MLCTensor *)beta
                                       gamma:(MLCTensor *)gamma
                               varianceEpsilon:(float)varianceEpsilon
                                     momentum:(float)momentum
{
    MLCInstanceNormalizationLayer *layer = [[MLCInstanceNormalizationLayer alloc] charon_init];
    [layer charon_label:@"InstanceNorm"];
    if (!CharonMLCPerChannel(beta, featureChannelCount) && !(beta == nil && gamma == nil)) {
        return layer;
    }
    layer->_featureChannelCount = featureChannelCount;
    layer->_varianceEpsilon = varianceEpsilon;
    layer->_momentum = momentum;
    if (beta) {
        layer->_beta = beta;
        layer->_betaParameter = CharonMLCParameter(beta);
    }
    if (gamma) {
        layer->_gamma = gamma;
        layer->_gammaParameter = CharonMLCParameter(gamma);
    }
    if (mean && CharonMLCPerChannel(mean, featureChannelCount) && variance && CharonMLCPerChannel(variance, featureChannelCount)) {
        layer->_mean = mean;
        layer->_variance = variance;
    }
    return layer;
}

+ (instancetype)layerWithFeatureChannelCount:(NSUInteger)featureChannelCount
                                        beta:(MLCTensor *)beta
                                       gamma:(MLCTensor *)gamma
                               varianceEpsilon:(float)varianceEpsilon
{
    // A normalization with no running mean and no running variance: the framework's own declaration of
    // the mean and the variance is not optional, so the port's own path is what carries the absence,
    // and the layer answers no mean and no variance (measured).
    return [self layerWithFeatureChannelCount:featureChannelCount
                                         beta:beta
                                        gamma:gamma
                                varianceEpsilon:varianceEpsilon
                                      momentum:0.99f];
}

+ (instancetype)layerWithFeatureChannelCount:(NSUInteger)featureChannelCount
                                        beta:(MLCTensor *)beta
                                       gamma:(MLCTensor *)gamma
                               varianceEpsilon:(float)varianceEpsilon
                                     momentum:(float)momentum
{
    // MLCInstanceNormalizationLayer.h:95-99, the momentum overload of the header's own five-argument
    // form. Same layer with the momentum the caller gave instead of the default the form above uses:
    // the momentum is what the header sets for smoothing the running statistics (:92). This layer has
    // no running mean and no running variance to compute, so the
    // value is kept and is what -momentum answers.
    MLCInstanceNormalizationLayer *layer = [[MLCInstanceNormalizationLayer alloc] charon_init];
    [layer charon_label:@"InstanceNorm"];
    [layer charon_setFeatureChannelCount:featureChannelCount
                                    beta:beta
                                   gamma:gamma
                           varianceEpsilon:varianceEpsilon
                                 momentum:momentum
                                    mean:nil
                                variance:nil];
    return layer;
}

- (void)charon_setFeatureChannelCount:(NSUInteger)channels
                                  beta:(MLCTensor *)beta
                                 gamma:(MLCTensor *)gamma
                         varianceEpsilon:(float)epsilon
                               momentum:(float)momentum
                                   mean:(MLCTensor *)mean
                               variance:(MLCTensor *)variance
{
    if (!CharonMLCPerChannel(beta, channels) && !(beta == nil && gamma == nil)) {
        return;
    }
    _featureChannelCount = channels;
    _varianceEpsilon = epsilon;
    _momentum = momentum;
    if (beta) {
        _beta = beta;
        _betaParameter = CharonMLCParameter(beta);
    }
    if (gamma) {
        _gamma = gamma;
        _gammaParameter = CharonMLCParameter(gamma);
    }
    if (mean && variance && CharonMLCPerChannel(mean, channels) && CharonMLCPerChannel(variance, channels)) {
        _mean = mean;
        _variance = variance;
    }
}

- (NSUInteger)featureChannelCount
{
    return _featureChannelCount;
}

- (MLCTensor *)mean
{
    return _mean;
}

- (MLCTensor *)variance
{
    return _variance;
}

- (MLCTensor *)beta
{
    return _beta;
}

- (MLCTensor *)gamma
{
    return _gamma;
}

- (MLCTensorParameter *)betaParameter
{
    return _betaParameter;
}

- (MLCTensorParameter *)gammaParameter
{
    return _gammaParameter;
}

- (float)varianceEpsilon
{
    return _varianceEpsilon;
}

- (float)momentum
{
    return _momentum;
}

@end

@implementation MLCGroupNormalizationLayer {
    NSUInteger _featureChannelCount;
    NSUInteger _groupCount;
    MLCTensor *_beta;
    MLCTensor *_gamma;
    MLCTensorParameter *_betaParameter;
    MLCTensorParameter *_gammaParameter;
    float _varianceEpsilon;
}

+ (instancetype)layerWithFeatureChannelCount:(NSUInteger)featureChannelCount
                                    groupCount:(NSUInteger)groupCount
                                         beta:(MLCTensor *)beta
                                        gamma:(MLCTensor *)gamma
                               varianceEpsilon:(float)varianceEpsilon
{
    MLCGroupNormalizationLayer *layer = [[MLCGroupNormalizationLayer alloc] charon_init];
    [layer charon_label:@"GroupNorm"];
    if (groupCount == 0 || !CharonMLCPerChannel(beta, featureChannelCount) || !CharonMLCPerChannel(gamma, featureChannelCount)) {
        return layer;
    }
    layer->_featureChannelCount = featureChannelCount;
    layer->_groupCount = groupCount;
    layer->_beta = beta;
    layer->_gamma = gamma;
    layer->_varianceEpsilon = varianceEpsilon;
    layer->_betaParameter = CharonMLCParameter(beta);
    layer->_gammaParameter = CharonMLCParameter(gamma);
    return layer;
}

- (NSUInteger)featureChannelCount
{
    return _featureChannelCount;
}

- (NSUInteger)groupCount
{
    return _groupCount;
}

- (MLCTensor *)beta
{
    return _beta;
}

- (MLCTensor *)gamma
{
    return _gamma;
}

- (MLCTensorParameter *)betaParameter
{
    return _betaParameter;
}

- (MLCTensorParameter *)gammaParameter
{
    return _gammaParameter;
}

- (float)varianceEpsilon
{
    return _varianceEpsilon;
}

@end

@implementation MLCLayerNormalizationLayer {
    NSArray<NSNumber *> *_normalizedShape;
    MLCTensor *_beta;
    MLCTensor *_gamma;
    MLCTensorParameter *_betaParameter;
    MLCTensorParameter *_gammaParameter;
    float _varianceEpsilon;
}

+ (instancetype)layerWithNormalizedShape:(NSArray<NSNumber *> *)normalizedShape
                                    beta:(MLCTensor *)beta
                                   gamma:(MLCTensor *)gamma
                           varianceEpsilon:(float)varianceEpsilon
{
    MLCLayerNormalizationLayer *layer = [[MLCLayerNormalizationLayer alloc] charon_init];
    [layer charon_label:@"LayerNorm"];
    if (!CharonMLCNormalized(beta, normalizedShape) || !CharonMLCNormalized(gamma, normalizedShape)) {
        return layer;
    }
    layer->_normalizedShape = [normalizedShape copy];
    layer->_beta = beta;
    layer->_gamma = gamma;
    layer->_varianceEpsilon = varianceEpsilon;
    layer->_betaParameter = CharonMLCParameter(beta);
    layer->_gammaParameter = CharonMLCParameter(gamma);
    return layer;
}

- (NSArray<NSNumber *> *)normalizedShape
{
    return _normalizedShape;
}

- (MLCTensor *)beta
{
    return _beta;
}

- (MLCTensor *)gamma
{
    return _gamma;
}

- (MLCTensorParameter *)betaParameter
{
    return _betaParameter;
}

- (MLCTensorParameter *)gammaParameter
{
    return _gammaParameter;
}

- (float)varianceEpsilon
{
    return _varianceEpsilon;
}

@end

#pragma mark - MLCLossLayer, MLCYOLOLossLayer, MLCYOLOLossDescriptor's layer

@implementation MLCLossLayer {
    MLCLossDescriptor *_descriptor;
    MLCTensor *_weights;
}

+ (instancetype)layerWithDescriptor:(MLCLossDescriptor *)lossDescriptor
{
    // The label weights are optional: a loss with none of them is the common one, and the framework's
    // own declaration is not optional, so the port's own path is what carries the absence.
    MLCLossLayer *layer = [[MLCLossLayer alloc] charon_init];
    layer->_descriptor = lossDescriptor;
    return [layer charon_label:@"Loss"];
}

+ (instancetype)layerWithDescriptor:(MLCLossDescriptor *)lossDescriptor weights:(MLCTensor *)weights
{
    MLCLossLayer *layer = [[MLCLossLayer alloc] charon_init];
    layer->_descriptor = lossDescriptor;
    layer->_weights = weights;
    [layer charon_label:@"Loss"];
    return layer;
}

+ (instancetype)softmaxCrossEntropyLossWithReductionType:(MLCReductionType)reductionType
                                            labelSmoothing:(float)labelSmoothing
                                              classCount:(NSUInteger)classCount
                                                   weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeSoftmaxCrossEntropy
                                                            reductionType:reductionType
                                                                  weight:weight
                                                          labelSmoothing:labelSmoothing
                                                            classCount:classCount]];
}

+ (instancetype)softmaxCrossEntropyLossWithReductionType:(MLCReductionType)reductionType
                                            labelSmoothing:(float)labelSmoothing
                                              classCount:(NSUInteger)classCount
                                                 weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeSoftmaxCrossEntropy
                                                            reductionType:reductionType
                                                                  weight:1.0f
                                                          labelSmoothing:labelSmoothing
                                                            classCount:classCount]
                             weights:weights];
}

+ (instancetype)categoricalCrossEntropyLossWithReductionType:(MLCReductionType)reductionType
                                               labelSmoothing:(float)labelSmoothing
                                                 classCount:(NSUInteger)classCount
                                                      weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeCategoricalCrossEntropy
                                                            reductionType:reductionType
                                                                  weight:weight
                                                          labelSmoothing:labelSmoothing
                                                            classCount:classCount]];
}

+ (instancetype)categoricalCrossEntropyLossWithReductionType:(MLCReductionType)reductionType
                                               labelSmoothing:(float)labelSmoothing
                                                 classCount:(NSUInteger)classCount
                                                    weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeCategoricalCrossEntropy
                                                            reductionType:reductionType
                                                                  weight:1.0f
                                                          labelSmoothing:labelSmoothing
                                                            classCount:classCount]
                             weights:weights];
}

+ (instancetype)sigmoidCrossEntropyLossWithReductionType:(MLCReductionType)reductionType
                                           labelSmoothing:(float)labelSmoothing
                                                   weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeSigmoidCrossEntropy
                                                            reductionType:reductionType
                                                                  weight:weight
                                                          labelSmoothing:labelSmoothing
                                                            classCount:1]];
}

+ (instancetype)sigmoidCrossEntropyLossWithReductionType:(MLCReductionType)reductionType
                                           labelSmoothing:(float)labelSmoothing
                                                  weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeSigmoidCrossEntropy
                                                            reductionType:reductionType
                                                                  weight:1.0f
                                                          labelSmoothing:labelSmoothing
                                                            classCount:1]
                             weights:weights];
}

+ (instancetype)logLossWithReductionType:(MLCReductionType)reductionType epsilon:(float)epsilon weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeLog
                                                            reductionType:reductionType
                                                                  weight:weight
                                                          labelSmoothing:0.0f
                                                            classCount:1
                                                                epsilon:epsilon
                                                                  delta:1.0f]];
}

+ (instancetype)logLossWithReductionType:(MLCReductionType)reductionType epsilon:(float)epsilon weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeLog
                                                            reductionType:reductionType
                                                                  weight:1.0f
                                                          labelSmoothing:0.0f
                                                            classCount:1
                                                                epsilon:epsilon
                                                                  delta:1.0f]
                             weights:weights];
}

+ (instancetype)huberLossWithReductionType:(MLCReductionType)reductionType delta:(float)delta weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeHuber
                                                            reductionType:reductionType
                                                                  weight:weight
                                                          labelSmoothing:0.0f
                                                            classCount:1
                                                                epsilon:1e-7f
                                                                  delta:delta]];
}

+ (instancetype)huberLossWithReductionType:(MLCReductionType)reductionType delta:(float)delta weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeHuber
                                                            reductionType:reductionType
                                                                  weight:1.0f
                                                          labelSmoothing:0.0f
                                                            classCount:1
                                                                epsilon:1e-7f
                                                                  delta:delta]
                             weights:weights];
}

+ (instancetype)meanAbsoluteErrorLossWithReductionType:(MLCReductionType)reductionType weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeMeanAbsoluteError
                                                            reductionType:reductionType
                                                                  weight:weight]];
}

+ (instancetype)meanAbsoluteErrorLossWithReductionType:(MLCReductionType)reductionType weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeMeanAbsoluteError
                                                            reductionType:reductionType
                                                                  weight:1.0f]
                             weights:weights];
}

+ (instancetype)meanSquaredErrorLossWithReductionType:(MLCReductionType)reductionType weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeMeanSquaredError
                                                            reductionType:reductionType
                                                                  weight:weight]];
}

+ (instancetype)meanSquaredErrorLossWithReductionType:(MLCReductionType)reductionType weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeMeanSquaredError
                                                            reductionType:reductionType
                                                                  weight:1.0f]
                             weights:weights];
}

+ (instancetype)hingeLossWithReductionType:(MLCReductionType)reductionType weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeHinge
                                                            reductionType:reductionType
                                                                  weight:weight]];
}

+ (instancetype)hingeLossWithReductionType:(MLCReductionType)reductionType weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeHinge
                                                            reductionType:reductionType
                                                                  weight:1.0f]
                             weights:weights];
}

+ (instancetype)cosineDistanceLossWithReductionType:(MLCReductionType)reductionType weight:(float)weight
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeCosineDistance
                                                            reductionType:reductionType
                                                                  weight:weight]];
}

+ (instancetype)cosineDistanceLossWithReductionType:(MLCReductionType)reductionType weights:(MLCTensor *)weights
{
    return [self layerWithDescriptor:[MLCLossDescriptor descriptorWithType:MLCLossTypeCosineDistance
                                                            reductionType:reductionType
                                                                  weight:1.0f]
                             weights:weights];
}

- (MLCLossDescriptor *)descriptor
{
    return _descriptor;
}

- (MLCTensor *)weights
{
    return _weights;
}

@end

@implementation MLCYOLOLossLayer {
    MLCYOLOLossDescriptor *_yoloLossDescriptor;
}

+ (instancetype)layerWithDescriptor:(MLCYOLOLossDescriptor *)lossDescriptor
{
    MLCYOLOLossLayer *layer = [[MLCYOLOLossLayer alloc] charon_init];
    layer->_yoloLossDescriptor = lossDescriptor;
    [layer charon_label:@"Loss"];
    return layer;
}

- (MLCYOLOLossDescriptor *)yoloLossDescriptor
{
    return _yoloLossDescriptor;
}

@end

#pragma mark - MLCLSTMLayer and MLCMultiheadAttentionLayer

@implementation MLCLSTMLayer {
    MLCLSTMDescriptor *_descriptor;
    NSArray<MLCActivationDescriptor *> *_gateActivations;
    MLCActivationDescriptor *_outputResultActivation;
    NSArray<MLCTensor *> *_inputWeights;
    NSArray<MLCTensor *> *_hiddenWeights;
    NSArray<MLCTensor *> *_peepholeWeights;
    NSArray<MLCTensor *> *_biases;
    NSArray<MLCTensorParameter *> *_inputWeightsParameters;
    NSArray<MLCTensorParameter *> *_hiddenWeightsParameters;
    NSArray<MLCTensorParameter *> *_peepholeWeightsParameters;
    NSArray<MLCTensorParameter *> *_biasesParameters;
}

// The gates of a long short-term memory when the factory is given none: three sigmoids and a tanh - the
// input, the forget and the output gate are sigmoids and the cell gate a tanh - and the activation of
// the result is a tanh too. The framework supplies them only when it has weights to supply them for: a
// layer with no weights at all answers no gate and an identity output (measured, both ways).
+ (instancetype)charon_layerWithDescriptor:(MLCLSTMDescriptor *)descriptor
                             inputWeights:(NSArray<MLCTensor *> *)inputWeights
                            hiddenWeights:(NSArray<MLCTensor *> *)hiddenWeights
                           peepholeWeights:(NSArray<MLCTensor *> *)peepholeWeights
                                    biases:(NSArray<MLCTensor *> *)biases
                            gateActivations:(NSArray<MLCActivationDescriptor *> *)gateActivations
                       outputResultActivation:(MLCActivationDescriptor *)outputResultActivation
{
    MLCLSTMLayer *layer = [[MLCLSTMLayer alloc] charon_init];
    [layer charon_label:@"LSTM"];
    layer->_descriptor = descriptor;
    layer->_inputWeights = [inputWeights copy];
    layer->_hiddenWeights = [hiddenWeights copy];
    layer->_peepholeWeights = [peepholeWeights copy];
    layer->_biases = [biases copy];
    layer->_inputWeightsParameters = CharonMLCParameters(inputWeights);
    layer->_hiddenWeightsParameters = CharonMLCParameters(hiddenWeights);
    layer->_peepholeWeightsParameters = CharonMLCParameters(peepholeWeights);
    layer->_biasesParameters = CharonMLCParameters(biases);
    if (gateActivations) {
        layer->_gateActivations = [gateActivations copy];
    } else if (layer->_inputWeights) {
        layer->_gateActivations = [MLCLSTMLayer charon_defaultGates];
    }
    if (outputResultActivation) {
        layer->_outputResultActivation = outputResultActivation;
    } else if (layer->_inputWeights) {
        layer->_outputResultActivation = [MLCActivationDescriptor descriptorWithType:MLCActivationTypeTanh];
    }
    return layer;
}

+ (NSArray<MLCActivationDescriptor *> *)charon_defaultGates
{
    static const MLCActivationType types[] = { MLCActivationTypeSigmoid, MLCActivationTypeSigmoid,
                                               MLCActivationTypeTanh, MLCActivationTypeSigmoid };
    NSMutableArray *gates = [NSMutableArray arrayWithCapacity:4];
    for (int index = 0; index < 4; index++) {
        [gates addObject:[MLCActivationDescriptor descriptorWithType:types[index]]];
    }
    return gates;
}

+ (instancetype)layerWithDescriptor:(MLCLSTMDescriptor *)descriptor
                        inputWeights:(NSArray<MLCTensor *> *)inputWeights
                       hiddenWeights:(NSArray<MLCTensor *> *)hiddenWeights
                             biases:(NSArray<MLCTensor *> *)biases
{
    return [self charon_layerWithDescriptor:descriptor
                              inputWeights:inputWeights
                             hiddenWeights:hiddenWeights
                            peepholeWeights:nil
                                     biases:biases
                             gateActivations:nil
                        outputResultActivation:nil];
}

+ (instancetype)layerWithDescriptor:(MLCLSTMDescriptor *)descriptor
                        inputWeights:(NSArray<MLCTensor *> *)inputWeights
                       hiddenWeights:(NSArray<MLCTensor *> *)hiddenWeights
                     peepholeWeights:(NSArray<MLCTensor *> *)peepholeWeights
                             biases:(NSArray<MLCTensor *> *)biases
{
    // nil, as the framework answers. This form and the one that also takes both activation arrays refuse
    // every peephole weight and gate arrangement tried - four gates of the hidden size, one, three, none,
    // with and without biases, the biases declared and not - and answer nil every time, while the three
    // shorter forms keep what they are given (measured, facts/MLCompute/Layers.md). The port answers nil
    // for the same reason: a factory that answered a layer the framework would not is a row whose
    // behaviour is not the framework's, and the rule that accepts them is not measured. Both are cases in
    // tests/backports/host/mlcompute, so a framework that starts accepting weights shows up there rather
    // than in a silence.
    return nil;
}

+ (instancetype)layerWithDescriptor:(MLCLSTMDescriptor *)descriptor
                        inputWeights:(NSArray<MLCTensor *> *)inputWeights
                       hiddenWeights:(NSArray<MLCTensor *> *)hiddenWeights
                     peepholeWeights:(NSArray<MLCTensor *> *)peepholeWeights
                             biases:(NSArray<MLCTensor *> *)biases
                     gateActivations:(NSArray<MLCActivationDescriptor *> *)gateActivations
                outputResultActivation:(MLCActivationDescriptor *)outputResultActivation
{
    return nil;
}

- (MLCLSTMDescriptor *)descriptor
{
    return _descriptor;
}

- (NSArray<MLCActivationDescriptor *> *)gateActivations
{
    return _gateActivations;
}

- (MLCActivationDescriptor *)outputResultActivation
{
    return _outputResultActivation;
}

- (NSArray<MLCTensor *> *)inputWeights
{
    return _inputWeights;
}

- (NSArray<MLCTensor *> *)hiddenWeights
{
    return _hiddenWeights;
}

- (NSArray<MLCTensor *> *)peepholeWeights
{
    return _peepholeWeights;
}

- (NSArray<MLCTensor *> *)biases
{
    return _biases;
}

- (NSArray<MLCTensorParameter *> *)inputWeightsParameters
{
    return _inputWeightsParameters;
}

- (NSArray<MLCTensorParameter *> *)hiddenWeightsParameters
{
    return _hiddenWeightsParameters;
}

- (NSArray<MLCTensorParameter *> *)peepholeWeightsParameters
{
    return _peepholeWeightsParameters;
}

- (NSArray<MLCTensorParameter *> *)biasesParameters
{
    return _biasesParameters;
}

@end

@implementation MLCMultiheadAttentionLayer {
    MLCMultiheadAttentionDescriptor *_descriptor;
    NSArray<MLCTensor *> *_weights;
    NSArray<MLCTensor *> *_biases;
    NSArray<MLCTensor *> *_attentionBiases;
    NSArray<MLCTensorParameter *> *_weightsParameters;
    NSArray<MLCTensorParameter *> *_biasesParameters;
}

+ (instancetype)layerWithDescriptor:(MLCMultiheadAttentionDescriptor *)descriptor
                             weights:(NSArray<MLCTensor *> *)weights
                              biases:(NSArray<MLCTensor *> *)biases
                      attentionBiases:(NSArray<MLCTensor *> *)attentionBiases
{
    // nil, as the framework answers. It refused every arrangement of weights and biases tried - four
    // matrices of the model's dimension, one of them, two of half it, three of them, with and without
    // biases, with the biases declared, a model of 8, a single head - and answered a layer with nothing
    // every time (measured, facts/MLCompute/Layers.md). The port answers nil for the same reason as the two
    // long short-term memory factories above: a factory that answered a layer the framework would not is a
    // row whose behaviour is not the framework's. It is a case in tests/backports/host/mlcompute, which
    // had none.
    return nil;
}

- (MLCMultiheadAttentionDescriptor *)descriptor
{
    return _descriptor;
}

- (NSArray<MLCTensor *> *)weights
{
    return _weights;
}

- (NSArray<MLCTensor *> *)biases
{
    return _biases;
}

- (NSArray<MLCTensor *> *)attentionBiases
{
    return _attentionBiases;
}

- (NSArray<MLCTensorParameter *> *)weightsParameters
{
    return _weightsParameters;
}

- (NSArray<MLCTensorParameter *> *)biasesParameters
{
    return _biasesParameters;
}

@end
