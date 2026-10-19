#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

static id<MTLDevice> device;
static int compared = 0;
static int mismatches = 0;

static void expectFloats(NSString *label, NSArray<NSNumber *> *got, NSArray<NSNumber *> *want)
{
    for (NSUInteger i = 0; i < want.count; i++) {
        compared++;
        double a = [got[i] doubleValue], b = [want[i] doubleValue];
        if (a != b) {
            mismatches++;
            printf("%s element %lu: port %.9g, reference %.9g\n", [label UTF8String], (unsigned long)i, a, b);
        }
    }
}

static MPSNDArray *makeArray(NSArray<NSNumber *> *values, NSUInteger *sizes, NSUInteger dimensions)
{
    MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32
                                                                    dimensionCount:dimensions
                                                                    dimensionSizes:sizes];
    MPSNDArray *array = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
    NSUInteger count = values.count;
    float *bytes = malloc(count * sizeof(float));
    for (NSUInteger i = 0; i < count; i++)
        bytes[i] = (float)[values[i] doubleValue];
    [array writeBytes:bytes strideBytes:NULL];
    free(bytes);
    return array;
}

static NSArray<NSNumber *> *readArray(MPSNDArray *array)
{
    NSUInteger count = 1;
    for (NSUInteger i = 0; i < array.numberOfDimensions; i++)
        count *= [array lengthOfDimension:i];
    float *bytes = malloc(count * sizeof(float));
    [array readBytes:bytes strideBytes:NULL];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++)
        [values addObject:@(bytes[i])];
    free(bytes);
    return values;
}

static NSArray<NSNumber *> *zerosOf(NSUInteger count)
{
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++)
        [values addObject:@0];
    return values;
}

