// What the thirty layer classes answer: the name each factory gives its layer, what each keeps, and
// what each refuses. Written once and run twice - beside the host's MLCompute and beside the port's
// own translation units - by run.sh, which renames the port's names so both can be in one build.
#import "mlcompute-16.h"

static void key(NSString *name, NSString *value)
{
    NSMutableString *flat = [NSMutableString string];
    for (NSUInteger index = 0; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        [flat appendFormat:@"%C", (character == '\n' || character == '\t' || character == ' ') ? ' ' : character];
    }
    printf("%s\t%s\n", name.UTF8String, flat.UTF8String);
}

static void row(NSString *name, id value)
{
    key(name, value ? [value description] : @"(nil)");
}

static void text(NSString *name, NSString *value)
{
    key(name, value);
}

static NSString *nums(NSArray *values)
{
    if (!values) {
        return @"(nil)";
    }
    NSMutableString *out = [NSMutableString string];
    for (NSNumber *value in values) {
        if (out.length) {
            [out appendString:@","];
        }
        [out appendString:value.stringValue];
    }
    return out;
}

static void shape(NSString *name, NSArray *values)
{
    text(name, nums(values));
}

static MLCTensorDescriptor *shape_(NSArray *list)
{
    return [MLCTensorDescriptor descriptorWithShape:list dataType:MLCDataTypeFloat32];
}

static MLCTensor *perChannel(NSUInteger channels, float value)
{
    return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:channels dataType:MLCDataTypeFloat32]
                                fillWithData:@(value)];
}

static MLCTensor *vector(NSUInteger count, float value)
{
    return [MLCTensor tensorWithDescriptor:shape_(@[ @(count) ]) fillWithData:@(value)];
}

