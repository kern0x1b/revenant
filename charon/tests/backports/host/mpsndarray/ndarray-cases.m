// ndarray-cases.m - the shape, the view and the bytes, stated once and asked of two builds.
//
// The build against the system's own MPSPerformanceShaders and the build against this port's classes
// answer the same questions, and the answers are compared element by element. Every case names its
// inputs and its expectations in this file, so a case whose expected value came from the port's own
// arithmetic could not agree with itself.
//
// WHAT IS AND IS NOT AN ORACLE HERE. An MPSNDArray is storage, not a kernel: the release makes one
// from a descriptor, takes a view of it and reads and writes it through -readBytes:strideBytes: and
// -writeBytes:strideBytes:. None of that needs a compute encoder, so the release's own MPSNDArray
// runs on this host and IS the oracle for every case here. That is a stronger claim than the image
// and matrix families in this package can make - tests/backports/host/mpsimage9/run.sh records that
// this host's AGX family lacks computeCommandEncoderWithDispatchType: and the release's own MPSImage
// kernels die encoding - and it is why this harness compares two builds rather than a build against a
// CPU reference written from the headers.
//
// The kernel cases are NOT here and are not claimed: MPSNDArrayGather and its gradient, the strided
// slice and its gradient, and the matrix multiplication all encode into a command buffer this host
// cannot commit, and their own rows say so.
//
// The ShallNotAlias COPY and the export/import pair are not here either, and that is measured rather than assumed: the
// release's own -exportDataWithCommandBuffer:toBuffer:... dies on this host with
// '-[AGXG16XFamilyCommandBuffer_mtlnext retainedReferences]: unrecognized selector', raised inside
// MPSCore's MPSNewBufferForTexture on its way to MPSDecrementReadCount - the same AGX-family
// limitation tests/backports/host/mpsimage9/run.sh records for the image kernels, reached here
// through a STORAGE path rather than a compute one. The ShallNotAlias copy of case 9 - which the
// header defines as "Always make a copy" (MPSCoreTypes.h:329) - dies there too, and the stack names
// the same MPSNewBufferForTexture: the release makes its copy through a texture this host's family
// cannot give it. So cases 9 and 12 are in export-cases.m, which runs against the port alone and
// states its own expectations.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

static id<MTLDevice> device;

static void printShape(const char *label, MPSNDArray *array)
{
    printf("%s dimensions=%lu", label, (unsigned long)array.numberOfDimensions);
    for (NSUInteger i = 0; i < array.numberOfDimensions; i++)
        printf(" %lu", (unsigned long)[array lengthOfDimension:i]);
    printf("\n");
}

static void printValues(const char *label, MPSNDArray *array)
{
    NSUInteger count = 1;
    for (NSUInteger i = 0; i < array.numberOfDimensions; i++)
        count *= [array lengthOfDimension:i];
    if (!count)
        count = 1;
    unsigned char *values = malloc(count * sizeof(float));
    [array readBytes:values strideBytes:NULL];
    // The RAW BYTES, not the values they print as. A planted build that shifts one bit of one
    // element's exponent is invisible at %.6g - 1.0f and 1.0000002f print the same - and a harness
    // whose printing hides its own plant reports a green run it did not earn. Little-endian byte
    // order, printed in address order, which is the order both sides walk in.
    printf("%s", label);
    for (NSUInteger i = 0; i < count * sizeof(float); i++)
        printf(" %02x", values[i]);
    printf("\n");
    free(values);
}

static void printOrder(const char *label, MPSNDArrayDescriptor *descriptor)
{
    vector_uchar16 order = [descriptor dimensionOrder];
    printf("%s", label);
    for (NSUInteger i = 0; i < 16; i++)
        printf(" %u", (unsigned)order[i]);
    printf("\n");
}

