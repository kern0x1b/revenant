// The ten value objects an MLCompute layer is described with, and the layer base they and the layers share.
//
// Every default and every refusal here was measured on the host's own MLCompute and is held to it case by
// case (tests/backports/host/mlcompute); facts/MLCompute/Descriptors.md carries the table. The three
// shapes of answer worth naming:
//
//   - a descriptor is a value: -copyWithZone: gives another one with the same numbers, and every
//     property is readonly, so there is nothing to keep in step;
//   - the factories that take fewer arguments than the header's longest form keep the longer form's
//     default for what they do not carry. That is measured for every one of them, and it is not always 1:
//     +[MLCActivationDescriptor descriptorWithType:] answers a = 0.2 and b = 0.5 for a hard sigmoid,
//     0.01 for the leaky ReLU's a, 0 for ReLU6's a and 6 for its b, and the GELU's a and b are
//     0.797885 and 0.044715 - sqrt(2/pi) and its own, written down in the facts;
//   - a factory handed something it cannot describe answers nil, and the answer for a shape it can
//     describe is the shape itself, not a correction. Nothing here rounds a value to what the layer would
//     rather use.
//
// The properties of MLCLayer are in MLCTensors14.m beside the tensors, since the counter of the layers and
// the one of the tensors are the same kind of thing.

#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

// The methods the factories of a descriptor reach, declared before the factories that use them.
@interface MLCActivationDescriptor (CharonStorage)
- (void)charon_setType:(MLCActivationType)type a:(float)a b:(float)b c:(float)c;
@end

@interface MLCConvolutionDescriptor (CharonStorage)
- (void)charon_setType:(MLCConvolutionType)type
             kernel:(NSUInteger)width
                by:(NSUInteger)height
                in:(NSUInteger)inputs
               out:(NSUInteger)outputs
             groups:(NSUInteger)groups
           strideX:(NSUInteger)strideX
           strideY:(NSUInteger)strideY
       dilationX:(NSUInteger)dilationX
       dilationY:(NSUInteger)dilationY
      padding:(MLCPaddingPolicy)padding
   paddingSizeX:(NSUInteger)paddingSizeX
   paddingSizeY:(NSUInteger)paddingSizeY;
@end

@interface MLCPoolingDescriptor (CharonStorage)
- (void)charon_setType:(MLCPoolingType)type
              kernelX:(NSUInteger)width
              kernelY:(NSUInteger)height
              strideX:(NSUInteger)strideX
              strideY:(NSUInteger)strideY
           dilationX:(NSUInteger)dilationX
           dilationY:(NSUInteger)dilationY
             padding:(MLCPaddingPolicy)padding
          paddingX:(NSUInteger)paddingX
          paddingY:(NSUInteger)paddingY
     countsPadding:(BOOL)countsPadding;
@end

@interface MLCLossDescriptor (CharonStorage)
- (void)charon_setType:(MLCLossType)type
           reduction:(MLCReductionType)reduction
               weight:(float)weight
        labelSmoothing:(float)labelSmoothing
          classCount:(NSUInteger)classCount
              epsilon:(float)epsilon
                delta:(float)delta;
@end

@interface MLCOptimizerDescriptor (CharonStorage)
- (void)charon_setLearningRate:(float)learningRate
                gradientRescale:(float)rescale
        appliesGradientClipping:(BOOL)clipping
              gradientClippingType:(MLCGradientClippingType)clippingType
                  gradientClipMax:(float)clipMax
                  gradientClipMin:(float)clipMin
             maximumClippingNorm:(float)maximumNorm
                customGlobalNorm:(float)globalNorm
               regularizationType:(MLCRegularizationType)regularizationType
             regularizationScale:(float)regularizationScale;
@end

@interface MLCLSTMDescriptor (CharonStorage)
- (void)charon_setInputSize:(NSUInteger)inputSize
                  hiddenSize:(NSUInteger)hiddenSize
                  layerCount:(NSUInteger)layerCount
                  usesBiases:(BOOL)usesBiases
                 batchFirst:(BOOL)batchFirst
              isBidirectional:(BOOL)bidirectional
              returnsSequences:(BOOL)returnsSequences
                     dropout:(float)dropout
                  resultMode:(MLCLSTMResultMode)resultMode;
@end

@interface MLCMultiheadAttentionDescriptor (CharonStorage)
- (void)charon_setModelDimension:(NSUInteger)modelDimension
                     keyDimension:(NSUInteger)keyDimension
                   valueDimension:(NSUInteger)valueDimension
                       headCount:(NSUInteger)headCount
                        dropout:(float)dropout
                      hasBiases:(BOOL)hasBiases
             hasAttentionBiases:(BOOL)hasAttentionBiases
              addsZeroAttention:(BOOL)addsZeroAttention;
@end

@interface MLCEmbeddingDescriptor (CharonStorage)
- (void)charon_setCount:(NSNumber *)count
            dimension:(NSNumber *)dimension
           paddingIndex:(NSNumber *)paddingIndex
           maximumNorm:(NSNumber *)maximumNorm
                 pNorm:(NSNumber *)pNorm
scalesGradientByFrequency:(BOOL)scales;
@end

@interface MLCYOLOLossDescriptor (CharonStorage)
- (void)charon_setAnchorBoxes:(NSData *)boxes count:(NSUInteger)count;
@end

// The default every activation carries for the parameter its type does not use, and the default the
// factories of the two- and three-argument forms keep for the ones they do not name. Measured: a
// descriptor of any type made with no argument has a = b = c = 1 except ReLU (a = 0), linear (b = 0), hard
// sigmoid (a = 0.2, b = 0.5), hard shrink and soft shrink (a = 0.5) - and nothing else, so the ReLUN and
// the tanh shrink carry 1, as does the GELU. The a of 0 belongs to +[MLCActivationLayer relu6Layer] and
// +[MLCActivationLayer tanhShrinkLayer], which name a and give it, not to the descriptor's default; the
// longer forms take what they are given and keep 1 for the rest.
static void CharonMLCDefaultActivation(MLCActivationType type, float *a, float *b, float *c)
{
    *a = 1.0f;
    *b = 1.0f;
    *c = 1.0f;
    switch (type) {
        case MLCActivationTypeReLU:
            *a = 0.0f;
            break;
        case MLCActivationTypeLinear:
            *b = 0.0f;
            break;
        case MLCActivationTypeHardSigmoid:
            *a = 0.2f;
            *b = 0.5f;
            break;
        case MLCActivationTypeHardShrink:
        case MLCActivationTypeSoftShrink:
            *a = 0.5f;
            break;
        default:
            break;
    }
}

#pragma mark - MLCActivationDescriptor

@implementation MLCActivationDescriptor {
    MLCActivationType _activationType;
    float _a;
    float _b;
    float _c;
}

