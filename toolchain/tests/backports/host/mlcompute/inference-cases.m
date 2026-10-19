#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

#import "mlcompute-16.h"

void revenant_mlcompute_inference_cases(void);

static MLCDevice *inferenceDevice;

static MLCTensor *inferenceTensor(NSArray<NSNumber *> *shape)
{
    return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:MLCDataTypeFloat32]
                                   fillWithData:@0];
}

static MLCTensorData *inferenceData(MLCTensor *tensor)
{
    NSUInteger count = tensor.descriptor.tensorAllocationSizeInBytes;
    NSMutableData *bytes = [NSMutableData dataWithLength:count];
    return [MLCTensorData dataWithImmutableBytesNoCopy:bytes.bytes length:bytes.length];
}

static void key(NSString *name, NSString *value)
{
    printf("%s\t%s\n", name.UTF8String, value.UTF8String);
}

static void answer(NSString *name, BOOL value)
{
    key(name, value ? @"YES" : @"NO");
}

static void number(NSString *name, NSUInteger value)
{
    key(name, [NSString stringWithFormat:@"%lu", (unsigned long)value]);
}

static NSString *shapeOf(MLCTensor *tensor)
{
    if (!tensor) {
        return @"(nil)";
    }
    NSMutableString *text = [NSMutableString string];
    for (NSNumber *n in tensor.descriptor.shape) {
        if (text.length) {
            [text appendString:@","];
        }
        [text appendFormat:@"%@", n];
    }
    return [NSString stringWithFormat:@"[%@] type=%ld", text, (long)tensor.descriptor.dataType];
}

static NSString *shapesOf(NSArray<MLCTensor *> *list)
{
    if (list.count == 0) {
        return @"0 (none)";
    }
    NSMutableString *text = [NSMutableString string];
    for (MLCTensor *tensor in list) {
        if (text.length) {
            [text appendString:@" "];
        }
        [text appendString:shapeOf(tensor)];
    }
    return [NSString stringWithFormat:@"%lu %@", (unsigned long)list.count, text];
}

static float imageBytes[4] = { -1.0f, 2.0f, -3.0f, 4.0f };

static NSString *valuesIn(MLCTensorData *data)
{
    if (!data.bytes || data.length < sizeof(imageBytes)) {
        return @"(no bytes)";
    }
    const float *values = (const float *)data.bytes;
    return [NSString stringWithFormat:@"%g %g %g %g", values[0], values[1], values[2], values[3]];
}

void revenant_mlcompute_inference_cases(void);

