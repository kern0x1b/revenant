#import "RevenantMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

@interface MLCLayer (RevenantFactory)
- (instancetype)revenant_init;
- (instancetype)revenant_label:(NSString *)name;
@end

@interface MLCPaddingLayer (RevenantPadding)
+ (instancetype)revenant_layerWithType:(MLCPaddingType)type
                             padding:(NSArray<NSNumber *> *)padding
                       constantValue:(float)constantValue;
@end

@interface MLCInstanceNormalizationLayer (RevenantNormalizing)
- (void)revenant_setFeatureChannelCount:(NSUInteger)channels
                                  beta:(MLCTensor *)beta
                                 gamma:(MLCTensor *)gamma
                         varianceEpsilon:(float)epsilon
                               momentum:(float)momentum
                                   mean:(MLCTensor *)mean
                               variance:(MLCTensor *)variance;
@end

@interface MLCLSTMLayer (RevenantGates)
+ (NSArray<MLCActivationDescriptor *> *)revenant_defaultGates;
+ (instancetype)revenant_layerWithDescriptor:(MLCLSTMDescriptor *)descriptor
                              inputWeights:(NSArray<MLCTensor *> *)inputWeights
                             hiddenWeights:(NSArray<MLCTensor *> *)hiddenWeights
                            peepholeWeights:(NSArray<MLCTensor *> *)peepholeWeights
                                     biases:(NSArray<MLCTensor *> *)biases
                             gateActivations:(NSArray<MLCActivationDescriptor *> *)gateActivations
                        outputResultActivation:(MLCActivationDescriptor *)outputResultActivation;
@end

static MLCTensorParameter *RevenantMLCParameter(MLCTensor *tensor)
{
    return tensor ? [MLCTensorParameter parameterWithTensor:tensor] : nil;
}

static NSArray<MLCTensorParameter *> *RevenantMLCParameters(NSArray<MLCTensor *> *tensors)
{
    if (!tensors) {
        return nil;
    }
    NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:tensors.count];
    for (MLCTensor *tensor in tensors) {
        [parameters addObject:RevenantMLCParameter(tensor)];
    }
    return parameters;
}

#pragma mark - MLCSelectionLayer

@implementation MLCSelectionLayer

+ (instancetype)layer
{
    MLCSelectionLayer *layer = [[MLCSelectionLayer alloc] revenant_init];
    [layer revenant_label:@"Selection"];
    return layer;
}

@end

#pragma mark - MLCActivationLayer

@implementation MLCActivationLayer {
    MLCActivationDescriptor *_descriptor;
}

static MLCActivationLayer *RevenantMLCActivation(MLCActivationDescriptor *descriptor)
{
    MLCActivationLayer *layer = [[MLCActivationLayer alloc] revenant_init];
    layer->_descriptor = descriptor;
    [layer revenant_label:@"Activation"];
    return layer;
}

+ (instancetype)layerWithDescriptor:(MLCActivationDescriptor *)descriptor
{
    return RevenantMLCActivation(descriptor);
}

+ (MLCActivationLayer *)reluLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]);
}

+ (MLCActivationLayer *)relu6Layer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLUN a:0 b:6]);
}

+ (MLCActivationLayer *)leakyReLULayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU a:0.01]);
}

+ (instancetype)leakyReLULayerWithNegativeSlope:(float)negativeSlope
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU a:negativeSlope]);
}

+ (instancetype)linearLayerWithScale:(float)scale bias:(float)bias
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeLinear a:scale b:bias]);
}

+ (MLCActivationLayer *)sigmoidLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSigmoid]);
}

+ (MLCActivationLayer *)hardSigmoidLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardSigmoid]);
}

+ (MLCActivationLayer *)tanhLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeTanh]);
}

+ (MLCActivationLayer *)absoluteLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeAbsolute]);
}

+ (MLCActivationLayer *)softPlusLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftPlus]);
}

+ (instancetype)softPlusLayerWithBeta:(float)beta
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftPlus a:1.0f b:beta]);
}