- (instancetype)init
{
    // The header's unavailable initialiser: the identity activation with every parameter at zero
    // (measured).
    self = [super init];
    if (self) {
        _activationType = MLCActivationTypeNone;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptorWithType:(MLCActivationType)activationType
{
    float a, b, c;
    CharonMLCDefaultActivation(activationType, &a, &b, &c);
    MLCActivationDescriptor *descriptor = [[MLCActivationDescriptor alloc] init];
    [descriptor charon_setType:activationType a:a b:b c:c];
    return descriptor;
}

+ (instancetype)descriptorWithType:(MLCActivationType)activationType a:(float)a
{
    float ignored, b, c;
    CharonMLCDefaultActivation(activationType, &ignored, &b, &c);
    MLCActivationDescriptor *descriptor = [[MLCActivationDescriptor alloc] init];
    [descriptor charon_setType:activationType a:a b:b c:c];
    return descriptor;
}

+ (instancetype)descriptorWithType:(MLCActivationType)activationType a:(float)a b:(float)b
{
    float ignored, ignored2, c;
    CharonMLCDefaultActivation(activationType, &ignored, &ignored2, &c);
    MLCActivationDescriptor *descriptor = [[MLCActivationDescriptor alloc] init];
    [descriptor charon_setType:activationType a:a b:b c:c];
    return descriptor;
}

+ (instancetype)descriptorWithType:(MLCActivationType)activationType a:(float)a b:(float)b c:(float)c
{
    MLCActivationDescriptor *descriptor = [[MLCActivationDescriptor alloc] init];
    [descriptor charon_setType:activationType a:a b:b c:c];
    return descriptor;
}

- (void)charon_setType:(MLCActivationType)type a:(float)a b:(float)b c:(float)c
{
    _activationType = type;
    _a = a;
    _b = b;
    _c = c;
}

- (MLCActivationType)activationType
{
    return _activationType;
}

- (float)a
{
    return _a;
}

- (float)b
{
    return _b;
}

- (float)c
{
    return _c;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCActivationDescriptor *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setType:_activationType a:_a b:_b c:_c];
    return copy;
}

@end

#pragma mark - MLCConvolutionDescriptor

@implementation MLCConvolutionDescriptor {
    MLCConvolutionType _convolutionType;
    NSUInteger _kernelWidth;
    NSUInteger _kernelHeight;
    NSUInteger _inputFeatureChannelCount;
    NSUInteger _outputFeatureChannelCount;
    NSUInteger _groupCount;
    NSUInteger _strideInX;
    NSUInteger _strideInY;
    NSUInteger _dilationRateInX;
    NSUInteger _dilationRateInY;
    MLCPaddingPolicy _paddingPolicy;
    NSUInteger _paddingSizeInX;
    NSUInteger _paddingSizeInY;
}

- (instancetype)init
{
    // The header's unavailable initialiser: a standard convolution of a one by one kernel from one channel
    // to one, with a stride and a dilation of one and no padding (measured).
    self = [super init];
    if (self) {
        _convolutionType = MLCConvolutionTypeStandard;
        _kernelWidth = 1;
        _kernelHeight = 1;
        _inputFeatureChannelCount = 1;
        _outputFeatureChannelCount = 1;
        _groupCount = 1;
        _strideInX = 1;
        _strideInY = 1;
        _dilationRateInX = 1;
        _dilationRateInY = 1;
        _paddingPolicy = MLCPaddingPolicySame;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

// The pair an argument array carries, read the way the framework reads it: the second entry is the x of the
// name and the first the y, and a one-entry array is that value for both (measured: kernelSizes 3, 5 is a
// kernelWidth of 5 and a kernelHeight of 3, strides 2, 1 is a strideInX of 1 and a strideInY of 2, and
// paddingSizes 4, 2 is a paddingSizeInX of 2 and a paddingSizeInY of 4).
static void CharonMLCPair(NSArray<NSNumber *> *values, NSUInteger *x, NSUInteger *y)
{
    NSUInteger first = values.count > 0 ? values[0].unsignedIntegerValue : 1;
    NSUInteger second = values.count > 1 ? values[1].unsignedIntegerValue : first;
    *x = second;
    *y = first;
}

// The same, for the two padding sizes, whose default is no padding at all where a kernel, a stride and a
// dilation default to one (measured: a convolution with the same padding policy and no padding sizes
// answers zero by zero, and a max pooling with none as well).
static void CharonMLCPaddingPair(NSArray<NSNumber *> *values, NSUInteger *x, NSUInteger *y)
{
    NSUInteger first = values.count > 0 ? values[0].unsignedIntegerValue : 0;
    NSUInteger second = values.count > 1 ? values[1].unsignedIntegerValue : first;
    *x = second;
    *y = first;
}

+ (instancetype)descriptorWithType:(MLCConvolutionType)convolutionType
                         kernelSizes:(NSArray<NSNumber *> *)kernelSizes
             inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
            outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
                           groupCount:(NSUInteger)groupCount
                             strides:(NSArray<NSNumber *> *)strides
                        dilationRates:(NSArray<NSNumber *> *)dilationRates
                       paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                        paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    NSUInteger width, height, strideX, strideY, dilationX, dilationY, paddingX = 0, paddingY = 0;
    CharonMLCPair(kernelSizes, &width, &height);
    CharonMLCPair(strides, &strideX, &strideY);
    CharonMLCPair(dilationRates, &dilationX, &dilationY);
    CharonMLCPaddingPair(paddingSizes, &paddingX, &paddingY);
    MLCConvolutionDescriptor *descriptor = [[MLCConvolutionDescriptor alloc] init];
    [descriptor charon_setType:convolutionType
                        kernel:width
                           by:height
                           in:inputFeatureChannelCount
                          out:outputFeatureChannelCount
                      groups:groupCount
                     strideX:strideX
                     strideY:strideY
                  dilationX:dilationX
                  dilationY:dilationY
                    padding:paddingPolicy
                 paddingSizeX:paddingX
                 paddingSizeY:paddingY];
    return descriptor;
}

+ (instancetype)descriptorWithKernelWidth:(NSUInteger)kernelWidth
                             kernelHeight:(NSUInteger)kernelHeight
                 inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
{
    MLCConvolutionDescriptor *descriptor = [[MLCConvolutionDescriptor alloc] init];
    [descriptor charon_setType:MLCConvolutionTypeStandard
                        kernel:kernelWidth
                           by:kernelHeight
                           in:inputFeatureChannelCount
                          out:outputFeatureChannelCount
                      groups:1
                     strideX:1
                     strideY:1
                  dilationX:1
                  dilationY:1
                    padding:MLCPaddingPolicySame
                 paddingSizeX:0
                 paddingSizeY:0];
    return descriptor;
}

+ (instancetype)descriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                 inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
                             strides:(NSArray<NSNumber *> *)strides
                        paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                         paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self descriptorWithType:MLCConvolutionTypeStandard
                         kernelSizes:kernelSizes
             inputFeatureChannelCount:inputFeatureChannelCount
            outputFeatureChannelCount:outputFeatureChannelCount
                           groupCount:1
                             strides:strides
                        dilationRates:@[]
                       paddingPolicy:paddingPolicy
                        paddingSizes:paddingSizes];
}

+ (instancetype)descriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                 inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
                           groupCount:(NSUInteger)groupCount
                             strides:(NSArray<NSNumber *> *)strides
                        dilationRates:(NSArray<NSNumber *> *)dilationRates
                       paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                        paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self descriptorWithType:MLCConvolutionTypeStandard
                         kernelSizes:kernelSizes
             inputFeatureChannelCount:inputFeatureChannelCount
            outputFeatureChannelCount:outputFeatureChannelCount
                           groupCount:groupCount
                             strides:strides
                        dilationRates:dilationRates
                       paddingPolicy:paddingPolicy
                        paddingSizes:paddingSizes];
}

