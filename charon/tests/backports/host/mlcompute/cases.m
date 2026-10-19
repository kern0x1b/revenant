// Every case of the value surface of MLCompute this port carries, each one printed as a key and what the
// code answers. Written once and run twice: beside the host's own MLCompute, which is where the answers
// were measured from, and beside the port's, which has to answer the same. A line is a case; a case that
// answers nil says so in words rather than in an empty value, and a value that cannot be printed as text
// is printed as the numbers it holds.

#import "mlcompute-16.h"

// One case, one line: an array's or a tensor's own -description runs over several lines, and a diff of two
// runs is only readable when a case cannot straddle one.
static void key(NSString *name, NSString *value)
{
    NSMutableString *flat = [NSMutableString string];
    for (NSUInteger index = 0; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        [flat appendFormat:@"%C", (character == '\n' || character == '\t' || character == ' ') ? ' ' : character];
    }
    printf("%s\t%s\n", name.UTF8String, flat.UTF8String);
}

static void record(NSString *name, id value)
{
    key(name, value ? [value description] : @"(nil)");
}

static void number(NSString *name, double value)
{
    key(name, [NSString stringWithFormat:@"%g", value]);
}

static void counted(NSString *name, NSUInteger value)
{
    key(name, [NSString stringWithFormat:@"%lu", (unsigned long)value]);
}

static void flag(NSString *name, BOOL value)
{
    key(name, value ? @"YES" : @"NO");
}

static void list(NSString *name, NSArray<NSNumber *> *values)
{
    if (!values) {
        key(name, @"(nil)");
        return;
    }
    NSMutableString *text = [NSMutableString string];
    for (NSNumber *value in values) {
        if (text.length) {
            [text appendString:@","];
        }
        [text appendString:value.stringValue];
    }
    key(name, text);
}

static void showTensor(NSString *name, MLCTensor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    MLCTensorDescriptor *descriptor = value.descriptor;
    key(name, [NSString stringWithFormat:@"id=%lu shape=%@ stride=%@ bytes=%lu type=%d data=%@ label=%@ device=%d optimizerData=%lu",
                      (unsigned long)value.tensorID, descriptor.shape, descriptor.stride, (unsigned long)descriptor.tensorAllocationSizeInBytes,
                      (int)descriptor.dataType, value.data ? [NSString stringWithFormat:@"%lu", (unsigned long)value.data.length] : @"(nil)", value.label,
                      value.device ? 1 : 0, (unsigned long)value.optimizerData.count]);
}

static void showDescriptor(NSString *name, MLCTensorDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"dims=%lu shape=%@ stride=%@ bytes=%lu type=%d lengths=%@ sorted=%d perStep=%@", (unsigned long)value.dimensionCount,
                      value.shape, value.stride, (unsigned long)value.tensorAllocationSizeInBytes, (int)value.dataType, value.sequenceLengths,
                      (int)value.sortedSequences, value.batchSizePerSequenceStep]);
}

static void showActivation(NSString *name, MLCActivationDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"type=%d a=%g b=%g c=%g", (int)value.activationType, value.a, value.b, value.c]);
}

static void showConvolution(NSString *name, MLCConvolutionDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"type=%d kw=%lu kh=%lu in=%lu out=%lu group=%lu stride=%lux%lu dilation=%lux%lu pad=%d pad=%lux%lu transpose=%d depthwise=%d",
                      (int)value.convolutionType, (unsigned long)value.kernelWidth, (unsigned long)value.kernelHeight, (unsigned long)value.inputFeatureChannelCount,
                      (unsigned long)value.outputFeatureChannelCount, (unsigned long)value.groupCount, (unsigned long)value.strideInX, (unsigned long)value.strideInY,
                      (unsigned long)value.dilationRateInX, (unsigned long)value.dilationRateInY, (int)value.paddingPolicy, (unsigned long)value.paddingSizeInX,
                      (unsigned long)value.paddingSizeInY, (int)value.isConvolutionTranspose, (int)value.usesDepthwiseConvolution]);
}

static void showPooling(NSString *name, MLCPoolingDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"type=%d kw=%lu kh=%lu stride=%lux%lu dilation=%lux%lu pad=%d pad=%lux%lu counts=%d", (int)value.poolingType,
                      (unsigned long)value.kernelWidth, (unsigned long)value.kernelHeight, (unsigned long)value.strideInX, (unsigned long)value.strideInY,
                      (unsigned long)value.dilationRateInX, (unsigned long)value.dilationRateInY, (int)value.paddingPolicy, (unsigned long)value.paddingSizeInX,
                      (unsigned long)value.paddingSizeInY, (int)value.countIncludesPadding]);
}

static void showLoss(NSString *name, MLCLossDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"type=%d reduction=%d weight=%g labelSmoothing=%g classes=%lu epsilon=%g delta=%g", (int)value.lossType, (int)value.reductionType,
                      value.weight, value.labelSmoothing, (unsigned long)value.classCount, value.epsilon, value.delta]);
}

static void showOptimizer(NSString *name, MLCOptimizerDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"lr=%g rescale=%g clip=%d clipType=%d clipMax=%g clipMin=%g maxNorm=%g globalNorm=%g regType=%d regScale=%g", value.learningRate,
                      value.gradientRescale, (int)value.appliesGradientClipping, (int)value.gradientClippingType, value.gradientClipMax, value.gradientClipMin,
                      value.maximumClippingNorm, value.customGlobalNorm, (int)value.regularizationType, value.regularizationScale]);
}

static void showLstm(NSString *name, MLCLSTMDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"in=%lu hidden=%lu layers=%lu bias=%d batchFirst=%d bidir=%d returns=%d dropout=%g resultMode=%d", (unsigned long)value.inputSize,
                      (unsigned long)value.hiddenSize, (unsigned long)value.layerCount, (int)value.usesBiases, (int)value.batchFirst, (int)value.isBidirectional,
                      (int)value.returnsSequences, value.dropout, (int)value.resultMode]);
}

static void showAttention(NSString *name, MLCMultiheadAttentionDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"model=%lu key=%lu value=%lu heads=%lu dropout=%g bias=%d attnBias=%d zero=%d", (unsigned long)value.modelDimension,
                      (unsigned long)value.keyDimension, (unsigned long)value.valueDimension, (unsigned long)value.headCount, value.dropout, (int)value.hasBiases,
                      (int)value.hasAttentionBiases, (int)value.addsZeroAttention]);
}

static void showEmbedding(NSString *name, MLCEmbeddingDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"count=%@ dimension=%@ padding=%@ maximumNorm=%@ pNorm=%@ frequency=%d", value.embeddingCount, value.embeddingDimension,
                      value.paddingIndex, value.maximumNorm, value.pNorm, (int)value.scalesGradientByFrequency]);
}

static void showYolo(NSString *name, MLCYOLOLossDescriptor *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"count=%lu bytes=%lu rescore=%d position=%g size=%g noObject=%g object=%g class=%g minIOU=%g maxIOU=%g", (unsigned long)value.anchorBoxCount,
                      (unsigned long)value.anchorBoxes.length, (int)value.shouldRescore, value.scaleSpatialPositionLoss, value.scaleSpatialSizeLoss,
                      value.scaleNoObjectConfidenceLoss, value.scaleObjectConfidenceLoss, value.scaleClassLoss, value.minimumIOUForObjectPresence,
                      value.maximumIOUForObjectAbsence]);
}

