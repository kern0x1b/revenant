#import <Foundation/Foundation.h>
#include <unistd.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

static id<MTLDevice> gDevice = nil;

static float normSource[4][3] = {{0.5f, 1.5f, 2.5f}, {3.5f, 4.5f, 5.5f}, {6.5f, 7.5f, 8.5f}, {9.5f, 0.5f, 1.5f}};
static float normOut[4][3];
static float normGivenMean[3] = {5.0f, 6.0f, 7.0f};
static float normGivenVariance[3] = {2.0f, 3.0f, 4.0f};
static float normGamma[3] = {1.5f, 0.75f, 2.5f};
static float normBeta[3] = {-1.0f, 0.5f, 1.0f};

static MPSMatrix *matrixOf(const void *values, MPSDataType type, NSUInteger rows, NSUInteger columns)
{
    return [[MPSMatrix alloc] initWithBuffer:[gDevice newBufferWithBytes:values
                                                                   length:rows * columns * sizeof(float)
                                                                  options:MTLResourceStorageModeShared]
                                descriptor:[MPSMatrixDescriptor matrixDescriptorWithRows:rows columns:columns matrices:1
                                                                               rowBytes:columns * sizeof(float)
                                                                           matrixBytes:rows * columns * sizeof(float)
                                                                                dataType:type]];
}

static MPSVector *vectorOf(const void *values, MPSDataType type, NSUInteger length)
{
    return [[MPSVector alloc] initWithBuffer:[gDevice newBufferWithBytes:values length:length * sizeof(float)
                                                                 options:MTLResourceStorageModeShared]
                                 descriptor:[MPSVectorDescriptor vectorDescriptorWithLength:length vectors:1
                                                                  vectorBytes:length * sizeof(float) dataType:type]];
}

static const char *typeName(MPSCNNNeuronType t)
{
    switch (t) {
        case MPSCNNNeuronTypeNone: return "None";
        case MPSCNNNeuronTypeReLU: return "ReLU";
        case MPSCNNNeuronTypeLinear: return "Linear";
        case MPSCNNNeuronTypeSigmoid: return "Sigmoid";
        case MPSCNNNeuronTypeHardSigmoid: return "HardSigmoid";
        case MPSCNNNeuronTypeTanH: return "TanH";
        case MPSCNNNeuronTypeAbsolute: return "Absolute";
        case MPSCNNNeuronTypeSoftPlus: return "SoftPlus";
        case MPSCNNNeuronTypeSoftSign: return "SoftSign";
        case MPSCNNNeuronTypeELU: return "ELU";
        case MPSCNNNeuronTypeReLUN: return "ReLUN";
        case MPSCNNNeuronTypePReLU: return "PReLU";
        case MPSCNNNeuronTypePower: return "Power";
        case MPSCNNNeuronTypeExponential: return "Exponential";
        case MPSCNNNeuronTypeLogarithm: return "Logarithm";
        case MPSCNNNeuronTypeGeLU: return "GeLU";
        default: return "unknown";
    }
}

static void say(const char *step)
{
    char line[128];
    int n = snprintf(line, sizeof(line), "STEP %s\n", step);
    write(2, line, (size_t)n);
}

static void oneCase(MPSCNNNeuronType type, const char *label)
{
    char who[64];
    int wn = snprintf(who, sizeof(who), "STEP case begin, type %d = %s, a %g b %g c %g\n",
                      (int)type, typeName(type), 1.0f, 1.0f, 2.0f);
    write(2, who, (size_t)wn);
    memset(normOut, 0, sizeof(normOut));
    say("buffers created");
    static id<MTLCommandQueue> queue;
    if (!queue) queue = [gDevice newCommandQueue];
    id<MTLCommandBuffer> buffer = [queue commandBufferWithUnretainedReferences];
    MPSMatrix *in = matrixOf(&normSource[0][0], MPSDataTypeFloat32, 4, 3);
    MPSMatrix *out = matrixOf(&normOut[0][0], MPSDataTypeFloat32, 4, 3);
    MPSVector *m = vectorOf(normGivenMean, MPSDataTypeFloat32, 3);
    MPSVector *v = vectorOf(normGivenVariance, MPSDataTypeFloat32, 3);
    MPSVector *g = vectorOf(normGamma, MPSDataTypeFloat32, 3);
    MPSVector *b = vectorOf(normBeta, MPSDataTypeFloat32, 3);
    say("kernel alloc");
    MPSMatrixBatchNormalization *kernel = [[MPSMatrixBatchNormalization alloc] initWithDevice:gDevice];
    say("kernel allocated");
    [kernel setNeuronType:type parameterA:1.0f parameterB:1.0f parameterC:2.0f];
    kernel.epsilon = 0.001f;
    say("neuron set");
    [kernel encodeToCommandBuffer:buffer inputMatrix:in meanVector:m varianceVector:v
                      gammaVector:g betaVector:b resultMatrix:out];
    say("encoded");
    [buffer commit];
    say("committed");
    [buffer waitUntilCompleted];
    say("completed");
    printf("%-28s status %ld  out %g %g %g\n", label, (long)buffer.status, normOut[0][0], normOut[1][0], normOut[2][0]);
    fflush(stdout);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        gDevice = MTLCreateSystemDefaultDevice();
        if (!gDevice) { printf("no device\n"); return 2; }
        const unsigned kPreceding = (argc > 1) ? (unsigned)atoi(argv[1]) : 0;
        printf("device %s, preceding cases %u\n", [[gDevice name] UTF8String], kPreceding);
        fflush(stdout);
        say("device ready");
        if (argc > 2) {
            oneCase((MPSCNNNeuronType)atoi(argv[2]), "chosen type");
        } else {
            for (int t = 0; t < 15; t++) {
                if (t == MPSCNNNeuronTypePReLU) {
                    printf("--- type %d PReLU skipped: the release asserts it is not supported\n", t);
                    fflush(stdout);
                    continue;
                }
                oneCase((MPSCNNNeuronType)t, "loop");
            }
        }
        printf("survived\n");
    }
    return 0;
}
