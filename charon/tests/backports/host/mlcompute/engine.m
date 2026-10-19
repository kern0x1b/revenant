// What the host's own MLCompute computes for a layer, asked through an inference graph so the numbers
// come from the framework's own arithmetic rather than from a hand calculation. This is the oracle the
// port's engine is written against: one input tensor, one or two layers, and the values that come out.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <string.h>
#import "mlcompute-16.h"

static void row(NSString *name, NSString *value)
{
    printf("%s\t%s\n", name.UTF8String, value.UTF8String);
}

static NSString *nums(NSArray *array)
{
    if (!array) {
        return @"(nil)";
    }
    NSMutableString *text = [NSMutableString string];
    for (NSNumber *number in array) {
        if (text.length) {
            [text appendString:@","];
        }
        [text appendString:number.stringValue];
    }
    return text;
}

// A unary operation is asked with one source and a binary one with two, and the framework compiles only
// the arity each really has (measured: every unary operation and every logical comparison fails to
// compile with two sources, and every binary one fails with one).
static BOOL isUnary(MLCArithmeticOperation operation)
{
    switch (operation) {
        case MLCArithmeticOperationAdd:
        case MLCArithmeticOperationSubtract:
        case MLCArithmeticOperationMultiply:
        case MLCArithmeticOperationDivide:
        case MLCArithmeticOperationPow:
        case MLCArithmeticOperationMultiplyNoNaN:
        case MLCArithmeticOperationDivideNoNaN:
        case MLCArithmeticOperationMin:
        case MLCArithmeticOperationMax:
            return NO;
        default:
            return YES;
    }
}

static MLCTensorDescriptor *described(NSArray *shape)
{
    return [MLCTensorDescriptor descriptorWithShape:shape dataType:MLCDataTypeFloat32];
}

