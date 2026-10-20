#import "RevenantMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

@interface MLCActivationDescriptor (RevenantStorage)
- (void)revenant_setType:(MLCActivationType)type a:(float)a b:(float)b c:(float)c;
@end

@interface MLCConvolutionDescriptor (RevenantStorage)
- (void)revenant_setType:(MLCConvolutionType)type
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

@interface MLCPoolingDescriptor (RevenantStorage)
- (void)revenant_setType:(MLCPoolingType)type
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

@interface MLCLossDescriptor (RevenantStorage)
- (void)revenant_setType:(MLCLossType)type
           reduction:(MLCReductionType)reduction
               weight:(float)weight
        labelSmoothing:(float)labelSmoothing
          classCount:(NSUInteger)classCount
              epsilon:(float)epsilon
                delta:(float)delta;
@end

@interface MLCOptimizerDescriptor (RevenantStorage)
- (void)revenant_setLearningRate:(float)learningRate
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

@interface MLCLSTMDescriptor (RevenantStorage)
- (void)revenant_setInputSize:(NSUInteger)inputSize
                  hiddenSize:(NSUInteger)hiddenSize
                  layerCount:(NSUInteger)layerCount
                  usesBiases:(BOOL)usesBiases
                 batchFirst:(BOOL)batchFirst
              isBidirectional:(BOOL)bidirectional
              returnsSequences:(BOOL)returnsSequences
                     dropout:(float)dropout
                  resultMode:(MLCLSTMResultMode)resultMode;
@end

@interface MLCMultiheadAttentionDescriptor (RevenantStorage)
- (void)revenant_setModelDimension:(NSUInteger)modelDimension
                     keyDimension:(NSUInteger)keyDimension
                   valueDimension:(NSUInteger)valueDimension
                       headCount:(NSUInteger)headCount
                        dropout:(float)dropout
                      hasBiases:(BOOL)hasBiases
             hasAttentionBiases:(BOOL)hasAttentionBiases
              addsZeroAttention:(BOOL)addsZeroAttention;
@end

@interface MLCEmbeddingDescriptor (RevenantStorage)
- (void)revenant_setCount:(NSNumber *)count
            dimension:(NSNumber *)dimension
           paddingIndex:(NSNumber *)paddingIndex
           maximumNorm:(NSNumber *)maximumNorm
                 pNorm:(NSNumber *)pNorm
scalesGradientByFrequency:(BOOL)scales;
@end

@interface MLCYOLOLossDescriptor (RevenantStorage)
- (void)revenant_setAnchorBoxes:(NSData *)boxes count:(NSUInteger)count;
@end

static void RevenantMLCDefaultActivation(MLCActivationType type, float *a, float *b, float *c)
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
    RevenantMLCDefaultActivation(activationType, &a, &b, &c);
    MLCActivationDescriptor *descriptor = [[MLCActivationDescriptor alloc] init];
    [descriptor revenant_setType:activationType a:a b:b c:c];
    return descriptor;
}

+ (instancetype)descriptorWithType:(MLCActivationType)activationType a:(float)a
{
    float ignored, b, c;
    RevenantMLCDefaultActivation(activationType, &ignored, &b, &c);
    MLCActivationDescriptor *descriptor = [[MLCActivationDescriptor alloc] init];
    [descriptor revenant_setType:activationType a:a b:b c:c];
    return descriptor;
}

+ (instancetype)descriptorWithType:(MLCActivationType)activationType a:(float)a b:(float)b
{
    float ignored, ignored2, c;
    RevenantMLCDefaultActivation(activationType, &ignored, &ignored2, &c);
    MLCActivationDescriptor *descriptor = [[MLCActivationDescriptor alloc] init];
    [descriptor revenant_setType:activationType a:a b:b c:c];
    return descriptor;
}

+ (instancetype)descriptorWithType:(MLCActivationType)activationType a:(float)a b:(float)b c:(float)c
{
    MLCActivationDescriptor *descriptor = [[MLCActivationDescriptor alloc] init];
    [descriptor revenant_setType:activationType a:a b:b c:c];
    return descriptor;
}

- (void)revenant_setType:(MLCActivationType)type a:(float)a b:(float)b c:(float)c
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
    [copy revenant_setType:_activationType a:_a b:_b c:_c];
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

static void RevenantMLCPair(NSArray<NSNumber *> *values, NSUInteger *x, NSUInteger *y)
{
    NSUInteger first = values.count > 0 ? values[0].unsignedIntegerValue : 1;
    NSUInteger second = values.count > 1 ? values[1].unsignedIntegerValue : first;
    *x = second;
    *y = first;
}