void charon_mlcompute_layer_cases(void)
{
    @autoreleasepool {
        MLCConvolutionDescriptor *convolution = [MLCConvolutionDescriptor descriptorWithKernelWidth:3 kernelHeight:3 inputFeatureChannelCount:4 outputFeatureChannelCount:5];
        MLCPoolingDescriptor *pooling = [MLCPoolingDescriptor poolingDescriptorWithType:MLCPoolingTypeMax kernelSize:2 stride:2];
        MLCLossDescriptor *loss = [MLCLossDescriptor descriptorWithType:MLCLossTypeMeanSquaredError reductionType:MLCReductionTypeMean];
        MLCOptimizerDescriptor *optimizer = [MLCOptimizerDescriptor descriptorWithLearningRate:0.1 gradientRescale:1
                                                                      regularizationType:MLCRegularizationTypeNone
                                                                     regularizationScale:0];
        (void)optimizer;
        MLCTensor *weights = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionWeightsDescriptorWithWidth:3 height:3 inputFeatureChannelCount:4 outputFeatureChannelCount:5 dataType:MLCDataTypeFloat32]
                                                  fillWithData:@(1)];
        MLCTensor *biases = perChannel(5, 2);
        MLCTensor *wrong = [MLCTensor tensorWithDescriptor:shape_(@[ @3, @3, @4, @5 ]) fillWithData:@(1)];

        printf("== the name each factory gives its layer\n");
        row(@"label selection", [MLCSelectionLayer layer].label);
        row(@"label activation relu", [MLCActivationLayer reluLayer].label);
        row(@"label activation relu6", [MLCActivationLayer relu6Layer].label);
        row(@"label activation leaky", [MLCActivationLayer leakyReLULayer].label);
        row(@"label activation leaky 0.2", [MLCActivationLayer leakyReLULayerWithNegativeSlope:0.2].label);
        row(@"label activation linear", [MLCActivationLayer linearLayerWithScale:3 bias:4].label);
        row(@"label activation sigmoid", [MLCActivationLayer sigmoidLayer].label);
        row(@"label activation hardSigmoid", [MLCActivationLayer hardSigmoidLayer].label);
        row(@"label activation tanh", [MLCActivationLayer tanhLayer].label);
        row(@"label activation absolute", [MLCActivationLayer absoluteLayer].label);
        row(@"label activation softPlus", [MLCActivationLayer softPlusLayer].label);
        row(@"label activation softPlus 2", [MLCActivationLayer softPlusLayerWithBeta:2].label);
        row(@"label activation softSign", [MLCActivationLayer softSignLayer].label);
        row(@"label activation elu", [MLCActivationLayer eluLayer].label);
        row(@"label activation elu 0.5", [MLCActivationLayer eluLayerWithA:0.5].label);
        row(@"label activation relun", [MLCActivationLayer relunLayerWithA:0.1 b:6].label);
        row(@"label activation logSigmoid", [MLCActivationLayer logSigmoidLayer].label);
        row(@"label activation selu", [MLCActivationLayer seluLayer].label);
        row(@"label activation celu", [MLCActivationLayer celuLayer].label);
        row(@"label activation celu 0.7", [MLCActivationLayer celuLayerWithA:0.7].label);
        row(@"label activation hardShrink", [MLCActivationLayer hardShrinkLayer].label);
        row(@"label activation hardShrink 0.3", [MLCActivationLayer hardShrinkLayerWithA:0.3].label);
        row(@"label activation softShrink", [MLCActivationLayer softShrinkLayer].label);
        row(@"label activation softShrink 0.4", [MLCActivationLayer softShrinkLayerWithA:0.4].label);
        row(@"label activation tanhShrink", [MLCActivationLayer tanhShrinkLayer].label);
        row(@"label activation threshold", [MLCActivationLayer thresholdLayerWithThreshold:0.6 replacement:-1].label);
        row(@"label activation gelu", [MLCActivationLayer geluLayer].label);
        row(@"label activation hardSwish", [MLCActivationLayer hardSwishLayer].label);
        row(@"label activation clamp", [MLCActivationLayer clampLayerWithMinValue:-1 maxValue:2].label);
        row(@"label activation from a descriptor", [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeTanh]].label);
        row(@"label arithmetic", [MLCArithmeticLayer layerWithOperation:MLCArithmeticOperationAdd].label);
        row(@"label comparison", [MLCComparisonLayer layerWithOperation:MLCComparisonOperationLess].label);
        row(@"label concatenation", [MLCConcatenationLayer layer].label);
        row(@"label concatenation 2", [MLCConcatenationLayer layerWithDimension:2].label);
        row(@"label convolution", [MLCConvolutionLayer layerWithWeights:weights biases:biases descriptor:convolution].label);
        row(@"label dropout", [MLCDropoutLayer layerWithRate:0.5 seed:7].label);
        row(@"label gather", [MLCGatherLayer layerWithDimension:1].label);
        row(@"label gram matrix", [MLCGramMatrixLayer layerWithScale:2].label);
        row(@"label matmul", [MLCMatMulLayer layerWithDescriptor:[MLCMatMulDescriptor descriptor]].label);
        row(@"label padding zero", [MLCPaddingLayer layerWithZeroPadding:@[ @1, @2, @3, @4 ]].label);
        row(@"label padding constant", [MLCPaddingLayer layerWithConstantPadding:@[ @1, @1, @2, @2 ] constantValue:3.5].label);
        row(@"label padding symmetric", [MLCPaddingLayer layerWithSymmetricPadding:@[ @1, @1, @1, @1 ]].label);
        row(@"label padding reflection", [MLCPaddingLayer layerWithReflectionPadding:@[ @1, @1, @1, @1 ]].label);
        row(@"label pooling", [MLCPoolingLayer layerWithDescriptor:pooling].label);
        row(@"label reduction", [MLCReductionLayer layerWithReductionType:MLCReductionTypeMean dimension:1].label);
        row(@"label reshape", [MLCReshapeLayer layerWithShape:@[ @1, @2, @3, @4 ]].label);
        row(@"label scatter", [MLCScatterLayer layerWithDimension:1 reductionType:MLCReductionTypeSum].label);
        row(@"label slice", [MLCSliceLayer sliceLayerWithStart:@[ @0 ] end:@[ @2 ] stride:nil].label);
        row(@"label softmax", [MLCSoftmaxLayer layerWithOperation:MLCSoftmaxOperationSoftmax].label);
        row(@"label split", [MLCSplitLayer layerWithSplitCount:2 dimension:1].label);
        row(@"label transpose", [MLCTransposeLayer layerWithDimensions:@[ @0, @2, @1, @3 ]].label);
        row(@"label upsample", [MLCUpsampleLayer layerWithShape:@[ @2, @2 ]].label);
        row(@"label loss", [MLCLossLayer layerWithDescriptor:loss].label);
        row(@"label loss mse", [MLCLossLayer meanSquaredErrorLossWithReductionType:MLCReductionTypeMean weight:1].label);

        printf("== what each layer reads back\n");
        text(@"activation relu6 descriptor", [NSString stringWithFormat:@"type=%d a=%g b=%g", (int)[MLCActivationLayer relu6Layer].descriptor.activationType,
                                                        [MLCActivationLayer relu6Layer].descriptor.a, [MLCActivationLayer relu6Layer].descriptor.b]);
        text(@"activation leaky descriptor", [NSString stringWithFormat:@"a=%g", [MLCActivationLayer leakyReLULayer].descriptor.a]);
        text(@"activation hardSigmoid descriptor", [NSString stringWithFormat:@"a=%g b=%g", [MLCActivationLayer hardSigmoidLayer].descriptor.a,
                                                             [MLCActivationLayer hardSigmoidLayer].descriptor.b]);
        text(@"activation gelu descriptor", [NSString stringWithFormat:@"a=%g b=%g", [MLCActivationLayer geluLayer].descriptor.a,
                                                   [MLCActivationLayer geluLayer].descriptor.b]);
        text(@"activation hardShrink descriptor", [NSString stringWithFormat:@"a=%g", [MLCActivationLayer hardShrinkLayer].descriptor.a]);
        text(@"activation softShrink descriptor", [NSString stringWithFormat:@"a=%g", [MLCActivationLayer softShrinkLayer].descriptor.a]);
        text(@"activation tanhShrink descriptor", [NSString stringWithFormat:@"a=%g", [MLCActivationLayer tanhShrinkLayer].descriptor.a]);
        text(@"activation softPlus 2 descriptor", [NSString stringWithFormat:@"b=%g", [MLCActivationLayer softPlusLayerWithBeta:2].descriptor.b]);
        text(@"activation relun descriptor", [NSString stringWithFormat:@"a=%g b=%g", [MLCActivationLayer relunLayerWithA:0.1 b:6].descriptor.a,
                                                   [MLCActivationLayer relunLayerWithA:0.1 b:6].descriptor.b]);
        text(@"activation clamp descriptor", [NSString stringWithFormat:@"a=%g b=%g", [MLCActivationLayer clampLayerWithMinValue:-1 maxValue:2].descriptor.a,
                                                 [MLCActivationLayer clampLayerWithMinValue:-1 maxValue:2].descriptor.b]);
        text(@"activation linear descriptor", [NSString stringWithFormat:@"a=%g b=%g", [MLCActivationLayer linearLayerWithScale:3 bias:4].descriptor.a,
                                                  [MLCActivationLayer linearLayerWithScale:3 bias:4].descriptor.b]);
        text(@"arithmetic operation", [NSString stringWithFormat:@"%d", (int)[MLCArithmeticLayer layerWithOperation:MLCArithmeticOperationMultiplyNoNaN].operation]);
        text(@"comparison operation", [NSString stringWithFormat:@"%d", (int)[MLCComparisonLayer layerWithOperation:MLCComparisonOperationLogicalXOR].operation]);
        text(@"concatenation dimension", [NSString stringWithFormat:@"%lu", (unsigned long)[MLCConcatenationLayer layer].dimension]);
        text(@"concatenation dimension 3", [NSString stringWithFormat:@"%lu", (unsigned long)[MLCConcatenationLayer layerWithDimension:3].dimension]);
        text(@"dropout", [NSString stringWithFormat:@"rate=%g seed=%lu", [MLCDropoutLayer layerWithRate:0.25 seed:99].rate,
                              (unsigned long)[MLCDropoutLayer layerWithRate:0.25 seed:99].seed]);
        text(@"gather dimension", [NSString stringWithFormat:@"%lu", (unsigned long)[MLCGatherLayer layerWithDimension:2].dimension]);
        text(@"gram matrix scale", [NSString stringWithFormat:@"%g", [MLCGramMatrixLayer layerWithScale:1.5].scale]);
        shape(@"reduction dimensions", [MLCReductionLayer layerWithReductionType:MLCReductionTypeSum dimensions:@[ @1, @2 ]].dimensions);
        text(@"reduction dimension", [NSString stringWithFormat:@"%lu", (unsigned long)[MLCReductionLayer layerWithReductionType:MLCReductionTypeMax dimension:2].dimension]);
        shape(@"reduction one dimension", [MLCReductionLayer layerWithReductionType:MLCReductionTypeMax dimension:2].dimensions);
        shape(@"reshape shape", [MLCReshapeLayer layerWithShape:@[ @8 ]].shape);
        text(@"scatter", [NSString stringWithFormat:@"dimension=%lu reduction=%d", (unsigned long)[MLCScatterLayer layerWithDimension:0 reductionType:MLCReductionTypeSum].dimension,
                                (int)[MLCScatterLayer layerWithDimension:0 reductionType:MLCReductionTypeSum].reductionType]);
        row(@"scatter with a reduction of mean", [MLCScatterLayer layerWithDimension:0 reductionType:MLCReductionTypeMean]);
        shape(@"slice start", [MLCSliceLayer sliceLayerWithStart:@[ @1, @2 ] end:@[ @3, @4 ] stride:@[ @2, @2 ]].start);
        shape(@"slice end", [MLCSliceLayer sliceLayerWithStart:@[ @1, @2 ] end:@[ @3, @4 ] stride:@[ @2, @2 ]].end);
        shape(@"slice stride", [MLCSliceLayer sliceLayerWithStart:@[ @1, @2 ] end:@[ @3, @4 ] stride:@[ @2, @2 ]].stride);
        shape(@"slice stride of nil", [MLCSliceLayer sliceLayerWithStart:@[ @1 ] end:@[ @4 ] stride:nil].stride);
        text(@"softmax", [NSString stringWithFormat:@"operation=%d dimension=%lu", (int)[MLCSoftmaxLayer layerWithOperation:MLCSoftmaxOperationLogSoftmax].operation,
                              (unsigned long)[MLCSoftmaxLayer layerWithOperation:MLCSoftmaxOperationLogSoftmax].dimension]);
        text(@"softmax dimension 3", [NSString stringWithFormat:@"%lu", (unsigned long)[MLCSoftmaxLayer layerWithOperation:MLCSoftmaxOperationSoftmax dimension:3].dimension]);
        text(@"split by count", [NSString stringWithFormat:@"dimension=%lu count=%lu lengths=%@", (unsigned long)[MLCSplitLayer layerWithSplitCount:3 dimension:2].dimension,
                                        (unsigned long)[MLCSplitLayer layerWithSplitCount:3 dimension:2].splitCount, nums([MLCSplitLayer layerWithSplitCount:3 dimension:2].splitSectionLengths)]);
        text(@"split by lengths", [NSString stringWithFormat:@"dimension=%lu count=%lu lengths=%@", (unsigned long)[MLCSplitLayer layerWithSplitSectionLengths:@[ @1, @2, @3 ] dimension:0].dimension,
                                         (unsigned long)[MLCSplitLayer layerWithSplitSectionLengths:@[ @1, @2, @3 ] dimension:0].splitCount,
                                         nums([MLCSplitLayer layerWithSplitSectionLengths:@[ @1, @2, @3 ] dimension:0].splitSectionLengths)]);
        shape(@"transpose dimensions", [MLCTransposeLayer layerWithDimensions:@[ @0, @2, @1, @3 ]].dimensions);
        text(@"upsample", [NSString stringWithFormat:@"shape=%@ mode=%d aligns=%d", nums([MLCUpsampleLayer layerWithShape:@[ @2, @3 ] sampleMode:MLCSampleModeLinear alignsCorners:YES].shape),
                              (int)[MLCUpsampleLayer layerWithShape:@[ @2, @3 ] sampleMode:MLCSampleModeLinear alignsCorners:YES].sampleMode,
                              (int)[MLCUpsampleLayer layerWithShape:@[ @2, @3 ] sampleMode:MLCSampleModeLinear alignsCorners:YES].alignsCorners]);
        shape(@"upsample of one", [MLCUpsampleLayer layerWithShape:@[ @4 ]].shape);
        MLCPaddingLayer *pad = [MLCPaddingLayer layerWithZeroPadding:@[ @1, @2, @3, @4 ]];
        text(@"padding zero", [NSString stringWithFormat:@"type=%d top=%lu bottom=%lu left=%lu right=%lu value=%g", (int)pad.paddingType,
                                   (unsigned long)pad.paddingTop, (unsigned long)pad.paddingBottom, (unsigned long)pad.paddingLeft,
                                   (unsigned long)pad.paddingRight, pad.constantValue]);
        MLCPaddingLayer *padPair = [MLCPaddingLayer layerWithZeroPadding:@[ @2, @2 ]];
        text(@"padding of two", [NSString stringWithFormat:@"top=%lu bottom=%lu left=%lu right=%lu", (unsigned long)padPair.paddingTop,
                                 (unsigned long)padPair.paddingBottom, (unsigned long)padPair.paddingLeft, (unsigned long)padPair.paddingRight]);
        MLCPaddingLayer *padOne = [MLCPaddingLayer layerWithZeroPadding:@[ @5 ]];
        text(@"padding of one", [NSString stringWithFormat:@"top=%lu bottom=%lu left=%lu right=%lu", (unsigned long)padOne.paddingTop,
                                    (unsigned long)padOne.paddingBottom, (unsigned long)padOne.paddingLeft, (unsigned long)padOne.paddingRight]);
        MLCPaddingLayer *padConstant = [MLCPaddingLayer layerWithConstantPadding:@[ @1, @2, @3, @4 ] constantValue:2.5];
        text(@"padding constant", [NSString stringWithFormat:@"type=%d value=%g", (int)padConstant.paddingType, padConstant.constantValue]);
        MLCPaddingLayer *padSymmetric = [MLCPaddingLayer layerWithSymmetricPadding:@[ @1, @1, @1, @1 ]];
        text(@"padding symmetric type", [NSString stringWithFormat:@"%d", (int)padSymmetric.paddingType]);
        MLCPaddingLayer *padReflect = [MLCPaddingLayer layerWithReflectionPadding:@[ @1, @1, @1, @1 ]];
        text(@"padding reflection type", [NSString stringWithFormat:@"%d", (int)padReflect.paddingType]);
        MLCLossLayer *withWeights = [MLCLossLayer layerWithDescriptor:loss weights:biases];
        row(@"loss weights kept", withWeights.weights ? @"kept" : @"no");
        text(@"loss descriptor", [NSString stringWithFormat:@"type=%d reduction=%d weight=%g", (int)withWeights.descriptor.lossType,
                                  (int)withWeights.descriptor.reductionType, withWeights.descriptor.weight]);
        text(@"loss mse factory", [NSString stringWithFormat:@"type=%d", (int)[MLCLossLayer meanSquaredErrorLossWithReductionType:MLCReductionTypeMean weight:2].descriptor.lossType]);
        text(@"loss softmax factory", [NSString stringWithFormat:@"type=%d classes=%lu", (int)[MLCLossLayer softmaxCrossEntropyLossWithReductionType:MLCReductionTypeSum labelSmoothing:0 classCount:5 weight:1].descriptor.lossType,
                                       (unsigned long)[MLCLossLayer softmaxCrossEntropyLossWithReductionType:MLCReductionTypeSum labelSmoothing:0 classCount:5 weight:1].descriptor.classCount]);
        text(@"loss huber factory", [NSString stringWithFormat:@"delta=%g", [MLCLossLayer huberLossWithReductionType:MLCReductionTypeMean delta:2 weight:1].descriptor.delta]);
        text(@"loss log factory", [NSString stringWithFormat:@"epsilon=%g", [MLCLossLayer logLossWithReductionType:MLCReductionTypeMean epsilon:1e-6 weight:1].descriptor.epsilon]);
        text(@"loss mae factory", [NSString stringWithFormat:@"type=%d", (int)[MLCLossLayer meanAbsoluteErrorLossWithReductionType:MLCReductionTypeMean weight:1].descriptor.lossType]);
        text(@"loss hinge factory", [NSString stringWithFormat:@"type=%d", (int)[MLCLossLayer hingeLossWithReductionType:MLCReductionTypeMean weight:1].descriptor.lossType]);
        text(@"loss cosine factory", [NSString stringWithFormat:@"type=%d", (int)[MLCLossLayer cosineDistanceLossWithReductionType:MLCReductionTypeMean weight:1].descriptor.lossType]);
        text(@"loss sigmoid factory", [NSString stringWithFormat:@"type=%d", (int)[MLCLossLayer sigmoidCrossEntropyLossWithReductionType:MLCReductionTypeMean labelSmoothing:0 weight:1].descriptor.lossType]);
        text(@"loss categorical factory", [NSString stringWithFormat:@"type=%d", (int)[MLCLossLayer categoricalCrossEntropyLossWithReductionType:MLCReductionTypeMean labelSmoothing:0 classCount:3 weight:1].descriptor.lossType]);
        // The YOLO loss layer is not asked here: the current macOS header marks it gone past macOS 14
        // (MLCOMPUTE_AVAILABLE_STARTING_BUT_DEPRECATED_MACOS14), and a Mac Catalyst build cannot even
        // name it, so there is no host answer to compare against. The port carries it - SDK 16.4 declares
        // it for iOS 14, where it is not deprecated, and the corpus of SDK 26.2 names it - and
        // facts/MLCompute/Layers.md says the host can no longer be its oracle.
        printf("== what a factory keeps and what it refuses\n");
        MLCConvolutionLayer *mismatched = [MLCConvolutionLayer layerWithWeights:wrong biases:biases descriptor:convolution];
        row(@"convolution refused, descriptor", mismatched.descriptor ? @"kept" : @"no");
        row(@"convolution refused, weights", mismatched.weights ? @"kept" : @"no");
        row(@"convolution refused, biases", mismatched.biases ? @"kept" : @"no");
        row(@"convolution refused, weightsParameter", mismatched.weightsParameter ? @"kept" : @"no");
        MLCConvolutionLayer *unbiased = [MLCConvolutionLayer layerWithWeights:weights biases:nil descriptor:convolution];
        row(@"convolution without biases, weights", unbiased.weights ? @"kept" : @"no");
        row(@"convolution without biases, biases", unbiased.biases ? @"kept" : @"no");
        row(@"convolution without biases, biasesParameter", unbiased.biasesParameter ? @"kept" : @"no");
        MLCConvolutionLayer *good = [MLCConvolutionLayer layerWithWeights:weights biases:biases descriptor:convolution];
        row(@"convolution, descriptor", good.descriptor ? @"kept" : @"no");
        row(@"convolution, weights", good.weights ? @"kept" : @"no");
        row(@"convolution, biases", good.biases ? @"kept" : @"no");
        row(@"convolution, weightsParameter", good.weightsParameter ? @"kept" : @"no");
        row(@"convolution, biasesParameter", good.biasesParameter ? @"kept" : @"no");
        MLCFullyConnectedLayer *connected = [MLCFullyConnectedLayer layerWithWeights:weights biases:biases descriptor:convolution];
        row(@"fully connected refused, descriptor", connected.descriptor ? @"kept" : @"no");
        row(@"fully connected refused, weights", connected.weights ? @"kept" : @"no");
        row(@"fully connected refused, weightsParameter", connected.weightsParameter ? @"kept" : @"no");
        MLCEmbeddingDescriptor *embeddingDescriptor = [MLCEmbeddingDescriptor descriptorWithEmbeddingCount:@(100) embeddingDimension:@(8)];
        MLCTensor *embeddingWeights = [MLCTensor tensorWithDescriptor:shape_(@[ @1, @100, @1, @8 ]) fillWithData:@(1)];
        MLCEmbeddingLayer *embedding = [MLCEmbeddingLayer layerWithDescriptor:embeddingDescriptor weights:embeddingWeights];
        row(@"embedding, descriptor", embedding.descriptor ? @"kept" : @"no");
        row(@"embedding, weights", embedding.weights ? @"kept" : @"no");
        row(@"embedding, weightsParameter", embedding.weightsParameter ? @"kept" : @"no");
        MLCEmbeddingLayer *wrongEmbedding = [MLCEmbeddingLayer layerWithDescriptor:embeddingDescriptor
                                                                            weights:[MLCTensor tensorWithDescriptor:shape_(@[ @1, @50, @1, @8 ]) fillWithData:@(1)]];
        row(@"embedding refused, descriptor", wrongEmbedding.descriptor ? @"kept" : @"no");
        row(@"embedding refused, weights", wrongEmbedding.weights ? @"kept" : @"no");
        row(@"embedding refused, weightsParameter", wrongEmbedding.weightsParameter ? @"kept" : @"no");

        MLCTensor *one = perChannel(4, 0), *two = perChannel(4, 1), *three = perChannel(4, 2), *four = perChannel(4, 3);
        MLCBatchNormalizationLayer *batch = [MLCBatchNormalizationLayer layerWithFeatureChannelCount:4 mean:one variance:two beta:three gamma:four varianceEpsilon:1e-5];
        text(@"batch norm", [NSString stringWithFormat:@"channels=%lu mean=%@ variance=%@ beta=%@ gamma=%@ betaP=%@ gammaP=%@ epsilon=%g momentum=%g",
                                (unsigned long)batch.featureChannelCount, batch.mean == one ? @"kept" : @"no", batch.variance == two ? @"kept" : @"no",
                                batch.beta == three ? @"kept" : @"no", batch.gamma == four ? @"kept" : @"no", batch.betaParameter ? @"kept" : @"no",
                                batch.gammaParameter ? @"kept" : @"no", batch.varianceEpsilon, batch.momentum]);
        MLCBatchNormalizationLayer *bare = [MLCBatchNormalizationLayer layerWithFeatureChannelCount:4 mean:one variance:two beta:nil gamma:nil varianceEpsilon:2e-5 momentum:0.8];
        text(@"batch norm without beta", [NSString stringWithFormat:@"channels=%lu beta=%@ gamma=%@ epsilon=%g momentum=%g", (unsigned long)bare.featureChannelCount,
                                          bare.beta ? @"kept" : @"no", bare.gamma ? @"kept" : @"no", bare.varianceEpsilon, bare.momentum]);
        MLCInstanceNormalizationLayer *instance = [MLCInstanceNormalizationLayer layerWithFeatureChannelCount:4 mean:one variance:two beta:three gamma:four varianceEpsilon:1e-5 momentum:0.9];
        text(@"instance norm", [NSString stringWithFormat:@"channels=%lu mean=%@ variance=%@ beta=%@ gamma=%@ epsilon=%g momentum=%g",
                                (unsigned long)instance.featureChannelCount, instance.mean == one ? @"kept" : @"no", instance.variance == two ? @"kept" : @"no",
                                instance.beta == three ? @"kept" : @"no", instance.gamma == four ? @"kept" : @"no", instance.varianceEpsilon, instance.momentum]);
        MLCInstanceNormalizationLayer *running = [MLCInstanceNormalizationLayer layerWithFeatureChannelCount:4 beta:three gamma:four varianceEpsilon:1e-5];
        text(@"instance norm without running", [NSString stringWithFormat:@"channels=%lu mean=%@ variance=%@ beta=%@ gamma=%@ momentum=%g",
                                               (unsigned long)running.featureChannelCount, running.mean ? @"kept" : @"no", running.variance ? @"kept" : @"no",
                                               running.beta == three ? @"kept" : @"no", running.gamma == four ? @"kept" : @"no", running.momentum]);
        MLCGroupNormalizationLayer *group = [MLCGroupNormalizationLayer layerWithFeatureChannelCount:4 groupCount:2 beta:three gamma:four varianceEpsilon:1e-5];
        text(@"group norm", [NSString stringWithFormat:@"channels=%lu groups=%lu beta=%@ gamma=%@ betaP=%@ gammaP=%@ epsilon=%g",
                               (unsigned long)group.featureChannelCount, (unsigned long)group.groupCount, group.beta == three ? @"kept" : @"no",
                               group.gamma == four ? @"kept" : @"no", group.betaParameter ? @"kept" : @"no", group.gammaParameter ? @"kept" : @"no",
                               group.varianceEpsilon]);
        MLCLayerNormalizationLayer *normalized = [MLCLayerNormalizationLayer layerWithNormalizedShape:@[ @4 ] beta:vector(4, 0) gamma:vector(4, 1) varianceEpsilon:1e-5];
        text(@"layer norm", [NSString stringWithFormat:@"shape=%@ beta=%@ gamma=%@ betaP=%@ gammaP=%@ epsilon=%g", nums(normalized.normalizedShape),
                                normalized.beta ? @"kept" : @"no", normalized.gamma ? @"kept" : @"no", normalized.betaParameter ? @"kept" : @"no",
                                normalized.gammaParameter ? @"kept" : @"no", normalized.varianceEpsilon]);
        MLCLayerNormalizationLayer *wrongNormalized = [MLCLayerNormalizationLayer layerWithNormalizedShape:@[ @4 ] beta:three gamma:four varianceEpsilon:1e-5];
        row(@"layer norm refused, shape", wrongNormalized.normalizedShape);
        row(@"layer norm refused, beta", wrongNormalized.beta ? @"kept" : @"no");

        // The multihead attention factory, which had no case. The port answers nil for every arrangement
        // tried, as the framework does; the host cannot be asked, because MLCompute 26's macOS header
        // removes the class from the interface and a Catalyst build cannot name it, so this one case is
        // asked of the port alone and says what the framework's own answer was measured to be.
        MLCMultiheadAttentionDescriptor *attentionDescriptor = [MLCMultiheadAttentionDescriptor descriptorWithModelDimension:4 headCount:2];
        MLCTensor *attentionWeights = [MLCTensor tensorWithDescriptor:shape_(@[ @4, @4 ]) fillWithData:@(1)];
        MLCTensor *attentionBiases = [MLCTensor tensorWithDescriptor:shape_(@[ @4 ]) fillWithData:@(1)];
        MLCMultiheadAttentionLayer *attention = [MLCMultiheadAttentionLayer layerWithDescriptor:attentionDescriptor
                                                                                   weights:@[ attentionWeights ]
                                                                                    biases:@[ attentionBiases ]
                                                                        attentionBiases:@[ attentionBiases ]];
        row(@"attention factory", attention);
        MLCMultiheadAttentionLayer *attentionEmpty = [MLCMultiheadAttentionLayer layerWithDescriptor:attentionDescriptor
                                                                                        weights:@[] biases:@[] attentionBiases:@[]];
        row(@"attention factory with no weights", attentionEmpty);

        MLCTensor *gateIn = [MLCTensor tensorWithDescriptor:shape_(@[ @5, @4 ]) fillWithData:@(1)];
        MLCTensor *gateHidden = [MLCTensor tensorWithDescriptor:shape_(@[ @5, @5 ]) fillWithData:@(1)];
        MLCTensor *gateBias = [MLCTensor tensorWithDescriptor:shape_(@[ @5 ]) fillWithData:@(1)];
        MLCLSTMLayer *lstm = [MLCLSTMLayer layerWithDescriptor:[MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:1 usesBiases:YES isBidirectional:NO dropout:0]
                                                  inputWeights:@[ gateIn, gateIn, gateIn, gateIn ]
                                                 hiddenWeights:@[ gateHidden, gateHidden, gateHidden, gateHidden ]
                                                        biases:@[ gateBias, gateBias, gateBias, gateBias ]];
        text(@"lstm", [NSString stringWithFormat:@"input=%lu hidden=%lu biases=%lu peephole=%@ gates=%lu gatesP=%lu hiddenP=%lu biasesP=%lu outputActivation=%d",
                       (unsigned long)lstm.inputWeights.count, (unsigned long)lstm.hiddenWeights.count, (unsigned long)lstm.biases.count,
                       lstm.peepholeWeights ? @"kept" : @"no", (unsigned long)lstm.gateActivations.count,
                       (unsigned long)lstm.inputWeightsParameters.count, (unsigned long)lstm.hiddenWeightsParameters.count,
                       (unsigned long)lstm.biasesParameters.count, (int)lstm.outputResultActivation.activationType]);
        // The two forms the host refuses are counted rather than described, so that the line does not
        // carry a pointer that differs from run to run.
        MLCLSTMLayer *peepholed = [MLCLSTMLayer layerWithDescriptor:[MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:1 usesBiases:YES isBidirectional:NO dropout:0]
                                   inputWeights:@[ gateIn, gateIn, gateIn, gateIn ]
                                  hiddenWeights:@[ gateHidden, gateHidden, gateHidden, gateHidden ]
                                peepholeWeights:@[ gateBias, gateBias, gateBias, gateBias ]
                                         biases:@[ gateBias, gateBias, gateBias, gateBias ]];
        text(@"lstm with peepholes", peepholed ? [NSString stringWithFormat:@"peepholes=%lu gates=%lu", (unsigned long)peepholed.peepholeWeights.count,
                                                 (unsigned long)peepholed.gateActivations.count]
                                               : @"(nil)");
        MLCLSTMLayer *gated = [MLCLSTMLayer layerWithDescriptor:[MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:1 usesBiases:YES isBidirectional:NO dropout:0]
                               inputWeights:@[ gateIn, gateIn, gateIn, gateIn ]
                              hiddenWeights:@[ gateHidden, gateHidden, gateHidden, gateHidden ]
                            peepholeWeights:nil
                                     biases:@[ gateBias, gateBias, gateBias, gateBias ]
                             gateActivations:@[ [MLCActivationDescriptor descriptorWithType:MLCActivationTypeTanh] ]
                        outputResultActivation:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeSigmoid]];
        text(@"lstm with gates", gated ? [NSString stringWithFormat:@"gates=%lu output=%d", (unsigned long)gated.gateActivations.count,
                                         (int)gated.outputResultActivation.activationType]
                                       : @"(nil)");
    }
}