+ (MLCActivationLayer *)softSignLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftSign]);
}

+ (MLCActivationLayer *)eluLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeELU]);
}

+ (instancetype)eluLayerWithA:(float)a
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeELU a:a]);
}

+ (instancetype)relunLayerWithA:(float)a b:(float)b
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLUN a:a b:b]);
}

+ (MLCActivationLayer *)logSigmoidLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeLogSigmoid]);
}

+ (MLCActivationLayer *)seluLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSELU]);
}

+ (MLCActivationLayer *)celuLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeCELU]);
}

+ (instancetype)celuLayerWithA:(float)a
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeCELU a:a]);
}

+ (MLCActivationLayer *)hardShrinkLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardShrink]);
}

+ (instancetype)hardShrinkLayerWithA:(float)a
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardShrink a:a]);
}

+ (MLCActivationLayer *)softShrinkLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftShrink]);
}

+ (instancetype)softShrinkLayerWithA:(float)a
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeSoftShrink a:a]);
}

+ (MLCActivationLayer *)tanhShrinkLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeTanhShrink a:0]);
}

+ (instancetype)thresholdLayerWithThreshold:(float)threshold replacement:(float)replacement
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeThreshold a:threshold b:replacement]);
}

+ (MLCActivationLayer *)geluLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeGELU a:0.7978845608f b:0.044715f]);
}

+ (MLCActivationLayer *)hardSwishLayer
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardSwish]);
}

