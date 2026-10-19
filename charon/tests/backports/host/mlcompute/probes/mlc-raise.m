// mlc-raise.m - which binding of an inference execute raises on this host, one variant per process.
//
// The one that matters for the harness is MLCExecutionOptionsSkipWritingInputDataToDevice, which makes the
// plain execute form raise an NSRangeException inside the host; every case therefore passes
// MLCExecutionOptionsNone or MLCExecutionOptionsSynchronous. The other three variants are here so the
// negative is measured rather than assumed: the data of an input may be shorter than the tensor, longer than
// it, and a tensor may be of rank 1, and none of those raises on this host.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <MLCompute/MLCompute.h>

static MLCTensor *tensor(NSArray<NSNumber *> *shape)
{
    return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:MLCDataTypeFloat32]
                                   fillWithData:@0];
}

static MLCTensorData *dataOfLength(NSUInteger bytes)
{
    NSMutableData *buffer = [NSMutableData dataWithLength:bytes];
    return [MLCTensorData dataWithImmutableBytesNoCopy:buffer.bytes length:buffer.length];
}

int main(int argc, char **argv)
{
    setbuf(stdout, NULL);
    NSString *variant = argc > 1 ? @(argv[1]) : @"skipwriting";
    @autoreleasepool {
        MLCDevice *device = [MLCDevice cpuDevice];
        NSArray<NSNumber *> *shape = [variant isEqualToString:@"rank1"] ? @[@6] : @[@2, @3];
        MLCTensor *input = tensor(shape);
        MLCLayer *relu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];
        MLCGraph *graph = [MLCGraph graph];
        [graph nodeWithLayer:relu source:input];
        MLCInferenceGraph *inference = [MLCInferenceGraph graphWithGraphObjects:@[graph]];
        [inference addInputs:@{@"a": input}];

        MLCExecutionOptions options = MLCExecutionOptionsNone;
        if ([variant isEqualToString:@"skipwriting"]) {
            options = MLCExecutionOptionsSkipWritingInputDataToDevice;
        } else if ([variant isEqualToString:@"sync"]) {
            options = MLCExecutionOptionsSynchronous;
        }

        NSUInteger length = 24;
        if ([variant isEqualToString:@"short"]) {
            length = 4;
        } else if ([variant isEqualToString:@"long"]) {
            length = 40;
        }
        NSDictionary<NSString *, MLCTensorData *> *inputs = @{@"a": dataOfLength(length)};

        printf("compile\t%s\n", [inference compileWithOptions:0 device:device] ? "YES" : "NO");
        @try {
            printf("execute\t%s\n",
                   [inference executeWithInputsData:inputs batchSize:2 options:options completionHandler:nil]
                       ? "YES"
                       : "NO");
            if ([variant isEqualToString:@"twice"]) {
                printf("execute again\t%s\n",
                       [inference executeWithInputsData:inputs batchSize:2 options:options completionHandler:nil]
                           ? "YES"
                           : "NO");
            }
        } @catch (NSException *exception) {
            printf("execute\tRAISED %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }
    }
    return 0;
}