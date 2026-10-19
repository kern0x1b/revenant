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
