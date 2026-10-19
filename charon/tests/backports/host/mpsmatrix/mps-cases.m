// mps-cases.m — the matrix and vector operations of Metal Performance Shaders, run twice: once
// against the system's own MPS and once against this port's classes compiled under names of their own.
// Every operation writes its result into a buffer, and the program prints those buffers as bytes, so
// the two runs are compared exactly rather than through a tolerance this file chooses.
//
// The port build is compiled with -include rename.h, which maps every MPS class name this library
// carries to a Charon name, and with prefix_selectors.py's prefixed declarations, so the port's
// implementations are reached through names of their own and do not replace the system's.
//
// Every case's data is at file scope, because a block cannot capture a C array.

#import <Foundation/Foundation.h>
#include <string.h>
#import <objc/runtime.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

static id<MTLDevice> gDevice;

// Every matrix and vector a case is built from a C array, and a kernel writes into the MTLBuffer behind
// it, never into that array. So each one remembers where it came from, and every result is read back out
// of the buffer into its array before it is printed. Without this a case prints the values it went in
// with and both runs agree whatever the kernel did.
typedef struct {
    id object;
    void *source;
    size_t bytes;
} CharonMPSSource;
static CharonMPSSource gSources[4096];
static NSUInteger gSourceCount;

static void remember(id object, void *source, size_t bytes)
{
    if (gSourceCount < sizeof(gSources) / sizeof(gSources[0])) {
        gSources[gSourceCount].object = object;
        gSources[gSourceCount].source = source;
        gSources[gSourceCount].bytes = bytes;
        gSourceCount++;
    }
}

// Which image every compared class came out of, printed before anything else. A class of the port's
// with the same name as one of the host's is registered once and a message sent to it reaches whichever
// loaded first, so the run says which that was rather than leaving it to be inferred from a number that
// came out wrong - which is exactly how the unrenamed generators went on comparing the host with itself
// for a whole band.
static void printClassImages(void)
{
    NSString *names[] = {
        @"MPSKernel", @"MPSCommandBuffer", @"MPSPredicate", @"MPSState", @"MPSStateResourceList",
        @"MPSMatrix", @"MPSMatrixDescriptor", @"MPSVector", @"MPSVectorDescriptor",
        @"MPSTemporaryMatrix", @"MPSTemporaryVector", @"MPSMatrixRandom", @"MPSMatrixRandomPhilox",
        @"MPSMatrixRandomMTGP32", @"MPSMatrixRandomDistributionDescriptor",
        @"MPSMatrixMultiplication", @"MPSMatrixVectorMultiplication", @"MPSMatrixCopy",
        @"MPSMatrixSoftMax", @"MPSMatrixFindTopK", @"MPSMatrixSum", @"MPSMatrixNeuron",
        @"MPSMatrixNeuronGradient", @"MPSMatrixFullyConnected", @"MPSMatrixFullyConnectedGradient",
        @"MPSMatrixBatchNormalization", @"MPSMatrixBatchNormalizationGradient",
        @"MPSMatrixDecompositionLU", @"MPSMatrixDecompositionCholesky", @"MPSMatrixSolveLU",
        @"MPSMatrixSolveCholesky", @"MPSMatrixSolveTriangular",
        @"MPSCNNKernel", @"MPSCNNConvolution", @"MPSCNNPooling", @"MPSCNNPoolingAverage",
        @"MPSCNNPoolingMax", @"MPSCNNBatchNormalization", @"MPSCNNConvolutionDescriptor",
    };
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        Class cls = NSClassFromString(names[i]);
        printf("image %-40s %s\n", names[i].UTF8String,
               cls ? (class_getImageName(cls) ?: "(none)") : "(absent)");
        fflush(stdout);
        NSString *charon = [@"Charon" stringByAppendingString:names[i]];
        Class mine = NSClassFromString(charon);
        printf("image %-40s %s\n", charon.UTF8String,
               mine ? (class_getImageName(mine) ?: "(none)") : "(absent)");
    }
}

static void pullResults(void)
{
    for (NSUInteger i = 0; i < gSourceCount; i++) {
        CharonMPSSource *entry = &gSources[i];
        id<MTLBuffer> buffer = [(id)entry->object data];
        memcpy(entry->source, [buffer contents], entry->bytes);
    }
}

// Flushed after every case: the oracle's own teardown crashes, and an unflushed stream loses every
// answer printed since the last flush.
// The name of the case about to run, written unbuffered and on its own, so that a process which dies
// mid-case still leaves behind the name of the case that killed it. The differential's own message
// used the last line the oracle PRINTED, which is the last case in the file and not the one that
// died: the release's own kernel crashes at the eleventh neuron type and the message named a philox
// case, which sent the reading of it entirely wrong for several turns.
static void mark(const char *name)
{
    const char *path = getenv("CHARON_CASE_MARKER");
    if (!path) return;
    FILE *f = fopen(path, "w");
    if (!f) return;
    fprintf(f, "%s\n", name);
    fclose(f);
}

static void put(const char *name, const void *bytes, size_t length)
{
    if (strcmp(name, "gradient-reference-beta") == 0) {
        const float *shown = (const float *)bytes;
        printf("  REF-CASE put prints array:");
        for (size_t i = 0; i < length / sizeof(float); i++)
            printf(" %g", (double)shown[i]);
        printf("\n");
        fflush(stdout);
    }
    pullResults();
    printf("case %s %zu ", name, length);
    const unsigned char *p = (const unsigned char *)bytes;
    for (size_t i = 0; i < length; i++)
        printf("%02x", p[i]);
    printf("\n");
    fflush(stdout);
}

// The batch-normalisation gradient, computed by hand from the formula in the header so the comparison
// has a third opinion that is neither the host's nor this port's:
//     gradGamma[c] = sum over i of dY[i][c] * (x[i][c] - mean[c]) / sqrt(variance[c] + epsilon)
//     gradBeta[c]  = sum over i of dY[i][c]
static void referenceGradient(const float *source, const float *incoming, const float *mean,
                             const float *variance, float epsilon, int rows, int channels,
                             float *gradGamma, float *gradBeta)
{
    for (int c = 0; c < channels; c++) {
        double g = 0.0, b = 0.0;
        for (int i = 0; i < rows; i++) {
            double xhat = ((double)source[i * channels + c] - mean[c]) / sqrt((double)variance[c] + epsilon);
            double term = (double)incoming[i * channels + c];
            g += term * xhat;
            b += term;
#ifdef CHARON_REFERENCE_TRACE
            printf("  ref ch%d row%d src[%d][%d]=%g inc[%d][%d]=%g xhat=%g term=%g\n", c, i,
                   i, c, (double)source[i * channels + c], i, c, term, xhat, term);
#endif
        }
#ifdef CHARON_REFERENCE_TRACE
        printf("  ref ch%d gamma %g beta %g  (rows %d channels %d, stride %d floats, mean %g %g %g, var %g %g %g)\n",
               c, g, b, rows, channels, channels, mean[0], mean[1], mean[2],
               variance[0], variance[1], variance[2]);
#endif
        gradGamma[c] = (float)g;
        gradBeta[c] = (float)b;
    }
}

