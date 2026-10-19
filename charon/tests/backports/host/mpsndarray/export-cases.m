// export-cases.m - the export and import pair, against the PORT alone.
//
// The release cannot answer this one on this host, and that is measured: its own
// -exportDataWithCommandBuffer:toBuffer:destinationDataType:offset:rowStrides: dies with
// '-[AGXG16XFamilyCommandBuffer_mtlnext retainedReferences]: unrecognized selector', raised inside
// MPSCore's MPSNewBufferForTexture. The expected values below are therefore stated in this file and
// not measured from Apple's code, and every row that rests on them says so - this is the shape the
// image and matrix families in this package already take (tests/backports/host/mpsimage9/run.sh).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

static void printValues(const char *label, MPSNDArray *array)
{
    NSUInteger count = 1;
    for (NSUInteger i = 0; i < array.numberOfDimensions; i++)
        count *= [array lengthOfDimension:i];
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

int main(void)
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandBuffer> cmdBuf = (id<MTLCommandBuffer>)[device newCommandBuffer];
        if (!device || !cmdBuf) {
            printf("no device\n");
            return 1;
        }

        // ShallNotAlias, which MPSCoreTypes.h:329 defines as "Always make a copy", on a transposed
        // view of a [2,3] array holding 1..6. A copy and an alias answer the same numbers, so what
        // this pins is that ASKING for the copy does not change them and does not change the shape:
        // the six values of a transposed [2,3] are 1 3 5 2 4 6, the same as case 7 asks of an alias.
        {
            NSUInteger sizes[2] = {2, 3};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            float in[6] = {1, 2, 3, 4, 5, 6};
            [array writeBytes:in strideBytes:NULL];
            MPSNDArrayDescriptor *view = [array descriptor];
            [view transposeDimension:0 withDimension:1];
            MPSNDArray *copied = [array arrayViewWithCommandBuffer:cmdBuf descriptor:view aliasing:MPSAliasingStrategyShallNotAlias];
            printf("copy dimensions=%lu %lu\n", (unsigned long)copied.numberOfDimensions,
                   (unsigned long)[copied lengthOfDimension:0]);
            printValues("copy values", copied);
        }

        // A 4x2 float32 array holding 1..8, exported to a buffer at offset 0 with no row strides.
        // The header says the copy is of "the contents of a MPSNDArray" (MPSCore/MPSNDArray.h:322)
        // and that the destination's own data type is applied, so the expected bytes are 1..8 in the
        // array's own packed order, float32 at a time.
        {
            NSUInteger sizes[2] = {4, 2};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            float in[8] = {1, 2, 3, 4, 5, 6, 7, 8};
            [array writeBytes:in strideBytes:NULL];
            id<MTLBuffer> buffer = [device newBufferWithLength:64 options:MTLResourceStorageModeShared];
            [array exportDataWithCommandBuffer:cmdBuf toBuffer:buffer destinationDataType:MPSDataTypeFloat32 offset:0 rowStrides:NULL];
            float out[8] = {0};
            memcpy(out, [buffer contents], 32);
            printf("export packed:");
            for (int i = 0; i < 8; i++)
                printf(" %.6g", (double)out[i]);
            printf("\n");
        }

        // The same array exported with a row stride of 8 bytes per row and 2 rows, which is what
        // rowStrides is for: the header defines it as the byte distance between one position and the next along a dimension (MPSCore/MPSNDArray.h:328-329). So only the two elements of each row are
        // written and the six bytes between the rows are the buffer's own, which this harness
        // pre-fills with a sentinel so a row-strided write that overwrote them would show.
        {
            NSUInteger sizes[2] = {4, 2};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            float in[8] = {1, 2, 3, 4, 5, 6, 7, 8};
            [array writeBytes:in strideBytes:NULL];
            id<MTLBuffer> buffer = [device newBufferWithLength:64 options:MTLResourceStorageModeShared];
            memset([buffer contents], 0x7F, 32);
            NSInteger rowStrides[2] = {8, 16};
            [array exportDataWithCommandBuffer:cmdBuf toBuffer:buffer destinationDataType:MPSDataTypeFloat32 offset:0 rowStrides:rowStrides];
            unsigned char *raw = (unsigned char *)[buffer contents];
            printf("export strided:");
            for (int i = 0; i < 24; i++)
                printf(" %02x", raw[i]);
            printf("\n");
        }

        // A float32 array exported into a uint8 buffer, which is what destinationDataType is for:
        // the values are the numbers the destination type holds, not the bytes of the source's.
        {
            NSUInteger sizes[2] = {2, 2};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            float in[4] = {1.0f, 2.0f, 3.0f, 4.0f};
            [array writeBytes:in strideBytes:NULL];
            id<MTLBuffer> buffer = [device newBufferWithLength:64 options:MTLResourceStorageModeShared];
            [array exportDataWithCommandBuffer:cmdBuf toBuffer:buffer destinationDataType:MPSDataTypeUInt8 offset:0 rowStrides:NULL];
            unsigned char *raw = (unsigned char *)[buffer contents];
            printf("export to uint8:");
            for (int i = 0; i < 4; i++)
                printf(" %u", (unsigned)raw[i]);
            printf("\n");
        }

        // The import half, which is the mirror: a buffer of float32 read into an array that then
        // reads back the same eight numbers.
        {
            NSUInteger sizes[2] = {4, 2};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
            id<MTLBuffer> buffer = [device newBufferWithLength:64 options:MTLResourceStorageModeShared];
            float in[8] = {10, 20, 30, 40, 50, 60, 70, 80};
            memcpy([buffer contents], in, 32);
            [array importDataWithCommandBuffer:cmdBuf fromBuffer:buffer sourceDataType:MPSDataTypeFloat32 offset:0 rowStrides:NULL];
            float out[8] = {0};
            [array readBytes:out strideBytes:NULL];
            printf("import packed:");
            for (int i = 0; i < 8; i++)
                printf(" %.6g", (double)out[i]);
            printf("\n");
        }
    }
    return 0;
}