int main(void)
{
    @autoreleasepool {
        device = MTLCreateSystemDefaultDevice();
        if (!device) {
            printf("no device\n");
            return 1;
        }
        id<MTLCommandBuffer> cmdBuf = (id<MTLCommandBuffer>)[device newCommandBuffer];
        printf("commit: %s\n", cmdBuf ? "buffer made" : "no buffer");

        // CASE 1 - a four dimension descriptor from the dimensionCount form, whose sizes are given
        // fastest moving first (MPSCore/MPSNDArray.h:93-104). The expectation is the order the
        // header states, not the order the numbers are written in.
        {
            NSUInteger sizes[4] = {2, 3, 4, 5};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32
                                                                            dimensionCount:4
                                                                            dimensionSizes:sizes];
            printf("case1 type=%u dimensions=%lu\n", (unsigned)descriptor.dataType, (unsigned long)descriptor.numberOfDimensions);
            for (NSUInteger i = 0; i < 4; i++)
                printf("case1 length[%lu]=%lu\n", (unsigned long)i, (unsigned long)[descriptor lengthOfDimension:i]);
            printf("case1 pastEnd=%lu\n", (unsigned long)[descriptor lengthOfDimension:4]);
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            printShape("case1 array", array);
            printValues("case1 zero", array);
            printf("case1 resourceSize=%lu\n", (unsigned long)[array resourceSize]);
        }

        // CASE 2 - the shape form, whose order the header gives separately: "goes from slowest moving
        // to fastest moving dimension ... same order as MLMultiArray" (MPSCore/MPSNDArray.h:111-119),
        // and MPSCoreTypes.h:472 gives the worked example - a shape @[5,4,2] means the 0th dimension
        // is 2, the 1st is 4 and the slowest is 5. So the SAME numbers as case 1 in the OTHER order.
        {
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32
                                                                                    shape:@[@5, @4, @3, @2]];
            printf("case2 dimensions=%lu\n", (unsigned long)descriptor.numberOfDimensions);
            for (NSUInteger i = 0; i < 4; i++)
                printf("case2 length[%lu]=%lu\n", (unsigned long)i, (unsigned long)[descriptor lengthOfDimension:i]);
        }

        // CASE 3 - the variadic form, 0 terminated (MPSCore/MPSNDArray.h:120-124). A zero terminates
        // the list and is never a length, so the shape is 7 x 6 and not 7 x 6 x 0.
        {
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionSizes:7, 6, 0];
            printf("case3 dimensions=%lu length0=%lu length1=%lu\n", (unsigned long)descriptor.numberOfDimensions,
                   (unsigned long)[descriptor lengthOfDimension:0], (unsigned long)[descriptor lengthOfDimension:1]);
        }

        // CASE 4 - a transpose of dimensions 0 and 1, which the header says leaves the order at
        // {1,0,2,...,15} (MPSCore/MPSNDArray.h:70-74) and leaves the SHAPE alone: a transposed
        // [2,3] holds three rows of two and still six elements.
        {
            NSUInteger sizes[2] = {2, 3};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            printOrder("case4 before", descriptor);
            [descriptor transposeDimension:0 withDimension:1];
            printOrder("case4 after", descriptor);
            printf("case4 length0=%lu length1=%lu\n", (unsigned long)[descriptor lengthOfDimension:0], (unsigned long)[descriptor lengthOfDimension:1]);
        }

        // CASE 5 - writing a whole array through -writeBytes:strideBytes: and reading it back, so the
        // packed order is asked of both directions. A [2,3,4] array written 1..24 and read back must
        // read 1..24 again, and that is the statement that dim 0 is the fastest running.
        {
            NSUInteger sizes[3] = {2, 3, 4};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:3 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            float in[24];
            for (int i = 0; i < 24; i++)
                in[i] = (float)(i + 1);
            [array writeBytes:in strideBytes:NULL];
            printValues("case5 written", array);
        }

        // CASE 6 - a SLICED view, which is the case the class discussion is about: the slice is taken first and the result is transposed, and the slice of a dimension
        // starts at the header's own default, the full range of that dimension (MPSCore/MPSNDArray.h:60-64), so slicing dimension 1 of a 4 dimension array to 2..4 is a
        // view of two elements in that dimension and the same as many elsewhere.
        {
            NSUInteger sizes[3] = {3, 4, 2};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:3 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            float in[24];
            for (int i = 0; i < 24; i++)
                in[i] = (float)(i + 1);
            [array writeBytes:in strideBytes:NULL];
            MPSNDArrayDescriptor *view = [array descriptor];
            MPSDimensionSlice slice = {2, 2};
            [view sliceDimension:1 withSubrange:slice];
            MPSNDArray *sliced = [array arrayViewWithCommandBuffer:cmdBuf descriptor:view aliasing:MPSAliasingStrategyDefault];
            printShape("case6 sliced", sliced);
            printValues("case6 sliced values", sliced);
            printf("case6 aliased=%d\n", (int)(sliced.parent == array));
        }

        // CASE 7 - a TRANSPOSED view, which is the deferred transpose the class discussion describes:
        // the framework usually defers a physical transpose until later, so the view holds
        // the parent's elements in the other order. A [2,3] array holding 1..6 read transposed is
        // 1 4 2 5 3 6, which is what a [3,2] view of the same six elements must answer.
        {
            NSUInteger sizes[2] = {2, 3};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            float in[6] = {1, 2, 3, 4, 5, 6};
            [array writeBytes:in strideBytes:NULL];
            MPSNDArrayDescriptor *view = [array descriptor];
            [view transposeDimension:0 withDimension:1];
            MPSNDArray *transposed = [array arrayViewWithCommandBuffer:cmdBuf descriptor:view aliasing:MPSAliasingStrategyDefault];
            printShape("case7 transposed", transposed);
            printValues("case7 transposed values", transposed);
        }

        // CASE 8 - a slice AND a transpose together, which is the order the class discussion fixes:
        // the slice first, and the result of the slice transposed. So a [2,3] array sliced on
        // dimension 1 to 1..2 and transposed is a [2,2] view holding 2 5 3 6.
        {
            NSUInteger sizes[2] = {2, 3};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            float in[6] = {1, 2, 3, 4, 5, 6};
            [array writeBytes:in strideBytes:NULL];
            MPSNDArrayDescriptor *view = [array descriptor];
            MPSDimensionSlice slice = {1, 2};
            [view sliceDimension:1 withSubrange:slice];
            [view transposeDimension:0 withDimension:1];
            MPSNDArray *both = [array arrayViewWithCommandBuffer:cmdBuf descriptor:view aliasing:MPSAliasingStrategyDefault];
            printShape("case8 both", both);
            printValues("case8 both values", both);
        }

        // CASE 10 - -initWithDevice:scalar:, which the header gives as "a 1-Dimensional length=1
        // NDArray to hold a scalar" (MPSCore/MPSNDArray.h:270-272).
        {
            MPSNDArray *scalar = [[MPSNDArray alloc] initWithDevice:device scalar:3.5];
            printShape("case10 scalar", scalar);
            printValues("case10 scalar value", scalar);
            printf("case10 type=%u\n", (unsigned)scalar.dataType);
        }

        // CASE 11 - a non-float data type, so the element width is asked of a type other than the
        // float32 every other case uses. 2x3 int16 holding 1..6 is six elements of two bytes.
        {
            NSUInteger sizes[2] = {2, 3};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeInt16 dimensionCount:2 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            int16_t in[6] = {1, 2, 3, 4, 5, 6};
            [array writeBytes:in strideBytes:NULL];
            printf("case11 dataTypeSize=%lu resourceSize=%lu\n", (unsigned long)array.dataTypeSize, (unsigned long)[array resourceSize]);
            int16_t out[6] = {0};
            [array readBytes:out strideBytes:NULL];
            printf("case11 values");
            for (int i = 0; i < 6; i++)
                printf(" %d", (int)out[i]);
            printf("\n");
        }

    }
    return 0;
}
