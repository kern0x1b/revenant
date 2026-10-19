// mlc-inference.m - what this host's own MLCompute answers for MLCInferenceGraph and MLCTrainingGraph: what
// the factories answer, what addInputs:, addOutputs:, linkWithGraphs:, compileWithOptions:device: and the
// execute family answer, what deviceMemorySize is before and after a compile, and what the gradient and
// optimizer members answer.
//
// Read once, before the port's own answers are written down. Every case here is one the harness can ask of
// both sides, and the two that raise on this host are named in the facts rather than asked.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <MLCompute/MLCompute.h>

static MLCDevice *device;

static MLCTensor *tensor(NSArray<NSNumber *> *shape)
{
    return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:MLCDataTypeFloat32]
                                   fillWithData:@0];
}

static MLCTensorData *dataFor(MLCTensor *t)
{
    NSUInteger count = 1;
    for (NSNumber *n in t.descriptor.shape) count *= (NSUInteger)n.integerValue;
    NSMutableData *bytes = [NSMutableData dataWithLength:count * sizeof(float)];
    return [MLCTensorData dataWithImmutableBytesNoCopy:bytes.bytes length:bytes.length];
}

static void key(NSString *name, NSString *value)
{
    printf("%s\t%s\n", name.UTF8String, value.UTF8String);
}

static void yes(NSString *name, BOOL value)
{
    key(name, value ? @"YES" : @"NO");
}

static void num(NSString *name, NSUInteger value)
{
    key(name, [NSString stringWithFormat:@"%lu", (unsigned long)value]);
}