static void showLayer(NSString *name, MLCLayer *value)
{
    if (!value) {
        key(name, @"(nil)");
        return;
    }
    key(name, [NSString stringWithFormat:@"id=%lu label=%@ debug=%d deviceType=%d", (unsigned long)value.layerID, value.label, (int)value.isDebuggingEnabled,
                      (int)value.deviceType]);
}

static void attempted(NSString *name, void (^work)(void))
{
    @try {
        work();
    } @catch (NSException *raised) {
        key(name, [NSString stringWithFormat:@"raised %@: %@", raised.name, raised.reason]);
    }
}

// What one random initializer fills a tensor with: the range it covers and where its mean falls, not the
// values. The framework's own stream is not published, so the stream of the port's is its own; the range
// and the mean are what a program can rely on and what is compared (facts/MLCompute/Tensors.md).
static void initializer(NSString *name, MLCRandomInitializerType type)
{
    MLCTensor *tensor = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@64, @64] dataType:MLCDataTypeFloat32]
                                   randomInitializerType:type];
    if (!tensor || !tensor.data) {
        key(name, @"(nil)");
        return;
    }
    const float *values = tensor.data.bytes;
    float low = values[0], high = values[0];
    double sum = 0;
    for (NSUInteger index = 0; index < 4096; index++) {
        float value = values[index];
        if (value < low) {
            low = value;
        }
        if (value > high) {
            high = value;
        }
        sum += value;
    }
    // Two facts about the initializer, both checked against a four-thousand-sample window, and the second
    // one is the one that distinguishes the bounds: the sample stays inside the bound the initializer
    // documents, and it *reaches* that bound rather than sitting well inside it. A bound of one where
    // sqrt(3) is the truth would fail the second, because a Glorot sample fills 0 to 1.732 and a sample
    // capped at one cannot have a high above 1.0 - and the first check alone would have passed it, which is
    // what the earlier version of this case did.
    double bound = type == MLCRandomInitializerTypeUniform ? 1.0 : 1.7320508075688772;
    double center = type == MLCRandomInitializerTypeUniform ? 0.5 : 0.0;
    BOOL withinBound = low >= -bound - 0.05 && high <= bound + 0.05;
    BOOL reachesBound = high > bound * 0.9 || low < -bound * 0.9;
    BOOL meanNear = fabs(sum / 4096.0 - center) < 0.1;
    key(name, [NSString stringWithFormat:@"withinBound=%d reachesBound=%d meanNear=%d", (int)withinBound, (int)reachesBound, (int)meanNear]);
}

