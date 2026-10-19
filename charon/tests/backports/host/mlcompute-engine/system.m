// The host's own MLCompute, asked what each of the twenty-one activation types computes for a 2x2 image
// of one channel holding 1, 2, 3, 4. This is the side the port is held to, and it is the same question
// tests/backports/host/mlcompute/engine.m asked when the measurements were taken.
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <string.h>
#import <MLCompute/MLCompute.h>
#import "cases.h"

// The four values, each as the bits of the float rather than as a decimal: %g is six significant
// digits and the GELU's constant differs in the seventh, so a decimal comparison cannot see the error
// this differential exists to catch.
static uint32_t charon_bits(float value)
{
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static void print_values(const char *name, const float *values)
{
    printf("activation %s\t%08x,%08x,%08x,%08x\n", name, charon_bits(values[0]), charon_bits(values[1]),
           charon_bits(values[2]), charon_bits(values[3]));
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        for (int type = 0; type < CHARON_CASES; type++) {
            MLCTensorDescriptor *descriptor = [MLCTensorDescriptor descriptorWithShape:@[ @1, @1, @2, @2 ] dataType:MLCDataTypeFloat32];
            MLCTensor *input = [MLCTensor tensorWithDescriptor:descriptor];
            [input bindAndWriteData:[MLCTensorData dataWithBytesNoCopy:(float[4]){ 1, 2, 3, 4 } length:4 * sizeof(float)] toDevice:nil];
            MLCTensor *result = [MLCTensor tensorWithDescriptor:descriptor];
            [result bindAndWriteData:[MLCTensorData dataWithBytesNoCopy:calloc(1, 4 * sizeof(float)) length:4 * sizeof(float)] toDevice:nil];
            MLCActivationLayer *layer = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:type]];

            // The result of an execute is written into the buffer named in outputsData:, and the graph's own
            // tensor holds nothing - measured on the host while the engine's numbers were taken. So the
            // buffer is kept and read, not the tensor.
            float *out = calloc(1, 4 * sizeof(float));
            MLCTensorData *outData = [MLCTensorData dataWithBytesNoCopy:out length:4 * sizeof(float)];

            MLCDevice *cpu = [MLCDevice cpuDevice];
            MLCGraph *graph = [MLCGraph graph];
            MLCTensor *output = [graph nodeWithLayer:layer source:input];
            MLCInferenceGraph *inference = [MLCInferenceGraph graphWithGraphObjects:@[ graph ]];
            BOOL ready = [inference addInputs:@{ @"input": input }] && [inference addOutputs:@{ @"output": output }] &&
                         [inference compileWithOptions:MLCGraphCompilationOptionsNone device:cpu];
            __block BOOL done = NO;
            __block NSString *outcome = nil;
            if (ready) {
                [inference executeWithInputsData:@{ @"input": [MLCTensorData dataWithBytesNoCopy:(float[4]){ 1, 2, 3, 4 } length:4 * sizeof(float)] }
                                     outputsData:@{ @"output": outData }
                                       batchSize:0 options:MLCExecutionOptionsSynchronous
                                completionHandler:^(MLCTensor *tensor, NSError *error, NSTimeInterval time) {
                                    done = YES;
                                    outcome = error ? @"error" : @"ok";
                                }];
                for (int spin = 0; spin < 2000 && !done; spin++) {
                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
                }
            }
            if (!done || ![outcome isEqualToString:@"ok"]) {
                printf("activation %s\t(no answer: %s)\n", charon_case_names[type], outcome.UTF8String ?: "did not compile");
                continue;
            }
            print_values(charon_case_names[type], out);
            free(out);
        }
    }
    return 0;
}