+ (instancetype)convolutionTransposeDescriptorWithKernelWidth:(NSUInteger)kernelWidth
                                                 kernelHeight:(NSUInteger)kernelHeight
                                 inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                                outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
{
    MLCConvolutionDescriptor *descriptor = [[MLCConvolutionDescriptor alloc] init];
    [descriptor charon_setType:MLCConvolutionTypeTransposed
                        kernel:kernelWidth
                           by:kernelHeight
                           in:inputFeatureChannelCount
                          out:outputFeatureChannelCount
                      groups:1
                     strideX:1
                     strideY:1
                  dilationX:1
                  dilationY:1
                    padding:MLCPaddingPolicySame
                 paddingSizeX:0
                 paddingSizeY:0];
    return descriptor;
}

+ (instancetype)convolutionTransposeDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                     inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                                    outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
                                                 strides:(NSArray<NSNumber *> *)strides
                                            paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                             paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self descriptorWithType:MLCConvolutionTypeTransposed
                         kernelSizes:kernelSizes
             inputFeatureChannelCount:inputFeatureChannelCount
            outputFeatureChannelCount:outputFeatureChannelCount
                           groupCount:1
                             strides:strides
                        dilationRates:@[]
                       paddingPolicy:paddingPolicy
                        paddingSizes:paddingSizes];
}

+ (instancetype)convolutionTransposeDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                     inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                                    outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
                                                 groupCount:(NSUInteger)groupCount
                                                   strides:(NSArray<NSNumber *> *)strides
                                              dilationRates:(NSArray<NSNumber *> *)dilationRates
                                             paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                              paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self descriptorWithType:MLCConvolutionTypeTransposed
                         kernelSizes:kernelSizes
             inputFeatureChannelCount:inputFeatureChannelCount
            outputFeatureChannelCount:outputFeatureChannelCount
                           groupCount:groupCount
                             strides:strides
                        dilationRates:dilationRates
                       paddingPolicy:paddingPolicy
                        paddingSizes:paddingSizes];
}

+ (instancetype)depthwiseConvolutionDescriptorWithKernelWidth:(NSUInteger)kernelWidth
                                                   kernelHeight:(NSUInteger)kernelHeight
                                   inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                                              channelMultiplier:(NSUInteger)channelMultiplier
{
    // A depthwise convolution keeps the input's channels and multiplies them, so the output has as many
    // channels as the input times the multiplier (measured: 4 channels and a multiplier of 2 is 8).
    MLCConvolutionDescriptor *descriptor = [[MLCConvolutionDescriptor alloc] init];
    [descriptor charon_setType:MLCConvolutionTypeDepthwise
                        kernel:kernelWidth
                           by:kernelHeight
                           in:inputFeatureChannelCount
                          out:inputFeatureChannelCount * channelMultiplier
                      groups:1
                     strideX:1
                     strideY:1
                  dilationX:1
                  dilationY:1
                    padding:MLCPaddingPolicySame
                 paddingSizeX:0
                 paddingSizeY:0];
    return descriptor;
}

+ (instancetype)depthwiseConvolutionDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                     inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                                              channelMultiplier:(NSUInteger)channelMultiplier
                                                       strides:(NSArray<NSNumber *> *)strides
                                                  paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                                   paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self descriptorWithType:MLCConvolutionTypeDepthwise
                         kernelSizes:kernelSizes
             inputFeatureChannelCount:inputFeatureChannelCount
            outputFeatureChannelCount:inputFeatureChannelCount * channelMultiplier
                           groupCount:1
                             strides:strides
                        dilationRates:@[]
                       paddingPolicy:paddingPolicy
                        paddingSizes:paddingSizes];
}

+ (instancetype)depthwiseConvolutionDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                     inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                                              channelMultiplier:(NSUInteger)channelMultiplier
                                                       strides:(NSArray<NSNumber *> *)strides
                                                  dilationRates:(NSArray<NSNumber *> *)dilationRates
                                                 paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                                  paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self descriptorWithType:MLCConvolutionTypeDepthwise
                         kernelSizes:kernelSizes
             inputFeatureChannelCount:inputFeatureChannelCount
            outputFeatureChannelCount:inputFeatureChannelCount * channelMultiplier
                           groupCount:1
                             strides:strides
                        dilationRates:dilationRates
                       paddingPolicy:paddingPolicy
                        paddingSizes:paddingSizes];
}

- (void)charon_setType:(MLCConvolutionType)type
                kernel:(NSUInteger)width
                   by:(NSUInteger)height
                   in:(NSUInteger)inputs
                  out:(NSUInteger)outputs
              groups:(NSUInteger)groups
             strideX:(NSUInteger)strideX
             strideY:(NSUInteger)strideY
          dilationX:(NSUInteger)dilationX
          dilationY:(NSUInteger)dilationY
            padding:(MLCPaddingPolicy)padding
         paddingSizeX:(NSUInteger)paddingX
         paddingSizeY:(NSUInteger)paddingY
{
    _convolutionType = type;
    _kernelWidth = width;
    _kernelHeight = height;
    _inputFeatureChannelCount = inputs;
    _outputFeatureChannelCount = outputs;
    _groupCount = groups;
    _strideInX = strideX;
    _strideInY = strideY;
    _dilationRateInX = dilationX;
    _dilationRateInY = dilationY;
    _paddingPolicy = padding;
    _paddingSizeInX = paddingX;
    _paddingSizeInY = paddingY;
}

- (MLCConvolutionType)convolutionType
{
    return _convolutionType;
}

- (NSUInteger)kernelWidth
{
    return _kernelWidth;
}

- (NSUInteger)kernelHeight
{
    return _kernelHeight;
}

- (NSUInteger)inputFeatureChannelCount
{
    return _inputFeatureChannelCount;
}

- (NSUInteger)outputFeatureChannelCount
{
    return _outputFeatureChannelCount;
}

- (NSUInteger)strideInX
{
    return _strideInX;
}

- (NSUInteger)strideInY
{
    return _strideInY;
}

- (NSUInteger)dilationRateInX
{
    return _dilationRateInX;
}

- (NSUInteger)dilationRateInY
{
    return _dilationRateInY;
}

- (NSUInteger)groupCount
{
    return _groupCount;
}

- (MLCPaddingPolicy)paddingPolicy
{
    return _paddingPolicy;
}

- (NSUInteger)paddingSizeInX
{
    return _paddingSizeInX;
}

- (NSUInteger)paddingSizeInY
{
    return _paddingSizeInY;
}

- (BOOL)isConvolutionTranspose
{
    return _convolutionType == MLCConvolutionTypeTransposed;
}

- (BOOL)usesDepthwiseConvolution
{
    return _convolutionType == MLCConvolutionTypeDepthwise;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCConvolutionDescriptor *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setType:_convolutionType
                   kernel:_kernelWidth
                      by:_kernelHeight
                      in:_inputFeatureChannelCount
                     out:_outputFeatureChannelCount
                 groups:_groupCount
                strideX:_strideInX
                strideY:_strideInY
             dilationX:_dilationRateInX
             dilationY:_dilationRateInY
               padding:_paddingPolicy
            paddingSizeX:_paddingSizeInX
            paddingSizeY:_paddingSizeInY];
    return copy;
}