void charon_mlcompute_cases(void)
{
    __block int deallocatorCalled = 0;
    @autoreleasepool {
        printf("== enumerations\n");
        counted(@"MLCDataTypeCount", MLCDataTypeCount);
        counted(@"MLCArithmeticOperationCount", MLCArithmeticOperationCount);
        counted(@"MLCActivationTypeCount", MLCActivationTypeCount);
        counted(@"MLCReductionTypeCount", MLCReductionTypeCount);
        counted(@"MLCLossTypeCount", MLCLossTypeCount);
        counted(@"MLCPoolingTypeCount", MLCPoolingTypeCount);
        counted(@"MLCRandomInitializerTypeCount", MLCRandomInitializerTypeCount);
        counted(@"MLCDeviceTypeCount", MLCDeviceTypeCount);
        counted(@"MLCComparisonOperationCount", MLCComparisonOperationCount);
        key(@"MLCDataType values", [NSString stringWithFormat:@"%d %d %d %d %d %d %d %d %d", (int)MLCDataTypeInvalid, (int)MLCDataTypeFloat32, (int)MLCDataTypeFloat16,
                                        (int)MLCDataTypeBoolean, (int)MLCDataTypeInt64, (int)MLCDataTypeInt32, (int)MLCDataTypeInt8, (int)MLCDataTypeUInt8,
                                        (int)MLCDataTypeCount]);
        key(@"MLCActivationType values", [NSString stringWithFormat:@"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
                                                (int)MLCActivationTypeNone, (int)MLCActivationTypeReLU, (int)MLCActivationTypeLinear, (int)MLCActivationTypeSigmoid,
                                                (int)MLCActivationTypeHardSigmoid, (int)MLCActivationTypeTanh, (int)MLCActivationTypeAbsolute, (int)MLCActivationTypeSoftPlus,
                                                (int)MLCActivationTypeSoftSign, (int)MLCActivationTypeELU, (int)MLCActivationTypeReLUN, (int)MLCActivationTypeLogSigmoid,
                                                (int)MLCActivationTypeSELU, (int)MLCActivationTypeCELU, (int)MLCActivationTypeHardShrink, (int)MLCActivationTypeSoftShrink,
                                                (int)MLCActivationTypeTanhShrink, (int)MLCActivationTypeThreshold, (int)MLCActivationTypeGELU, (int)MLCActivationTypeHardSwish,
                                                (int)MLCActivationTypeClamp]);
        key(@"MLCReductionType values", [NSString stringWithFormat:@"%d %d %d %d %d %d %d %d %d %d", (int)MLCReductionTypeNone, (int)MLCReductionTypeSum, (int)MLCReductionTypeMean,
                                               (int)MLCReductionTypeMax, (int)MLCReductionTypeMin, (int)MLCReductionTypeArgMax, (int)MLCReductionTypeArgMin,
                                               (int)MLCReductionTypeL1Norm, (int)MLCReductionTypeAny, (int)MLCReductionTypeAll]);
        key(@"MLCDeviceType values", [NSString stringWithFormat:@"%d %d %d %d", (int)MLCDeviceTypeCPU, (int)MLCDeviceTypeGPU, (int)MLCDeviceTypeAny, (int)MLCDeviceTypeANE]);

        printf("== the functions that name a case\n");
        for (int type = 0; type < MLCActivationTypeCount; type++) {
            record([NSString stringWithFormat:@"MLCActivationTypeDebugDescription(%d)", type], MLCActivationTypeDebugDescription(type));
        }
        for (int type = 0; type < MLCArithmeticOperationCount; type++) {
            record([NSString stringWithFormat:@"MLCArithmeticOperationDebugDescription(%d)", type], MLCArithmeticOperationDebugDescription(type));
        }
        for (int type = 0; type < MLCReductionTypeCount; type++) {
            record([NSString stringWithFormat:@"MLCReductionTypeDebugDescription(%d)", type], MLCReductionTypeDebugDescription(type));
        }
        for (int type = 0; type < MLCLossTypeCount; type++) {
            record([NSString stringWithFormat:@"MLCLossTypeDebugDescription(%d)", type], MLCLossTypeDebugDescription(type));
        }
        for (int type = 0; type < 4; type++) {
            record([NSString stringWithFormat:@"MLCPaddingTypeDebugDescription(%d)", type], MLCPaddingTypeDebugDescription(type));
        }
        for (int type = 0; type < 3; type++) {
            record([NSString stringWithFormat:@"MLCConvolutionTypeDebugDescription(%d)", type], MLCConvolutionTypeDebugDescription(type));
        }
        for (int type = 1; type < MLCPoolingTypeCount; type++) {
            record([NSString stringWithFormat:@"MLCPoolingTypeDebugDescription(%d)", type], MLCPoolingTypeDebugDescription(type));
        }
        for (int type = 0; type < 2; type++) {
            record([NSString stringWithFormat:@"MLCSoftmaxOperationDebugDescription(%d)", type], MLCSoftmaxOperationDebugDescription(type));
        }
        for (int type = 0; type < 2; type++) {
            record([NSString stringWithFormat:@"MLCSampleModeDebugDescription(%d)", type], MLCSampleModeDebugDescription(type));
        }
        for (int type = 0; type < 2; type++) {
            record([NSString stringWithFormat:@"MLCLSTMResultModeDebugDescription(%d)", type], MLCLSTMResultModeDebugDescription(type));
        }
        for (int type = 0; type < 3; type++) {
            record([NSString stringWithFormat:@"MLCPaddingPolicyDebugDescription(%d)", type], MLCPaddingPolicyDebugDescription(type));
        }
        for (int type = 0; type < MLCComparisonOperationCount; type++) {
            record([NSString stringWithFormat:@"MLCComparisonOperationDebugDescription(%d)", type], MLCComparisonOperationDebugDescription(type));
        }
        for (int type = 0; type < 3; type++) {
            record([NSString stringWithFormat:@"MLCGradientClippingTypeDebugDescription(%d)", type], MLCGradientClippingTypeDebugDescription(type));
        }

        // A value outside each enumeration. The framework names the first case for a value that
        // is not one of its cases, and the port was answering nil: thirteen default arms that no
        // case reached. Both sides now answer the same thing for a value neither is a case of.
        for (int value = -1; value <= 999; value += 1000) {
            record([NSString stringWithFormat:@"MLCActivationTypeDebugDescription(%d)", value], MLCActivationTypeDebugDescription((MLCActivationType)value));
            record([NSString stringWithFormat:@"MLCArithmeticOperationDebugDescription(%d)", value], MLCArithmeticOperationDebugDescription((MLCArithmeticOperation)value));
            record([NSString stringWithFormat:@"MLCReductionTypeDebugDescription(%d)", value], MLCReductionTypeDebugDescription((MLCReductionType)value));
            record([NSString stringWithFormat:@"MLCLossTypeDebugDescription(%d)", value], MLCLossTypeDebugDescription((MLCLossType)value));
            record([NSString stringWithFormat:@"MLCPaddingTypeDebugDescription(%d)", value], MLCPaddingTypeDebugDescription((MLCPaddingType)value));
            record([NSString stringWithFormat:@"MLCConvolutionTypeDebugDescription(%d)", value], MLCConvolutionTypeDebugDescription((MLCConvolutionType)value));
            record([NSString stringWithFormat:@"MLCPoolingTypeDebugDescription(%d)", value], MLCPoolingTypeDebugDescription((MLCPoolingType)value));
            record([NSString stringWithFormat:@"MLCSoftmaxOperationDebugDescription(%d)", value], MLCSoftmaxOperationDebugDescription((MLCSoftmaxOperation)value));
            record([NSString stringWithFormat:@"MLCSampleModeDebugDescription(%d)", value], MLCSampleModeDebugDescription((MLCSampleMode)value));
            record([NSString stringWithFormat:@"MLCLSTMResultModeDebugDescription(%d)", value], MLCLSTMResultModeDebugDescription((MLCLSTMResultMode)value));
            record([NSString stringWithFormat:@"MLCPaddingPolicyDebugDescription(%d)", value], MLCPaddingPolicyDebugDescription((MLCPaddingPolicy)value));
            record([NSString stringWithFormat:@"MLCComparisonOperationDebugDescription(%d)", value], MLCComparisonOperationDebugDescription((MLCComparisonOperation)value));
            record([NSString stringWithFormat:@"MLCGradientClippingTypeDebugDescription(%d)", value], MLCGradientClippingTypeDebugDescription((MLCGradientClippingType)value));
        }

        printf("== MLCPlatform\n");
        record(@"getRNGseed before any", [MLCPlatform getRNGseed]);
        [MLCPlatform setRNGSeedTo:@(42)];
        record(@"getRNGseed after 42", [MLCPlatform getRNGseed]);
        [MLCPlatform setRNGSeedTo:@(-7)];
        record(@"getRNGseed after -7", [MLCPlatform getRNGseed]);
        [MLCPlatform setRNGSeedTo:@(0)];
        record(@"getRNGseed after 0", [MLCPlatform getRNGseed]);

        printf("== MLCDevice\n");
        MLCDevice *cpu = [MLCDevice cpuDevice];
        key(@"cpuDevice", cpu ? [NSString stringWithFormat:@"type=%d actual=%d gpus=%lu", (int)cpu.type, (int)cpu.actualDeviceType, (unsigned long)cpu.gpuDevices.count] : @"(nil)");
        MLCDevice *gpu = [MLCDevice gpuDevice];
        key(@"gpuDevice", gpu ? [NSString stringWithFormat:@"type=%d actual=%d gpus=%lu", (int)gpu.type, (int)gpu.actualDeviceType, (unsigned long)gpu.gpuDevices.count] : @"(nil)");
        MLCDevice *ane = [MLCDevice aneDevice];
        key(@"aneDevice", ane ? [NSString stringWithFormat:@"type=%d actual=%d", (int)ane.type, (int)ane.actualDeviceType] : @"(nil)");
        MLCDevice *any = [MLCDevice deviceWithType:MLCDeviceTypeAny];
        key(@"deviceWithType Any", any ? [NSString stringWithFormat:@"type=%d actual=%d", (int)any.type, (int)any.actualDeviceType] : @"(nil)");
        MLCDevice *multi = [MLCDevice deviceWithType:MLCDeviceTypeAny selectsMultipleComputeDevices:YES];
        key(@"deviceWithType Any multiple", multi ? [NSString stringWithFormat:@"type=%d actual=%d", (int)multi.type, (int)multi.actualDeviceType] : @"(nil)");
        MLCDevice *explicitGPU = [MLCDevice deviceWithType:MLCDeviceTypeGPU];
        key(@"deviceWithType GPU", explicitGPU ? [NSString stringWithFormat:@"type=%d actual=%d", (int)explicitGPU.type, (int)explicitGPU.actualDeviceType] : @"(nil)");
        MLCDevice *explicitCPU = [MLCDevice deviceWithType:MLCDeviceTypeCPU];
        key(@"deviceWithType CPU", explicitCPU ? [NSString stringWithFormat:@"type=%d actual=%d", (int)explicitCPU.type, (int)explicitCPU.actualDeviceType] : @"(nil)");
        MLCDevice *deviceCopy = [cpu copy];
        key(@"cpuDevice copy", deviceCopy ? [NSString stringWithFormat:@"type=%d actual=%d", (int)deviceCopy.type, (int)deviceCopy.actualDeviceType] : @"(nil)");
        key(@"deviceWithGPUDevices empty", [MLCDevice deviceWithGPUDevices:@[]] ? @"set" : @"(nil)");

        printf("== MLCTensorDescriptor\n");
        counted(@"maxTensorDimensions", [MLCTensorDescriptor maxTensorDimensions]);
        for (NSUInteger count = 1; count <= 6; count++) {
            NSMutableArray *shape = [NSMutableArray array];
            for (NSUInteger index = 0; index < count; index++) {
                [shape addObject:@(index + 2)];
            }
            showDescriptor([NSString stringWithFormat:@"descriptor %lu dimensions", (unsigned long)count],
                       [MLCTensorDescriptor descriptorWithShape:shape dataType:MLCDataTypeFloat32]);
        }
        for (int type = 0; type <= (int)MLCDataTypeCount; type++) {
            showDescriptor([NSString stringWithFormat:@"descriptor type %d", type], [MLCTensorDescriptor descriptorWithShape:@[@4, @4] dataType:(MLCDataType)type]);
        }
        attempted(@"descriptor empty shape", ^{
            showDescriptor(@"descriptor empty shape", [MLCTensorDescriptor descriptorWithShape:@[] dataType:MLCDataTypeFloat32]);
        });
        showDescriptor(@"descriptor with a zero", [MLCTensorDescriptor descriptorWithShape:@[@4, @0] dataType:MLCDataTypeFloat32]);
        showDescriptor(@"descriptor nchw", [MLCTensorDescriptor descriptorWithWidth:5 height:6 featureChannelCount:7 batchSize:8]);
        showDescriptor(@"descriptor nchw dataType", [MLCTensorDescriptor descriptorWithWidth:5 height:6 featureChannelCount:7 batchSize:8 dataType:MLCDataTypeInt32]);
        showDescriptor(@"descriptor convolution weights", [MLCTensorDescriptor convolutionWeightsDescriptorWithWidth:3
                                                                                                  height:3
                                                                                    inputFeatureChannelCount:4
                                                                                   outputFeatureChannelCount:5
                                                                                                dataType:MLCDataTypeFloat32]);
        showDescriptor(@"descriptor convolution weights unit", [MLCTensorDescriptor convolutionWeightsDescriptorWithInputFeatureChannelCount:4
                                                                                                       outputFeatureChannelCount:5
                                                                                                                dataType:MLCDataTypeFloat32]);
        showDescriptor(@"descriptor convolution biases", [MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:5 dataType:MLCDataTypeFloat32]);
        showDescriptor(@"descriptor sequence mismatched", [MLCTensorDescriptor descriptorWithShape:@[@4, @4]
                                                                           sequenceLengths:@[@3, @2, @1]
                                                                           sortedSequences:YES
                                                                                  dataType:MLCDataTypeFloat32]);
        showDescriptor(@"descriptor sequence 3 2", [MLCTensorDescriptor descriptorWithShape:@[@3, @2]
                                                                        sequenceLengths:@[@3, @2, @1]
                                                                        sortedSequences:YES
                                                                               dataType:MLCDataTypeFloat32]);
        showDescriptor(@"descriptor sequence 2 4", [MLCTensorDescriptor descriptorWithShape:@[@2, @4]
                                                                        sequenceLengths:@[@2, @1]
                                                                        sortedSequences:YES
                                                                               dataType:MLCDataTypeFloat32]);
        showDescriptor(@"descriptor copy", [[MLCTensorDescriptor descriptorWithShape:@[@2, @3, @4, @5] dataType:MLCDataTypeFloat32] copy]);
        showDescriptor(@"descriptor init", CharonNewOf(NSStringFromClass([MLCTensorDescriptor class])));
        showDescriptor(@"descriptor new", CharonNewOf(NSStringFromClass([MLCTensorDescriptor class])));

        printf("== MLCTensorData\n");
        float values[64];
        for (int index = 0; index < 64; index++) {
            values[index] = (float)(index + 1);
        }
        MLCTensorData *data = [MLCTensorData dataWithBytesNoCopy:values length:sizeof(values)];
        key(@"data no copy", [NSString stringWithFormat:@"same=%d length=%lu", (int)(data.bytes == values), (unsigned long)data.length]);
        MLCTensorData *immutable = [MLCTensorData dataWithImmutableBytesNoCopy:values length:12];
        key(@"data immutable no copy", [NSString stringWithFormat:@"same=%d length=%lu", (int)(immutable.bytes == values), (unsigned long)immutable.length]);
        MLCTensorData *empty = [MLCTensorData dataWithBytesNoCopy:values length:0];
        counted(@"data length zero", empty.length);
        @try {
            void *owned = malloc(32);
            MLCTensorData *deallocating = [MLCTensorData dataWithBytesNoCopy:owned
                                                                        length:32
                                                                   deallocator:^(void *bytes, NSUInteger length) {
                                                                       deallocatorCalled++;
                                                                       free(bytes);
                                                                   }];
            counted(@"data with a deallocator", deallocating.length);
            deallocating = nil;
        } @catch (NSException *raised) {
            key(@"data with a deallocator", [NSString stringWithFormat:@"raised %@", raised.name]);
        }
        key(@"data deallocator called", deallocatorCalled ? @"YES" : @"NO");
        key(@"data init", CharonNewOf(NSStringFromClass([MLCTensorData class])) ? @"set" : @"(nil)");
        MLCTensorData *newData = CharonNewOf(NSStringFromClass([MLCTensorData class]));
        if ([newData respondsToSelector:@selector(length)]) {
            counted(@"data new length", ((MLCTensorData *)newData).length);
        }

        printf("== MLCTensor\n");
        MLCTensor *tensor = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@2, @3, @4, @5] dataType:MLCDataTypeFloat32]];
        showTensor(@"tensor from a descriptor", tensor);
        counted(@"optimizerData count", tensor.optimizerData.count);
        counted(@"optimizerDeviceData count", tensor.optimizerDeviceData.count);
        flag(@"hasValidNumerics with no data", tensor.hasValidNumerics);
        flag(@"synchronizeData with no data", [tensor synchronizeData]);
        flag(@"synchronizeOptimizerData with no data", [tensor synchronizeOptimizerData]);
        float readBack[4] = { 0, 0, 0, 0 };
        flag(@"copyDataFromDeviceMemoryToBytes with no data", [tensor copyDataFromDeviceMemoryToBytes:readBack length:sizeof(readBack) synchronizeWithDevice:YES]);
        flag(@"bindAndWriteData with no data", [tensor bindAndWriteData:data toDevice:cpu]);
        flag(@"bindOptimizerData", [tensor bindOptimizerData:@[ data ] deviceData:nil]);
        counted(@"optimizerData after binding", tensor.optimizerData.count);
        tensor.label = @"named";
        record(@"label after setting", tensor.label);
        MLCTensor *copy = [tensor copy];
        showTensor(@"tensor copy", copy);
        // A copy of a tensor that *has* data, which is the only case that can show whether it keeps it.
        MLCTensor *filled3 = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@2, @2] dataType:MLCDataTypeFloat32] fillWithData:@(1.5)];
        filled3.label = @"named";
        MLCTensor *filledCopy = [filled3 copy];
        showTensor(@"tensor copy with data", filledCopy);
        MLCTensor *filled = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@2, @2] dataType:MLCDataTypeFloat32] fillWithData:@(3.5)];
        if (filled.data) {
            const float *filledBytes = filled.data.bytes;
            key(@"fillWithData 3.5", [NSString stringWithFormat:@"length=%lu %g %g %g %g", (unsigned long)filled.data.length, filledBytes[0], filledBytes[1], filledBytes[2],
                                           filledBytes[3]]);
        } else {
            key(@"fillWithData 3.5", @"(nil)");
        }
        MLCTensor *filledInteger = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@4] dataType:MLCDataTypeInt32] fillWithData:@(7)];
        if (filledInteger.data) {
            key(@"fillWithData 7 int32", [NSString stringWithFormat:@"length=%lu value=%d", (unsigned long)filledInteger.data.length,
                                                ((const int32_t *)filledInteger.data.bytes)[0]]);
        }
        MLCTensor *filledBytes = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@4] dataType:MLCDataTypeUInt8] fillWithData:@(7)];
        if (filledBytes.data) {
            key(@"fillWithData 7 uint8", [NSString stringWithFormat:@"length=%lu value=%u", (unsigned long)filledBytes.data.length,
                                                ((const uint8_t *)filledBytes.data.bytes)[0]]);
        }
        MLCTensor *withData = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@2, @3] dataType:MLCDataTypeFloat32]
                                                           data:[MLCTensorData dataWithBytesNoCopy:values length:sizeof(values)]];
        if (withData.data) {
            key(@"tensor with an oversized buffer", [NSString stringWithFormat:@"length=%lu first=%g", (unsigned long)withData.data.length,
                                                          ((const float *)withData.data.bytes)[0]]);
        }
        MLCTensor *withShortData = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@2, @2] dataType:MLCDataTypeFloat32]
                                                              data:[MLCTensorData dataWithBytesNoCopy:values length:8]];
        if (withShortData.data) {
            key(@"tensor with a short buffer", [NSString stringWithFormat:@"length=%lu", (unsigned long)withShortData.data.length]);
        }
        showTensor(@"tensorWithShape", [MLCTensor tensorWithShape:@[@2, @3]]);
        showTensor(@"tensorWithShape dataType", [MLCTensor tensorWithShape:@[@2, @3] dataType:MLCDataTypeInt32]);
        showTensor(@"tensorWithShape random", [MLCTensor tensorWithShape:@[@2, @3] randomInitializerType:MLCRandomInitializerTypeGlorotUniform]);
        showTensor(@"tensorWithShape random dataType", [MLCTensor tensorWithShape:@[@2, @3]
                                                            randomInitializerType:MLCRandomInitializerTypeUniform
                                                                         dataType:MLCDataTypeFloat32]);
        MLCTensorData *short2 = [MLCTensorData dataWithBytesNoCopy:values length:2 * 3 * 4 * sizeof(float)];
        showTensor(@"tensorWithShape data", [MLCTensor tensorWithShape:@[@2, @3] data:short2 dataType:MLCDataTypeFloat32]);
        showTensor(@"tensorWithShape fill", [MLCTensor tensorWithShape:@[@2, @3] fillWithData:@(1) dataType:MLCDataTypeFloat32]);
        showTensor(@"tensor nchw", [MLCTensor tensorWithWidth:2 height:3 featureChannelCount:4 batchSize:1]);
        showTensor(@"tensor nchw fill", [MLCTensor tensorWithWidth:2 height:3 featureChannelCount:4 batchSize:1 fillWithData:1 dataType:MLCDataTypeFloat32]);
        showTensor(@"tensor nchw random", [MLCTensor tensorWithWidth:2 height:3 featureChannelCount:4 batchSize:1
                                             randomInitializerType:MLCRandomInitializerTypeXavier]);
        showTensor(@"tensor nchw data", [MLCTensor tensorWithWidth:2 height:3 featureChannelCount:4 batchSize:1 data:short2]);
        showTensor(@"tensor nchw data dataType", [MLCTensor tensorWithWidth:2 height:3 featureChannelCount:4 batchSize:1 data:short2 dataType:MLCDataTypeFloat32]);
        showTensor(@"tensor sequence length", [MLCTensor tensorWithSequenceLength:3 featureChannelCount:2 batchSize:2]);
        showTensor(@"tensor sequence length random", [MLCTensor tensorWithSequenceLength:3 featureChannelCount:2 batchSize:2
                                                                   randomInitializerType:MLCRandomInitializerTypeUniform]);
        showTensor(@"tensor sequence length data", [MLCTensor tensorWithSequenceLength:3 featureChannelCount:2 batchSize:2 data:nil]);
        showTensor(@"tensor sequence lengths", [MLCTensor tensorWithSequenceLengths:@[@3, @2, @1]
                                                                   sortedSequences:YES
                                                              featureChannelCount:2
                                                                        batchSize:1
                                                            randomInitializerType:MLCRandomInitializerTypeInvalid]);
        showTensor(@"tensor sequence lengths data", [MLCTensor tensorWithSequenceLengths:@[@3, @2, @1]
                                                                        sortedSequences:YES
                                                                   featureChannelCount:2
                                                                         batchSize:1
                                                                              data:nil]);
        initializer(@"initializer uniform", MLCRandomInitializerTypeUniform);
        initializer(@"initializer glorot", MLCRandomInitializerTypeGlorotUniform);
        initializer(@"initializer xavier", MLCRandomInitializerTypeXavier);
        @try {
            MLCTensor *first = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@4, @4] dataType:MLCDataTypeFloat32]
                                              randomInitializerType:MLCRandomInitializerTypeUniform];
            MLCTensor *again = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@4, @4] dataType:MLCDataTypeFloat32]
                                             randomInitializerType:MLCRandomInitializerTypeUniform];
            float left = ((const float *)first.data.bytes)[0];
            float right = ((const float *)again.data.bytes)[0];
            key(@"two initializers with no seed", left == right ? @"the same values" : @"different values");
        } @catch (NSException *raised) {
            key(@"two initializers with no seed", [NSString stringWithFormat:@"raised %@", raised.name]);
        }
        @try {
            [MLCPlatform setRNGSeedTo:@(11)];
            MLCTensor *first = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@4, @4] dataType:MLCDataTypeFloat32]
                                              randomInitializerType:MLCRandomInitializerTypeUniform];
            [MLCPlatform setRNGSeedTo:@(11)];
            MLCTensor *again = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@4, @4] dataType:MLCDataTypeFloat32]
                                             randomInitializerType:MLCRandomInitializerTypeUniform];
            [MLCPlatform setRNGSeedTo:@(12)];
            MLCTensor *other = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@4, @4] dataType:MLCDataTypeFloat32]
                                            randomInitializerType:MLCRandomInitializerTypeUniform];
            float one = ((const float *)first.data.bytes)[0];
            float two = ((const float *)again.data.bytes)[0];
            float three = ((const float *)other.data.bytes)[0];
            key(@"one seed twice and another", one == two && one != three ? @"same then different" : @"not reproducible");
        } @catch (NSException *raised) {
            key(@"one seed twice and another", [NSString stringWithFormat:@"raised %@", raised.name]);
        }
        MLCTensor *quantizable = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@2, @2] dataType:MLCDataTypeFloat32]
                                                            fillWithData:@(2.5)];
        MLCTensor *quantized = [quantizable tensorByQuantizingToType:MLCDataTypeUInt8 scale:0.25 bias:3];
        key(@"quantized to uint8", quantized ? [NSString stringWithFormat:@"type=%d length=%lu", (int)quantized.descriptor.dataType, (unsigned long)quantized.data.length] : @"(nil)");
        MLCTensor *quantizedInt8 = [quantizable tensorByQuantizingToType:MLCDataTypeInt8 scale:0.5 bias:1];
        key(@"quantized to int8", quantizedInt8 ? [NSString stringWithFormat:@"type=%d", (int)quantizedInt8.descriptor.dataType] : @"(nil)");
        MLCTensor *quantizedInt32 = [quantizable tensorByQuantizingToType:MLCDataTypeInt32 scale:0.5 bias:1];
        key(@"quantized to int32", quantizedInt32 ? [NSString stringWithFormat:@"type=%d", (int)quantizedInt32.descriptor.dataType] : @"(nil)");
        MLCTensor *quantizedFloat = [quantizable tensorByQuantizingToType:MLCDataTypeFloat32 scale:0.5 bias:1];
        key(@"quantized to float32", quantizedFloat ? @"set" : @"(nil)");
        MLCTensor *scaleTensor = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@1] dataType:MLCDataTypeFloat32] fillWithData:@(0.5)];
        MLCTensor *biasTensor = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@1] dataType:MLCDataTypeInt32] fillWithData:@(1)];
        MLCTensor *perAxis = [quantizable tensorByQuantizingToType:MLCDataTypeInt8 scale:scaleTensor bias:biasTensor axis:1];
        key(@"quantized per axis", perAxis ? [NSString stringWithFormat:@"type=%d", (int)perAxis.descriptor.dataType] : @"(nil)");
        MLCTensor *dequantized = [quantized tensorByDequantizingToType:MLCDataTypeFloat32 scale:scaleTensor bias:biasTensor];
        key(@"dequantized", dequantized ? [NSString stringWithFormat:@"type=%d", (int)dequantized.descriptor.dataType] : @"(nil)");
        MLCTensor *dequantizedAxis = [quantized tensorByDequantizingToType:MLCDataTypeFloat32 scale:scaleTensor bias:biasTensor axis:1];
        key(@"dequantized per axis", dequantizedAxis ? [NSString stringWithFormat:@"type=%d", (int)dequantizedAxis.descriptor.dataType] : @"(nil)");
        MLCTensor *dequantizedInt = [quantized tensorByDequantizingToType:MLCDataTypeInt32 scale:scaleTensor bias:biasTensor];
        key(@"dequantized to int32", dequantizedInt ? @"set" : @"(nil)");
        key(@"tensor init", CharonNewOf(NSStringFromClass([MLCTensor class])) ? @"set" : @"(nil)");
        MLCTensor *newTensor = CharonNewOf(NSStringFromClass([MLCTensor class]));
        if (newTensor) {
            showTensor(@"tensor new", newTensor);
        }
        MLCTensor *noDescriptor = [MLCTensor tensorWithDescriptor:nil];
        key(@"tensor of a nil descriptor", noDescriptor ? @"set" : @"(nil)");

        printf("== MLCTensorParameter\n");
        MLCTensorParameter *parameter = [MLCTensorParameter parameterWithTensor:tensor];
        key(@"parameter", [NSString stringWithFormat:@"same=%d updatable=%d", (int)(parameter.tensor == tensor), (int)parameter.isUpdatable]);
        MLCTensorParameter *withOptimizer = [MLCTensorParameter parameterWithTensor:tensor optimizerData:@[ data ]];
        key(@"parameter with optimizer data", [NSString stringWithFormat:@"same=%d updatable=%d", (int)(withOptimizer.tensor == tensor), (int)withOptimizer.isUpdatable]);
        parameter.isUpdatable = NO;
        flag(@"parameter updatable set", parameter.isUpdatable);
        MLCTensorParameter *newParameter = CharonNewOf(NSStringFromClass([MLCTensorParameter class]));
        key(@"parameter init", newParameter ? [NSString stringWithFormat:@"tensor=%@ updatable=%d", newParameter.tensor, (int)newParameter.isUpdatable] : @"(nil)");
        MLCTensorParameter *newParameter2 = CharonNewOf(NSStringFromClass([MLCTensorParameter class]));
        // The device-side optimizer buffers: the class the two rows are, which had no case.
        id optimizerDeviceData = CharonNewOf(NSStringFromClass([MLCTensorOptimizerDeviceData class]));
        // The class and the copy, not -description: this class has no description of its own, so the two
        // sides spell one differently and that is not a behaviour of the port.
        flag(@"MLCTensorOptimizerDeviceData new is of the class",
             [optimizerDeviceData isKindOfClass:[MLCTensorOptimizerDeviceData class]]);
        flag(@"MLCTensorOptimizerDeviceData copies", [optimizerDeviceData copy] ? @"yes" : @"no");

        printf("== MLCLayer\n");
        MLCLayer *layer0 = CharonNewOf(NSStringFromClass([MLCLayer class]));
        showLayer(@"layer init", layer0);
        showLayer(@"layer new", CharonNewOf(NSStringFromClass([MLCLayer class])));
        layer0.label = @"named";
        layer0.isDebuggingEnabled = YES;
        showLayer(@"layer after setting", layer0);
        for (int type = 0; type <= (int)MLCDataTypeCount; type++) {
            flag([NSString stringWithFormat:@"supportsDataType %d on the cpu", type], [MLCLayer supportsDataType:(MLCDataType)type onDevice:cpu]);
        }
        flag(@"supportsDataType float32 with no device", [MLCLayer supportsDataType:MLCDataTypeFloat32 onDevice:nil]);

        printf("== MLCActivationDescriptor\n");
        for (int type = 0; type < MLCActivationTypeCount; type++) {
            showActivation([NSString stringWithFormat:@"activation %d", type], [MLCActivationDescriptor descriptorWithType:(MLCActivationType)type]);
            showActivation([NSString stringWithFormat:@"activation %d a", type], [MLCActivationDescriptor descriptorWithType:(MLCActivationType)type a:0.5]);
            showActivation([NSString stringWithFormat:@"activation %d a b", type], [MLCActivationDescriptor descriptorWithType:(MLCActivationType)type a:0.5 b:0.25]);
            showActivation([NSString stringWithFormat:@"activation %d a b c", type], [MLCActivationDescriptor descriptorWithType:(MLCActivationType)type a:0.5 b:0.25 c:0.125]);
        }
        showActivation(@"activation copy", [[MLCActivationDescriptor descriptorWithType:MLCActivationTypeHardSwish a:1 b:2 c:3] copy]);
        showActivation(@"activation init", CharonNewOf(NSStringFromClass([MLCActivationDescriptor class])));

        printf("== MLCConvolutionDescriptor\n");
        showConvolution(@"convolution kernel sizes", [MLCConvolutionDescriptor descriptorWithKernelWidth:3
                                                                     kernelHeight:3
                                                                     inputFeatureChannelCount:4
                                                                    outputFeatureChannelCount:5]);
        showConvolution(@"convolution every argument", [MLCConvolutionDescriptor descriptorWithType:MLCConvolutionTypeStandard
                                                                                kernelSizes:@[@3, @5]
                                                                            inputFeatureChannelCount:4
                                                                           outputFeatureChannelCount:6
                                                                                  groupCount:2
                                                                                    strides:@[@2, @1]
                                                                               dilationRates:@[@1, @3]
                                                                              paddingPolicy:MLCPaddingPolicyUsePaddingSize
                                                                               paddingSizes:@[@4, @2]]);
        showConvolution(@"convolution no group", [MLCConvolutionDescriptor descriptorWithKernelSizes:@[@3, @3]
                                                                          inputFeatureChannelCount:4
                                                                         outputFeatureChannelCount:5
                                                                                        strides:@[@1, @1]
                                                                                   paddingPolicy:MLCPaddingPolicyUsePaddingSize
                                                                                    paddingSizes:@[@2, @2]]);
        showConvolution(@"convolution same", [MLCConvolutionDescriptor descriptorWithKernelSizes:@[@3, @3]
                                                                      inputFeatureChannelCount:4
                                                                     outputFeatureChannelCount:5
                                                                                       strides:@[@1, @1]
                                                                                  paddingPolicy:MLCPaddingPolicySame
                                                                                   paddingSizes:nil]);
        showConvolution(@"convolution valid", [MLCConvolutionDescriptor descriptorWithKernelSizes:@[@3, @3]
                                                                       inputFeatureChannelCount:4
                                                                      outputFeatureChannelCount:5
                                                                                        strides:@[@1, @1]
                                                                                   paddingPolicy:MLCPaddingPolicyValid
                                                                                    paddingSizes:nil]);
        showConvolution(@"convolution transpose kernel sizes", [MLCConvolutionDescriptor convolutionTransposeDescriptorWithKernelWidth:3
                                                                                                   kernelHeight:3
                                                                                   inputFeatureChannelCount:4
                                                                                  outputFeatureChannelCount:5]);
        showConvolution(@"convolution transpose every argument", [MLCConvolutionDescriptor convolutionTransposeDescriptorWithKernelSizes:@[@2, @3]
                                                                                                   inputFeatureChannelCount:4
                                                                                                  outputFeatureChannelCount:6
                                                                                                                groupCount:2
                                                                                                                  strides:@[@1, @1]
                                                                                                             dilationRates:@[@1, @1]
                                                                                                            paddingPolicy:MLCPaddingPolicySame
                                                                                                             paddingSizes:nil]);
        showConvolution(@"convolution depthwise kernel sizes", [MLCConvolutionDescriptor depthwiseConvolutionDescriptorWithKernelWidth:3
                                                                                                     kernelHeight:3
                                                                                     inputFeatureChannelCount:4
                                                                                                channelMultiplier:2]);
        showConvolution(@"convolution depthwise no dilation", [MLCConvolutionDescriptor depthwiseConvolutionDescriptorWithKernelSizes:@[@3, @3]
                                                                                                      inputFeatureChannelCount:4
                                                                                                             channelMultiplier:2
                                                                                                                      strides:@[@1, @1]
                                                                                                                 paddingPolicy:MLCPaddingPolicyValid
                                                                                                                  paddingSizes:nil]);
        showConvolution(@"convolution depthwise every argument", [MLCConvolutionDescriptor depthwiseConvolutionDescriptorWithKernelSizes:@[@3, @3]
                                                                                                         inputFeatureChannelCount:4
                                                                                                                channelMultiplier:2
                                                                                                                         strides:@[@1, @1]
                                                                                                                    dilationRates:@[@1, @1]
                                                                                                                   paddingPolicy:MLCPaddingPolicyValid
                                                                                                                    paddingSizes:nil]);
        showConvolution(@"convolution copy", [[MLCConvolutionDescriptor descriptorWithKernelWidth:3 kernelHeight:5 inputFeatureChannelCount:1 outputFeatureChannelCount:2] copy]);
        showConvolution(@"convolution init", CharonNewOf(NSStringFromClass([MLCConvolutionDescriptor class])));

        printf("== MLCPoolingDescriptor\n");
        showPooling(@"pooling kernel size and stride", [MLCPoolingDescriptor poolingDescriptorWithType:MLCPoolingTypeMax kernelSize:2 stride:2]);
        showPooling(@"pooling max", [MLCPoolingDescriptor maxPoolingDescriptorWithKernelSizes:@[@2, @3]
                                                                                 strides:@[@1, @2]
                                                                            paddingPolicy:MLCPaddingPolicyUsePaddingSize
                                                                             paddingSizes:@[@4, @5]]);
        showPooling(@"pooling max with dilation", [MLCPoolingDescriptor maxPoolingDescriptorWithKernelSizes:@[@2, @3]
                                                                                        strides:@[@1, @2]
                                                                                   dilationRates:@[@3, @1]
                                                                                  paddingPolicy:MLCPaddingPolicySame
                                                                                   paddingSizes:nil]);
        showPooling(@"pooling average", [MLCPoolingDescriptor averagePoolingDescriptorWithKernelSizes:@[@2, @2]
                                                                                        strides:@[@2, @2]
                                                                                   paddingPolicy:MLCPaddingPolicyValid
                                                                                    paddingSizes:nil
                                                                            countIncludesPadding:YES]);
        showPooling(@"pooling average with dilation", [MLCPoolingDescriptor averagePoolingDescriptorWithKernelSizes:@[@2, @2]
                                                                                                strides:@[@2, @2]
                                                                                           dilationRates:@[@2, @1]
                                                                                          paddingPolicy:MLCPaddingPolicyUsePaddingSize
                                                                                           paddingSizes:@[@1, @1]
                                                                                   countIncludesPadding:NO]);
        showPooling(@"pooling l2", [MLCPoolingDescriptor l2NormPoolingDescriptorWithKernelSizes:@[@2, @3]
                                                                                  strides:@[@1, @1]
                                                                             paddingPolicy:MLCPaddingPolicySame
                                                                              paddingSizes:nil]);
        showPooling(@"pooling l2 with dilation", [MLCPoolingDescriptor l2NormPoolingDescriptorWithKernelSizes:@[@2, @3]
                                                                                             strides:@[@1, @1]
                                                                                        dilationRates:@[@1, @2]
                                                                                       paddingPolicy:MLCPaddingPolicyValid
                                                                                        paddingSizes:nil]);
        showPooling(@"pooling copy", [[MLCPoolingDescriptor poolingDescriptorWithType:MLCPoolingTypeL2Norm kernelSize:3 stride:1] copy]);
        showPooling(@"pooling init", CharonNewOf(NSStringFromClass([MLCPoolingDescriptor class])));

        printf("== MLCLossDescriptor\n");
        showLoss(@"loss type and reduction", [MLCLossDescriptor descriptorWithType:MLCLossTypeSoftmaxCrossEntropy reductionType:MLCReductionTypeMean]);
        showLoss(@"loss with a weight", [MLCLossDescriptor descriptorWithType:MLCLossTypeMeanSquaredError reductionType:MLCReductionTypeSum weight:5]);
        showLoss(@"loss with smoothing", [MLCLossDescriptor descriptorWithType:MLCLossTypeLog reductionType:MLCReductionTypeMean
                                                                   weight:3 labelSmoothing:0.2 classCount:4]);
        showLoss(@"loss with every argument", [MLCLossDescriptor descriptorWithType:MLCLossTypeHuber reductionType:MLCReductionTypeSum
                                                                         weight:2 labelSmoothing:0.1 classCount:7 epsilon:1e-5 delta:0.5]);
        showLoss(@"loss copy", [[MLCLossDescriptor descriptorWithType:MLCLossTypeHinge reductionType:MLCReductionTypeMax weight:2] copy]);
        showLoss(@"loss init", CharonNewOf(NSStringFromClass([MLCLossDescriptor class])));

        printf("== MLCOptimizerDescriptor\n");
        showOptimizer(@"optimizer four arguments", [MLCOptimizerDescriptor descriptorWithLearningRate:0.01
                                                                       gradientRescale:0.5
                                                                regularizationType:MLCRegularizationTypeL2
                                                              regularizationScale:0.001]);
        showOptimizer(@"optimizer with clipping", [MLCOptimizerDescriptor descriptorWithLearningRate:0.02
                                                                    gradientRescale:1.0
                                                            appliesGradientClipping:YES
                                                                  gradientClipMax:3
                                                                  gradientClipMin:-3
                                                           regularizationType:MLCRegularizationTypeL1
                                                         regularizationScale:0.01]);
        showOptimizer(@"optimizer every argument", [MLCOptimizerDescriptor descriptorWithLearningRate:0.03
                                                                  gradientRescale:2.0
                                                          appliesGradientClipping:YES
                                                        gradientClippingType:MLCGradientClippingTypeByGlobalNorm
                                                            gradientClipMax:1
                                                            gradientClipMin:-1
                                                       maximumClippingNorm:4
                                                          customGlobalNorm:5
                                                         regularizationType:MLCRegularizationTypeL2
                                                       regularizationScale:0.02]);
        showOptimizer(@"optimizer copy", [[MLCOptimizerDescriptor descriptorWithLearningRate:0.5 gradientRescale:3 regularizationType:MLCRegularizationTypeL1 regularizationScale:0.5] copy]);
        showOptimizer(@"optimizer init", CharonNewOf(NSStringFromClass([MLCOptimizerDescriptor class])));

        printf("== MLCMatMulDescriptor\n");
        MLCMatMulDescriptor *matmul = [MLCMatMulDescriptor descriptorWithAlpha:2 transposesX:YES transposesY:NO];
        key(@"matmul", [NSString stringWithFormat:@"alpha=%g transposesX=%d transposesY=%d", matmul.alpha, (int)matmul.transposesX, (int)matmul.transposesY]);
        MLCMatMulDescriptor *plain = [MLCMatMulDescriptor descriptor];
        key(@"matmul descriptor", [NSString stringWithFormat:@"alpha=%g transposesX=%d transposesY=%d", plain.alpha, (int)plain.transposesX, (int)plain.transposesY]);
        MLCMatMulDescriptor *matmulCopy = [matmul copy];
        key(@"matmul copy", [NSString stringWithFormat:@"alpha=%g transposesX=%d", matmulCopy.alpha, (int)matmulCopy.transposesX]);
        MLCMatMulDescriptor *matmulInit = CharonNewOf(NSStringFromClass([MLCMatMulDescriptor class]));
        key(@"matmul init", matmulInit ? [NSString stringWithFormat:@"alpha=%g", matmulInit.alpha] : @"(nil)");

        printf("== MLCEmbeddingDescriptor\n");
        showEmbedding(@"embedding count and dimension", [MLCEmbeddingDescriptor descriptorWithEmbeddingCount:@(100) embeddingDimension:@(8)]);
        showEmbedding(@"embedding every argument", [MLCEmbeddingDescriptor descriptorWithEmbeddingCount:@(50)
                                                                                 embeddingDimension:@(4)
                                                                                       paddingIndex:@(2)
                                                                                       maximumNorm:@(3)
                                                                                             pNorm:@(1.5)
                                                                           scalesGradientByFrequency:YES]);
        showEmbedding(@"embedding copy", [[MLCEmbeddingDescriptor descriptorWithEmbeddingCount:@(7) embeddingDimension:@(3)] copy]);
        showEmbedding(@"embedding init", CharonNewOf(NSStringFromClass([MLCEmbeddingDescriptor class])));

        printf("== MLCLSTMDescriptor\n");
        showLstm(@"lstm three arguments", [MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:2]);
        showLstm(@"lstm five arguments", [MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:2 usesBiases:YES isBidirectional:YES dropout:0.25]);
        showLstm(@"lstm six arguments", [MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:2 usesBiases:YES batchFirst:YES isBidirectional:NO dropout:0.5]);
        showLstm(@"lstm seven arguments", [MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:2 usesBiases:YES batchFirst:NO isBidirectional:NO
                                     returnsSequences:YES dropout:0.1]);
        showLstm(@"lstm every argument", [MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:2 usesBiases:YES batchFirst:NO isBidirectional:NO
                                   returnsSequences:YES dropout:0.1 resultMode:MLCLSTMResultModeOutputAndStates]);
        showLstm(@"lstm copy", [[MLCLSTMDescriptor descriptorWithInputSize:1 hiddenSize:2 layerCount:3] copy]);
        showLstm(@"lstm init", CharonNewOf(NSStringFromClass([MLCLSTMDescriptor class])));

        printf("== MLCMultiheadAttentionDescriptor\n");
        showAttention(@"attention model and heads", [MLCMultiheadAttentionDescriptor descriptorWithModelDimension:8 headCount:2]);
        showAttention(@"attention every argument", [MLCMultiheadAttentionDescriptor descriptorWithModelDimension:8
                                                                         keyDimension:6
                                                                       valueDimension:4
                                                                           headCount:2
                                                                            dropout:0.1
                                                                          hasBiases:YES
                                                                 hasAttentionBiases:YES
                                                                  addsZeroAttention:YES]);
        showAttention(@"attention copy", [[MLCMultiheadAttentionDescriptor descriptorWithModelDimension:16 headCount:4] copy]);
        showAttention(@"attention init", CharonNewOf(NSStringFromClass([MLCMultiheadAttentionDescriptor class])));

        printf("== MLCYOLOLossDescriptor\n");
        float anchors[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
        NSData *anchorData = [NSData dataWithBytes:anchors length:sizeof(anchors)];
        MLCYOLOLossDescriptor *yolo = [MLCYOLOLossDescriptor descriptorWithAnchorBoxes:anchorData anchorBoxCount:2];
        showYolo(@"yolo defaults", yolo);
        yolo.shouldRescore = YES;
        yolo.scaleSpatialPositionLoss = 1.5f;
        yolo.scaleSpatialSizeLoss = 2.5f;
        yolo.scaleNoObjectConfidenceLoss = 3.5f;
        yolo.scaleObjectConfidenceLoss = 4.5f;
        yolo.scaleClassLoss = 5.5f;
        yolo.minimumIOUForObjectPresence = 0.75f;
        yolo.maximumIOUForObjectAbsence = 0.85f;
        showYolo(@"yolo after setting", yolo);
        showYolo(@"yolo copy", [yolo copy]);
        showYolo(@"yolo init", CharonNewOf(NSStringFromClass([MLCYOLOLossDescriptor class])));
    }
}