static MPSNDArrayOffsets offsetsWithFirst(NSInteger first)
{
    MPSNDArrayOffsets strides;
    for (int i = 0; i < 16; i++)
        strides.dimensions[i] = 1;
    strides.dimensions[0] = first;
    return strides;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        device = MTLCreateSystemDefaultDevice();
        if (!device) {
            printf("no device\n");
            return 1;
        }
        id<MTLCommandBuffer> cmdBuf = (id<MTLCommandBuffer>)[device newCommandBuffer];

        printf("case: gather axis 0\n");
        {
            NSUInteger sourceSizes[2] = {3, 2};
            NSUInteger resultSizes[2] = {3, 2};
            NSUInteger indexSizes[1] = {3};
            MPSNDArray *array = makeArray(@[@1, @2, @3, @4, @5, @6], sourceSizes, 2);
            MPSNDArray *indices = makeArray(@[@2, @0, @2], indexSizes, 1);
            MPSNDArrayGather *gather = [[MPSNDArrayGather alloc] initWithDevice:device];
            gather.axis = 0;
            MPSNDArray *result = [gather encodeToCommandBuffer:cmdBuf primarySourceArray:array secondarySourceArray:indices];
            printf("gather axis0 shape: %lu x %lu\n", (unsigned long)[result lengthOfDimension:0], (unsigned long)[result lengthOfDimension:1]);
            MPSNDArray *expected = makeArray(@[@3, @1, @3, @6, @4, @6], resultSizes, 2);
            expectFloats(@"gather axis0", readArray(result), readArray(expected));
        }

        printf("case: gather axis 1\n");
        {
            NSUInteger sourceSizes[2] = {3, 2};
            NSUInteger resultSizes[2] = {3, 4};
            NSUInteger indexSizes[1] = {4};
            MPSNDArray *array = makeArray(@[@1, @2, @3, @4, @5, @6], sourceSizes, 2);
            MPSNDArray *indices = makeArray(@[@1, @1, @0, @0], indexSizes, 1);
            MPSNDArrayGather *gather = [[MPSNDArrayGather alloc] initWithDevice:device];
            gather.axis = 1;
            MPSNDArray *result = [gather encodeToCommandBuffer:cmdBuf primarySourceArray:array secondarySourceArray:indices];
            printf("gather axis1 shape: %lu x %lu\n", (unsigned long)[result lengthOfDimension:0], (unsigned long)[result lengthOfDimension:1]);
            MPSNDArray *expected = makeArray(@[@4, @5, @6, @4, @5, @6, @1, @2, @3, @1, @2, @3], resultSizes, 2);
            expectFloats(@"gather axis1", readArray(result), readArray(expected));
            printf("case: gather axis 1 done\n");
        }

        printf("case: gather gradient\n");
        {
            NSUInteger sourceSizes[2] = {3, 2};
            NSUInteger indexSizes[1] = {3};
            MPSNDArray *array = makeArray(@[@1, @2, @3, @4, @5, @6], sourceSizes, 2);
            MPSNDArray *indices = makeArray(@[@2, @0, @2], indexSizes, 1);
            MPSNDArray *gradient = makeArray(@[@10, @20, @30, @40, @50, @60], sourceSizes, 2);
            MPSNDArrayGather *gather = [[MPSNDArrayGather alloc] initWithDevice:device];
            gather.axis = 0;
            MPSNDArrayGradientState *state = (MPSNDArrayGradientState *)
                [gather resultStateForSourceArrays:@[array, indices] sourceStates:nil destinationArray:array];
            MPSNDArrayGatherGradient *back = [[MPSNDArrayGatherGradient alloc] initWithDevice:device];
            MPSNDArray *destination = makeArray(zerosOf(6), sourceSizes, 2);
            [back encodeToCommandBuffer:cmdBuf primarySourceArray:array secondarySourceArray:indices
                      sourceGradient:gradient gradientState:state destinationArray:destination];
            MPSNDArray *expected = makeArray(@[@20, @0, @40, @50, @0, @100], sourceSizes, 2);
            expectFloats(@"gather gradient", readArray(destination), readArray(expected));
        }

        printf("case: strided slice stride 2\n");
        {
            NSUInteger sourceSizes[2] = {5, 1};
            NSUInteger resultSizes[2] = {3, 1};
            MPSNDArray *array = makeArray(@[@1, @2, @3, @4, @5], sourceSizes, 2);
            MPSNDArrayStridedSlice *slice = [[MPSNDArrayStridedSlice alloc] initWithDevice:device];
            slice.strides = offsetsWithFirst(2);
            MPSNDArray *destination = makeArray(zerosOf(3), resultSizes, 2);
            [slice encodeToCommandBuffer:cmdBuf sourceArray:array destinationArray:destination];
            MPSNDArray *expected = makeArray(@[@1, @3, @5], resultSizes, 2);
            expectFloats(@"strided slice stride2", readArray(destination), readArray(expected));
        }

        printf("case: strided slice stride 1\n");
        {
            NSUInteger sourceSizes[2] = {4, 2};
            MPSNDArray *array = makeArray(@[@1, @2, @3, @4, @5, @6, @7, @8], sourceSizes, 2);
            MPSNDArrayStridedSlice *slice = [[MPSNDArrayStridedSlice alloc] initWithDevice:device];
            MPSNDArray *destination = makeArray(zerosOf(8), sourceSizes, 2);
            [slice encodeToCommandBuffer:cmdBuf sourceArray:array destinationArray:destination];
            expectFloats(@"strided slice stride1", readArray(destination), readArray(array));
        }

        printf("case: strided slice gradient\n");
        {
            NSUInteger sourceSizes[2] = {5, 1};
            NSUInteger gradientSizes[2] = {3, 1};
            MPSNDArray *array = makeArray(@[@1, @2, @3, @4, @5], sourceSizes, 2);
            MPSNDArray *gradient = makeArray(@[@7, @8, @9], gradientSizes, 2);
            MPSNDArrayStridedSlice *slice = [[MPSNDArrayStridedSlice alloc] initWithDevice:device];
            slice.strides = offsetsWithFirst(2);
            MPSNDArrayGradientState *state = (MPSNDArrayGradientState *)
                [slice resultStateForSourceArrays:@[array] sourceStates:nil destinationArray:array];
            MPSNDArrayStridedSliceGradient *back = [[MPSNDArrayStridedSliceGradient alloc] initWithDevice:device];
            MPSNDArray *destination = makeArray(zerosOf(5), sourceSizes, 2);
            [back encodeToCommandBuffer:cmdBuf sourceArray:array sourceGradient:gradient
                           gradientState:state destinationArray:destination];
            MPSNDArray *expected = makeArray(@[@7, @0, @8, @0, @9], sourceSizes, 2);
            expectFloats(@"strided slice gradient", readArray(destination), readArray(expected));
        }

        printf("case: matmul\n");
        {
            NSUInteger leftSizes[2] = {2, 3};
            NSUInteger rightSizes[2] = {3, 2};
            NSUInteger resultSizes[2] = {3, 3};
            MPSNDArray *left = makeArray(@[@1, @2, @3, @4, @5, @6], leftSizes, 2);
            MPSNDArray *right = makeArray(@[@7, @8, @9, @10, @11, @12], rightSizes, 2);
            MPSNDArrayMatrixMultiplication *product = [[MPSNDArrayMatrixMultiplication alloc] initWithDevice:device
                                                                                               sourceCount:2];
            product.alpha = 1.0;
            product.beta = 0.0;
            MPSNDArray *destination = makeArray(zerosOf(9), resultSizes, 2);
            [product encodeToCommandBuffer:cmdBuf sourceArrays:@[left, right] destinationArray:destination];
            MPSNDArray *expected = makeArray(@[@27, @30, @33, @61, @68, @75, @95, @106, @117], resultSizes, 2);
            expectFloats(@"matmul 2x3 by 3x2", readArray(destination), readArray(expected));
        }

        printf("case: matmul alpha beta\n");
        {
            NSUInteger sizes[2] = {2, 2};
            MPSNDArray *left = makeArray(@[@1, @2, @3, @4], sizes, 2);
            MPSNDArray *right = makeArray(@[@5, @6, @7, @8], sizes, 2);
            MPSNDArray *addend = makeArray(@[@1, @1, @1, @1], sizes, 2);
            MPSNDArrayMatrixMultiplication *product = [[MPSNDArrayMatrixMultiplication alloc] initWithDevice:device
                                                                                               sourceCount:3];
            product.alpha = 2.0;
            product.beta = 3.0;
            MPSNDArray *destination = makeArray(zerosOf(4), sizes, 2);
            [product encodeToCommandBuffer:cmdBuf sourceArrays:@[left, right, addend] destinationArray:destination];
            MPSNDArray *expected = makeArray(@[@41, @47, @89, @103], sizes, 2);
            expectFloats(@"matmul alpha beta", readArray(destination), readArray(expected));
        }

        printf("case: matmul batch broadcast\n");
        {
            NSUInteger leftSizes[4] = {2, 2, 2, 1};
            NSUInteger rightSizes[4] = {2, 2, 1, 2};
            NSUInteger resultSizes[4] = {2, 2, 2, 2};
            NSArray *leftValues = @[@1, @0, @0, @1, @1, @2, @3, @4];
            NSArray *rightValues = @[@1, @2, @3, @4, @5, @6, @7, @8];
            MPSNDArray *left = makeArray(leftValues, leftSizes, 4);
            MPSNDArray *right = makeArray(rightValues, rightSizes, 4);
            MPSNDArrayMatrixMultiplication *product = [[MPSNDArrayMatrixMultiplication alloc] initWithDevice:device
                                                                                               sourceCount:2];
            product.alpha = 1.0;
            product.beta = 0.0;
            MPSNDArray *destination = makeArray(zerosOf(16), resultSizes, 4);
            [product encodeToCommandBuffer:cmdBuf sourceArrays:@[left, right] destinationArray:destination];
            NSArray *expected = @[@1, @2, @3, @4, @7, @10, @15, @22, @5, @6, @7, @8, @19, @22, @43, @50];
            expectFloats(@"matmul batch broadcast", readArray(destination), expected);
        }
    }
    printf("compared: %d elements, mismatches: %d\n", compared, mismatches);
    return mismatches ? 1 : 0;
}
