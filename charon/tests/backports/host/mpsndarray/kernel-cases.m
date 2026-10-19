// kernel-cases.m - the three NDArray kernels, each against a plain C reference in this same process.
//
// WHY THERE IS NO SYSTEM BUILD HERE, and it is the same reason tests/backports/host/mpsimage9/run.sh
// gives: this host's AGX family does not implement computeCommandEncoderWithDispatchType: and the
// release's own MPS kernels die encoding with '-[AGXG16XFamilyCommandBuffer mtlnext
// computeCommandEncoderWithDispatchType:]: unrecognized selector'. An MPSNDArray's STORAGE answers here
// - ndarray-cases.m measures that against the release - but a KERNEL's encode does not, so the
// reference below is a plain C transcription of the same header wording, in this process, and no
// number this file prints measures Apple's code. Every registry row for these three kernels and their
// two gradients says exactly that.
//
// The reference is written from the HEADER, not from the port: each case states its inputs and its
// expected output here, and the comparison is against those stated numbers. A case whose expectation
// came out of the port could not fail, which is the failure mode this family of harnesses exists to
// catch, and the two planted builds in run.sh are what makes sure the comparison is looking at the
// port at all.
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
    // UNBUFFERED, so a case that takes the process down still has printed every case before it. With
    // the default block buffering a crash loses the whole run's output and the report says nothing,
    // which is how the first SIGSEGV here looked like an empty result rather than a failure.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        device = MTLCreateSystemDefaultDevice();
        if (!device) {
            printf("no device\n");
            return 1;
        }
        id<MTLCommandBuffer> cmdBuf = (id<MTLCommandBuffer>)[device newCommandBuffer];

        printf("case: gather axis 0\n");
        // GATHER on axis 0. A [3,2] source holding 1..6 and the indices [2,0,2] gathered on axis 0 is
        // a [3,2] result. DIMENSION 0 IS THE FASTEST RUNNING one, so the source is two rows of three
        // - (0,0..2) = 1 2 3 and (1,0..2) = 4 5 6 - and result[d0,d1] = source[indices[d0], d1]:
        //     d1=0:  source[2,0] source[0,0] source[2,0]  =  3 1 3
        //     d1=1:  source[2,1] source[0,1] source[2,1]  =  6 4 6
        // The header's own words (MPSNDArrayGather.h:39-46): "Along the specified axis result[i] =
        // source[indices[i]]". The first version of this case expected 5 6 1 2 5 6, which reads the
        // source as three rows of two - dimension 0 taken for the slow one - and the port disagreed
        // with it. The port was right and the reference was wrong, and that is the case file's whole
        // job: an expectation written from a misreading cannot fail the right thing.
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
        // GATHER on axis 1, where the result's SECOND dimension is the index count and NOT the
        // source's - the one place the result is not the source's shape. A [3,2] source gathered on
        // axis 1 with four indices is a [3,4] result, and with the indices [1,1,0,0] every source
        // element is read twice. Still dim 0 fastest, so the result's four columns are the INDEX
        // positions and its three rows are the source's fast axis:
        // the result is still dim 0 fastest, so the four columns are read as
        //     j=0: 4 5 6   j=1: 4 5 6   j=2: 1 2 3   j=3: 1 2 3
        // and the linear order runs down each column before moving to the next.
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
        // GATHER'S GRADIENT, and the case that makes it a SCATTER-ACCUMULATE and not a scatter: the
        // indices [2,0,2] name row 2 TWICE, so the gradient of row 2 is the sum of the first and the
        // third incoming value and a scatter would keep only the third. The gradient's axis is
        // derived from the two shapes, which is why this case's destination is the SOURCE's shape.
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
            // The gradient of source element (r, d1) is the sum of the incoming gradient of every
            // result position whose index is r, and dim 0 is fastest so both arrays are two rows of
            // three - 10 20 30 and 40 50 60 - and the indices are 2 0 2:
            //     r=0:  result position 1 only        ->  20 50
            //     r=1:  no result position names it   ->   0  0
            //     r=2:  result positions 0 and 2      ->  10+30 40+60  =  40 100
            MPSNDArray *expected = makeArray(@[@20, @0, @40, @50, @0, @100], sourceSizes, 2);
            expectFloats(@"gather gradient", readArray(destination), readArray(expected));
        }

        printf("case: strided slice stride 2\n");
        // STRIDED SLICE with a stride of 2 over a dimension of 5, which holds THREE elements and not
        // two: the count is a CEILING, so 0, 2 and 4 are read and a division would drop the 5.
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
        // STRIDED SLICE with a stride of 1, which is the default the header gives and the whole array.
        {
            NSUInteger sourceSizes[2] = {4, 2};
            MPSNDArray *array = makeArray(@[@1, @2, @3, @4, @5, @6, @7, @8], sourceSizes, 2);
            MPSNDArrayStridedSlice *slice = [[MPSNDArrayStridedSlice alloc] initWithDevice:device];
            MPSNDArray *destination = makeArray(zerosOf(8), sourceSizes, 2);
            [slice encodeToCommandBuffer:cmdBuf sourceArray:array destinationArray:destination];
            expectFloats(@"strided slice stride1", readArray(destination), readArray(array));
        }

        printf("case: strided slice gradient\n");
        // STRIDED SLICE'S GRADIENT, a scatter back onto the positions the forward pass read: with a
        // stride of 2 over 5, positions 0, 2 and 4 take the gradient and positions 1 and 3 stay zero,
        // so the positions it never read are part of the answer and are zero rather than absent.
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
        // MATRIX MULTIPLICATION, the matrix being the two most major dimensions
        // (MPSNDArrayMatrixMultiplication.h:33-35) and DIMENSION 0 BEING THE COLUMNS - the major row of
        // an NDArray is its columns, the same way MPSMatrix's descriptor counts. So a [2,3] array is
        // three rows of two and a [3,2] is two rows of three, and their product is three rows of
        // three, held as a [3,3]:
        //     1 2         7 8 9        27  30  33
        //     3 4    x   10 11 12  =   61  68  75
        //     5 6                         95 106 117
        //
        // The first version of this case expected 58 64 70 / 139 154 169 / 220 240 260, which is
        // [[1,2,3],[4,5,6]] x [[7,8],[9,10],[11,12]] - the product of a 2x3 and a 3x2. That is the
        // pairing the numbers have if dimension 0 is taken for the ROW, which is the reading the port
        // had before this case and the harness disagreed with. With dimension 0 as the columns the
        // same six numbers are a 3x2, and the answer is the one above.
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
        // MATRIX MULTIPLICATION with the third source and both scales, which is the header's own
        // formula "D = alpha * A * B + beta * C" (:31) and the only way beta is reached at all.
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
            // 2 * [[19,22],[43,50]] + 3 * 1 = [[41,47],[89,103]]
            MPSNDArray *expected = makeArray(@[@41, @47, @89, @103], sizes, 2);
            expectFloats(@"matmul alpha beta", readArray(destination), readArray(expected));
        }

        printf("case: matmul batch broadcast\n");
        // MATRIX MULTIPLICATION with a BATCH and a BROADCAST on BOTH sides: a dimension of 1 on an input is broadcast across the other input's matching dimension (:36-37).
        // The left is [2,2,2,1] - two batches, ONE matrix each - and
        // the right is [2,2,1,2] - ONE batch, two matrices - so every pair meets, and the result is
        // [2,2,2,2]. Batch 0 of the left is the identity, so batch 0 of the result is the right-hand
        // matrices unchanged and batch 1 is their ordinary products. Dim 0 fastest throughout, so the
        // linear order runs down the two columns of a matrix, then the batch, then the matrix index:
        //     m0 b0: 1 2 3 4     m0 b1: [[1,2],[3,4]]^2            = 7 10 15 22
        //     m1 b0: 5 6 7 8     m1 b1: [[1,2],[3,4]]*[[5,6],[7,8]] = 19 22 43 50
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