static MPSMatrix *matrixOf(const void *values, MPSDataType type, NSUInteger rows, NSUInteger columns, NSUInteger matrices, size_t rowBytes, size_t matrixBytes)
{
    size_t element = MPSSizeofMPSDataType(type);
    size_t bytes = (matrices - 1) * matrixBytes + (rows - 1) * rowBytes + columns * element;
    id<MTLBuffer> buffer = [gDevice newBufferWithBytes:values length:bytes options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *descriptor = [MPSMatrixDescriptor matrixDescriptorWithRows:rows columns:columns matrices:matrices rowBytes:rowBytes matrixBytes:matrixBytes dataType:type];
    MPSMatrix *matrix = [[MPSMatrix alloc] initWithBuffer:buffer descriptor:descriptor];
    // The contract, checked rather than assumed: the matrix wraps the buffer it was made from and does
    // not copy it, so the two are the same object and a kernel that writes one writes the other.
    if (matrix.data != buffer)
        printf("CONTRACT matrix.data is not the buffer it was made from\n");
    remember(matrix, (void *)values, bytes);
    return matrix;
}

static MPSVector *vectorOf(const void *values, MPSDataType type, NSUInteger length, NSUInteger vectors, size_t vectorBytes)
{
    size_t element = MPSSizeofMPSDataType(type);
    size_t bytes = (vectors - 1) * vectorBytes + length * element;
    id<MTLBuffer> buffer = [gDevice newBufferWithBytes:values length:bytes options:MTLResourceStorageModeShared];
    MPSVectorDescriptor *descriptor = [MPSVectorDescriptor vectorDescriptorWithLength:length vectors:vectors vectorBytes:vectorBytes dataType:type];
    MPSVector *vector = [[MPSVector alloc] initWithBuffer:buffer descriptor:descriptor];
    if (vector.data != buffer)
        printf("CONTRACT vector.data is not the buffer it was made from\n");
    remember(vector, (void *)values, bytes);
    return vector;
}

// A command buffer from a queue, not from the device: on macOS 26.5 -newCommandBuffer answers an
// MTL4 command buffer, and the MPS of that release asks it for a method it does not carry, so the
// oracle would be the host's own crash rather than the host's own arithmetic. The queue's
// -commandBufferWithUnretainedReferences answers the classic one every MTLCommandBuffer conforms to.
static id<MTLCommandBuffer> freshCommandBuffer(void)
{
    static id<MTLCommandQueue> queue;
    if (!queue)
        queue = [gDevice newCommandQueue];
    return [queue commandBufferWithUnretainedReferences];
}

static void run(const char *name, void (^encode)(id<MTLCommandBuffer>))
{
    mark(name);
    id<MTLCommandBuffer> buffer = freshCommandBuffer();
    encode(buffer);
    [buffer commit];
    [buffer waitUntilCompleted];
}


#pragma mark - the device questions

static void casesDevice(void)
{
    printf("supports %d\n", (int)MPSSupportsMTLDevice(gDevice));
    printf("preferred %d\n", MPSGetPreferredDevice(MPSDeviceOptionsDefault) != nil);
    printf("rect %lld %lld %lld %lld %lld\n", (long long)MPSRectNoClip.origin.x, (long long)MPSRectNoClip.origin.y,
           (long long)MPSRectNoClip.size.width, (long long)MPSRectNoClip.size.height, (long long)MPSRectNoClip.size.depth);
}

#pragma mark - the descriptors

static void casesDescriptors(void)
{
    MPSDataType types[] = {MPSDataTypeFloat32, MPSDataTypeFloat16, MPSDataTypeInt8, MPSDataTypeInt16,
                           MPSDataTypeInt32, MPSDataTypeUInt8, MPSDataTypeUInt16, MPSDataTypeUInt32};
    for (unsigned t = 0; t < 8; t++) {
        for (NSUInteger columns = 0; columns < 70; columns++)
            printf("rowBytes %u %lu %zu\n", (unsigned)types[t], (unsigned long)columns,
                   [MPSMatrixDescriptor rowBytesForColumns:columns dataType:types[t]]);
        for (NSUInteger length = 0; length < 70; length++)
            printf("vectorBytes %u %lu %zu\n", (unsigned)types[t], (unsigned long)length,
                   [MPSVectorDescriptor vectorBytesForLength:length dataType:types[t]]);
    }
    MPSMatrixDescriptor *m = [MPSMatrixDescriptor matrixDescriptorWithRows:2 columns:3 rowBytes:8 dataType:MPSDataTypeFloat32];
    printf("descriptor %lu %lu %lu %lu %lu %u\n", (unsigned long)m.rows, (unsigned long)m.columns,
           (unsigned long)m.matrices, (unsigned long)m.rowBytes, (unsigned long)m.matrixBytes, (unsigned)m.dataType);
    m.rowBytes = 16;
    m.rows = 5;
    m.columns = 4;
    m.dataType = MPSDataTypeFloat16;
    printf("descriptor-mutated %lu %lu %lu %lu %lu %u\n", (unsigned long)m.rows, (unsigned long)m.columns,
           (unsigned long)m.matrices, (unsigned long)m.rowBytes, (unsigned long)m.matrixBytes, (unsigned)m.dataType);
    MPSMatrixDescriptor *batched = [MPSMatrixDescriptor matrixDescriptorWithRows:2 columns:2 matrices:3 rowBytes:8 matrixBytes:24 dataType:MPSDataTypeFloat32];
    printf("descriptor-batched %lu %lu\n", (unsigned long)batched.matrices, (unsigned long)batched.matrixBytes);
    MPSVectorDescriptor *v = [MPSVectorDescriptor vectorDescriptorWithLength:4 dataType:MPSDataTypeFloat32];
    printf("vector-descriptor %lu %lu %lu\n", (unsigned long)v.length, (unsigned long)v.vectors, (unsigned long)v.vectorBytes);
    v.length = 9;
    printf("vector-descriptor-mutated %lu %lu %lu\n", (unsigned long)v.length, (unsigned long)v.vectors, (unsigned long)v.vectorBytes);
    MPSVectorDescriptor *batchedVector = [MPSVectorDescriptor vectorDescriptorWithLength:4 vectors:3 vectorBytes:32 dataType:MPSDataTypeFloat32];
    printf("vector-descriptor-batched %lu %lu\n", (unsigned long)batchedVector.vectors, (unsigned long)batchedVector.vectorBytes);
}

#pragma mark - multiplication

static float multiplyLeft[3][3] = {{1, 2, 3}, {4, 5, 6}, {0, 0, 0}};
static float multiplyRight[3][3] = {{7, 8, 0}, {9, 10, 0}, {11, 12, 0}};
static float multiplySeed[2][2] = {{0.5f, 0.25f}, {-1, -2}};
static float multiplyOut[3][3];
static uint16_t multiplyHalfLeft[4][4] = {{0x3C00, 0x4000, 0x4200, 0x4400}, {0x4500, 0x4600, 0x4700, 0x4800}, {0, 0, 0, 0}, {0, 0, 0, 0}};
static uint16_t multiplyHalfRight[4][4] = {{0x3C00, 0x3C00, 0, 0}, {0x3C00, 0x4000, 0, 0}, {0x4000, 0x4000, 0, 0}, {0x4000, 0x4200, 0, 0}};
static uint16_t multiplyHalfOut[4][4];
static float batchLeft[3][2][2] = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}, {{9, 10}, {11, 12}}};
static float batchRight[3][2][2] = {{{1, 0}, {0, 1}}, {{2, 0}, {0, 2}}, {{3, 0}, {0, 3}}};
static float batchOut[3][2][2];