static void RevenantMLCPaddingPair(NSArray<NSNumber *> *values, NSUInteger *x, NSUInteger *y)
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
    RevenantMLCPair(kernelSizes, &width, &height);
    RevenantMLCPair(strides, &strideX, &strideY);
    RevenantMLCPair(dilationRates, &dilationX, &dilationY);
    RevenantMLCPaddingPair(paddingSizes, &paddingX, &paddingY);
    MLCConvolutionDescriptor *descriptor = [[MLCConvolutionDescriptor alloc] init];
    [descriptor revenant_setType:convolutionType
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
    [descriptor revenant_setType:MLCConvolutionTypeStandard
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
    [descriptor revenant_setType:MLCConvolutionTypeTransposed
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
    MLCConvolutionDescriptor *descriptor = [[MLCConvolutionDescriptor alloc] init];
    [descriptor revenant_setType:MLCConvolutionTypeDepthwise
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

- (void)revenant_setType:(MLCConvolutionType)type
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
    [copy revenant_setType:_convolutionType
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
    [descriptor revenant_setType:poolingType
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
    return [self revenant_poolingDescriptorOfType:MLCPoolingTypeMax
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
    return [self revenant_poolingDescriptorOfType:MLCPoolingTypeMax
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
    return [self revenant_poolingDescriptorOfType:MLCPoolingTypeAverage
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
    return [self revenant_poolingDescriptorOfType:MLCPoolingTypeAverage
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
    return [self revenant_poolingDescriptorOfType:MLCPoolingTypeL2Norm
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
    return [self revenant_poolingDescriptorOfType:MLCPoolingTypeL2Norm
                                    kernelSizes:kernelSizes
                                        strides:strides
                                   dilationRates:dilationRates
                                  paddingPolicy:paddingPolicy
                                   paddingSizes:paddingSizes
                               countsPadding:NO];
}

+ (instancetype)revenant_poolingDescriptorOfType:(MLCPoolingType)type
                                  kernelSizes:(NSArray<NSNumber *> *)kernelSizes
                                      strides:(NSArray<NSNumber *> *)strides
                                 dilationRates:(NSArray<NSNumber *> *)dilationRates
                                paddingPolicy:(MLCPaddingPolicy)paddingPolicy
                                 paddingSizes:(NSArray<NSNumber *> *)paddingSizes
                                 countsPadding:(BOOL)countsPadding
{
    NSUInteger width, height, strideX = 0, strideY = 0, dilationX, dilationY, paddingX = 0, paddingY = 0;
    RevenantMLCPair(kernelSizes, &width, &height);
    if (strides) {
        RevenantMLCPair(strides, &strideX, &strideY);
    } else {
        strideX = width;
        strideY = height;
    }
    RevenantMLCPair(dilationRates, &dilationX, &dilationY);
    RevenantMLCPaddingPair(paddingSizes, &paddingX, &paddingY);
    MLCPoolingDescriptor *descriptor = [[MLCPoolingDescriptor alloc] init];
    [descriptor revenant_setType:type
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

- (void)revenant_setType:(MLCPoolingType)type
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
    [copy revenant_setType:_poolingType
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
    [descriptor revenant_setType:lossType
                    reduction:reductionType
                        weight:weight
                labelSmoothing:labelSmoothing
                   classCount:classCount
                       epsilon:epsilon
                         delta:delta];
    return descriptor;
}

- (void)revenant_setType:(MLCLossType)type
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
    [copy revenant_setType:_lossType
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
    [descriptor revenant_setLearningRate:learningRate
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

- (void)revenant_setLearningRate:(float)learningRate
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
    [copy revenant_setLearningRate:_learningRate
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
    self = [super init];
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptorWithEmbeddingCount:(NSNumber *)embeddingCount embeddingDimension:(NSNumber *)embeddingDimension
{
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
    [descriptor revenant_setCount:embeddingCount
                    dimension:embeddingDimension
                   paddingIndex:paddingIndex
                   maximumNorm:maximumNorm
                         pNorm:pNorm
    scalesGradientByFrequency:scalesGradientByFrequency];
    return descriptor;
}

- (void)revenant_setCount:(NSNumber *)count
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
    [copy revenant_setCount:_embeddingCount
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
    [descriptor revenant_setInputSize:inputSize
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

- (void)revenant_setInputSize:(NSUInteger)inputSize
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
    [copy revenant_setInputSize:_inputSize
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
    self = [super init];
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)descriptorWithModelDimension:(NSUInteger)modelDimension headCount:(NSUInteger)headCount
{
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
    [descriptor revenant_setModelDimension:modelDimension
                             keyDimension:keyDimension
                           valueDimension:valueDimension
                               headCount:headCount
                                dropout:dropout
                              hasBiases:hasBiases
                     hasAttentionBiases:hasAttentionBiases
                      addsZeroAttention:addsZeroAttention];
    return descriptor;
}

- (void)revenant_setModelDimension:(NSUInteger)modelDimension
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
    [copy revenant_setModelDimension:_modelDimension
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

+ (instancetype)descriptorWithAnchorBoxes:(NSData *)anchorBoxes anchorBoxCount:(NSUInteger)anchorBoxCount
{
    MLCYOLOLossDescriptor *descriptor = [[MLCYOLOLossDescriptor alloc] init];
    [descriptor revenant_setAnchorBoxes:anchorBoxes count:anchorBoxCount];
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

- (void)revenant_setAnchorBoxes:(NSData *)boxes count:(NSUInteger)count
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
    return [[self class] descriptorWithAnchorBoxes:_anchorBoxes anchorBoxCount:_anchorBoxCount];
}

@end
