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
    NSString *variant = argc > 1 ? @(argv[1]) : @"relu-loss";
    @autoreleasepool {
        MLCDevice *device = [MLCDevice cpuDevice];
        MLCTensor *input = tensor(@[@2, @3]);
        MLCLayer *relu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];
        MLCLossLayer *loss = [MLCLossLayer softmaxCrossEntropyLossWithReductionType:MLCReductionTypeMean
                                                                     labelSmoothing:0.0f
                                                                         classCount:3
                                                                             weight:1.0f];
        MLCLayer *lossLayer = [variant isEqualToString:@"softmax"] ? (MLCLayer *)loss : (MLCLayer *)relu;

        MLCGraph *graph = [MLCGraph graph];
        MLCTensor *output = [graph nodeWithLayer:relu source:input];
        MLCGraph *lossGraph = [MLCGraph graph];
        MLCTensor *lossResult = [lossGraph nodeWithLayer:lossLayer sources:@[output, input]];
        printf("loss node\t%s\n", lossResult ? "made" : "(nil)");

        MLCTrainingGraph *training = [MLCTrainingGraph graphWithGraphObjects:@[graph, lossGraph]
                                                                   lossLayer:lossLayer
                                                                   optimizer:nil];
        report(@"addInputs lossLabels", [training addInputs:@{@"a": input} lossLabels:@{@"a": input}]);
        report(@"addOutputs", [training addOutputs:@{@"y": output}]);
        report(@"compile", [training compileWithOptions:0 device:device]);
        printf("deviceMemorySize\t%lu\n", (unsigned long)training.deviceMemorySize);
        report(@"compile constants",
               [training compileWithOptions:0 device:device inputTensors:@{@"a": input}
                            inputTensorsData:@{@"a": dataFor(input)}]);
        @try {
            report(@"executeForward", [training executeForwardWithBatchSize:2 options:MLCExecutionOptionsSynchronous
                                                           completionHandler:nil]);
        } @catch (NSException *exception) {
            printf("executeForward\tRAISED %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }
        @try {
            report(@"executeForward outputsData",
                   [training executeForwardWithBatchSize:2 options:MLCExecutionOptionsSynchronous
                                            outputsData:@{@"y": dataFor(output)} completionHandler:nil]);
        } @catch (NSException *exception) {
            printf("executeForward outputsData\tRAISED %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }
        @try {
            report(@"executeGradient", [training executeGradientWithBatchSize:2 options:MLCExecutionOptionsSynchronous
                                                            completionHandler:nil]);
        } @catch (NSException *exception) {
            printf("executeGradient\tRAISED %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }
        @try {
            report(@"executeOptimizerUpdate",
                   [training executeOptimizerUpdateWithOptions:MLCExecutionOptionsSynchronous completionHandler:nil]);
        } @catch (NSException *exception) {
            printf("executeOptimizerUpdate\tRAISED %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }

        @try {
            MLCInferenceGraph *empty = [MLCInferenceGraph graphWithGraphObjects:@[]];
            report(@"empty graph compile", [empty compileWithOptions:0 device:device]);
        } @catch (NSException *exception) {
            printf("empty graph compile\tRAISED %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }

        for (NSString *name in @[ @"MLCInferenceGraph", @"MLCTrainingGraph" ]) {
            Class cls = NSClassFromString(name);
            id fresh = [cls new];
            MLCGraph *made = (MLCGraph *)[[cls alloc] init];
            printf("%s\tnew %s init %s\n", name.UTF8String, fresh ? "an object" : "(nil)", made ? "an object" : "(nil)");
        }
    }
    return 0;
}
