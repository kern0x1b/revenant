#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <MLCompute/MLCompute.h>

static MLCTensor *tensor(NSArray<NSNumber *> *shape)
{
    return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:MLCDataTypeFloat32]
                                   fillWithData:@0];
}

static MLCTensorData *dataFor(MLCTensor *tensor)
{
    NSUInteger count = 1;
    for (NSNumber *n in tensor.descriptor.shape)
        count *= (NSUInteger)n.integerValue;
    NSMutableData *bytes = [NSMutableData dataWithLength:count * sizeof(float)];
    return [MLCTensorData dataWithImmutableBytesNoCopy:bytes.bytes length:bytes.length];
}

static void report(NSString *name, BOOL ok)
{
    printf("%s\t%s\n", name.UTF8String, ok ? "YES" : "NO");
}

int main(int argc, char **argv)
{
    setbuf(stdout, NULL);
    NSString *which = argc > 1 ? @(argv[1]) : @"cpu";
    NSString *form = argc > 2 ? @(argv[2]) : @"plain";
    MLCExecutionOptions options = MLCExecutionOptionsNone;
    if (argc > 3 && [@(argv[3]) isEqualToString:@"sync"]) {
        options = MLCExecutionOptionsSynchronous;
    }
    @autoreleasepool {
        MLCDevice *device = [MLCDevice cpuDevice];
        if ([which isEqualToString:@"gpu"]) {
            device = [MLCDevice deviceWithType:MLCDeviceTypeGPU];
        } else if ([which isEqualToString:@"ane"]) {
            device = [MLCDevice deviceWithType:MLCDeviceTypeANE];
        } else if ([which isEqualToString:@"nil"]) {
            device = nil;
        }

        MLCTensor *input = tensor(@[@2, @3]);
        MLCLayer *relu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];
        MLCGraph *graph = [MLCGraph graph];
        MLCTensor *output = [graph nodeWithLayer:relu source:input];
        MLCInferenceGraph *inference = [MLCInferenceGraph graphWithGraphObjects:@[graph]];
        report(@"addInputs", [inference addInputs:@{@"a": input}]);
        report(@"addOutputs", [inference addOutputs:@{@"y": output}]);
        if (argc > 4 && [@(argv[4]) isEqualToString:@"declared"]) {
            report(@"addInputs lossLabels weights",
                   [inference addInputs:@{@"a": input} lossLabels:@{@"a": input} lossLabelWeights:@{@"a": input}]);
        }

        NSDictionary<NSString *, MLCTensorData *> *inputs = @{@"a": dataFor(input)};
        NSDictionary<NSString *, MLCTensorData *> *outputs = @{@"y": dataFor(output)};

        report(@"compile constants nil",
               [inference compileWithOptions:0 device:device inputTensors:nil inputTensorsData:nil]);
        report(@"compile constants empty",
               [inference compileWithOptions:0 device:device inputTensors:@{} inputTensorsData:@{}]);
        report(@"compile constants tensors only",
               [inference compileWithOptions:0 device:device inputTensors:@{@"a": input} inputTensorsData:@{}]);
        report(@"compile constants data only",
               [inference compileWithOptions:0 device:device inputTensors:@{} inputTensorsData:@{@"a": dataFor(input)}]);
        report(@"compile constants both",
               [inference compileWithOptions:0 device:device inputTensors:@{@"a": input}
                            inputTensorsData:@{@"a": dataFor(input)}]);

        @try {
            report(@"compile", [inference compileWithOptions:0 device:device]);
            BOOL ok = NO;
            if ([form isEqualToString:@"plain"]) {
                ok = [inference executeWithInputsData:inputs batchSize:2 options:options completionHandler:nil];
            } else if ([form isEqualToString:@"out"]) {
                ok = [inference executeWithInputsData:inputs outputsData:outputs batchSize:2 options:options
                                     completionHandler:nil];
            } else if ([form isEqualToString:@"loss"]) {
                ok = [inference executeWithInputsData:inputs lossLabelsData:inputs lossLabelWeightsData:inputs
                                        batchSize:2 options:options completionHandler:nil];
            } else {
                ok = [inference executeWithInputsData:inputs lossLabelsData:inputs lossLabelWeightsData:inputs
                                         outputsData:outputs batchSize:2 options:options completionHandler:nil];
            }
            report([@"execute " stringByAppendingString:form], ok);
        } @catch (NSException *exception) {
            printf("execute %s\tRAISED %s: %s\n", form.UTF8String, exception.name.UTF8String, exception.reason.UTF8String);
        }

        @try {
            MLCInferenceGraph *empty = [MLCInferenceGraph graphWithGraphObjects:@[]];
            printf("empty graph\tlayers %lu\n", (unsigned long)empty.layers.count);
            report(@"empty compile", [empty compileWithOptions:0 device:device]);
        } @catch (NSException *exception) {
            printf("empty compile\tRAISED %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }

        MLCGraph *second = [MLCGraph graph];
        printf("node of a used layer in a second graph\t%s\n",
               [second nodeWithLayer:relu source:input] ? "made" : "(nil)");
        printf("node of a fresh layer in a second graph\t%s\n",
               [second nodeWithLayer:[MLCActivationLayer layerWithDescriptor:
                                                  [MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]]
                                source:input]
                   ? "made"
                   : "(nil)");

        MLCLayer *thirdRelu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];
        MLCGraph *third = [MLCGraph graph];
        [third nodeWithLayer:thirdRelu source:input];
        MLCInferenceGraph *later = [MLCInferenceGraph graphWithGraphObjects:@[third]];
        report(@"compile with no device first", [later compileWithOptions:0 device:nil]);
        report(@"compile with a device after", [later compileWithOptions:0 device:device]);
        report(@"compile with no device after", [later compileWithOptions:0 device:nil]);
    }
    return 0;
}