static void shape(NSString *name, MLCTensor *t)
{
    if (!t) { key(name, @"(nil)"); return; }
    NSMutableString *text = [NSMutableString string];
    for (NSNumber *n in t.descriptor.shape) {
        if (text.length) [text appendString:@","];
        [text appendFormat:@"%@", n];
    }
    key(name, ([NSString stringWithFormat:@"[%@]", text]));
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        device = [MLCDevice cpuDevice];
        MLCTensor *input = tensor(@[@2, @3]);
        MLCTensor *other = tensor(@[@2, @3]);
        MLCLayer *relu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];

        // What the two factories answer about a graph that has one node in it.
        MLCGraph *graph = [MLCGraph graph];
        MLCTensor *output = [graph nodeWithLayer:relu source:input];
        MLCInferenceGraph *inference = [MLCInferenceGraph graphWithGraphObjects:@[graph]];
        MLCTrainingGraph *training = [MLCTrainingGraph graphWithGraphObjects:@[graph]
                                                                   lossLayer:relu
                                                                   optimizer:[MLCAdamOptimizer optimizerWithDescriptor:
                                                                               [MLCOptimizerDescriptor descriptorWithLearningRate:0.01f
                                                                                                                gradientRescale:1.0f
                                                                                                     regularizationType:MLCRegularizationTypeNone
                                                                                                                regularizationScale:0.0f]]];
        key(@"inference class", [NSString stringWithUTF8String:class_getName([inference class])]);
        key(@"training class", [NSString stringWithUTF8String:class_getName([training class])]);
        num(@"inference deviceMemorySize before", inference.deviceMemorySize);
        num(@"training deviceMemorySize before", training.deviceMemorySize);
        key(@"training optimizer", training.optimizer ? @"kept" : @"(nil)");

        // addInputs: and addOutputs:, over a name the graph knows and one it does not.
        yes(@"inference addInputs known", [inference addInputs:@{@"a": input}]);
        yes(@"inference addInputs unknown", [inference addInputs:@{@"zz": input}]);
        yes(@"inference addInputs empty", [inference addInputs:@{}]);
        yes(@"inference addInputs nil", [inference addInputs:nil]);
        yes(@"inference addOutputs known", [inference addOutputs:@{@"y": output}]);
        yes(@"inference addOutputs unknown", [inference addOutputs:@{@"zz": output}]);
        yes(@"inference addOutputs nil", [inference addOutputs:nil]);
        yes(@"training addInputs lossLabels", [training addInputs:@{@"a": input} lossLabels:@{@"a": input}]);
        yes(@"training addInputs lossLabels weights",
            [training addInputs:@{@"a": input} lossLabels:@{@"a": input} lossLabelWeights:@{@"a": input}]);
        yes(@"training addOutputs", [training addOutputs:@{@"y": output}]);

        // linkWithGraphs: with nothing, with itself, and with another of its own kind.
        yes(@"inference link empty", [inference linkWithGraphs:@[]]);
        yes(@"inference link itself", [inference linkWithGraphs:@[inference]]);
        yes(@"inference link another",
            [inference linkWithGraphs:@[[MLCInferenceGraph graphWithGraphObjects:@[graph]]]]);
        yes(@"training link empty", [training linkWithGraphs:@[]]);
        yes(@"training link itself", [training linkWithGraphs:@[training]]);
        yes(@"training link another",
            [training linkWithGraphs:@[[MLCTrainingGraph graphWithGraphObjects:@[graph] lossLayer:nil optimizer:nil]]]);

        // compileWithOptions:device: and its two shorter forms.
        num(@"inference deviceMemorySize after inputs", inference.deviceMemorySize);
        yes(@"inference compile", [inference compileWithOptions:0 device:device]);
        num(@"inference deviceMemorySize after compile", inference.deviceMemorySize);
        yes(@"inference compile nil device", [inference compileWithOptions:0 device:nil]);
        yes(@"inference compile twice", [inference compileWithOptions:0 device:device]);
        yes(@"inference compile after execute", (([inference executeWithInputsData:@{@"a": dataFor(input)}
                                                                                  batchSize:2
                                                                                  options:0
                                                                            completionHandler:nil])
                                                ? @"YES" : @"NO"));
        num(@"inference deviceMemorySize after execute", inference.deviceMemorySize);

        yes(@"training compile", [training compileWithOptions:0 device:device]);
        num(@"training deviceMemorySize after compile", training.deviceMemorySize);
        yes(@"training compileOptimizer", [training compileOptimizer:[MLCSGDOptimizer optimizerWithDescriptor:
                                                                    [MLCOptimizerDescriptor descriptorWithLearningRate:0.01f
                                                                                                     gradientRescale:1.0f
                                                                                              regularizationType:MLCRegularizationTypeNone
                                                                                                     regularizationScale:0.0f]]]);

        // The gradient and the optimizer members, over an input the graph was given.
        shape(@"training gradientTensorForInput", [training gradientTensorForInput:input]);
        shape(@"training gradientTensorForOutput", [training gradientTensorForInput:output]);
        shape(@"training gradientTensorForUnknown", [training gradientTensorForInput:other]);
        num(@"training sourceGradientTensorsForLayer", [training sourceGradientTensorsForLayer:relu].count);
        num(@"training resultGradientTensorsForLayer", [training resultGradientTensorsForLayer:relu].count);
        key(@"training gradientDataForParameter",
            [training gradientDataForParameter:input layer:relu] ? @"some data" : @"(nil)");
        shape(@"training allocateUserGradientForTensor", [training allocateUserGradientForTensor:input]);
        shape(@"training allocateUserGradientForUnknown", [training allocateUserGradientForTensor:other]);
        yes(@"training stopGradientForTensors", [training stopGradientForTensors:@[input]]);
        yes(@"training stopGradientForUnknown", [training stopGradientForTensors:@[other]]);
        yes(@"training setTrainingTensorParameters", [training setTrainingTensorParameters:@[]]);
        yes(@"training bindOptimizerData", [training bindOptimizerData:@[dataFor(input)] deviceData:nil withTensor:input]);
        yes(@"training bindOptimizerData unknown", [training bindOptimizerData:@[dataFor(input)] deviceData:nil withTensor:other]);
        [training synchronizeUpdates];

        // The training execute family, one form each, so the shape of the answer is measured and not guessed.
        yes(@"training executeForward", [training executeForwardWithBatchSize:2 options:0 completionHandler:nil]);
        yes(@"training executeForward outputsData",
            [training executeForwardWithBatchSize:2 options:0 outputsData:@{@"y": dataFor(output)} completionHandler:nil]);
        yes(@"training executeGradient", [training executeGradientWithBatchSize:2 options:0 completionHandler:nil]);
        yes(@"training executeOptimizerUpdate", [training executeOptimizerUpdateWithOptions:0 completionHandler:nil]);
        yes(@"training execute", [training executeWithInputsData:@{@"a": dataFor(input)}
                                              lossLabelsData:@{@"a": dataFor(input)}
                                              lossLabelWeightsData:@{@"a": dataFor(input)}
                                                        batchSize:2
                                                          options:0
                                                completionHandler:nil]);
        yes(@"training execute outputsData",
            [training executeWithInputsData:@{@"a": dataFor(input)}
                          lossLabelsData:@{@"a": dataFor(input)}
                   lossLabelWeightsData:@{@"a": dataFor(input)}
                              outputsData:@{@"y": dataFor(output)}
                                 batchSize:2
                                   options:0
                         completionHandler:nil]);
        num(@"training deviceMemorySize at the end", training.deviceMemorySize);

        // What a training graph answers for a nil optimizer and a nil loss layer.
        MLCTrainingGraph *bare = [MLCTrainingGraph graphWithGraphObjects:@[graph] lossLayer:nil optimizer:nil];
        key(@"bare optimizer", bare.optimizer ? @"kept" : @"(nil)");
        yes(@"bare compile", [bare compileWithOptions:0 device:device]);
        num(@"bare deviceMemorySize", bare.deviceMemorySize);
        yes(@"bare executeForward", [bare executeForwardWithBatchSize:2 options:0 completionHandler:nil]);
    }
    return 0;
}