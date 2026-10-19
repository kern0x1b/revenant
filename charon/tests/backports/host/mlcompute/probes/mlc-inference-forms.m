// mlc-inference-forms.m - which binding of the inference graph's execute family answers YES on this host, and
// which one answers NO, one case per process so a raise in one cannot stop the next.
//
// The question is the binding, not the member: over a graph that has NOT declared its loss label tensors the
// two forms that carry loss label data answer NO and the two that do not answer YES, and over the same graph
// after -addInputs:lossLabels:lossLabelWeights: all four answer YES. That is what the header's own comment asks
// a caller to do, and it is what tests/backports/host/mlcompute/inference-cases.m does before it asks the
// four forms of either side.
//
// argv[1] is the device (cpu, gpu, ane, nil), argv[2] the form (plain, out, loss, all), argv[3] the execution
// options (none, sync) and argv[4] whether the loss labels are declared on the graph before the execute
// (declared). What it also measures, and what facts/MLCompute/Graph.md records: the 14.0 compile answers NO
// for a nil device on a graph that has not been compiled, and -compileWithOptions:device:inputTensors:inputTensorsData:
// answers YES for nil dictionaries, two empty ones, tensors with no data, data with no tensors and both.
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

        // The 14.5 compile, in every shape of argument it accepts, over a graph with one node.
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

        // A graph made of no graph objects at all, and the compile that raises inside the host.
        @try {
            MLCInferenceGraph *empty = [MLCInferenceGraph graphWithGraphObjects:@[]];
            printf("empty graph\tlayers %lu\n", (unsigned long)empty.layers.count);
            report(@"empty compile", [empty compileWithOptions:0 device:device]);
        } @catch (NSException *exception) {
            printf("empty compile\tRAISED %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }

        // A layer that is already a node of another graph, used in a second graph: the node answers nil.
        MLCGraph *second = [MLCGraph graph];
        printf("node of a used layer in a second graph\t%s\n",
               [second nodeWithLayer:relu source:input] ? "made" : "(nil)");
        printf("node of a fresh layer in a second graph\t%s\n",
               [second nodeWithLayer:[MLCActivationLayer layerWithDescriptor:
                                                  [MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]]
                                source:input]
                   ? "made"
                   : "(nil)");

        // The compile with no device, on a graph nothing has compiled: the rule deviceMemorySize and the
        // compile share, asked here before anything else has compiled in this process. The layer is one of its
        // own, because a layer that is already a node of a graph answers nil when it is used in a second one.
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