static void casesMultiplication(void)
{
    for (int transposeLeft = 0; transposeLeft < 2; transposeLeft++) {
        for (int transposeRight = 0; transposeRight < 2; transposeRight++) {
            memcpy(multiplyOut, multiplySeed, sizeof(multiplyOut));
            memset(multiplyOut, 0, sizeof(multiplyOut));
            multiplyOut[0][0] = multiplySeed[0][0];
            multiplyOut[0][1] = multiplySeed[0][1];
            multiplyOut[1][0] = multiplySeed[1][0];
            multiplyOut[1][1] = multiplySeed[1][1];
            run("multiply %d %d", ^(id<MTLCommandBuffer> commandBuffer) {
                // A 3x3 descriptor for all three, so the same matrices serve whichever way round they
                // are read: MPS refuses a matrix whose row stride cannot hold the columns asked of it.
                MPSMatrix *a = matrixOf(&multiplyLeft[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
                MPSMatrix *b = matrixOf(&multiplyRight[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
                MPSMatrix *c = matrixOf(&multiplyOut[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
                MPSMatrixMultiplication *kernel = [[MPSMatrixMultiplication alloc] initWithDevice:gDevice
                                                                                      transposeLeft:transposeLeft
                                                                                     transposeRight:transposeRight
                                                                                         resultRows:2
                                                                                      resultColumns:2
                                                                                    interiorColumns:3
                                                                                              alpha:2.0
                                                                                               beta:0.5];
                [kernel encodeToCommandBuffer:commandBuffer leftMatrix:a rightMatrix:b resultMatrix:c];
            });
            char name[64];
            snprintf(name, sizeof(name), "multiply %d %d", transposeLeft, transposeRight);
            put(name, &multiplyOut[0][0], sizeof(multiplyOut));
        }
    }
    memset(multiplyHalfOut, 0, sizeof(multiplyHalfOut));
    run("matrix-vector %d", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *a = matrixOf(&multiplyHalfLeft[0][0], MPSDataTypeFloat16, 4, 4, 1, 4 * sizeof(uint16_t), 16 * sizeof(uint16_t));
        MPSMatrix *b = matrixOf(&multiplyHalfRight[0][0], MPSDataTypeFloat16, 4, 4, 1, 4 * sizeof(uint16_t), 16 * sizeof(uint16_t));
        MPSMatrix *c = matrixOf(&multiplyHalfOut[0][0], MPSDataTypeFloat16, 4, 4, 1, 4 * sizeof(uint16_t), 16 * sizeof(uint16_t));
        MPSMatrixMultiplication *kernel = [[MPSMatrixMultiplication alloc] initWithDevice:gDevice resultRows:2 resultColumns:2 interiorColumns:4];
        [kernel encodeToCommandBuffer:commandBuffer leftMatrix:a rightMatrix:b resultMatrix:c];
    });
    put("multiply-half", &multiplyHalfOut[0][0], sizeof(multiplyHalfOut));

    memset(batchOut, 0, sizeof(batchOut));
    run("matrix-vector %d", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *a = matrixOf(&batchLeft[0][0][0], MPSDataTypeFloat32, 2, 2, 3, 2 * sizeof(float), 4 * sizeof(float));
        MPSMatrix *b = matrixOf(&batchRight[0][0][0], MPSDataTypeFloat32, 2, 2, 3, 2 * sizeof(float), 4 * sizeof(float));
        MPSMatrix *c = matrixOf(&batchOut[0][0][0], MPSDataTypeFloat32, 2, 2, 3, 2 * sizeof(float), 4 * sizeof(float));
        MPSMatrixMultiplication *kernel = [[MPSMatrixMultiplication alloc] initWithDevice:gDevice resultRows:2 resultColumns:2 interiorColumns:2];
        // The origin's z names a matrix, which the release requires to be zero: the batch is the
        // batchStart/batchSize range, and the origin moves the window inside each matrix of it.
        kernel.leftMatrixOrigin = MTLOriginMake(0, 0, 0);
        kernel.batchStart = 1;
        kernel.batchSize = 2;
        [kernel encodeToCommandBuffer:commandBuffer leftMatrix:a rightMatrix:b resultMatrix:c];
    });
    put("multiply-batch", &batchOut[0][0][0], sizeof(batchOut));
}

static float vectorMatrix[3][3] = {{1, 2, 3}, {4, 5, 6}, {0, 0, 0}};
static float vectorX[3] = {1, -1, 2};
static float vectorOut[2];

static void casesVectorMultiplication(void)
{
    for (int transpose = 0; transpose < 2; transpose++) {
        vectorOut[0] = 0;
        vectorOut[1] = 0;
        run("matrix-vector %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *a = matrixOf(&vectorMatrix[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
            MPSVector *in = vectorOf(vectorX, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSVector *out = vectorOf(vectorOut, MPSDataTypeFloat32, 2, 1, 2 * sizeof(float));
            MPSMatrixVectorMultiplication *kernel = [[MPSMatrixVectorMultiplication alloc] initWithDevice:gDevice transpose:transpose rows:2 columns:3 alpha:1.5 beta:0.25];
            [kernel encodeToCommandBuffer:commandBuffer inputMatrix:a inputVector:in resultVector:out];
        });
        char name[64];
        snprintf(name, sizeof(name), "matrix-vector %d", transpose);
        put(name, vectorOut, sizeof(vectorOut));
    }
}

#pragma mark - copy

static float copySource[3][3] = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
static float copyDestination[3][3];
static float permuteSource[2][4] = {{1, 2, 3, 4}, {5, 6, 7, 8}};
static uint32_t permuteIndices[4] = {1, 0, 0, 0};
static uint32_t columnPermuteIndices[4] = {3, 2, 1, 0};
static float permuteDestination[2][4];

static void casesCopy(void)
{
    for (int transposeSource = 0; transposeSource < 2; transposeSource++) {
        for (int transposeDestination = 0; transposeDestination < 2; transposeDestination++) {
            memset(copyDestination, 0, sizeof(copyDestination));
            MPSMatrixCopyOffsets offsets = {1, 1, 0, 0};
            MPSMatrixCopy *kernel = [[MPSMatrixCopy alloc] initWithDevice:gDevice copyRows:2 copyColumns:2
                                                          sourcesAreTransposed:transposeSource
                                                     destinationsAreTransposed:transposeDestination];
            run("copy %d %d", ^(id<MTLCommandBuffer> commandBuffer) {
                MPSMatrix *a = matrixOf(&copySource[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
                MPSMatrix *b = matrixOf(&copyDestination[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
                MPSMatrixCopyDescriptor *descriptor = [MPSMatrixCopyDescriptor descriptorWithSourceMatrix:a destinationMatrix:b offsets:offsets];
                [kernel encodeToCommandBuffer:commandBuffer copyDescriptor:descriptor];
            });
            char name[64];
            snprintf(name, sizeof(name), "copy %d %d", transposeSource, transposeDestination);
            put(name, &copyDestination[0][0], sizeof(copyDestination));
        }
    }
    memset(permuteDestination, 0, sizeof(permuteDestination));
    run("casesCopy line 365", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *a = matrixOf(&permuteSource[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrix *b = matrixOf(&permuteDestination[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrixCopyDescriptor *descriptor = [MPSMatrixCopyDescriptor descriptorWithSourceMatrix:a destinationMatrix:b offsets:(MPSMatrixCopyOffsets){0, 0, 0, 0}];
        MPSMatrixCopy *kernel = [[MPSMatrixCopy alloc] initWithDevice:gDevice copyRows:2 copyColumns:4 sourcesAreTransposed:NO destinationsAreTransposed:NO];
        MPSVector *rows = vectorOf(permuteIndices, MPSDataTypeUInt32, 2, 1, 2 * sizeof(uint32_t));
        MPSVector *columns = vectorOf(columnPermuteIndices, MPSDataTypeUInt32, 4, 1, 4 * sizeof(uint32_t));
        [kernel encodeToCommandBuffer:commandBuffer copyDescriptor:descriptor rowPermuteIndices:rows rowPermuteOffset:0 columnPermuteIndices:columns columnPermuteOffset:0];
    });
    put("copy-permute", &permuteDestination[0][0], sizeof(permuteDestination));
}

#pragma mark - softmax and top k

static float softMaxSource[2][4] = {{1, 2, 3, 4}, {-3, 0.5f, 0.5f, 0.5f}};
static float softMaxPlain[2][4];
static float softMaxLogarithmic[2][4];
static float softMaxIncoming[2][4] = {{1, 2, 3, 4}, {4, 3, 2, 1}};
static float softMaxGradient[2][4];
static float topKSource[2][6] = {{5, 1, 9, 9, 0, 7}, {1, 1, 1, 1, 1, 1}};
static uint32_t topKIndices[2][3];
static float topKValues[2][3];

static void casesSoftMax(void)
{
    memset(softMaxPlain, 0, sizeof(softMaxPlain));
    run("casesSoftMax line 391", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *in = matrixOf(&softMaxSource[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrix *out = matrixOf(&softMaxPlain[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrixSoftMax *kernel = [[MPSMatrixSoftMax alloc] initWithDevice:gDevice];
        [kernel encodeToCommandBuffer:commandBuffer inputMatrix:in resultMatrix:out];
    });
    put("softmax", &softMaxPlain[0][0], sizeof(softMaxPlain));
    memset(softMaxLogarithmic, 0, sizeof(softMaxLogarithmic));
    run("casesSoftMax line 399", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *in = matrixOf(&softMaxSource[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrix *out = matrixOf(&softMaxLogarithmic[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrixLogSoftMax *kernel = [[MPSMatrixLogSoftMax alloc] initWithDevice:gDevice];
        [kernel encodeToCommandBuffer:commandBuffer inputMatrix:in resultMatrix:out];
    });
    put("logsoftmax", &softMaxLogarithmic[0][0], sizeof(softMaxLogarithmic));
    memset(softMaxGradient, 0, sizeof(softMaxGradient));
    run("neuron %d", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *g = matrixOf(&softMaxIncoming[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrix *y = matrixOf(&softMaxPlain[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrix *out = matrixOf(&softMaxGradient[0][0], MPSDataTypeFloat32, 2, 4, 1, 4 * sizeof(float), 8 * sizeof(float));
        MPSMatrixSoftMaxGradient *kernel = [[MPSMatrixSoftMaxGradient alloc] initWithDevice:gDevice];
        [kernel encodeToCommandBuffer:commandBuffer gradientMatrix:g forwardOutputMatrix:y resultMatrix:out];
    });
    put("softmax-gradient", &softMaxGradient[0][0], sizeof(softMaxGradient));
    memset(topKIndices, 0, sizeof(topKIndices));
    memset(topKValues, 0, sizeof(topKValues));
    run("neuron %d", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *in = matrixOf(&topKSource[0][0], MPSDataTypeFloat32, 2, 6, 1, 6 * sizeof(float), 12 * sizeof(float));
        MPSMatrix *i = matrixOf(&topKIndices[0][0], MPSDataTypeUInt32, 2, 3, 1, 3 * sizeof(uint32_t), 6 * sizeof(uint32_t));
        MPSMatrix *v = matrixOf(&topKValues[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
        MPSMatrixFindTopK *kernel = [[MPSMatrixFindTopK alloc] initWithDevice:gDevice numberOfTopKValues:3];
        [kernel encodeToCommandBuffer:commandBuffer inputMatrix:in resultIndexMatrix:i resultValueMatrix:v];
    });
    put("findtopk-indices", &topKIndices[0][0], sizeof(topKIndices));
    put("findtopk-values", &topKValues[0][0], sizeof(topKValues));
}

#pragma mark - the neuron family

static MPSCNNNeuronType gTypes[] = {
    MPSCNNNeuronTypeNone, MPSCNNNeuronTypeReLU, MPSCNNNeuronTypeLinear, MPSCNNNeuronTypeSigmoid,
    MPSCNNNeuronTypeHardSigmoid, MPSCNNNeuronTypeTanH, MPSCNNNeuronTypeAbsolute, MPSCNNNeuronTypeSoftPlus,
    MPSCNNNeuronTypeSoftSign, MPSCNNNeuronTypeELU, MPSCNNNeuronTypeReLUN, MPSCNNNeuronTypePower,
    MPSCNNNeuronTypeExponential, MPSCNNNeuronTypeLogarithm, MPSCNNNeuronTypeGeLU
};
static const unsigned gTypeCount = sizeof(gTypes) / sizeof(gTypes[0]);

static float neuronSource[3][4] = {{-2, -0.5f, 0, 0.5f}, {1, 2, 3, 4}, {-8, 8, 0.1f, 2}};
static float neuronBias[4] = {0.25f, -0.25f, 0.5f, -0.5f};
static float neuronIncoming[3][4] = {{1, 2, 3, 4}, {0.5f, 0.25f, 0.125f, 0.0625f}, {2, 2, 2, 2}};
static float neuronOut[3][4];
static float neuronGradientData[3][4];
static float neuronGradientBias[4];
static float neuronPreluA[4] = {0.1f, 0.2f, 0.3f, 0.4f};
static float neuronPreluOut[3][4];

static void casesNeuron(void)
{
    for (unsigned t = 0; t < gTypeCount; t++) {
        memset(neuronOut, 0, sizeof(neuronOut));
        run("neuron %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *in = matrixOf(&neuronSource[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
            MPSMatrix *out = matrixOf(&neuronOut[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
            MPSVector *b = vectorOf(neuronBias, MPSDataTypeFloat32, 4, 1, 4 * sizeof(float));
            MPSMatrixNeuron *kernel = [[MPSMatrixNeuron alloc] initWithDevice:gDevice];
            [kernel setNeuronType:gTypes[t] parameterA:1.5f parameterB:0.75f parameterC:2.5f];
            kernel.alpha = 0.5;
            [kernel encodeToCommandBuffer:commandBuffer inputMatrix:in biasVector:b resultMatrix:out];
        });
        char name[64];
        snprintf(name, sizeof(name), "neuron %d", (int)gTypes[t]);
        put(name, &neuronOut[0][0], sizeof(neuronOut));

        memset(neuronGradientData, 0, sizeof(neuronGradientData));
        memset(neuronGradientBias, 0, sizeof(neuronGradientBias));
        run("neuron-gradient-data %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *g = matrixOf(&neuronIncoming[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
            MPSMatrix *in = matrixOf(&neuronSource[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
            MPSMatrix *out = matrixOf(&neuronGradientData[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
            MPSVector *b = vectorOf(neuronBias, MPSDataTypeFloat32, 4, 1, 4 * sizeof(float));
            MPSVector *gb = vectorOf(neuronGradientBias, MPSDataTypeFloat32, 4, 1, 4 * sizeof(float));
            MPSMatrixNeuronGradient *kernel = [[MPSMatrixNeuronGradient alloc] initWithDevice:gDevice];
            [kernel setNeuronType:gTypes[t] parameterA:1.5f parameterB:0.75f parameterC:2.5f];
            kernel.alpha = 0.5;
            [kernel encodeToCommandBuffer:commandBuffer gradientMatrix:g inputMatrix:in biasVector:b
                 resultGradientForDataMatrix:out resultGradientForBiasVector:gb];
        });
        snprintf(name, sizeof(name), "neuron-gradient-data %d", (int)gTypes[t]);
        put(name, &neuronGradientData[0][0], sizeof(neuronGradientData));
        snprintf(name, sizeof(name), "neuron-gradient-bias %d", (int)gTypes[t]);
        put(name, neuronGradientBias, sizeof(neuronGradientBias));
    }
    memset(neuronPreluOut, 0, sizeof(neuronPreluOut));
    run("fully-connected %d", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *in = matrixOf(&neuronSource[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
        MPSMatrix *out = matrixOf(&neuronPreluOut[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
        MPSMatrixNeuron *kernel = [[MPSMatrixNeuron alloc] initWithDevice:gDevice];
        [kernel setNeuronToPReLUWithParametersA:[NSData dataWithBytes:neuronPreluA length:sizeof(neuronPreluA)]];
        [kernel encodeToCommandBuffer:commandBuffer inputMatrix:in biasVector:nil resultMatrix:out];
    });
    put("neuron-prelu", &neuronPreluOut[0][0], sizeof(neuronPreluOut));
}

#pragma mark - fully connected

static float fullyConnectedInput[3][2] = {{1, 2}, {3, 4}, {5, 6}};
static float fullyConnectedWeights[2][3] = {{1, -1, 0.5f}, {0.25f, 2, -3}};
static float fullyConnectedBias[3] = {0.1f, 0.2f, 0.3f};
static float fullyConnectedOut[3][3];
static float fullyConnectedIncoming[3][3] = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
static float fullyConnectedGradientData[3][2];
static float fullyConnectedGradientWeights[2][3];
static float fullyConnectedGradientBias[3];

static void casesFullyConnected(void)
{
    for (unsigned t = 0; t < gTypeCount; t++) {
        memset(fullyConnectedOut, 0, sizeof(fullyConnectedOut));
        run("fully-connected %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *in = matrixOf(&fullyConnectedInput[0][0], MPSDataTypeFloat32, 3, 2, 1, 2 * sizeof(float), 6 * sizeof(float));
            MPSMatrix *w = matrixOf(&fullyConnectedWeights[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
            MPSMatrix *out = matrixOf(&fullyConnectedOut[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
            MPSVector *b = vectorOf(fullyConnectedBias, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSMatrixFullyConnected *kernel = [[MPSMatrixFullyConnected alloc] initWithDevice:gDevice];
            [kernel setNeuronType:gTypes[t] parameterA:1.0f parameterB:1.0f parameterC:2.0f];
            kernel.alpha = 1.25;
            [kernel encodeToCommandBuffer:commandBuffer inputMatrix:in weightMatrix:w biasVector:b resultMatrix:out];
        });
        char name[64];
        snprintf(name, sizeof(name), "fully-connected %d", (int)gTypes[t]);
        put(name, &fullyConnectedOut[0][0], sizeof(fullyConnectedOut));
    }
    memset(fullyConnectedGradientData, 0, sizeof(fullyConnectedGradientData));
    run("casesFullyConnected line 524", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *g = matrixOf(&fullyConnectedIncoming[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
        MPSMatrix *w = matrixOf(&fullyConnectedWeights[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
        MPSMatrix *out = matrixOf(&fullyConnectedGradientData[0][0], MPSDataTypeFloat32, 3, 2, 1, 2 * sizeof(float), 6 * sizeof(float));
        MPSMatrixFullyConnectedGradient *kernel = [[MPSMatrixFullyConnectedGradient alloc] initWithDevice:gDevice];
        kernel.alpha = 1.25;
        [kernel encodeGradientForDataToCommandBuffer:commandBuffer gradientMatrix:g weightMatrix:w resultGradientForDataMatrix:out];
    });
    put("fully-connected-gradient-data", &fullyConnectedGradientData[0][0], sizeof(fullyConnectedGradientData));

    memset(fullyConnectedGradientWeights, 0, sizeof(fullyConnectedGradientWeights));
    memset(fullyConnectedGradientBias, 0, sizeof(fullyConnectedGradientBias));
    run("casesFullyConnected line 536", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *g = matrixOf(&fullyConnectedIncoming[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
        MPSMatrix *in = matrixOf(&fullyConnectedInput[0][0], MPSDataTypeFloat32, 3, 2, 1, 2 * sizeof(float), 6 * sizeof(float));
        MPSMatrix *gw = matrixOf(&fullyConnectedGradientWeights[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
        MPSVector *gb = vectorOf(fullyConnectedGradientBias, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSMatrixFullyConnectedGradient *kernel = [[MPSMatrixFullyConnectedGradient alloc] initWithDevice:gDevice];
        kernel.alpha = 1.25;
        [kernel encodeGradientForWeightsAndBiasToCommandBuffer:commandBuffer gradientMatrix:g inputMatrix:in
                              resultGradientForWeightMatrix:gw resultGradientForBiasVector:gb];
    });
    put("fully-connected-gradient-weights", &fullyConnectedGradientWeights[0][0], sizeof(fullyConnectedGradientWeights));
    put("fully-connected-gradient-bias", fullyConnectedGradientBias, sizeof(fullyConnectedGradientBias));
}

#pragma mark - batch normalization

static float normSource[4][3] = {{1, 2, 3}, {4, 5, 7}, {2, 8, 1}, {9, 1, 5}};
static float normMean[3];
static float normVariance[3];
static float normGamma[3] = {1.5f, 0.75f, 2.0f};
static float normBeta[3] = {0.5f, -0.5f, 1.0f};
static float normGivenMean[3] = {4, 5, 4};
static float normGivenVariance[3] = {8, 6, 6};
static float normOut[4][3];
static float normIncoming[4][3] = {{1, 2, 3}, {4, 5, 7}, {2, 8, 1}, {9, 1, 5}};
static id<MTLBuffer> normGammaBuffer, normBetaBuffer;
static MTLCommandBufferStatus normStatus;
static NSError *normError;
static float normGradientData[4][3];
static float normGradientGamma[3];
static float normGradientBeta[3];


// The forward normalisation, computed by hand from the header's formula: gamma * (x - mean) /
// sqrt(variance + epsilon) + beta, one channel at a time, so the comparison has a third opinion.
static void referenceForward(const float *source, const float *mean, const float *variance,
                             const float *gamma, const float *beta, float epsilon,
                             int rows, int channels, float *out)
{
    for (int c = 0; c < channels; c++) {
        double g = gamma[c], b = beta[c], m = mean[c];
        double root = sqrt((double)variance[c] + epsilon);
        for (int i = 0; i < rows; i++) {
            double x = source[i * channels + c];
            out[i * channels + c] = (float)(g * (x - m) / root + b);
        }
    }
}

static void casesBatchNormalization(void)
{
    for (unsigned t = 0; t < gTypeCount; t++) {
        memset(normOut, 0, sizeof(normOut));
        run("batch-normalization %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *in = matrixOf(&normSource[0][0], MPSDataTypeFloat32, 4, 3, 1, 3 * sizeof(float), 12 * sizeof(float));
            MPSMatrix *out = matrixOf(&normOut[0][0], MPSDataTypeFloat32, 4, 3, 1, 3 * sizeof(float), 12 * sizeof(float));
            MPSVector *m = vectorOf(normGivenMean, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSVector *v = vectorOf(normGivenVariance, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSVector *g = vectorOf(normGamma, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSVector *b = vectorOf(normBeta, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSMatrixBatchNormalization *kernel = [[MPSMatrixBatchNormalization alloc] initWithDevice:gDevice];
            [kernel setNeuronType:gTypes[t] parameterA:1.0f parameterB:1.0f parameterC:2.0f];
            kernel.epsilon = 0.001f;
            [kernel encodeToCommandBuffer:commandBuffer inputMatrix:in meanVector:m varianceVector:v gammaVector:g betaVector:b resultMatrix:out];
        });
        char name[64];
        snprintf(name, sizeof(name), "batch-normalization %d", (int)gTypes[t]);
        put(name, &normOut[0][0], sizeof(normOut));
    }
    memset(normMean, 0, sizeof(normMean));
    memset(normVariance, 0, sizeof(normVariance));
    memset(normOut, 0, sizeof(normOut));
    run("casesBatchNormalization line 608", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *in = matrixOf(&normSource[0][0], MPSDataTypeFloat32, 4, 3, 1, 3 * sizeof(float), 12 * sizeof(float));
        MPSMatrix *out = matrixOf(&normOut[0][0], MPSDataTypeFloat32, 4, 3, 1, 3 * sizeof(float), 12 * sizeof(float));
        MPSVector *m = vectorOf(normMean, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSVector *v = vectorOf(normVariance, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSMatrixBatchNormalization *kernel = [[MPSMatrixBatchNormalization alloc] initWithDevice:gDevice];
        kernel.epsilon = 0.001f;
        kernel.computeStatistics = YES;
        [kernel encodeToCommandBuffer:commandBuffer inputMatrix:in meanVector:m varianceVector:v gammaVector:nil betaVector:nil resultMatrix:out];
    });
    {
        float referenceForwardOut[12] = {0};
        referenceForward(&normSource[0][0], &normGivenMean[0], &normGivenVariance[0], &normGamma[0], &normBeta[0],
                          0.001f, 4, 3, referenceForwardOut);
        put("forward-reference", referenceForwardOut, sizeof(referenceForwardOut));
    }
    put("batch-normalization-statistics-mean", normMean, sizeof(normMean));
    put("batch-normalization-statistics-variance", normVariance, sizeof(normVariance));
    put("batch-normalization-statistics-result", &normOut[0][0], sizeof(normOut));

    // A sentinel, not a zero: 0x7f7f7f7f in every element, so a buffer the release leaves alone is
    // distinguishable from a buffer it fills with zero. The command buffer's status and error are
    // printed with the results.
    // The per-parameter gradient destinations go in with a sentinel rather than a zero, so a side that
    // leaves them alone is distinguishable from a side that writes zero.
    {
        float untouched[3] = {-1.0f, -1.0f, -1.0f};
        memcpy(normGradientGamma, untouched, sizeof(untouched));
        memcpy(normGradientBeta, untouched, sizeof(untouched));
    }
    memset(normGradientData, 0x7f, sizeof(normGradientData));
    memset(normGradientGamma, 0x7f, sizeof(normGradientGamma));
    memset(normGradientBeta, 0x7f, sizeof(normGradientBeta));
    normGammaBuffer = NULL;
    normBetaBuffer = NULL;
    {
        // The buffers the two result vectors are made from, so the print below can name them.
        id<MTLBuffer> probe = [gDevice newBufferWithLength:1 options:MTLResourceStorageModeShared];
        (void)probe;
    }
    run("case line 648", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *g = matrixOf(&normIncoming[0][0], MPSDataTypeFloat32, 4, 3, 1, 3 * sizeof(float), 12 * sizeof(float));
        MPSMatrix *in = matrixOf(&normSource[0][0], MPSDataTypeFloat32, 4, 3, 1, 3 * sizeof(float), 12 * sizeof(float));
        MPSMatrix *out = matrixOf(&normGradientData[0][0], MPSDataTypeFloat32, 4, 3, 1, 3 * sizeof(float), 12 * sizeof(float));
        MPSVector *m = vectorOf(normGivenMean, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSVector *v = vectorOf(normGivenVariance, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSVector *gm = vectorOf(normGamma, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSVector *gg = vectorOf(normGradientGamma, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSVector *gb = vectorOf(normGradientBeta, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSMatrixBatchNormalizationGradient *kernel = [[MPSMatrixBatchNormalizationGradient alloc] initWithDevice:gDevice];
        kernel.epsilon = 0.001f;
        [kernel encodeToCommandBuffer:commandBuffer gradientMatrix:g inputMatrix:in meanVector:m varianceVector:v
                  gammaVector:gm betaVector:nil resultGradientForDataMatrix:out
             resultGradientForGammaVector:gg resultGradientForBetaVector:gb];
        normStatus = commandBuffer.status;
        normError = commandBuffer.error;
    });
    {
        // Read straight back from the buffers, with no view and before any put: what is here now is
        // what the kernel left.
        printf("sentinel-readback gamma\n");
        for (unsigned i = 0; i < sizeof(normGradientGamma) / sizeof(float); i++)
            printf(" %02x", ((unsigned char *)normGradientGamma)[i]);
        printf("  buffer\n");
        printf("sentinel-readback beta \n");
        for (unsigned i = 0; i < sizeof(normGradientBeta) / sizeof(float); i++)
            printf(" %02x", ((unsigned char *)normGradientBeta)[i]);
        printf("  buffer\n");
        fflush(stdout);
    }
    {
        float referenceGamma[3] = {0, 0, 0}, referenceBeta[3] = {0, 0, 0};
        referenceGradient(&normSource[0][0], &normIncoming[0][0], &normGivenMean[0], &normGivenVariance[0],
                          0.001f, 4, 3, referenceGamma, referenceBeta);
        // A case of its own, so the comparison reads host, port and reference rather than host and
        // port, and the values are printed as text beside the hex because a hex read in the wrong byte
        // order has already produced three confident wrong numbers in this file.
        put("gradient-reference-text-gamma", referenceGamma, sizeof(referenceGamma));
        put("gradient-reference-text-beta", referenceBeta, sizeof(referenceBeta));
        printf("  REF-CASE filled  gamma %g %g %g  beta %g %g %g\n",
               (double)referenceGamma[0], (double)referenceGamma[1], (double)referenceGamma[2],
               (double)referenceBeta[0], (double)referenceBeta[1], (double)referenceBeta[2]);
        // What the kernel's own result vectors hold, read from their buffers, for the same run.
        pullResults();
        printf("  REF-CASE kernel  gamma %g %g %g  beta %g %g %g\n", (double)normGradientGamma[0],
               (double)normGradientGamma[1], (double)normGradientGamma[2], (double)normGradientBeta[0],
               (double)normGradientBeta[1], (double)normGradientBeta[2]);
        fflush(stdout);
        put("gradient-reference-gamma", referenceGamma, sizeof(referenceGamma));
        put("gradient-reference-beta", referenceBeta, sizeof(referenceBeta));
        printf("gradient-status %d error %s\n", (int)normStatus,
               normError ? normError.localizedDescription.UTF8String : "(none)");
        fflush(stdout);
    }
    put("batch-normalization-gradient-data", &normGradientData[0][0], sizeof(normGradientData));
    put("batch-normalization-gradient-gamma", normGradientGamma, sizeof(normGradientGamma));
    put("batch-normalization-gradient-beta", normGradientBeta, sizeof(normGradientBeta));
}


#pragma mark - sum

static float sumFirst[3][4] = {{1, 2, 3, 10}, {4, 5, 6, 11}, {7, 8, 9, 12}};
static float sumSecond[3][4] = {{0.5f, -1, 2, 20}, {1, 1, 1, 21}, {-2, 0, 0.5f, 22}};
static float sumThird[3][3] = {{-2, 0, 0.5f}, {0, 0, 0}, {1, 1, 1}};
static float sumScale[3] = {1, 2, 0.5f};
static float sumBias[3] = {0.25f, -0.5f, 1};
static float sumOut[2][3];
static MPSMatrixOffset sumOffsets[2] = {{1, 0}, {0, 1}};

static void casesSum(void)
{
    for (unsigned t = 0; t < gTypeCount; t++) {
        memset(sumOut, 0, sizeof(sumOut));
        run("sum %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *a = matrixOf(&sumFirst[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
            MPSMatrix *b = matrixOf(&sumSecond[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
            MPSMatrix *c = matrixOf(&sumThird[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
            MPSMatrix *out = matrixOf(&sumOut[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
            MPSVector *s = vectorOf(sumScale, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSVector *bv = vectorOf(sumBias, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSMatrixSum *kernel = [[MPSMatrixSum alloc] initWithDevice:gDevice count:3 rows:2 columns:3 transpose:NO];
            [kernel setNeuronType:gTypes[t] parameterA:1.0f parameterB:1.0f parameterC:2.0f];
            [kernel encodeToCommandBuffer:commandBuffer sourceMatrices:@[a, b, c] resultMatrix:out
                                scaleVector:s offsetVector:nil biasVector:bv startIndex:0];
        });
        char name[64];
        snprintf(name, sizeof(name), "sum %d", (int)gTypes[t]);
        put(name, &sumOut[0][0], sizeof(sumOut));
    }
    memset(sumOut, 0, sizeof(sumOut));
    run("sum-start-index-boundary %lu", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *a = matrixOf(&sumFirst[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
        MPSMatrix *b = matrixOf(&sumSecond[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
        MPSMatrix *out = matrixOf(&sumOut[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
        MPSVector *s = vectorOf(sumScale, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
        MPSMatrixSum *kernel = [[MPSMatrixSum alloc] initWithDevice:gDevice count:2 rows:2 columns:3 transpose:NO];
        [kernel encodeToCommandBuffer:commandBuffer sourceMatrices:@[a, b] resultMatrix:out scaleVector:s offsetVector:nil biasVector:nil startIndex:1];
    });
    put("sum-start-index", &sumOut[0][0], sizeof(sumOut));

    // The boundary: a startIndex that leaves exactly one factor in the list and then none at all, so
    // the scale guard's edge is exercised rather than assumed.
    for (NSUInteger start = 1; start <= 3; start++) {
        memset(sumOut, 0, sizeof(sumOut));
        run("sum-start-index-boundary %lu", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *a = matrixOf(&sumFirst[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
            MPSMatrix *b = matrixOf(&sumSecond[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
            MPSMatrix *out = matrixOf(&sumOut[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
            MPSVector *s = vectorOf(sumScale, MPSDataTypeFloat32, 3, 1, 3 * sizeof(float));
            MPSMatrixSum *kernel = [[MPSMatrixSum alloc] initWithDevice:gDevice count:2 rows:2 columns:3 transpose:NO];
            [kernel encodeToCommandBuffer:commandBuffer sourceMatrices:@[a, b] resultMatrix:out
                                scaleVector:s offsetVector:nil biasVector:nil startIndex:start];
        });
        char name[64];
        snprintf(name, sizeof(name), "sum-start-index-boundary %lu", (unsigned long)start);
        put(name, &sumOut[0][0], sizeof(sumOut));
    }

    memset(sumOut, 0, sizeof(sumOut));
    run("casesSum line 768", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *a = matrixOf(&sumFirst[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
        MPSMatrix *out = matrixOf(&sumOut[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
        // The release requires at least two matrices to sum, so the transposed source is given twice.
        MPSMatrixSum *kernel = [[MPSMatrixSum alloc] initWithDevice:gDevice count:2 rows:2 columns:3 transpose:YES];
        [kernel encodeToCommandBuffer:commandBuffer sourceMatrices:@[a, a] resultMatrix:out scaleVector:nil offsetVector:nil biasVector:nil startIndex:0];
    });
    put("sum-transpose", &sumOut[0][0], sizeof(sumOut));

    memset(sumOut, 0, sizeof(sumOut));
    run("casesSum line 778", ^(id<MTLCommandBuffer> commandBuffer) {
        // A two by three window read from each of two four column sources, the second from column one,
        // which is where the offset vector's second entry puts it.
        MPSMatrix *a = matrixOf(&sumFirst[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
        MPSMatrix *b = matrixOf(&sumSecond[0][0], MPSDataTypeFloat32, 3, 4, 1, 4 * sizeof(float), 12 * sizeof(float));
        MPSMatrix *out = matrixOf(&sumOut[0][0], MPSDataTypeFloat32, 2, 3, 1, 3 * sizeof(float), 6 * sizeof(float));
        MPSVector *o = vectorOf(sumOffsets, MPSDataTypeUInt32, 4, 1, 4 * sizeof(uint32_t));
        MPSMatrixSum *kernel = [[MPSMatrixSum alloc] initWithDevice:gDevice count:2 rows:2 columns:3 transpose:NO];
        [kernel encodeToCommandBuffer:commandBuffer sourceMatrices:@[a, b] resultMatrix:out scaleVector:nil offsetVector:o biasVector:nil startIndex:0];
    });
    put("sum-offsets", &sumOut[0][0], sizeof(sumOut));
}

#pragma mark - states, predicates and command buffers

static void casesState(void)
{
    MPSState *state = [[MPSState alloc] initWithResource:[gDevice newBufferWithLength:64 options:MTLResourceStorageModeShared]];
    printf("state %lu %d %lu\n", (unsigned long)state.resourceCount, (int)[state resourceTypeAtIndex:0], (unsigned long)[state bufferSizeAtIndex:0]);
    printf("state-is-temporary %d\n", (int)state.isTemporary);
    printf("divergent state-size %lu\n", (unsigned long)[state resourceSize]);
    MPSState *fromBuffer = [[MPSState alloc] initWithDevice:gDevice bufferSize:128];
    printf("state-buffer %lu %d %lu\n", (unsigned long)fromBuffer.resourceCount, (int)[fromBuffer resourceTypeAtIndex:0],
           (unsigned long)[fromBuffer bufferSizeAtIndex:0]);
    printf("state-lazy %d\n", [fromBuffer resourceAtIndex:0 allocateMemory:NO] == nil);
    printf("state-allocated %d\n", [fromBuffer resourceAtIndex:0 allocateMemory:YES] != nil);
    MPSStateResourceList *list = [MPSStateResourceList resourceListWithBufferSizes:32, 64, 128, nil];
    MPSState *fromList = [[MPSState alloc] initWithDevice:gDevice resourceList:list];
    printf("state-list %lu %lu %lu\n", (unsigned long)fromList.resourceCount, (unsigned long)[fromList bufferSizeAtIndex:0], (unsigned long)[fromList bufferSizeAtIndex:2]);
    NSArray<MPSState *> *batch = @[state, fromBuffer, fromList];
    printf("divergent state-batch-size %lu\n", MPSStateBatchResourceSize(batch));
    run("casesState line 809", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSStateBatchSynchronize(batch, commandBuffer);
    });
    printf("state-batch-synchronized 1\n");

    // The read count belongs to a temporary state: the release asserts on adjusting one that is not
    // temporary, so the batch's read counts are read from temporaries made against a command buffer.
    run("casesState line 816", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSState *a = [MPSState temporaryStateWithCommandBuffer:commandBuffer bufferSize:32];
        MPSState *b = [MPSState temporaryStateWithCommandBuffer:commandBuffer bufferSize:64];
        MPSState *c = [MPSState temporaryStateWithCommandBuffer:commandBuffer bufferSize:96];
        printf("temporary %d %d %d\n", (int)a.isTemporary, (int)b.isTemporary, (int)c.isTemporary);
        printf("temporary-read-count %lu %lu %lu\n", (unsigned long)a.readCount, (unsigned long)b.readCount, (unsigned long)c.readCount);
        NSArray<MPSState *> *temporaries = @[a, b, c];
        // Up by two, then down by one: the release asserts on a decrement that would take a count
        // below zero, so the case stays inside the range a read count can take.
        // The function's answer is the size of the batch, whatever it did to the counts: three states
        // answer three both times. The counts themselves are printed around it.
        printf("temporary-batch-up %lu\n", MPSStateBatchIncrementReadCount(temporaries, 2));
        printf("temporary-counts-up %lu %lu %lu\n", (unsigned long)a.readCount, (unsigned long)b.readCount, (unsigned long)c.readCount);
        printf("temporary-batch-down %lu\n", MPSStateBatchIncrementReadCount(temporaries, -1));
        printf("temporary-counts-down %lu %lu %lu\n", (unsigned long)a.readCount, (unsigned long)b.readCount, (unsigned long)c.readCount);
        // Synchronizing a temporary is not a case the release accepts: a temporary's storage is not
        // readable from the CPU, which is the whole of what synchronizing is for.
    });

    uint32_t predicate = 7;
    id<MTLBuffer> predicateBuffer = [gDevice newBufferWithBytes:&predicate length:4 options:MTLResourceStorageModeShared];
    MPSPredicate *yes = [MPSPredicate predicateWithBuffer:predicateBuffer offset:0];
    printf("predicate %lu %lu\n", (unsigned long)yes.predicateOffset, (unsigned long)yes.predicateBuffer.length);
    id<MTLCommandBuffer> buffer = freshCommandBuffer();
    MPSCommandBuffer *wrapped = [MPSCommandBuffer commandBufferWithCommandBuffer:buffer];
    wrapped.predicate = yes;
    printf("command-buffer %d %d\n", wrapped.commandBuffer == buffer, wrapped.predicate == yes);
    printf("root-command-buffer %d\n", wrapped.rootCommandBuffer == buffer);
    [wrapped prefetchHeapForWorkloadSize:1024];
    [buffer commit];
    [buffer waitUntilCompleted];
}


#pragma mark - the linear solvers

static float luSource[4][4] = {{0, 2, 1, 4}, {3, 8, 2, 1}, {1, 0, 7, 3}, {2, 1, 1, 9}};
static float luResult[4][4];
static uint32_t luPivots[4];
static int32_t luStatus[1];
static float luRight[4][2] = {{1, 2}, {3, 4}, {5, 6}, {7, 8}};
static float luSolution[4][2];
static float singularSource[3][3] = {{1, 2, 3}, {2, 4, 6}, {1, 1, 1}};
static float singularResult[3][3];
static uint32_t singularPivots[3];
static int32_t singularStatus[1];

// The solver cases. They are not called from main yet: MPSMatrixSolve.m is not in the tree, because
// its results do not yet match the release's (see the handoff in .agent-work). They are here so the
// cases are ready and reviewable, and they are run the moment the sources are.
static void casesDecomposition(void)
{
    {
        memset(luResult, 0, sizeof(luResult));
        memset(luPivots, 0, sizeof(luPivots));
        memset(luStatus, 0, sizeof(luStatus));
        run("cholesky %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *in = matrixOf(&luSource[0][0], MPSDataTypeFloat32, 4, 4, 1, 4 * sizeof(float), 16 * sizeof(float));
            MPSMatrix *out = matrixOf(&luResult[0][0], MPSDataTypeFloat32, 4, 4, 1, 4 * sizeof(float), 16 * sizeof(float));
            MPSMatrix *pivots = matrixOf(&luPivots[0], MPSDataTypeUInt32, 1, 4, 1, 4 * sizeof(uint32_t), 4 * sizeof(uint32_t));
            id<MTLBuffer> status = [gDevice newBufferWithLength:sizeof(luStatus) options:MTLResourceStorageModeShared];
            MPSMatrixDecompositionLU *kernel = [[MPSMatrixDecompositionLU alloc] initWithDevice:gDevice rows:4 columns:4];
            [kernel encodeToCommandBuffer:commandBuffer sourceMatrix:in resultMatrix:out pivotIndices:pivots status:status];
            [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> finished) {
                memcpy(luStatus, status.contents, sizeof(luStatus));
            }];
        });
        put("lu-result", &luResult[0][0], sizeof(luResult));
        put("lu-pivots", luPivots, sizeof(luPivots));
        put("lu-status", luStatus, sizeof(luStatus));
    }
    memset(singularResult, 0, sizeof(singularResult));
    memset(singularPivots, 0, sizeof(singularPivots));
    memset(singularStatus, 0, sizeof(singularStatus));
    run("cholesky %d", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *in = matrixOf(&singularSource[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
        MPSMatrix *out = matrixOf(&singularResult[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
        MPSMatrix *pivots = matrixOf(&singularPivots[0], MPSDataTypeUInt32, 1, 3, 1, 3 * sizeof(uint32_t), 3 * sizeof(uint32_t));
        id<MTLBuffer> status = [gDevice newBufferWithLength:sizeof(singularStatus) options:MTLResourceStorageModeShared];
        MPSMatrixDecompositionLU *kernel = [[MPSMatrixDecompositionLU alloc] initWithDevice:gDevice rows:3 columns:3];
        [kernel encodeToCommandBuffer:commandBuffer sourceMatrix:in resultMatrix:out pivotIndices:pivots status:status];
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> finished) {
            memcpy(singularStatus, status.contents, sizeof(singularStatus));
        }];
    });
    put("lu-singular-result", &singularResult[0][0], sizeof(singularResult));
    put("lu-singular-pivots", singularPivots, sizeof(singularPivots));
    put("lu-singular-status", singularStatus, sizeof(singularStatus));
}

static float choleskyLower[4][4] = {{4, 0, 0, 0}, {1, 3, 0, 0}, {2, -1, 5, 0}, {1, 1, 1, 6}};
static float choleskyUpper[4][4] = {{4, 1, 2, 1}, {0, 3, -1, 1}, {0, 0, 5, 1}, {0, 0, 0, 6}};
static float choleskyResult[4][4];
static int32_t choleskyStatus[1];
static float indefinite[2][2] = {{1, 2}, {2, 1}};
static float indefiniteResult[2][2];
static int32_t indefiniteStatus[1];

static void casesCholesky(void)
{
    for (int lower = 0; lower < 2; lower++) {
        memset(choleskyResult, 0, sizeof(choleskyResult));
        memset(choleskyStatus, 0, sizeof(choleskyStatus));
        float (*source)[4] = lower ? choleskyLower : choleskyUpper;
        run("cholesky %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *in = matrixOf(&source[0][0], MPSDataTypeFloat32, 4, 4, 1, 4 * sizeof(float), 16 * sizeof(float));
            MPSMatrix *out = matrixOf(&choleskyResult[0][0], MPSDataTypeFloat32, 4, 4, 1, 4 * sizeof(float), 16 * sizeof(float));
            id<MTLBuffer> status = [gDevice newBufferWithLength:sizeof(choleskyStatus) options:MTLResourceStorageModeShared];
            MPSMatrixDecompositionCholesky *kernel = [[MPSMatrixDecompositionCholesky alloc] initWithDevice:gDevice lower:lower order:4];
            [kernel encodeToCommandBuffer:commandBuffer sourceMatrix:in resultMatrix:out status:status];
            [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> finished) {
                memcpy(choleskyStatus, status.contents, sizeof(choleskyStatus));
            }];
        });
        char name[64];
        snprintf(name, sizeof(name), "cholesky %d", lower);
        put(name, &choleskyResult[0][0], sizeof(choleskyResult));
        snprintf(name, sizeof(name), "cholesky-status %d", lower);
        put(name, choleskyStatus, sizeof(choleskyStatus));
    }
    memset(indefiniteResult, 0, sizeof(indefiniteResult));
    memset(indefiniteStatus, 0, sizeof(indefiniteStatus));
    run("solve-triangular %d %d %d %d", ^(id<MTLCommandBuffer> commandBuffer) {
        MPSMatrix *in = matrixOf(&indefinite[0][0], MPSDataTypeFloat32, 2, 2, 1, 2 * sizeof(float), 4 * sizeof(float));
        MPSMatrix *out = matrixOf(&indefiniteResult[0][0], MPSDataTypeFloat32, 2, 2, 1, 2 * sizeof(float), 4 * sizeof(float));
        id<MTLBuffer> status = [gDevice newBufferWithLength:sizeof(indefiniteStatus) options:MTLResourceStorageModeShared];
        MPSMatrixDecompositionCholesky *kernel = [[MPSMatrixDecompositionCholesky alloc] initWithDevice:gDevice lower:YES order:2];
        [kernel encodeToCommandBuffer:commandBuffer sourceMatrix:in resultMatrix:out status:status];
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> finished) {
            memcpy(indefiniteStatus, status.contents, sizeof(indefiniteStatus));
        }];
    });
    put("cholesky-indefinite-result", &indefiniteResult[0][0], sizeof(indefiniteResult));
    put("cholesky-indefinite-status", indefiniteStatus, sizeof(indefiniteStatus));
}

static float triangularLower[3][3] = {{2, 0, 0}, {1, 3, 0}, {-1, 2, 4}};
static float triangularUpper[3][3] = {{2, 1, -1}, {0, 3, 2}, {0, 0, 4}};
static float triangularRight[3][3] = {{1, 2, 9}, {3, 4, 9}, {5, 6, 9}};
static float triangularSolution[3][3];

static void casesSolveTriangular(void)
{
    for (int upper = 0; upper < 2; upper++) {
        for (int right = 0; right < 2; right++) {
            for (int transpose = 0; transpose < 2; transpose++) {
                for (int unit = 0; unit < 2; unit++) {
                    memset(triangularSolution, 0, sizeof(triangularSolution));
                    float (*source)[3] = upper ? triangularUpper : triangularLower;
                    run("solve-triangular %d %d %d %d", ^(id<MTLCommandBuffer> commandBuffer) {
                        MPSMatrix *in = matrixOf(&source[0][0], MPSDataTypeFloat32, 3, 3, 1, 3 * sizeof(float), 9 * sizeof(float));
                        // The right hand side is order x sides, or sides x order when the right hand
                        // side is on the right, which is the shape the release insists on.
                        NSUInteger rhsRows = right ? 2 : 3, rhsColumns = right ? 3 : 2;
                        MPSMatrix *rhs = matrixOf(&triangularRight[0][0], MPSDataTypeFloat32, rhsRows, rhsColumns, 1, 3 * sizeof(float), 9 * sizeof(float));
                        MPSMatrix *out = matrixOf(&triangularSolution[0][0], MPSDataTypeFloat32, rhsRows, rhsColumns, 1, 3 * sizeof(float), 9 * sizeof(float));
                        MPSMatrixSolveTriangular *kernel = [[MPSMatrixSolveTriangular alloc] initWithDevice:gDevice
                                                                                                   right:right
                                                                                                   upper:upper
                                                                                               transpose:transpose
                                                                                                    unit:unit
                                                                                                   order:3
                                                                                  numberOfRightHandSides:2
                                                                                                   alpha:1.5];
                        [kernel encodeToCommandBuffer:commandBuffer sourceMatrix:in rightHandSideMatrix:rhs solutionMatrix:out];
                    });
                    char name[96];
                    snprintf(name, sizeof(name), "solve-triangular %d %d %d %d", upper, right, transpose, unit);
                    put(name, &triangularSolution[0][0], right ? 2 * 3 * sizeof(float) : 3 * 2 * sizeof(float));
                }
            }
        }
    }
}

static void casesSolveLU(void)
{
    for (int transpose = 0; transpose < 2; transpose++) {
        memset(luSolution, 0, sizeof(luSolution));
        run("solve-lu %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *in = matrixOf(&luResult[0][0], MPSDataTypeFloat32, 4, 4, 1, 4 * sizeof(float), 16 * sizeof(float));
            MPSMatrix *rhs = matrixOf(&luRight[0][0], MPSDataTypeFloat32, 4, 2, 1, 2 * sizeof(float), 8 * sizeof(float));
            MPSMatrix *pivots = matrixOf(&luPivots[0], MPSDataTypeUInt32, 1, 4, 1, 4 * sizeof(uint32_t), 4 * sizeof(uint32_t));
            MPSMatrix *out = matrixOf(&luSolution[0][0], MPSDataTypeFloat32, 4, 2, 1, 2 * sizeof(float), 8 * sizeof(float));
            MPSMatrixSolveLU *kernel = [[MPSMatrixSolveLU alloc] initWithDevice:gDevice transpose:transpose order:4 numberOfRightHandSides:2];
            [kernel encodeToCommandBuffer:commandBuffer sourceMatrix:in rightHandSideMatrix:rhs pivotIndices:pivots solutionMatrix:out];
        });
        char name[64];
        snprintf(name, sizeof(name), "solve-lu %d", transpose);
        put(name, &luSolution[0][0], sizeof(luSolution));
    }
}

static void casesSolveCholesky(void)
{
    for (int upper = 0; upper < 2; upper++) {
        memset(luSolution, 0, sizeof(luSolution));
        run("solve-cholesky %d", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *in = matrixOf(&choleskyResult[0][0], MPSDataTypeFloat32, 4, 4, 1, 4 * sizeof(float), 16 * sizeof(float));
            MPSMatrix *rhs = matrixOf(&luRight[0][0], MPSDataTypeFloat32, 4, 2, 1, 2 * sizeof(float), 8 * sizeof(float));
            MPSMatrix *out = matrixOf(&luSolution[0][0], MPSDataTypeFloat32, 4, 2, 1, 2 * sizeof(float), 8 * sizeof(float));
            MPSMatrixSolveCholesky *kernel = [[MPSMatrixSolveCholesky alloc] initWithDevice:gDevice upper:upper order:4 numberOfRightHandSides:2];
            [kernel encodeToCommandBuffer:commandBuffer sourceMatrix:in rightHandSideMatrix:rhs solutionMatrix:out];
        });
        char name[64];
        snprintf(name, sizeof(name), "solve-cholesky %d", upper);
        put(name, &luSolution[0][0], sizeof(luSolution));
    }
}

#pragma mark - the random generators

static uint32_t randomWords[16];
static float randomFloats[16];

static void casesRandom(void)
{
    for (uint32_t seed = 0; seed < 3; seed++) {
        memset(randomWords, 0, sizeof(randomWords));
        run("philox-uint32 %u", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *out = matrixOf(&randomWords[0], MPSDataTypeUInt32, 4, 4, 1, 4 * sizeof(uint32_t), 16 * sizeof(uint32_t));
            MPSMatrixRandomPhilox *kernel = [[MPSMatrixRandomPhilox alloc] initWithDevice:gDevice destinationDataType:MPSDataTypeUInt32 seed:seed];
            [kernel encodeToCommandBuffer:commandBuffer destinationMatrix:out];
        });
        char name[64];
        snprintf(name, sizeof(name), "philox-uint32 %u", seed);
        put(name, randomWords, sizeof(randomWords));

        // A Float32 destination, which the release does answer, through the twenty-three bit fraction
        // and the scale and add of facts/MetalPerformanceShaders/Random.md.
        for (int which = 0; which < 2; which++) {
            memset(randomFloats, 0, sizeof(randomFloats));
            run("philox-float32-uniform %u %d", ^(id<MTLCommandBuffer> commandBuffer) {
                MPSMatrix *out = matrixOf(&randomFloats[0], MPSDataTypeFloat32, 4, 4, 1, 4 * sizeof(float), 16 * sizeof(float));
                MPSMatrixRandomPhilox *kernel = [[MPSMatrixRandomPhilox alloc] initWithDevice:gDevice destinationDataType:MPSDataTypeFloat32 seed:seed
                                 distributionDescriptor:which == 0
                                     ? [MPSMatrixRandomDistributionDescriptor uniformDistributionDescriptorWithMinimum:0 maximum:1]
                                     : [MPSMatrixRandomDistributionDescriptor uniformDistributionDescriptorWithMinimum:-2 maximum:3]];
                [kernel encodeToCommandBuffer:commandBuffer destinationMatrix:out];
            });
            snprintf(name, sizeof(name), "philox-float32-uniform %u %d", seed, which);
            put(name, randomFloats, sizeof(randomFloats));
        }
        // The normal distribution goes through the release's own single precision inverse normal, which
        // a sixteen digit one does not land on to the bit; named as a divergence, not compared.
        memset(randomFloats, 0, sizeof(randomFloats));
        run("divergent philox-float32-normal %u", ^(id<MTLCommandBuffer> commandBuffer) {
            MPSMatrix *out = matrixOf(&randomFloats[0], MPSDataTypeFloat32, 4, 4, 1, 4 * sizeof(float), 16 * sizeof(float));
            MPSMatrixRandomPhilox *kernel = [[MPSMatrixRandomPhilox alloc] initWithDevice:gDevice destinationDataType:MPSDataTypeFloat32 seed:seed
                             distributionDescriptor:[MPSMatrixRandomDistributionDescriptor normalDistributionDescriptorWithMean:2 standardDeviation:3]];
            [kernel encodeToCommandBuffer:commandBuffer destinationMatrix:out];
        });
        snprintf(name, sizeof(name), "divergent philox-float32-normal %u", seed);
        put(name, randomFloats, sizeof(randomFloats));

        // The MPSVector destination is the one the release does not answer: its own random kernel sends
        // -[MPSVector rowBytes], a selector MPSVector does not declare, and takes the process down. The
        // batch range over a matrix destination it refuses in its own validation, saying the range runs
        // past the image. Both are measurements, kept in crash-probe.m and named in Random.md.
    }
    // The uniform descriptor's own moments, which the release fills in.
    {
        float pairs[][2] = {{-2, 3}, {0, 1}, {1.5f, 2.5f}, {-10, 10}};
        for (unsigned i = 0; i < 4; i++) {
            MPSMatrixRandomDistributionDescriptor *uniform = [MPSMatrixRandomDistributionDescriptor uniformDistributionDescriptorWithMinimum:pairs[i][0] maximum:pairs[i][1]];
            printf("distribution-uniform %u %d %.9g %.9g %.9g %.9g\n", i, (int)uniform.distributionType, uniform.minimum, uniform.maximum, uniform.mean, uniform.standardDeviation);
            MPSMatrixRandomDistributionDescriptor *normal = [MPSMatrixRandomDistributionDescriptor normalDistributionDescriptorWithMean:1.25f standardDeviation:0.5f];
            printf("distribution-normal %u %d %.9g %.9g %.9g %.9g\n", i, (int)normal.distributionType, normal.minimum, normal.maximum, normal.mean, normal.standardDeviation);
            MPSMatrixRandomDistributionDescriptor *plain = [MPSMatrixRandomDistributionDescriptor defaultDistributionDescriptor];
            printf("distribution-default %u %d %.9g %.9g %.9g %.9g\n", i, (int)plain.distributionType, plain.minimum, plain.maximum, plain.mean, plain.standardDeviation);
        }
    }
}

int main(void)
{
    @autoreleasepool {
        gDevice = MTLCreateSystemDefaultDevice();
        if (!gDevice) {
            printf("no device\n");
            return 1;
        }
        printf("device %d\n", MPSSupportsMTLDevice(gDevice));
        @autoreleasepool {
            printf("group casesDevice\n");
            fflush(stdout);
            casesDevice();
        }
        @autoreleasepool {
            printf("group casesDescriptors\n");
            fflush(stdout);
            casesDescriptors();
        }
        @autoreleasepool {
            printf("group casesMultiplication\n");
            fflush(stdout);
            casesMultiplication();
        }
        @autoreleasepool {
            printf("group casesVectorMultiplication\n");
            fflush(stdout);
            casesVectorMultiplication();
        }
        @autoreleasepool {
            printf("group casesCopy\n");
            fflush(stdout);
            casesCopy();
        }
        @autoreleasepool {
            printf("group casesSoftMax\n");
            fflush(stdout);
            casesSoftMax();
        }
        @autoreleasepool {
            printf("group casesNeuron\n");
            fflush(stdout);
            casesNeuron();
        }
        @autoreleasepool {
            printf("group casesFullyConnected\n");
            fflush(stdout);
            casesFullyConnected();
        }
        @autoreleasepool {
            printf("group casesBatchNormalization\n");
            fflush(stdout);
            casesBatchNormalization();
        }
        @autoreleasepool {
            printf("group casesSum\n");
            fflush(stdout);
            casesSum();
        }
        @autoreleasepool {
            printf("group casesState\n");
            fflush(stdout);
            casesState();
        }
        @autoreleasepool {
            printf("group casesRandom\n");
            fflush(stdout);
            casesRandom();
        }
    }
    return 0;
}