@end

#pragma mark - MLCPoolingDescriptor

@implementation MLCPoolingDescriptor {
    MLCPoolingType _poolingType;
    NSUInteger _kernelWidth;
    NSUInteger _kernelHeight;
    NSUInteger _strideInX;
    NSUInteger _strideInY;
    NSUInteger _dilationRateInX;
    NSUInteger _dilationRateInY;
    MLCPaddingPolicy _paddingPolicy;
    NSUInteger _paddingSizeInX;
    NSUInteger _paddingSizeInY;
    BOOL _countIncludesPadding;
}

- (instancetype)init
{
    // The header's unavailable initialiser: every number zero and no pooling type at all, which is not one
    // of the three the framework names (measured).
    self = [super init];
    if (self) {
        _poolingType = (MLCPoolingType)0;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)poolingDescriptorWithType:(MLCPoolingType)poolingType kernelSize:(NSUInteger)kernelSize stride:(NSUInteger)stride
{
    MLCPoolingDescriptor *descriptor = [[MLCPoolingDescriptor alloc] init];
    [descriptor charon_setType:poolingType
                     kernelX:kernelSize
                     kernelY:kernelSize
                     strideX:stride
                     strideY:stride
                  dilationX:1
                  dilationY:1
                    padding:MLCPaddingPolicySame
                 paddingX:0
                 paddingY:0
            countsPadding:NO];
    return descriptor;
}

+ (instancetype)maxPoolingDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                           strides:(NSArray<NSNumber *> *)strides
                                      paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                       paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self charon_poolingDescriptorOfType:MLCPoolingTypeMax
                                    kernelSizes:kernelSizes
                                        strides:strides
                                   dilationRates:@[]
                                  paddingPolicy:paddingPolicy
                                   paddingSizes:paddingSizes
                               countsPadding:NO];
}

+ (instancetype)maxPoolingDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                           strides:(NSArray<NSNumber *> *)strides
                                      dilationRates:(NSArray<NSNumber *> *)dilationRates
                                     paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                      paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self charon_poolingDescriptorOfType:MLCPoolingTypeMax
                                    kernelSizes:kernelSizes
                                        strides:strides
                                   dilationRates:dilationRates
                                  paddingPolicy:paddingPolicy
                                   paddingSizes:paddingSizes
                               countsPadding:NO];
}

+ (instancetype)averagePoolingDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                                strides:(NSArray<NSNumber *> *)strides
                                           paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                            paddingSizes:(NSArray<NSNumber *> *)paddingSizes
                                        countIncludesPadding:(BOOL)countIncludesPadding
{
    return [self charon_poolingDescriptorOfType:MLCPoolingTypeAverage
                                    kernelSizes:kernelSizes
                                        strides:strides
                                   dilationRates:@[]
                                  paddingPolicy:paddingPolicy
                                   paddingSizes:paddingSizes
                               countsPadding:countIncludesPadding];
}

+ (instancetype)averagePoolingDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                                strides:(NSArray<NSNumber *> *)strides
                                           dilationRates:(NSArray<NSNumber *> *)dilationRates
                                          paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                           paddingSizes:(NSArray<NSNumber *> *)paddingSizes
                                       countIncludesPadding:(BOOL)countIncludesPadding
{
    return [self charon_poolingDescriptorOfType:MLCPoolingTypeAverage
                                    kernelSizes:kernelSizes
                                        strides:strides
                                   dilationRates:dilationRates
                                  paddingPolicy:paddingPolicy
                                   paddingSizes:paddingSizes
                               countsPadding:countIncludesPadding];
}

+ (instancetype)l2NormPoolingDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                              strides:(NSArray<NSNumber *> *)strides
                                         paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                          paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self charon_poolingDescriptorOfType:MLCPoolingTypeL2Norm
                                    kernelSizes:kernelSizes
                                        strides:strides
                                   dilationRates:@[]
                                  paddingPolicy:paddingPolicy
                                   paddingSizes:paddingSizes
                               countsPadding:NO];
}

+ (instancetype)l2NormPoolingDescriptorWithKernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                              strides:(NSArray<NSNumber *> *)strides
                                         dilationRates:(NSArray<NSNumber *> *)dilationRates
                                        paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                         paddingSizes:(NSArray<NSNumber *> *)paddingSizes
{
    return [self charon_poolingDescriptorOfType:MLCPoolingTypeL2Norm
                                    kernelSizes:kernelSizes
                                        strides:strides
                                   dilationRates:dilationRates
                                  paddingPolicy:paddingPolicy
                                   paddingSizes:paddingSizes
                               countsPadding:NO];
}

// The one place the six factories above come together. A missing stride is the kernel and a missing
// dilation the unit, and a padding size of zero for every other policy, which is what the host keeps
// (measured: a max pooling of kernels 2, 3 and strides 1, 2 with a padding size of 4, 5 answers a
// paddingSizeInX of 4 and a paddingSizeInY of 5, and one with the same policy as "same" answers zero).
+ (instancetype)charon_poolingDescriptorOfType:(MLCPoolingType)type
                                  kernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                      strides:(NSArray<NSNumber *> *)strides
                                 dilationRates:(NSArray<NSNumber *> *)dilationRates
                                paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                 paddingSizes:(NSArray<NSNumber *> *)paddingSizes
                                 countsPadding:(BOOL)countsPadding
{
    NSUInteger width, height, strideX = 0, strideY = 0, dilationX, dilationY, paddingX = 0, paddingY = 0;
    CharonMLCPair(kernelSizes, &width, &height);
    if (strides) {
        CharonMLCPair(strides, &strideX, &strideY);
    } else {
        strideX = width;
        strideY = height;
    }
    CharonMLCPair(dilationRates, &dilationX, &dilationY);
    CharonMLCPaddingPair(paddingSizes, &paddingX, &paddingY);
    MLCPoolingDescriptor *descriptor = [[MLCPoolingDescriptor alloc] init];
    [descriptor charon_setType:type
                     kernelX:width
                     kernelY:height
                     strideX:strideX
                     strideY:strideY
                  dilationX:dilationX
                  dilationY:dilationY
                    padding:paddingPolicy
                 paddingX:paddingX
                 paddingY:paddingY
            countsPadding:countsPadding];
    return descriptor;
}

- (void)charon_setType:(MLCPoolingType)type
              kernelX:(NSUInteger)width
              kernelY:(NSUInteger)height
              strideX:(NSUInteger)strideX
              strideY:(NSUInteger)strideY
           dilationX:(NSUInteger)dilationX
           dilationY:(NSUInteger)dilationY
             padding:(MLCPaddingPolicy)padding
          paddingX:(NSUInteger)paddingX
          paddingY:(NSUInteger)paddingY
     countsPadding:(BOOL)countsPadding
{
    _poolingType = type;
    _kernelWidth = width;
    _kernelHeight = height;
    _strideInX = strideX;
    _strideInY = strideY;
    _dilationRateInX = dilationX;
    _dilationRateInY = dilationY;
    _paddingPolicy = padding;
    _paddingSizeInX = paddingX;
    _paddingSizeInY = paddingY;
    _countIncludesPadding = countsPadding;
}