// One input, the layers in order, and the values of the first result. Nothing is compared here; the
// answers are the record.
static void through(NSString *name, NSArray *shape, NSArray<NSNumber *> *input, MLCTensor * (^build)(MLCGraph *graph, MLCTensor *input))
{
    @autoreleasepool {
        MLCDevice *cpu = [MLCDevice cpuDevice];
        MLCGraph *graph = [MLCGraph graph];
        MLCTensor *source = [MLCTensor tensorWithDescriptor:described(shape)];
        MLCTensor *result = build(graph, source);
        if (!result) {
            row(name, @"(nil)");
            return;
        }
        MLCInferenceGraph *inference = [MLCInferenceGraph graphWithGraphObjects:@[ graph ]];
        if (![inference addInputs:@{ @"input": source }] || ![inference addOutputs:@{ @"output": result }] ||
            ![inference compileWithOptions:MLCGraphCompilationOptionsNone device:cpu]) {
            row(name, @"(did not compile)");
            return;
        }
        float *bytes = malloc(4096);
        for (NSUInteger index = 0; index < input.count; index++) {
            bytes[index] = input[index].floatValue;
        }
        // The result of an execute is written into the buffer the caller names, and the tensor of the
        // graph that made it holds nothing: the inference graph owns its own tensors.
        float *out = malloc(4096);
        memset(out, 0, 4096);
        MLCTensorData *data = [MLCTensorData dataWithBytesNoCopy:bytes length:input.count * sizeof(float)];
        MLCTensorData *results = [MLCTensorData dataWithBytesNoCopy:out length:4096];
        __block BOOL done = NO;
        __block NSString *outcome = nil;
        [inference executeWithInputsData:@{ @"input": data }
                             outputsData:@{ @"output": results }
                               batchSize:0
                                 options:MLCExecutionOptionsSynchronous
                      completionHandler:^(MLCTensor *output, NSError *error, NSTimeInterval time) {
                          done = YES;
                          outcome = error ? error.localizedDescription : @"ok";
                      }];
        for (int spin = 0; spin < 2000 && !done; spin++) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
        }
        if (![outcome isEqualToString:@"ok"]) {
            row(name, [NSString stringWithFormat:@"%@", outcome]);
            free(bytes);
            return;
        }
        const float *values = out;
        NSMutableArray *all = [NSMutableArray array];
        NSUInteger count = result.descriptor.tensorAllocationSizeInBytes / sizeof(float);
        for (NSUInteger index = 0; index < count && index < 32; index++) {
            [all addObject:@(values[index])];
        }
        row([NSString stringWithFormat:@"%@ shape %@", name, nums(result.descriptor.shape)], all.count ? [NSString stringWithFormat:@"%@", nums(all)] : @"(none)");
        free(out);
        free(bytes);
    }
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        // A 2x2 image with one channel, values 1, 2, 3, 4.
        NSArray *image = @[ @1, @2, @3, @4 ];
        NSArray *imageShape = @[ @1, @1, @2, @2 ];

        printf("== every activation over 1, 2, 3, 4\n");
        NSArray *kinds = @[ @"none", @"relu", @"linear", @"sigmoid", @"hardSigmoid", @"tanh", @"absolute", @"softPlus", @"softSign", @"elu",
                             @"reluN", @"logSigmoid", @"selu", @"celu", @"hardShrink", @"softShrink", @"tanhShrink", @"threshold", @"gelu", @"hardSwish", @"clamp" ];
        for (MLCActivationType type = 0; type < MLCActivationTypeCount; type++) {
            NSString *label = [kinds[type] copy];
            through([NSString stringWithFormat:@"activation %@", label], imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
                return [graph nodeWithLayer:[MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:type]] source:input];
            });
        }

        printf("== the parameterised activations\n");
        through(@"leaky 0.2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer leakyReLULayerWithNegativeSlope:0.2] source:input];
        });
        through(@"linear 3 4", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer linearLayerWithScale:3 bias:4] source:input];
        });
        through(@"softPlus 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer softPlusLayerWithBeta:2] source:input];
        });
        through(@"elu 0.5", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer eluLayerWithA:0.5] source:input];
        });
        through(@"reluN 0.1 6", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer relunLayerWithA:0.1 b:6] source:input];
        });
        through(@"celu 0.7", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer celuLayerWithA:0.7] source:input];
        });
        through(@"hardShrink 0.3", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer hardShrinkLayerWithA:0.3] source:input];
        });
        through(@"softShrink 0.4", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer softShrinkLayerWithA:0.4] source:input];
        });
        through(@"threshold 0.6 -1", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer thresholdLayerWithThreshold:0.6 replacement:-1] source:input];
        });
        through(@"clamp -1 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer clampLayerWithMinValue:-1 maxValue:2] source:input];
        });
        through(@"relu6", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer relu6Layer] source:input];
        });
        through(@"leaky default", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer leakyReLULayer] source:input];
        });
        through(@"hardSigmoid default", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer hardSigmoidLayer] source:input];
        });
        through(@"hardShrink default", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer hardShrinkLayer] source:input];
        });
        through(@"gelu default", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCActivationLayer geluLayer] source:input];
        });

        printf("== the arithmetic operations\n");
        NSArray *left = @[ @1, @2, @3, @4 ];
        NSArray *operations = @[ @"add", @"subtract", @"multiply", @"divide", @"floor", @"round", @"ceil", @"sqrt", @"rsqrt", @"sin", @"cos", @"tan",
                                 @"asin", @"acos", @"atan", @"sinh", @"cosh", @"tanh", @"asinh", @"acosh", @"atanh", @"pow", @"exp", @"exp2", @"log",
                                 @"log2", @"multiplyNoNaN", @"divideNoNaN", @"min", @"max" ];
        for (MLCArithmeticOperation operation = 0; operation < MLCArithmeticOperationCount; operation++) {
            NSString *label = [operations[operation] copy];
            BOOL unary = isUnary(operation);
            through([NSString stringWithFormat:@"arithmetic %@", label], imageShape, left, ^(MLCGraph *graph, MLCTensor *input) {
                MLCArithmeticLayer *layer = [MLCArithmeticLayer layerWithOperation:operation];
                return unary ? [graph nodeWithLayer:layer source:input] : [graph nodeWithLayer:layer sources:@[ input, input ]];
            });
        }

        printf("== the comparison operations, a tensor against itself and a tensor against 2, 1, 1, 2\n");
        NSArray *comparisons = @[ @"equal", @"notEqual", @"less", @"greater", @"lessOrEqual", @"greaterOrEqual", @"and", @"or", @"not", @"nand", @"nor", @"xor" ];
        for (MLCComparisonOperation operation = 0; operation < MLCComparisonOperationCount; operation++) {
            NSString *label = [comparisons[operation] copy];
            BOOL logical = operation >= MLCComparisonOperationLogicalAND;
            through([NSString stringWithFormat:@"comparison %@ against itself", label], imageShape, left, ^(MLCGraph *graph, MLCTensor *input) {
                MLCComparisonLayer *layer = [MLCComparisonLayer layerWithOperation:operation];
                return logical ? [graph nodeWithLayer:layer source:input] : [graph nodeWithLayer:layer sources:@[ input, input ]];
            });
        }
        // the six ordering comparisons against a second tensor, whose values are 2, 1, 1, 2
        through(@"a tensor of 2,1,1,2", imageShape, @[ @2, @1, @1, @2 ], ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCArithmeticLayer layerWithOperation:MLCArithmeticOperationMultiply] source:input];
        });

        printf("== the shape-moving layers\n");
        through(@"reshape 1,4", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph reshapeWithShape:@[ @1, @4 ] source:input];
        });
        // the dimensions array has one entry for every dimension of the tensor, or the framework raises
        // (measured: three entries for a tensor of four raises NSInvalidArgumentException)
        through(@"transpose 0,2,1,3", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph transposeWithDimensions:@[ @0, @2, @1, @3 ] source:input];
        });
        through(@"transpose 0,1,2,3", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph transposeWithDimensions:@[ @0, @1, @2, @3 ] source:input];
        });
        through(@"transpose of three dimensions", @[ @1, @2, @2 ], @[ @1, @2, @3, @4 ], ^(MLCGraph *graph, MLCTensor *input) {
            return [graph transposeWithDimensions:@[ @0, @2, @1 ] source:input];
        });
        through(@"concatenate dimension 1", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph concatenateWithSources:@[ input, input ] dimension:1];
        });
        through(@"concatenate dimension 2", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph concatenateWithSources:@[ input, input ] dimension:2];
        });
        through(@"slice 1,1 to 2,2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCSliceLayer sliceLayerWithStart:@[ @0, @0, @1, @1 ] end:@[ @1, @1, @2, @2 ] stride:@[ @1, @1, @1, @1 ]] source:input];
        });
        through(@"split count 2 dimension 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            NSArray *parts = [graph splitWithSource:input splitCount:2 dimension:2];
            return parts.count ? parts[0] : nil;
        });
        through(@"upsample 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCUpsampleLayer layerWithShape:@[ @4, @4 ]] source:input];
        });
        through(@"padding zero 1,1,1,1", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCPaddingLayer layerWithZeroPadding:@[ @1, @1, @1, @1 ]] source:input];
        });
        through(@"padding constant 1,1,1,1 9", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCPaddingLayer layerWithConstantPadding:@[ @1, @1, @1, @1 ] constantValue:9] source:input];
        });
        through(@"padding reflect 1,1,1,1", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCPaddingLayer layerWithReflectionPadding:@[ @1, @1, @1, @1 ]] source:input];
        });
        through(@"padding symmetric 1,1,1,1", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCPaddingLayer layerWithSymmetricPadding:@[ @1, @1, @1, @1 ]] source:input];
        });
        through(@"softmax", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCSoftmaxLayer layerWithOperation:MLCSoftmaxOperationSoftmax] source:input];
        });
        through(@"log softmax", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCSoftmaxLayer layerWithOperation:MLCSoftmaxOperationLogSoftmax] source:input];
        });
        through(@"reduction mean dimension 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCReductionLayer layerWithReductionType:MLCReductionTypeMean dimension:2] source:input];
        });
        through(@"reduction sum dimensions 1,2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCReductionLayer layerWithReductionType:MLCReductionTypeSum dimensions:@[ @1, @2 ]] source:input];
        });
        through(@"reduction max dimension 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCReductionLayer layerWithReductionType:MLCReductionTypeMax dimension:2] source:input];
        });
        through(@"reduction argMax dimension 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCReductionLayer layerWithReductionType:MLCReductionTypeArgMax dimension:2] source:input];
        });
        through(@"pooling max 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCPoolingLayer layerWithDescriptor:[MLCPoolingDescriptor poolingDescriptorWithType:MLCPoolingTypeMax kernelSize:2 stride:2]] source:input];
        });
        through(@"pooling average 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCPoolingLayer layerWithDescriptor:[MLCPoolingDescriptor poolingDescriptorWithType:MLCPoolingTypeAverage kernelSize:2 stride:2]] source:input];
        });
        through(@"pooling l2Norm 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCPoolingLayer layerWithDescriptor:[MLCPoolingDescriptor poolingDescriptorWithType:MLCPoolingTypeL2Norm kernelSize:2 stride:2]] source:input];
        });
        through(@"convolution 1x1 weight 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *weights = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionWeightsDescriptorWithWidth:1 height:1 inputFeatureChannelCount:1 outputFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(2)];
            MLCConvolutionLayer *layer = [MLCConvolutionLayer layerWithWeights:weights biases:nil descriptor:[MLCConvolutionDescriptor descriptorWithKernelWidth:1 kernelHeight:1 inputFeatureChannelCount:1 outputFeatureChannelCount:1]];
            return [graph nodeWithLayer:layer source:input];
        });
        through(@"convolution 1x1 weight 2 bias 1", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *weights = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionWeightsDescriptorWithWidth:1 height:1 inputFeatureChannelCount:1 outputFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(2)];
            MLCTensor *biases = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(1)];
            MLCConvolutionLayer *layer = [MLCConvolutionLayer layerWithWeights:weights biases:biases descriptor:[MLCConvolutionDescriptor descriptorWithKernelWidth:1 kernelHeight:1 inputFeatureChannelCount:1 outputFeatureChannelCount:1]];
            return [graph nodeWithLayer:layer source:input];
        });
        through(@"fully connected 1x1 weight 2", imageShape, image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *weights = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionWeightsDescriptorWithWidth:1 height:1 inputFeatureChannelCount:1 outputFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(2)];
            MLCFullyConnectedLayer *layer = [MLCFullyConnectedLayer layerWithWeights:weights biases:nil descriptor:[MLCConvolutionDescriptor descriptorWithKernelWidth:1 kernelHeight:1 inputFeatureChannelCount:1 outputFeatureChannelCount:1]];
            return [graph nodeWithLayer:layer source:input];
        });
        through(@"batch norm", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *mean = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(1)];
            MLCTensor *variance = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(4)];
            MLCTensor *beta = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(0.5)];
            MLCTensor *gamma = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(2)];
            MLCBatchNormalizationLayer *layer = [MLCBatchNormalizationLayer layerWithFeatureChannelCount:1 mean:mean variance:variance beta:beta gamma:gamma varianceEpsilon:1e-5];
            return [graph nodeWithLayer:layer source:input];
        });
        through(@"gram matrix scale 2", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCGramMatrixLayer layerWithScale:2] source:input];
        });
        through(@"matmul", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCMatMulLayer layerWithDescriptor:[MLCMatMulDescriptor descriptor]] sources:@[ input, input ]];
        });
        through(@"gather", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *indices = [MLCTensor tensorWithDescriptor:described(@[ @1 ]) fillWithData:@(0)];
            return [graph gatherWithDimension:0 source:input indices:indices];
        });
        through(@"scatter", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *indices = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[ @1 ] dataType:MLCDataTypeInt32] fillWithData:@(0)];
            return [graph scatterWithDimension:0 source:input indices:indices copyFrom:input reductionType:MLCReductionTypeSum];
        });
        through(@"dropout", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            return [graph nodeWithLayer:[MLCDropoutLayer layerWithRate:0 seed:7] source:input];
        });
        through(@"layer normalization", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *beta = [MLCTensor tensorWithDescriptor:described(@[ @4 ]) fillWithData:@(0)];
            MLCTensor *gamma = [MLCTensor tensorWithDescriptor:described(@[ @4 ]) fillWithData:@(1)];
            MLCLayerNormalizationLayer *layer = [MLCLayerNormalizationLayer layerWithNormalizedShape:@[ @4 ] beta:beta gamma:gamma varianceEpsilon:1e-5];
            return [graph nodeWithLayer:layer source:input];
        });
        through(@"group normalization", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *beta = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(0)];
            MLCTensor *gamma = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(1)];
            MLCGroupNormalizationLayer *layer = [MLCGroupNormalizationLayer layerWithFeatureChannelCount:1 groupCount:1 beta:beta gamma:gamma varianceEpsilon:1e-5];
            return [graph nodeWithLayer:layer source:input];
        });
        through(@"instance normalization", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *beta = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(0)];
            MLCTensor *gamma = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:1 dataType:MLCDataTypeFloat32] fillWithData:@(1)];
            MLCInstanceNormalizationLayer *layer = [MLCInstanceNormalizationLayer layerWithFeatureChannelCount:1 beta:beta gamma:gamma varianceEpsilon:1e-5];
            return [graph nodeWithLayer:layer source:input];
        });
        through(@"selection", @[ @1, @1, @2, @2 ], image, ^(MLCGraph *graph, MLCTensor *input) {
            MLCTensor *condition = [MLCTensor tensorWithDescriptor:described(@[ @1, @1, @2, @2 ]) fillWithData:@(1)];
            return [graph selectWithSources:@[ input, input ] condition:condition];
        });
    }
    return 0;
}