void revenant_mlcompute_inference_cases(void)
{
    @autoreleasepool {
        inferenceDevice = [MLCDevice cpuDevice];
        MLCTensor *input = inferenceTensor(@[@2, @3]);
        MLCLayer *relu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];
        MLCLayer *otherRelu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];

        MLCGraph *graph = [MLCGraph graph];
        MLCTensor *output = [graph nodeWithLayer:relu source:input];
        MLCInferenceGraph *inference = [MLCInferenceGraph graphWithGraphObjects:@[graph]];

        number(@"inference layers", inference.layers.count);
        key(@"inference device before compile", inference.device ? @"a device" : @"(nil)");
        key(@"inference sources", shapesOf([inference sourceTensorsForLayer:relu]));
        key(@"inference results", shapesOf([inference resultTensorsForLayer:relu]));
        number(@"inference memory before", inference.deviceMemorySize);

        answer(@"inference addInputs known", [inference addInputs:@{@"input": input}]);
        answer(@"inference addInputs unknown", [inference addInputs:@{@"zz": input}]);
        answer(@"inference addInputs empty", [inference addInputs:@{}]);
        answer(@"inference addInputs nil", [inference addInputs:nil]);
        answer(@"inference addInputs lossLabels weights",
               [inference addInputs:@{@"input": input} lossLabels:@{@"input": input} lossLabelWeights:@{@"input": input}]);
        answer(@"inference addOutputs known", [inference addOutputs:@{@"output": output}]);
        answer(@"inference addOutputs unknown", [inference addOutputs:@{@"zz": output}]);
        answer(@"inference addOutputs nil", [inference addOutputs:nil]);

        MLCGraph *second = [MLCGraph graph];
        [second nodeWithLayer:relu source:input];
        answer(@"inference link empty", [inference linkWithGraphs:@[]]);
        answer(@"inference link itself", [inference linkWithGraphs:@[inference]]);
        answer(@"inference link another", [inference linkWithGraphs:@[[MLCInferenceGraph graphWithGraphObjects:@[second]]]]);
        number(@"inference layers after link", inference.layers.count);
        key(@"inference results after link", shapesOf([inference resultTensorsForLayer:relu]));

        answer(@"inference compile", [inference compileWithOptions:0 device:inferenceDevice]);
        key(@"inference device after compile", inference.device ? @"a device" : @"(nil)");
        number(@"inference memory after compile", inference.deviceMemorySize);
        answer(@"inference compile again", [inference compileWithOptions:0 device:inferenceDevice]);
        answer(@"inference compile with no device after", [inference compileWithOptions:0 device:nil]);

        answer(@"inference compile constants nil",
               [inference compileWithOptions:0 device:inferenceDevice inputTensors:nil inputTensorsData:nil]);
        answer(@"inference compile constants empty",
               [inference compileWithOptions:0 device:inferenceDevice inputTensors:@{} inputTensorsData:@{}]);
        answer(@"inference compile constants both",
               [inference compileWithOptions:0 device:inferenceDevice inputTensors:@{@"input": input}
                            inputTensorsData:@{@"input": inferenceData(input)}]);

        NSDictionary<NSString *, MLCTensorData *> *inputsData = @{@"input": inferenceData(input)};
        answer(@"inference execute", [inference executeWithInputsData:inputsData batchSize:2 options:0
                                                   completionHandler:nil]);
        answer(@"inference execute outputs",
               [inference executeWithInputsData:inputsData outputsData:@{@"output": inferenceData(output)}
                                     batchSize:2 options:0 completionHandler:nil]);
        answer(@"inference execute lossLabels",
               [inference executeWithInputsData:inputsData lossLabelsData:inputsData lossLabelWeightsData:inputsData
                                     batchSize:2 options:0 completionHandler:nil]);
        answer(@"inference execute all",
               [inference executeWithInputsData:inputsData lossLabelsData:inputsData lossLabelWeightsData:inputsData
                                    outputsData:@{@"output": inferenceData(output)} batchSize:2 options:0
                              completionHandler:nil]);

        MLCTensor *image = inferenceTensor(@[@1, @1, @2, @2]);
        MLCLayer *imageRelu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];
        MLCGraph *imageGraph = [MLCGraph graph];
        MLCTensor *imageOutput = [imageGraph nodeWithLayer:imageRelu source:image];
        MLCInferenceGraph *reluGraph = [MLCInferenceGraph graphWithGraphObjects:@[imageGraph]];
        [reluGraph addInputs:@{@"input": image}];
        [reluGraph addOutputs:@{@"output": imageOutput}];
        [reluGraph compileWithOptions:0 device:inferenceDevice];
        MLCTensorData *feed = [MLCTensorData dataWithBytesNoCopy:imageBytes length:sizeof(imageBytes)];
        MLCTensorData *result = [MLCTensorData dataWithBytesNoCopy:calloc(1, sizeof(imageBytes)) length:sizeof(imageBytes)];
        __block BOOL called = NO;
        __block BOOL failed = NO;
        BOOL ran = [reluGraph executeWithInputsData:@{@"input": feed} outputsData:@{@"output": result}
                                           batchSize:1 options:MLCExecutionOptionsSynchronous
                                 completionHandler:^(MLCTensor *tensor, NSError *error, NSTimeInterval time) {
                                     called = YES;
                                     failed = error != nil;
                                 }];
        answer(@"relu execute", ran);
        key(@"relu completion handler", called ? (failed ? @"called with an error" : @"called with no error") : @"not called");
        key(@"relu values", valuesIn(result));

        MLCTrainingGraph *training = [MLCTrainingGraph graphWithGraphObjects:@[graph] lossLayer:relu optimizer:nil];
        key(@"training optimizer without one", training.optimizer ? @"kept" : @"(nil)");
        number(@"training layers", training.layers.count);
        key(@"training device", training.device ? @"a device" : @"(nil)");
        key(@"training sources", shapesOf([training sourceTensorsForLayer:relu]));
        key(@"training results", shapesOf([training resultTensorsForLayer:relu]));
        number(@"training memory", training.deviceMemorySize);
        answer(@"training addInputs lossLabels", [training addInputs:@{@"input": input} lossLabels:@{@"input": input}]);
        answer(@"training addInputs lossLabels weights",
               [training addInputs:@{@"input": input} lossLabels:@{@"input": input} lossLabelWeights:@{@"input": input}]);
        answer(@"training addOutputs", [training addOutputs:@{@"output": output}]);
        answer(@"training link empty", [training linkWithGraphs:@[]]);
        answer(@"training link itself", [training linkWithGraphs:@[training]]);
        answer(@"training link another",
               [training linkWithGraphs:@[[MLCTrainingGraph graphWithGraphObjects:@[second] lossLayer:nil optimizer:nil]]]);
        answer(@"training compile", [training compileWithOptions:0 device:inferenceDevice]);
        number(@"training memory after compile", training.deviceMemorySize);
        answer(@"training compile constants",
               [training compileWithOptions:0 device:inferenceDevice inputTensors:@{@"input": input}
                            inputTensorsData:@{@"input": inferenceData(input)}]);
        answer(@"training compileOptimizer", [training compileOptimizer:
                                                  [MLCSGDOptimizer optimizerWithDescriptor:
                                                      [MLCOptimizerDescriptor descriptorWithLearningRate:0.01f
                                                                                           gradientRescale:1.0f
                                                                                    regularizationType:MLCRegularizationTypeNone
                                                                                   regularizationScale:0.0f]]]);

        MLCTrainingGraph *withOptimizer = [MLCTrainingGraph graphWithGraphObjects:@[graph]
                                                                       lossLayer:relu
                                                                       optimizer:[MLCAdamOptimizer optimizerWithDescriptor:
                                                                                       [MLCOptimizerDescriptor descriptorWithLearningRate:0.01f
                                                                                                        gradientRescale:1.0f
                                                                                             regularizationType:MLCRegularizationTypeNone
                                                                                            regularizationScale:0.0f]]];
        key(@"training optimizer with one", withOptimizer.optimizer ? @"kept" : @"(nil)");

        MLCTensor *unknown = inferenceTensor(@[@2, @3]);
        key(@"training gradient for the input", shapeOf([training gradientTensorForInput:input]));
        key(@"training gradient for the result", shapeOf([training gradientTensorForInput:output]));
        key(@"training gradient for an unknown tensor", shapeOf([training gradientTensorForInput:unknown]));
        key(@"training source gradients", shapesOf([training sourceGradientTensorsForLayer:relu]));
        key(@"training source gradients unknown layer", shapesOf([training sourceGradientTensorsForLayer:otherRelu]));
        key(@"training result gradients", shapesOf([training resultGradientTensorsForLayer:relu]));
        key(@"training gradient data for a parameter", [training gradientDataForParameter:input layer:relu] ? @"some data" : @"(nil)");
        key(@"training user gradient", shapeOf([training allocateUserGradientForTensor:input]));
        key(@"training user gradient unknown", shapeOf([training allocateUserGradientForTensor:unknown]));
        answer(@"training stopGradient", [training stopGradientForTensors:@[input]]);
        answer(@"training stopGradient unknown", [training stopGradientForTensors:@[unknown]]);
        answer(@"training setTrainingTensorParameters", [training setTrainingTensorParameters:@[]]);
        answer(@"training bindOptimizerData", [training bindOptimizerData:@[inferenceData(input)] deviceData:nil withTensor:input]);
        answer(@"training bindOptimizerData unknown", [training bindOptimizerData:@[inferenceData(input)] deviceData:nil withTensor:unknown]);

        answer(@"training executeForward", [training executeForwardWithBatchSize:2 options:0 completionHandler:nil]);
        answer(@"training executeForward outputs",
               [training executeForwardWithBatchSize:2 options:0 outputsData:@{@"output": inferenceData(output)}
                                   completionHandler:nil]);
        answer(@"training executeGradient", [training executeGradientWithBatchSize:2 options:0 completionHandler:nil]);
        answer(@"training executeGradient outputs",
               [training executeGradientWithBatchSize:2 options:0 outputsData:@{@"output": inferenceData(output)}
                                    completionHandler:nil]);
        answer(@"training executeOptimizerUpdate", [training executeOptimizerUpdateWithOptions:0 completionHandler:nil]);
        answer(@"training execute", [training executeWithInputsData:inputsData lossLabelsData:inputsData
                                                 lossLabelWeightsData:inputsData batchSize:2 options:0
                                           completionHandler:nil]);
        answer(@"training execute outputs",
               [training executeWithInputsData:inputsData lossLabelsData:inputsData lossLabelWeightsData:inputsData
                                  outputsData:@{@"output": inferenceData(output)} batchSize:2 options:0
                            completionHandler:nil]);
        [training synchronizeUpdates];
        key(@"training synchronizeUpdates", @"called");

        MLCGraph *freshInference = (MLCGraph *)RevenantNew([MLCInferenceGraph class]);
        key(@"inference init", freshInference ? @"an object" : @"(nil)");
        key(@"inference init layers", [NSString stringWithFormat:@"%lu", (unsigned long)freshInference.layers.count]);
        key(@"inference init device", freshInference.device ? @"a device" : @"(nil)");
        MLCGraph *freshTraining = (MLCGraph *)RevenantNew([MLCTrainingGraph class]);
        key(@"training init", freshTraining ? @"an object" : @"(nil)");
        key(@"training init layers", [NSString stringWithFormat:@"%lu", (unsigned long)freshTraining.layers.count]);
        key(@"training init device", freshTraining.device ? @"a device" : @"(nil)");
    }
}