- (MLCPoolingType)poolingType
{
    return _poolingType;
}

- (NSUInteger)kernelWidth
{
    return _kernelWidth;
}

- (NSUInteger)kernelHeight
{
    return _kernelHeight;
}

- (NSUInteger)strideInX
{
    return _strideInX;
}

- (NSUInteger)strideInY
{
    return _strideInY;
}

- (NSUInteger)dilationRateInX
{
    return _dilationRateInX;
}

- (NSUInteger)dilationRateInY
{
    return _dilationRateInY;
}

- (MLCPaddingPolicy)paddingPolicy
{
    return _paddingPolicy;
}

- (NSUInteger)paddingSizeInX
{
    return _paddingSizeInX;
}

- (NSUInteger)paddingSizeInY
{
    return _paddingSizeInY;
}

- (BOOL)countIncludesPadding
{
    return _countIncludesPadding;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCPoolingDescriptor *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setType:_poolingType
                kernelX:_kernelWidth
                kernelY:_kernelHeight
                strideX:_strideInX
                strideY:_strideInY
             dilationX:_dilationRateInX
             dilationY:_dilationRateInY
               padding:_paddingPolicy
                paddingX:_paddingSizeInX
                paddingY:_paddingSizeInY
           countsPadding:_countIncludesPadding];
    return copy;
}

@end

#pragma mark - MLCLossDescriptor

@implementation MLCLossDescriptor {
    MLCLossType _lossType;
    MLCReductionType _reductionType;
    float _weight;
    float _labelSmoothing;
    NSUInteger _classCount;
    float _epsilon;
    float _delta;
}

