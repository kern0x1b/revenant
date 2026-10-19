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

        {
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32
                                                                                    shape:@[@5, @4, @3, @2]];
            printf("case2 dimensions=%lu\n", (unsigned long)descriptor.numberOfDimensions);
            for (NSUInteger i = 0; i < 4; i++)
                printf("case2 length[%lu]=%lu\n", (unsigned long)i, (unsigned long)[descriptor lengthOfDimension:i]);
        }

        {
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionSizes:7, 6, 0];
            printf("case3 dimensions=%lu length0=%lu length1=%lu\n", (unsigned long)descriptor.numberOfDimensions,
                   (unsigned long)[descriptor lengthOfDimension:0], (unsigned long)[descriptor lengthOfDimension:1]);
        }

        {
            NSUInteger sizes[2] = {2, 3};
            MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:2 dimensionSizes:sizes];
            printOrder("case4 before", descriptor);
            [descriptor transposeDimension:0 withDimension:1];
            printOrder("case4 after", descriptor);
            printf("case4 length0=%lu length1=%lu\n", (unsigned long)[descriptor lengthOfDimension:0], (unsigned long)[descriptor lengthOfDimension:1]);
        }

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

        {
            MPSNDArray *scalar = [[MPSNDArray alloc] initWithDevice:device scalar:3.5];
            printShape("case10 scalar", scalar);
            printValues("case10 scalar value", scalar);
            printf("case10 type=%u\n", (unsigned)scalar.dataType);
        }

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