+ (instancetype)clampLayerWithMinValue:(float)minValue maxValue:(float)maxValue
{
    return RevenantMLCActivation([MLCActivationDescriptor descriptorWithType:MLCActivationTypeClamp a:minValue b:maxValue]);
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
    MLCArithmeticLayer *layer = [[MLCArithmeticLayer alloc] revenant_init];
    layer->_operation = operation;
    [layer revenant_label:@"Arithmetic"];
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
    MLCComparisonLayer *layer = [[MLCComparisonLayer alloc] revenant_init];
    layer->_operation = operation;
    [layer revenant_label:@"Compare"];
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
    MLCConcatenationLayer *layer = [[MLCConcatenationLayer alloc] revenant_init];
    layer->_dimension = dimension;
    [layer revenant_label:@"Concat"];
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

static BOOL RevenantMLCWeightsMatch(MLCConvolutionDescriptor *descriptor, MLCTensor *weights)
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
    MLCConvolutionLayer *layer = [[MLCConvolutionLayer alloc] revenant_init];
    [layer revenant_label:@"Convolution"];
    if (!RevenantMLCWeightsMatch(descriptor, weights)) {
        return layer;
    }
    layer->_descriptor = descriptor;
    layer->_weights = weights;
    layer->_weightsParameter = RevenantMLCParameter(weights);
    if (biases && biases.descriptor) {
        layer->_biases = biases;
        layer->_biasesParameter = RevenantMLCParameter(biases);
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

+ (instancetype)layerWithWeights:(MLCTensor *)weights
                           biases:(MLCTensor *)biases
                       descriptor:(MLCConvolutionDescriptor *)descriptor
{
    MLCFullyConnectedLayer *layer = [[MLCFullyConnectedLayer alloc] revenant_init];
    [layer revenant_label:@"FullyConnected"];
    layer->_descriptor = descriptor;
    layer->_weights = weights;
    layer->_weightsParameter = RevenantMLCParameter(weights);
    if (biases) {
        layer->_biases = biases;
        layer->_biasesParameter = RevenantMLCParameter(biases);
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
    MLCPoolingLayer *layer = [[MLCPoolingLayer alloc] revenant_init];
    layer->_descriptor = descriptor;
    [layer revenant_label:@"Pooling"];
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
    return [self revenant_layerWithType:MLCPaddingTypeZero padding:padding constantValue:0];
}

+ (instancetype)layerWithSymmetricPadding:(NSArray<NSNumber *> *)padding
{
    return [self revenant_layerWithType:MLCPaddingTypeSymmetric padding:padding constantValue:0];
}

+ (instancetype)layerWithReflectionPadding:(NSArray<NSNumber *> *)padding
{
    return [self revenant_layerWithType:MLCPaddingTypeReflect padding:padding constantValue:0];
}

+ (instancetype)layerWithConstantPadding:(NSArray<NSNumber *> *)padding constantValue:(float)constantValue
{
    return [self revenant_layerWithType:MLCPaddingTypeConstant padding:padding constantValue:constantValue];
}

+ (instancetype)revenant_layerWithType:(MLCPaddingType)type
                            padding:(NSArray<NSNumber *> *)padding
                      constantValue:(float)constantValue
{
    if (padding.count == 0 || padding.count == 3) {
        [NSException raise:NSRangeException format:@"*** -[__NSArrayM objectAtIndex:]: index 3 beyond bounds [0 .. %d]",
                           (int)(padding.count > 0 ? padding.count - 1 : 0)];
    }
    MLCPaddingLayer *paddingLayer = [[MLCPaddingLayer alloc] revenant_init];
    [paddingLayer revenant_label:@"Padding"];
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
    MLCPaddingLayer *copy = [MLCPaddingLayer revenant_layerWithType:_paddingType
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
    MLCSoftmaxLayer *layer = [[MLCSoftmaxLayer alloc] revenant_init];
    layer->_operation = operation;
    layer->_dimension = dimension;
    [layer revenant_label:@"Softmax"];
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
    MLCReductionLayer *layer = [[MLCReductionLayer alloc] revenant_init];
    layer->_reductionType = reductionType;
    layer->_dimensions = [dimensions copy];
    layer->_dimension = dimensions.count ? dimensions.firstObject.unsignedIntegerValue : 0;
    [layer revenant_label:@"Reduction"];
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
    MLCReshapeLayer *layer = [[MLCReshapeLayer alloc] revenant_init];
    layer->_shape = [shape copy];
    [layer revenant_label:@"Reshape"];
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
    MLCTransposeLayer *layer = [[MLCTransposeLayer alloc] revenant_init];
    layer->_dimensions = [dimensions copy];
    [layer revenant_label:@"Transpose"];
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
    MLCSliceLayer *layer = [[MLCSliceLayer alloc] revenant_init];
    layer->_start = [start copy];
    layer->_end = [end copy];
    NSUInteger count = MAX(MAX(start.count, end.count), stride.count);
    NSMutableArray *every = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) {
        [every addObject:@(index < stride.count ? stride[index].unsignedIntegerValue : 1)];
    }
    layer->_stride = every;
    [layer revenant_label:@"Slice"];
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
    MLCSplitLayer *layer = [[MLCSplitLayer alloc] revenant_init];
    layer->_dimension = dimension;
    layer->_splitCount = splitCount;
    [layer revenant_label:@"Split"];
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
    MLCUpsampleLayer *layer = [[MLCUpsampleLayer alloc] revenant_init];
    layer->_shape = [shape copy];
    layer->_sampleMode = sampleMode;
    layer->_alignsCorners = alignsCorners;
    [layer revenant_label:@"Upsampling"];
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
    MLCGatherLayer *layer = [[MLCGatherLayer alloc] revenant_init];
    layer->_dimension = dimension;
    [layer revenant_label:@"Gather"];
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
    if (reductionType != MLCReductionTypeNone && reductionType != MLCReductionTypeSum) {
        return nil;
    }
    MLCScatterLayer *layer = [[MLCScatterLayer alloc] revenant_init];
    layer->_dimension = dimension;
    layer->_reductionType = reductionType;
    [layer revenant_label:@"Scatter"];
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
    MLCDropoutLayer *layer = [[MLCDropoutLayer alloc] revenant_init];
    layer->_rate = rate;
    layer->_seed = seed;
    [layer revenant_label:@"Dropout"];
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
    MLCGramMatrixLayer *layer = [[MLCGramMatrixLayer alloc] revenant_init];
    layer->_scale = scale;
    [layer revenant_label:@"GramMatrix"];
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
    MLCMatMulLayer *layer = [[MLCMatMulLayer alloc] revenant_init];
    layer->_descriptor = descriptor;
    [layer revenant_label:@"MatMul"];
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
    MLCEmbeddingLayer *layer = [[MLCEmbeddingLayer alloc] revenant_init];
    layer->_descriptor = descriptor;
    layer->_weights = weights;
    layer->_weightsParameter = RevenantMLCParameter(weights);
    [layer revenant_label:@"Embedding"];
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

static BOOL RevenantMLCPerChannel(MLCTensor *tensor, NSUInteger channels)
{
    if (!tensor || !tensor.descriptor) {
        return NO;
    }
    NSArray *wanted = @[ @1, @(channels), @1, @1 ];
    return [tensor.descriptor.shape isEqualToArray:wanted];
}

static BOOL RevenantMLCNormalized(MLCTensor *tensor, NSArray<NSNumber *> *shape)
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
    MLCBatchNormalizationLayer *layer = [[MLCBatchNormalizationLayer alloc] revenant_init];
    if (!RevenantMLCPerChannel(mean, featureChannelCount) || !RevenantMLCPerChannel(variance, featureChannelCount)) {
        return layer;
    }
    layer->_featureChannelCount = featureChannelCount;
    layer->_mean = mean;
    layer->_variance = variance;
    layer->_varianceEpsilon = varianceEpsilon;
    layer->_momentum = momentum;
    if (beta && RevenantMLCPerChannel(beta, featureChannelCount)) {
        layer->_beta = beta;
        layer->_betaParameter = RevenantMLCParameter(beta);
    }
    if (gamma && RevenantMLCPerChannel(gamma, featureChannelCount)) {
        layer->_gamma = gamma;
        layer->_gammaParameter = RevenantMLCParameter(gamma);
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
    MLCInstanceNormalizationLayer *layer = [[MLCInstanceNormalizationLayer alloc] revenant_init];
    [layer revenant_label:@"InstanceNorm"];
    if (!RevenantMLCPerChannel(beta, featureChannelCount) && !(beta == nil && gamma == nil)) {
        return layer;
    }
    layer->_featureChannelCount = featureChannelCount;
    layer->_varianceEpsilon = varianceEpsilon;
    layer->_momentum = momentum;
    if (beta) {
        layer->_beta = beta;
        layer->_betaParameter = RevenantMLCParameter(beta);
    }
    if (gamma) {
        layer->_gamma = gamma;
        layer->_gammaParameter = RevenantMLCParameter(gamma);
    }
    if (mean && RevenantMLCPerChannel(mean, featureChannelCount) && variance && RevenantMLCPerChannel(variance, featureChannelCount)) {
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
    MLCInstanceNormalizationLayer *layer = [[MLCInstanceNormalizationLayer alloc] revenant_init];
    [layer revenant_label:@"InstanceNorm"];
    [layer revenant_setFeatureChannelCount:featureChannelCount
                                    beta:beta
                                   gamma:gamma
                           varianceEpsilon:varianceEpsilon
                                 momentum:momentum
                                    mean:nil
                                variance:nil];
    return layer;
}

- (void)revenant_setFeatureChannelCount:(NSUInteger)channels
                                  beta:(MLCTensor *)beta
                                 gamma:(MLCTensor *)gamma
                         varianceEpsilon:(float)epsilon
                               momentum:(float)momentum
                                   mean:(MLCTensor *)mean
                               variance:(MLCTensor *)variance
{
    if (!RevenantMLCPerChannel(beta, channels) && !(beta == nil && gamma == nil)) {
        return;
    }
    _featureChannelCount = channels;
    _varianceEpsilon = epsilon;
    _momentum = momentum;
    if (beta) {
        _beta = beta;
        _betaParameter = RevenantMLCParameter(beta);
    }
    if (gamma) {
        _gamma = gamma;
        _gammaParameter = RevenantMLCParameter(gamma);
    }
    if (mean && variance && RevenantMLCPerChannel(mean, channels) && RevenantMLCPerChannel(variance, channels)) {
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
    MLCGroupNormalizationLayer *layer = [[MLCGroupNormalizationLayer alloc] revenant_init];
    [layer revenant_label:@"GroupNorm"];
    if (groupCount == 0 || !RevenantMLCPerChannel(beta, featureChannelCount) || !RevenantMLCPerChannel(gamma, featureChannelCount)) {
        return layer;
    }
    layer->_featureChannelCount = featureChannelCount;
    layer->_groupCount = groupCount;
    layer->_beta = beta;
    layer->_gamma = gamma;
    layer->_varianceEpsilon = varianceEpsilon;
    layer->_betaParameter = RevenantMLCParameter(beta);
    layer->_gammaParameter = RevenantMLCParameter(gamma);
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
    MLCLayerNormalizationLayer *layer = [[MLCLayerNormalizationLayer alloc] revenant_init];
    [layer revenant_label:@"LayerNorm"];
    if (!RevenantMLCNormalized(beta, normalizedShape) || !RevenantMLCNormalized(gamma, normalizedShape)) {
        return layer;
    }
    layer->_normalizedShape = [normalizedShape copy];
    layer->_beta = beta;
    layer->_gamma = gamma;
    layer->_varianceEpsilon = varianceEpsilon;
    layer->_betaParameter = RevenantMLCParameter(beta);
    layer->_gammaParameter = RevenantMLCParameter(gamma);
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
    MLCLossLayer *layer = [[MLCLossLayer alloc] revenant_init];
    layer->_descriptor = lossDescriptor;
    return [layer revenant_label:@"Loss"];
}

+ (instancetype)layerWithDescriptor:(MLCLossDescriptor *)lossDescriptor weights:(MLCTensor *)weights
{
    MLCLossLayer *layer = [[MLCLossLayer alloc] revenant_init];
    layer->_descriptor = lossDescriptor;
    layer->_weights = weights;
    [layer revenant_label:@"Loss"];
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
    MLCYOLOLossLayer *layer = [[MLCYOLOLossLayer alloc] revenant_init];
    layer->_yoloLossDescriptor = lossDescriptor;
    [layer revenant_label:@"Loss"];
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

+ (instancetype)revenant_layerWithDescriptor:(MLCLSTMDescriptor *)descriptor
                             inputWeights:(NSArray<MLCTensor *> *)inputWeights
                            hiddenWeights:(NSArray<MLCTensor *> *)hiddenWeights
                           peepholeWeights:(NSArray<MLCTensor *> *)peepholeWeights
                                    biases:(NSArray<MLCTensor *> *)biases
                            gateActivations:(NSArray<MLCActivationDescriptor *> *)gateActivations
                       outputResultActivation:(MLCActivationDescriptor *)outputResultActivation
{
    MLCLSTMLayer *layer = [[MLCLSTMLayer alloc] revenant_init];
    [layer revenant_label:@"LSTM"];
    layer->_descriptor = descriptor;
    layer->_inputWeights = [inputWeights copy];
    layer->_hiddenWeights = [hiddenWeights copy];
    layer->_peepholeWeights = [peepholeWeights copy];
    layer->_biases = [biases copy];
    layer->_inputWeightsParameters = RevenantMLCParameters(inputWeights);
    layer->_hiddenWeightsParameters = RevenantMLCParameters(hiddenWeights);
    layer->_peepholeWeightsParameters = RevenantMLCParameters(peepholeWeights);
    layer->_biasesParameters = RevenantMLCParameters(biases);
    if (gateActivations) {
        layer->_gateActivations = [gateActivations copy];
    } else if (layer->_inputWeights) {
        layer->_gateActivations = [MLCLSTMLayer revenant_defaultGates];
    }
    if (outputResultActivation) {
        layer->_outputResultActivation = outputResultActivation;
    } else if (layer->_inputWeights) {
        layer->_outputResultActivation = [MLCActivationDescriptor descriptorWithType:MLCActivationTypeTanh];
    }
    return layer;
}

+ (NSArray<MLCActivationDescriptor *> *)revenant_defaultGates
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
    return [self revenant_layerWithDescriptor:descriptor
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