- (instancetype)init
{
    // The header's unavailable initialiser: the mean absolute error with no reduction, and every parameter
    // at zero (measured).
    self = [super init];
    if (self) {
        _lossType = MLCLossTypeMeanAbsoluteError;
        _reductionType = MLCReductionTypeNone;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptorWithType:(MLCLossType)lossType reductionType:(MLCReductionType)reductionType
{
    return [self descriptorWithType:lossType
                      reductionType:reductionType
                            weight:1.0f
                    labelSmoothing:0.0f
                      classCount:1
                          epsilon:1e-7f
                            delta:1.0f];
}

+ (instancetype)descriptorWithType:(MLCLossType)lossType
                      reductionType:(MLCReductionType)reductionType
                            weight:(float)weight
{
    return [self descriptorWithType:lossType
                      reductionType:reductionType
                            weight:weight
                    labelSmoothing:0.0f
                      classCount:1
                          epsilon:1e-7f
                            delta:1.0f];
}

+ (instancetype)descriptorWithType:(MLCLossType)lossType
                      reductionType:(MLCReductionType)reductionType
                            weight:(float)weight
                    labelSmoothing:(float)labelSmoothing
                      classCount:(NSUInteger)classCount
{
    return [self descriptorWithType:lossType
                      reductionType:reductionType
                            weight:weight
                    labelSmoothing:labelSmoothing
                      classCount:classCount
                          epsilon:1e-7f
                            delta:1.0f];
}

+ (instancetype)descriptorWithType:(MLCLossType)lossType
                      reductionType:(MLCReductionType)reductionType
                            weight:(float)weight
                    labelSmoothing:(float)labelSmoothing
                      classCount:(NSUInteger)classCount
                          epsilon:(float)epsilon
                            delta:(float)delta
{
    MLCLossDescriptor *descriptor = [[MLCLossDescriptor alloc] init];
    [descriptor charon_setType:lossType
                    reduction:reductionType
                        weight:weight
                labelSmoothing:labelSmoothing
                   classCount:classCount
                       epsilon:epsilon
                         delta:delta];
    return descriptor;
}

- (void)charon_setType:(MLCLossType)type
             reduction:(MLCReductionType)reduction
                 weight:(float)weight
         labelSmoothing:(float)labelSmoothing
            classCount:(NSUInteger)classCount
                epsilon:(float)epsilon
                  delta:(float)delta
{
    _lossType = type;
    _reductionType = reduction;
    _weight = weight;
    _labelSmoothing = labelSmoothing;
    _classCount = classCount;
    _epsilon = epsilon;
    _delta = delta;
}

- (MLCLossType)lossType
{
    return _lossType;
}

- (MLCReductionType)reductionType
{
    return _reductionType;
}

- (float)weight
{
    return _weight;
}

- (float)labelSmoothing
{
    return _labelSmoothing;
}

- (NSUInteger)classCount
{
    return _classCount;
}

- (float)epsilon
{
    return _epsilon;
}

- (float)delta
{
    return _delta;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCLossDescriptor *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setType:_lossType
               reduction:_reductionType
                   weight:_weight
           labelSmoothing:_labelSmoothing
              classCount:_classCount
                  epsilon:_epsilon
                    delta:_delta];
    return copy;
}

@end

#pragma mark - MLCOptimizerDescriptor

@implementation MLCOptimizerDescriptor {
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
}

- (instancetype)init
{
    // The header's unavailable initialiser: every number zero, no clipping and no regularization
    // (measured).
    self = [super init];
    if (self) {
        _gradientClipMin = 0.0f;
        _gradientClipMax = 0.0f;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptorWithLearningRate:(float)learningRate
                           gradientRescale:(float)gradientRescale
                        regularizationType:(MLCRegularizationType)regularizationType
                      regularizationScale:(float)regularizationScale
{
    return [self descriptorWithLearningRate:learningRate
                             gradientRescale:gradientRescale
                     appliesGradientClipping:NO
                           gradientClippingType:MLCGradientClippingTypeByValue
                               gradientClipMax:1.0f
                               gradientClipMin:-1.0f
                          maximumClippingNorm:1.0f
                             customGlobalNorm:1.0f
                            regularizationType:regularizationType
                          regularizationScale:regularizationScale];
}

+ (instancetype)descriptorWithLearningRate:(float)learningRate
                           gradientRescale:(float)gradientRescale
                   appliesGradientClipping:(BOOL)appliesGradientClipping
                           gradientClipMax:(float)gradientClipMax
                           gradientClipMin:(float)gradientClipMin
                        regularizationType:(MLCRegularizationType)regularizationType
                      regularizationScale:(float)regularizationScale
{
    return [self descriptorWithLearningRate:learningRate
                             gradientRescale:gradientRescale
                     appliesGradientClipping:appliesGradientClipping
                           gradientClippingType:MLCGradientClippingTypeByValue
                               gradientClipMax:gradientClipMax
                               gradientClipMin:gradientClipMin
                          maximumClippingNorm:1.0f
                             customGlobalNorm:1.0f
                            regularizationType:regularizationType
                          regularizationScale:regularizationScale];
}

+ (instancetype)descriptorWithLearningRate:(float)learningRate
                           gradientRescale:(float)gradientRescale
                   appliesGradientClipping:(BOOL)appliesGradientClipping
                      gradientClippingType:(MLCGradientClippingType)gradientClippingType
                           gradientClipMax:(float)gradientClipMax
                           gradientClipMin:(float)gradientClipMin
                      maximumClippingNorm:(float)maximumClippingNorm
                         customGlobalNorm:(float)customGlobalNorm
                        regularizationType:(MLCRegularizationType)regularizationType
                      regularizationScale:(float)regularizationScale
{
    MLCOptimizerDescriptor *descriptor = [[MLCOptimizerDescriptor alloc] init];
    [descriptor charon_setLearningRate:learningRate
                        gradientRescale:gradientRescale
                appliesGradientClipping:appliesGradientClipping
                  gradientClippingType:gradientClippingType
                      gradientClipMax:gradientClipMax
                      gradientClipMin:gradientClipMin
                 maximumClippingNorm:maximumClippingNorm
                    customGlobalNorm:customGlobalNorm
                   regularizationType:regularizationType
                 regularizationScale:regularizationScale];
    return descriptor;
}

- (void)charon_setLearningRate:(float)learningRate
                gradientRescale:(float)rescale
        appliesGradientClipping:(BOOL)clipping
              gradientClippingType:(MLCGradientClippingType)clippingType
                  gradientClipMax:(float)clipMax
                  gradientClipMin:(float)clipMin
             maximumClippingNorm:(float)maximumNorm
                customGlobalNorm:(float)globalNorm
               regularizationType:(MLCRegularizationType)regularizationType
             regularizationScale:(float)regularizationScale
{
    _learningRate = learningRate;
    _gradientRescale = rescale;
    _appliesGradientClipping = clipping;
    _gradientClippingType = clippingType;
    _gradientClipMax = clipMax;
    _gradientClipMin = clipMin;
    _maximumClippingNorm = maximumNorm;
    _customGlobalNorm = globalNorm;
    _regularizationType = regularizationType;
    _regularizationScale = regularizationScale;
}

- (float)learningRate
{
    return _learningRate;
}

- (float)gradientRescale
{
    return _gradientRescale;
}

- (BOOL)appliesGradientClipping
{
    return _appliesGradientClipping;
}

- (float)gradientClipMax
{
    return _gradientClipMax;
}

- (float)gradientClipMin
{
    return _gradientClipMin;
}

- (float)regularizationScale
{
    return _regularizationScale;
}

- (MLCRegularizationType)regularizationType
{
    return _regularizationType;
}

- (MLCGradientClippingType)gradientClippingType
{
    return _gradientClippingType;
}

- (float)maximumClippingNorm
{
    return _maximumClippingNorm;
}

- (float)customGlobalNorm
{
    return _customGlobalNorm;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCOptimizerDescriptor *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setLearningRate:_learningRate
                  gradientRescale:_gradientRescale
          appliesGradientClipping:_appliesGradientClipping
                gradientClippingType:_gradientClippingType
                    gradientClipMax:_gradientClipMax
                    gradientClipMin:_gradientClipMin
               maximumClippingNorm:_maximumClippingNorm
                  customGlobalNorm:_customGlobalNorm
                 regularizationType:_regularizationType
               regularizationScale:_regularizationScale];
    return copy;
}

@end

#pragma mark - MLCMatMulDescriptor

@implementation MLCMatMulDescriptor {
    float _alpha;
    BOOL _transposesX;
    BOOL _transposesY;
}

- (instancetype)init
{
    // The header's unavailable initialiser: no scale, no transposition (measured).
    self = [super init];
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptor
{
    MLCMatMulDescriptor *descriptor = [[MLCMatMulDescriptor alloc] init];
    descriptor->_alpha = 1.0f;
    return descriptor;
}

+ (instancetype)descriptorWithAlpha:(float)alpha transposesX:(BOOL)transposesX transposesY:(BOOL)transposesY
{
    MLCMatMulDescriptor *descriptor = [[MLCMatMulDescriptor alloc] init];
    descriptor->_alpha = alpha;
    descriptor->_transposesX = transposesX;
    descriptor->_transposesY = transposesY;
    return descriptor;
}

- (float)alpha
{
    return _alpha;
}

- (BOOL)transposesX
{
    return _transposesX;
}

- (BOOL)transposesY
{
    return _transposesY;
}

- (id)copyWithZone:(NSZone *)zone
{
    // The copy keeps the scale and loses both transpositions. That is what the host's copy does (measured:
    // a descriptor with a scale of 2 and a transposed x copies to a scale of 2 and no transposition), and
    // the port keeps it rather than being quietly better than the framework it stands for;
    // facts/MLDescriptors.md names it.
    MLCMatMulDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy->_alpha = _alpha;
    return copy;
}

@end

#pragma mark - MLCEmbeddingDescriptor

@implementation MLCEmbeddingDescriptor {
    NSNumber *_embeddingCount;
    NSNumber *_embeddingDimension;
    NSNumber *_paddingIndex;
    NSNumber *_maximumNorm;
    NSNumber *_pNorm;
    BOOL _scalesGradientByFrequency;
}

- (instancetype)init
{
    // The header's unavailable initialiser: nothing set at all, not even the number of rows (measured).
    self = [super init];
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptorWithEmbeddingCount:(NSNumber *)embeddingCount embeddingDimension:(NSNumber *)embeddingDimension
{
    // The shorter form leaves the padding index and the maximum norm unset and gives a p-norm of two, which
    // is the exponent the longest form's default of nothing means (measured).
    return [self descriptorWithEmbeddingCount:embeddingCount
                             embeddingDimension:embeddingDimension
                                   paddingIndex:nil
                                   maximumNorm:nil
                                         pNorm:@(2)
                     scalesGradientByFrequency:NO];
}

+ (instancetype)descriptorWithEmbeddingCount:(NSNumber *)embeddingCount
                           embeddingDimension:(NSNumber *)embeddingDimension
                                 paddingIndex:(NSNumber *)paddingIndex
                                 maximumNorm:(NSNumber *)maximumNorm
                                       pNorm:(NSNumber *)pNorm
                   scalesGradientByFrequency:(BOOL)scalesGradientByFrequency
{
    MLCEmbeddingDescriptor *descriptor = [[MLCEmbeddingDescriptor alloc] init];
    [descriptor charon_setCount:embeddingCount
                    dimension:embeddingDimension
                   paddingIndex:paddingIndex
                   maximumNorm:maximumNorm
                         pNorm:pNorm
    scalesGradientByFrequency:scalesGradientByFrequency];
    return descriptor;
}

- (void)charon_setCount:(NSNumber *)count
              dimension:(NSNumber *)dimension
           paddingIndex:(NSNumber *)paddingIndex
           maximumNorm:(NSNumber *)maximumNorm
                 pNorm:(NSNumber *)pNorm
scalesGradientByFrequency:(BOOL)scales
{
    _embeddingCount = [count copy];
    _embeddingDimension = [dimension copy];
    _paddingIndex = [paddingIndex copy];
    _maximumNorm = [maximumNorm copy];
    _pNorm = [pNorm copy];
    _scalesGradientByFrequency = scales;
}

- (NSNumber *)embeddingCount
{
    return _embeddingCount;
}

- (NSNumber *)embeddingDimension
{
    return _embeddingDimension;
}

- (NSNumber *)paddingIndex
{
    return _paddingIndex;
}

- (NSNumber *)maximumNorm
{
    return _maximumNorm;
}

- (NSNumber *)pNorm
{
    return _pNorm;
}

- (BOOL)scalesGradientByFrequency
{
    return _scalesGradientByFrequency;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCEmbeddingDescriptor *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setCount:_embeddingCount
                dimension:_embeddingDimension
             paddingIndex:_paddingIndex
             maximumNorm:_maximumNorm
                   pNorm:_pNorm
scalesGradientByFrequency:_scalesGradientByFrequency];
    return copy;
}

@end

#pragma mark - MLCLSTMDescriptor

@implementation MLCLSTMDescriptor {
    NSUInteger _inputSize;
    NSUInteger _hiddenSize;
    NSUInteger _layerCount;
    BOOL _usesBiases;
    BOOL _batchFirst;
    BOOL _isBidirectional;
    BOOL _returnsSequences;
    float _dropout;
    MLCLSTMResultMode _resultMode;
}

- (instancetype)init
{
    // The header's unavailable initialiser: everything zero, no biases and the output result mode
    // (measured).
    self = [super init];
    if (self) {
        _resultMode = MLCLSTMResultModeOutput;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptorWithInputSize:(NSUInteger)inputSize hiddenSize:(NSUInteger)hiddenSize layerCount:(NSUInteger)layerCount
{
    return [self descriptorWithInputSize:inputSize
                             hiddenSize:hiddenSize
                             layerCount:layerCount
                             usesBiases:YES
                            batchFirst:YES
                         isBidirectional:NO
                        returnsSequences:YES
                               dropout:0.0f
                            resultMode:MLCLSTMResultModeOutput];
}

+ (instancetype)descriptorWithInputSize:(NSUInteger)inputSize
                             hiddenSize:(NSUInteger)hiddenSize
                             layerCount:(NSUInteger)layerCount
                             usesBiases:(BOOL)usesBiases
                        isBidirectional:(BOOL)isBidirectional
                               dropout:(float)dropout
{
    return [self descriptorWithInputSize:inputSize
                             hiddenSize:hiddenSize
                             layerCount:layerCount
                             usesBiases:usesBiases
                            batchFirst:YES
                         isBidirectional:isBidirectional
                        returnsSequences:YES
                               dropout:dropout
                            resultMode:MLCLSTMResultModeOutput];
}

+ (instancetype)descriptorWithInputSize:(NSUInteger)inputSize
                             hiddenSize:(NSUInteger)hiddenSize
                             layerCount:(NSUInteger)layerCount
                             usesBiases:(BOOL)usesBiases
                            batchFirst:(BOOL)batchFirst
                         isBidirectional:(BOOL)isBidirectional
                               dropout:(float)dropout
{
    return [self descriptorWithInputSize:inputSize
                             hiddenSize:hiddenSize
                             layerCount:layerCount
                             usesBiases:usesBiases
                            batchFirst:batchFirst
                         isBidirectional:isBidirectional
                        returnsSequences:YES
                               dropout:dropout
                            resultMode:MLCLSTMResultModeOutput];
}

+ (instancetype)descriptorWithInputSize:(NSUInteger)inputSize
                             hiddenSize:(NSUInteger)hiddenSize
                             layerCount:(NSUInteger)layerCount
                             usesBiases:(BOOL)usesBiases
                            batchFirst:(BOOL)batchFirst
                         isBidirectional:(BOOL)isBidirectional
                        returnsSequences:(BOOL)returnsSequences
                               dropout:(float)dropout
{
    return [self descriptorWithInputSize:inputSize
                             hiddenSize:hiddenSize
                             layerCount:layerCount
                             usesBiases:usesBiases
                            batchFirst:batchFirst
                         isBidirectional:isBidirectional
                        returnsSequences:returnsSequences
                               dropout:dropout
                            resultMode:MLCLSTMResultModeOutput];
}

+ (instancetype)descriptorWithInputSize:(NSUInteger)inputSize
                             hiddenSize:(NSUInteger)hiddenSize
                             layerCount:(NSUInteger)layerCount
                             usesBiases:(BOOL)usesBiases
                            batchFirst:(BOOL)batchFirst
                         isBidirectional:(BOOL)isBidirectional
                        returnsSequences:(BOOL)returnsSequences
                               dropout:(float)dropout
                            resultMode:(MLCLSTMResultMode)resultMode
{
    MLCLSTMDescriptor *descriptor = [[MLCLSTMDescriptor alloc] init];
    [descriptor charon_setInputSize:inputSize
                        hiddenSize:hiddenSize
                        layerCount:layerCount
                        usesBiases:usesBiases
                       batchFirst:batchFirst
                    isBidirectional:isBidirectional
                    returnsSequences:returnsSequences
                           dropout:dropout
                        resultMode:resultMode];
    return descriptor;
}

- (void)charon_setInputSize:(NSUInteger)inputSize
                  hiddenSize:(NSUInteger)hiddenSize
                  layerCount:(NSUInteger)layerCount
                  usesBiases:(BOOL)usesBiases
                 batchFirst:(BOOL)batchFirst
              isBidirectional:(BOOL)bidirectional
              returnsSequences:(BOOL)returnsSequences
                     dropout:(float)dropout
                  resultMode:(MLCLSTMResultMode)resultMode
{
    _inputSize = inputSize;
    _hiddenSize = hiddenSize;
    _layerCount = layerCount;
    _usesBiases = usesBiases;
    _batchFirst = batchFirst;
    _isBidirectional = bidirectional;
    _returnsSequences = returnsSequences;
    _dropout = dropout;
    _resultMode = resultMode;
}

- (NSUInteger)inputSize
{
    return _inputSize;
}

- (NSUInteger)hiddenSize
{
    return _hiddenSize;
}

- (NSUInteger)layerCount
{
    return _layerCount;
}

- (BOOL)usesBiases
{
    return _usesBiases;
}

- (BOOL)batchFirst
{
    return _batchFirst;
}

- (BOOL)isBidirectional
{
    return _isBidirectional;
}

- (BOOL)returnsSequences
{
    return _returnsSequences;
}

- (float)dropout
{
    return _dropout;
}

- (MLCLSTMResultMode)resultMode
{
    return _resultMode;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCLSTMDescriptor *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setInputSize:_inputSize
                    hiddenSize:_hiddenSize
                    layerCount:_layerCount
                    usesBiases:_usesBiases
                   batchFirst:_batchFirst
                isBidirectional:_isBidirectional
                returnsSequences:_returnsSequences
                       dropout:_dropout
                    resultMode:_resultMode];
    return copy;
}

@end

#pragma mark - MLCMultiheadAttentionDescriptor

@implementation MLCMultiheadAttentionDescriptor {
    NSUInteger _modelDimension;
    NSUInteger _keyDimension;
    NSUInteger _valueDimension;
    NSUInteger _headCount;
    float _dropout;
    BOOL _hasBiases;
    BOOL _hasAttentionBiases;
    BOOL _addsZeroAttention;
}

- (instancetype)init
{
    // The header's unavailable initialiser: no dimensions, no heads and no biases (measured).
    self = [super init];
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptorWithModelDimension:(NSUInteger)modelDimension headCount:(NSUInteger)headCount
{
    // The key and the value take the model's own dimension, and the biases are there: the shorter form is
    // the longer one with those four arguments left out (measured: a model of 8 and 2 heads answers a key
    // and a value of 8, a bias, no attention bias and no zero attention).
    return [self descriptorWithModelDimension:modelDimension
                                  keyDimension:modelDimension
                                valueDimension:modelDimension
                                    headCount:headCount
                                     dropout:0.0f
                                   hasBiases:YES
                          hasAttentionBiases:NO
                           addsZeroAttention:NO];
}

+ (instancetype)descriptorWithModelDimension:(NSUInteger)modelDimension
                                 keyDimension:(NSUInteger)keyDimension
                               valueDimension:(NSUInteger)valueDimension
                                   headCount:(NSUInteger)headCount
                                    dropout:(float)dropout
                                  hasBiases:(BOOL)hasBiases
                         hasAttentionBiases:(BOOL)hasAttentionBiases
                          addsZeroAttention:(BOOL)addsZeroAttention
{
    MLCMultiheadAttentionDescriptor *descriptor = [[MLCMultiheadAttentionDescriptor alloc] init];
    [descriptor charon_setModelDimension:modelDimension
                             keyDimension:keyDimension
                           valueDimension:valueDimension
                               headCount:headCount
                                dropout:dropout
                              hasBiases:hasBiases
                     hasAttentionBiases:hasAttentionBiases
                      addsZeroAttention:addsZeroAttention];
    return descriptor;
}

- (void)charon_setModelDimension:(NSUInteger)modelDimension
                     keyDimension:(NSUInteger)keyDimension
                   valueDimension:(NSUInteger)valueDimension
                       headCount:(NSUInteger)headCount
                        dropout:(float)dropout
                      hasBiases:(BOOL)hasBiases
             hasAttentionBiases:(BOOL)hasAttentionBiases
              addsZeroAttention:(BOOL)addsZeroAttention
{
    _modelDimension = modelDimension;
    _keyDimension = keyDimension;
    _valueDimension = valueDimension;
    _headCount = headCount;
    _dropout = dropout;
    _hasBiases = hasBiases;
    _hasAttentionBiases = hasAttentionBiases;
    _addsZeroAttention = addsZeroAttention;
}

- (NSUInteger)modelDimension
{
    return _modelDimension;
}

- (NSUInteger)keyDimension
{
    return _keyDimension;
}

- (NSUInteger)valueDimension
{
    return _valueDimension;
}

- (NSUInteger)headCount
{
    return _headCount;
}

- (float)dropout
{
    return _dropout;
}

- (BOOL)hasBiases
{
    return _hasBiases;
}

- (BOOL)hasAttentionBiases
{
    return _hasAttentionBiases;
}

- (BOOL)addsZeroAttention
{
    return _addsZeroAttention;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCMultiheadAttentionDescriptor *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setModelDimension:_modelDimension
                        keyDimension:_keyDimension
                      valueDimension:_valueDimension
                          headCount:_headCount
                           dropout:_dropout
                         hasBiases:_hasBiases
                hasAttentionBiases:_hasAttentionBiases
                 addsZeroAttention:_addsZeroAttention];
    return copy;
}

@end

#pragma mark - MLCYOLOLossDescriptor

@implementation MLCYOLOLossDescriptor {
    NSUInteger _anchorBoxCount;
    NSData *_anchorBoxes;
    BOOL _shouldRescore;
    float _scaleSpatialPositionLoss;
    float _scaleSpatialSizeLoss;
    float _scaleNoObjectConfidenceLoss;
    float _scaleObjectConfidenceLoss;
    float _scaleClassLoss;
    float _minimumIOUForObjectPresence;
    float _maximumIOUForObjectAbsence;
}

- (instancetype)init
{
    // The header's unavailable initialiser: no anchor boxes, a count of zero and every scale zero, with no
    // rescore (measured).
    self = [super init];
    if (self) {
        _anchorBoxes = [NSData data];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

// The scales the loss itself runs with, which the factory carries and an initialiser does not: a rescore of
// yes, 10 for each of the spatial position and the spatial size, 5 for the confidence that no object is
// there, 100 for the one that an object is, 2 for the class, an intersection over union of 0.7 for an
// object to be there and 0.3 for it to be absent (measured).
+ (instancetype)descriptorWithAnchorBoxes:(NSData *)anchorBoxes anchorBoxCount:(NSUInteger)anchorBoxCount
{
    MLCYOLOLossDescriptor *descriptor = [[MLCYOLOLossDescriptor alloc] init];
    [descriptor charon_setAnchorBoxes:anchorBoxes count:anchorBoxCount];
    descriptor->_shouldRescore = YES;
    descriptor->_scaleSpatialPositionLoss = 10.0f;
    descriptor->_scaleSpatialSizeLoss = 10.0f;
    descriptor->_scaleNoObjectConfidenceLoss = 5.0f;
    descriptor->_scaleObjectConfidenceLoss = 100.0f;
    descriptor->_scaleClassLoss = 2.0f;
    descriptor->_minimumIOUForObjectPresence = 0.7f;
    descriptor->_maximumIOUForObjectAbsence = 0.3f;
    return descriptor;
}

- (void)charon_setAnchorBoxes:(NSData *)boxes count:(NSUInteger)count
{
    _anchorBoxes = [boxes copy] ?: [NSData data];
    _anchorBoxCount = count;
}

- (NSUInteger)anchorBoxCount
{
    return _anchorBoxCount;
}

- (NSData *)anchorBoxes
{
    return _anchorBoxes;
}

- (BOOL)shouldRescore
{
    return _shouldRescore;
}

- (void)setShouldRescore:(BOOL)shouldRescore
{
    _shouldRescore = shouldRescore;
}

- (float)scaleSpatialPositionLoss
{
    return _scaleSpatialPositionLoss;
}

- (void)setScaleSpatialPositionLoss:(float)scale
{
    _scaleSpatialPositionLoss = scale;
}

- (float)scaleSpatialSizeLoss
{
    return _scaleSpatialSizeLoss;
}

- (void)setScaleSpatialSizeLoss:(float)scale
{
    _scaleSpatialSizeLoss = scale;
}

- (float)scaleNoObjectConfidenceLoss
{
    return _scaleNoObjectConfidenceLoss;
}

- (void)setScaleNoObjectConfidenceLoss:(float)scale
{
    _scaleNoObjectConfidenceLoss = scale;
}

- (float)scaleObjectConfidenceLoss
{
    return _scaleObjectConfidenceLoss;
}

- (void)setScaleObjectConfidenceLoss:(float)scale
{
    _scaleObjectConfidenceLoss = scale;
}

- (float)scaleClassLoss
{
    return _scaleClassLoss;
}

- (void)setScaleClassLoss:(float)scale
{
    _scaleClassLoss = scale;
}

- (float)minimumIOUForObjectPresence
{
    return _minimumIOUForObjectPresence;
}

- (void)setMinimumIOUForObjectPresence:(float)minimum
{
    _minimumIOUForObjectPresence = minimum;
}

- (float)maximumIOUForObjectAbsence
{
    return _maximumIOUForObjectAbsence;
}

- (void)setMaximumIOUForObjectAbsence:(float)maximum
{
    _maximumIOUForObjectAbsence = maximum;
}

- (id)copyWithZone:(NSZone *)zone
{
    // The copy keeps the anchor boxes and their count and takes the loss's own scales, not the ones the
    // descriptor was last given (measured: a descriptor whose class scale was set to 5.5 copies to 2). The
    // port keeps that, and facts/MLCDescriptors.md names it.
    return [[self class] descriptorWithAnchorBoxes:_anchorBoxes anchorBoxCount:_anchorBoxCount];
}

@end
