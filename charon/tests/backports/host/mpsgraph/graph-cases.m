// graph-cases.m - the builder side and the arithmetic family of MPSGraph, run twice: once against the
// system's own MPSGraph and once against this port's classes under names of their own. Every case
// prints the bytes of a buffer the case owns, so the two runs are compared exactly.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;
#include <stdlib.h>
#include <string.h>
// The two encode forms below encode into MPSGraph's OWN command buffer, whose class is declared inside the
// MetalPerformanceShaders umbrella and nowhere in MetalPerformanceShadersGraph. It is reachable from the
// graph umbrella too - MetalPerformanceShadersGraph.h imports MPSGraph.h, which imports MPSGraphCore.h,
// which imports MetalPerformanceShaders.h, which imports MPSCore/MPSCore.h - so this import states the
// dependency rather than leaving it to that chain: a band that concluded "the class cannot be made" was
// looking in the wrong framework for a declaration the graph umbrella already carried.
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>


// A case has to compile against both sides, and the SDK the port builds against - the iPhoneOS 16.4 one -
// predates some of the methods the framework on this host has. They are declared here so the same call
// is on both sides of the comparison; the spellings are the 26.2 headers', and the host's own framework
// answers them.
@interface MPSGraph (MPSGraph26)
- (MPSGraphTensor *)squareWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)reciprocalWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)squareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)reverseSquareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)logarithmWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)absoluteWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)signWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)identityWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)additionWithPrimaryTensor:(MPSGraphTensor *)primary secondaryTensor:(MPSGraphTensor *)secondary name:(NSString *)name;
// The constant a slice's gradient takes the shape of its forward input as, and the one factory that puts a
// caller's NSData in a graph (MPSGraphMemoryOps.h, ios(14.0)).
- (MPSGraphTensor *)constantWithData:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)dataType;
- (MPSGraphTensor *)constantWithShape:(MPSShape *)shape
                            dataType:(MPSDataType)dataType
                              values:(NSData *)values
                                name:(NSString *)name;
// The four of 15.0 and the four of 15.3, which the iPhoneOS 16.4 SDK this package compiles against
// already declares (MPSGraphReductionOps.h and MPSGraphArithmeticOps.h, ios(15.0) and ios(15.3)).
- (MPSGraphTensor *)reductionArgMaximumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)reductionArgMinimumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)reductionAndWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)reductionAndWithTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *)name;
- (MPSGraphTensor *)reductionOrWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)reductionOrWithTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *)name;
- (MPSGraphTensor *)minimumWithNaNPropagationWithPrimaryTensor:(MPSGraphTensor *)primary
                                             secondaryTensor:(MPSGraphTensor *)secondary
                                                        name:(NSString *)name;
- (MPSGraphTensor *)maximumWithNaNPropagationWithPrimaryTensor:(MPSGraphTensor *)primary
                                             secondaryTensor:(MPSGraphTensor *)secondary
                                                        name:(NSString *)name;
// The two 18.2 fed slice forms and the two fed gradient forms, which are asked of the release in
// refusals.m because every one of them takes the release down (MPSGraphTensorShapeOps.h, ios(18.2)).
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor startTensor:(MPSGraphTensor *)startTensor endTensor:(MPSGraphTensor *)endTensor strideTensor:(MPSGraphTensor *)strideTensor startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor startTensor:(MPSGraphTensor *)startTensor sizeTensor:(MPSGraphTensor *)sizeTensor squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor startTensor:(MPSGraphTensor *)startTensor endTensor:(MPSGraphTensor *)endTensor strideTensor:(MPSGraphTensor *)strideTensor startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor startTensor:(MPSGraphTensor *)startTensor sizeTensor:(MPSGraphTensor *)sizeTensor squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
// The completion and scheduled handlers the header gives the descriptor, and MPSGraph's own command buffer -
// the wait is on the BUFFER, which is where -waitUntilCompleted is, and a queue does not have it.
- (void)setWaitUntilCompleted:(BOOL)waitUntilCompleted;
// The seven run, async and encode forms of the graph, the four of the executable and the two shared-event
// methods of an execution descriptor (MPSGraph.h, MPSGraphExecutable.h, ios(14.0) and the 16.0 events).
- (MPSGraphTensorDataDictionary *)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue feeds:(NSDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations;
- (void)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue feeds:(NSDictionary *)feeds targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations resultsDictionary:(NSDictionary *)resultsDictionary;
- (MPSGraphTensorDataDictionary *)runAsyncWithFeeds:(NSDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor;
- (MPSGraphTensorDataDictionary *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue feeds:(NSDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor;
- (void)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue feeds:(NSDictionary *)feeds targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations resultsDictionary:(NSDictionary *)resultsDictionary executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor;
- (MPSGraphTensorDataDictionary *)encodeToCommandBuffer:(MPSCommandBuffer *)commandBuffer feeds:(NSDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor;
- (void)encodeToCommandBuffer:(MPSCommandBuffer *)commandBuffer feeds:(NSDictionary *)feeds targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations resultsDictionary:(NSDictionary *)resultsDictionary executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor;
- (void)specializeWithDevice:(MPSGraphDevice *)device inputTypes:(NSArray<MPSGraphType *> *)inputTypes compilationDescriptor:(MPSGraphCompilationDescriptor *)compilationDescriptor;
- (NSArray<MPSGraphShapedType *> *)getOutputTypesWithDevice:(MPSGraphDevice *)device inputTypes:(NSArray<MPSGraphType *> *)inputTypes compilationDescriptor:(MPSGraphCompilationDescriptor *)compilationDescriptor;
- (NSArray<MPSGraphTensorData *> *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue inputsArray:(NSArray<MPSGraphTensorData *> *)inputsArray resultsArray:(NSArray<MPSGraphTensorData *> *)resultsArray executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)executionDescriptor;
- (NSArray<MPSGraphTensorData *> *)encodeToCommandBuffer:(MPSCommandBuffer *)commandBuffer inputsArray:(NSArray<MPSGraphTensorData *> *)inputsArray resultsArray:(NSArray<MPSGraphTensorData *> *)resultsArray executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)executionDescriptor;
- (void)waitForEvent:(id<MTLSharedEvent>)event value:(uint64_t)value;
- (void)signalEvent:(id<MTLSharedEvent>)event atExecutionEvent:(MPSGraphExecutionStage)stage value:(uint64_t)value;
// The pad and the tile, and their two gradients (MPSGraphTensorShapeOps.h, ios(14.0)). The two periodic
// padding modes are asked of the release in refusals.m because the release refuses them.
- (MPSGraphTensor *)padTensor:(MPSGraphTensor *)tensor withPaddingMode:(MPSGraphPaddingMode)paddingMode leftPadding:(NSArray<NSNumber *> *)leftPadding rightPadding:(NSArray<NSNumber *> *)rightPadding constantValue:(double)constantValue name:(NSString *)name;
- (MPSGraphTensor *)tileTensor:(MPSGraphTensor *)tensor withMultiplier:(NSArray<NSNumber *> *)multiplier name:(NSString *)name;
// The cumulative family of 16.0 (MPSGraphCumulativeOps.h, ios(16.0)), sixteen methods over four
// operations: an axis written down, and an axis fed at run time, each with and without the two flags.
- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis exclusive:(BOOL)exclusive reverse:(BOOL)reverse name:(NSString *)name;
- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor name:(NSString *)name;
- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor exclusive:(BOOL)exclusive reverse:(BOOL)reverse name:(NSString *)name;
- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis exclusive:(BOOL)exclusive reverse:(BOOL)reverse name:(NSString *)name;
- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor name:(NSString *)name;
- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor exclusive:(BOOL)exclusive reverse:(BOOL)reverse name:(NSString *)name;
- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis exclusive:(BOOL)exclusive reverse:(BOOL)reverse name:(NSString *)name;
- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor name:(NSString *)name;
- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor exclusive:(BOOL)exclusive reverse:(BOOL)reverse name:(NSString *)name;
- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis exclusive:(BOOL)exclusive reverse:(BOOL)reverse name:(NSString *)name;
- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor name:(NSString *)name;
- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor exclusive:(BOOL)exclusive reverse:(BOOL)reverse name:(NSString *)name;
// The shape and axis operations: 14.0's two-axis transpose, 15.0's flattens, broadcasts and reverses, 15.4's
// squeezes and expanded dimensions, and 16.0's permutation transpose (MPSGraphTensorShapeOps.h).
- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)tensor dimension:(NSUInteger)dimension withDimension:(NSUInteger)withDimension name:(NSString *)name;
- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)tensor permutation:(NSArray<NSNumber *> *)permutation name:(NSString *)name;
- (MPSGraphTensor *)flatten2DTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)flatten2DTensor:(MPSGraphTensor *)tensor axisTensor:(MPSGraphTensor *)axisTensor name:(NSString *)name;
- (MPSGraphTensor *)broadcastTensor:(MPSGraphTensor *)tensor toShape:(NSArray<NSNumber *> *)toShape name:(NSString *)name;
- (MPSGraphTensor *)broadcastTensor:(MPSGraphTensor *)tensor toShapeTensor:(MPSGraphTensor *)toShapeTensor name:(NSString *)name;
- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *)name;
- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor axesTensor:(MPSGraphTensor *)axesTensor name:(NSString *)name;
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor name:(NSString *)name;
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *)name;
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor axesTensor:(MPSGraphTensor *)axesTensor name:(NSString *)name;
- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *)name;
- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *)name;
- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)tensor axesTensor:(MPSGraphTensor *)axesTensor name:(NSString *)name;
@end

static id<MTLDevice> gDevice;
static MPSGraphDevice *gGraphDevice;

// Every matrix a case builds from a C array, and the result buffer it reads back out of. Sixty-four was
// enough for the twenty-four cases this file had; there are a hundred and more now, so the table is
// sized by the case count and not by the number of cases there were when it was written - a table one
// entry short writes past its own end, which is a crash in the middle of a run and not a failed
// comparison.
typedef struct { id<MTLBuffer> buffer; void *source; size_t bytes; } Source;
static Source gSources[512];
static NSUInteger gSourceCount;
static void remember(id<MTLBuffer> buffer, void *source, size_t bytes)
{
    gSources[gSourceCount].buffer = buffer; gSources[gSourceCount].source = source; gSources[gSourceCount].bytes = bytes; gSourceCount++;
}
static void pullResults(void)
{
    for (NSUInteger i = 0; i < gSourceCount; i++) {
        if (gSources[i].buffer) memcpy(gSources[i].source, [gSources[i].buffer contents], gSources[i].bytes);
    }
}
// Every line of a case carries the marker "#case ", because the framework this file runs against writes
// diagnostics of its own to the same standard output: building one of the predicates prints a warning
// about the operand the comparison kernel was handed ("ConvertBinaryCompareToZero expects the second
// operand to be zero", MPSGraphUtilities.mm:254), and a boolean result printed through the same stream
// makes it print another ("ANE I/O op can only do F16 MemRef <-> F32 Tensor cast"). Those are the
// framework talking to itself and not a case, so run.sh compares only the marked lines and the count it
// compares is the count of cases rather than of lines of output.
static void put(const char *name, const void *bytes, size_t length)
{
    pullResults();
    printf("#case %s %zu ", name, length);
    const unsigned char *p = (const unsigned char *)bytes;
    for (size_t i = 0; i < length; i++) printf("%02x", p[i]);
    printf("\n");
}
static MPSGraphTensorData *feed(const void *values, NSArray<NSNumber *> *shape, MPSDataType type)
{
    NSUInteger count = 1;
    for (NSNumber *dimension in shape) count *= (NSUInteger)dimension.integerValue;
    size_t bytes = count * MPSSizeofMPSDataType(type);
    id<MTLBuffer> buffer = [gDevice newBufferWithBytes:values length:bytes options:MTLResourceStorageModeShared];
    // The feed is not remembered: a case's input array stays what the case put in it, and only the
    // result buffer is read back. Remembering the feed as well meant the first put() overwrote every
    // input array with what the run had left in that buffer, and both sides then agreed on the wrong
    // numbers.
    return [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:shape dataType:type];
}

// One element per input class the arithmetic has to distinguish, so every case in this file covers the
// whole space rather than the handful of values that first showed a difference: a positive and a
// negative, a negative zero and a positive zero, both infinities, a NaN of each sign, a NaN carrying a
// payload, a denormal of each sign, the largest denormal, the smallest normal just above it, an ordinary
// small value, an ordinary value below one and one above it. The hex float literals are how a denormal
// is written; no decimal literal below 1.2e-38 is one.
// Measured against this host's own MPSGraph, macOS 27.0 build 26A428 (M4 Pro, Metal 4):
// 1, -1, -0.0, 0.0, +inf, -inf, qNaN, -qNaN, 0x1p-149, -0x1p-149, 0x1.fffffep-127, 0x1p-126, 0x1p-20,
// 0x1.fffffep-1, -0x1p-20, 1e-20. facts/MetalPerformanceShadersGraph/Core.md carries what each
// operation answers for each of them.
static float leftValues[32] = {
    1.0f, -1.0f, -0.0f, 0.0f, INFINITY, -INFINITY, NAN, -NAN,
    0x1p-149f, -0x1p-149f, 0x1.fffffep-127f, 0x1p-126f, 0x1p-20f, 0x1.fffffep-1f, -0x1p-20f, 1e-20f,
    // Sixteen ordinary values after the sixteen classes, because a tolerance is measured over inputs and
    // sixteen inputs are not enough to measure one: they are the inputs whose answer was looked at once.
    // These are a fixed walk - 2^(-16 + i/2) and its negative, then the same with 1 added - so the sweep is
    // the same on every machine and every run and does not need a seed.
    0x1p-16f, -0x1p-16f, 0x1.8p-16f, -0x1.8p-16f, 0x1p-15f, -0x1p-15f, 0x1.8p-15f, -0x1.8p-15f,
    1.0f + 0x1p-16f, 1.0f + 0x1.8p-16f, 1.0f + 0x1p-15f, 1.0f + 0x1.8p-15f,
    -(1.0f + 0x1p-16f), -(1.0f + 0x1.8p-16f), -(1.0f + 0x1p-15f), -(1.0f + 0x1.8p-15f),
};
// The second operand carries the classes the divisor column needs - a positive zero, a negative zero, an
// infinity of each sign, a NaN, a denormal - and ordinary values elsewhere, so a division is checked
// against every kind of divisor and not only against ones that divide.
static float rightValues[32] = {
    0.0f, -0.0f, INFINITY, -INFINITY, NAN, -NAN, 0x1p-149f, 2.0f,
    4.0f, -4.0f, 0.5f, 8.0f, 16.0f, 3.0f, 1.0f, 1.0f,
    0x1p-16f, -0x1p-16f, 0x1.8p-16f, -0x1.8p-16f, 0x1p-15f, -0x1p-15f, 0x1.8p-15f, -0x1.8p-15f,
    2.0f + 0x1p-16f, -(2.0f + 0x1p-15f), 1.0f / 3.0f, 7.0f,
};
static unsigned char resultBytes[4096];
// The feeds of the reduction family, one per data type and each of eight elements in a 2x4. They are
// ordinary values rather than the sixteen classes above because a reduction is a question about a set and
// a set of infinities and denormals answers a sum and a product that are both infinite or both zero, which
// tells a reader nothing about the axis arithmetic; the sixteen classes are asked of every reduction too,
// through leftValues in reduction_families below.
static float rowFeed[8] = { 1.0f, 2.0f, 3.0f, 4.0f, 10.0f, 20.0f, 30.0f, 40.0f };
static float meanFeed[2] = { 2.5f, 25.0f };
static float nanFeed[8] = { NAN, NAN, NAN, NAN, NAN, NAN, NAN, NAN };
static int32_t intFeed[8] = { -3, -2, -1, 0, 1, 2, 3, 4 };
static int32_t intMeanFeed[2] = { -1, 2 };
static uint16_t halfFeed[8] = { 0x3c00, 0x4000, 0x4200, 0x4400, 0x4500, 0x4600, 0x4700, 0x4800 };
static float constantValues[4] = {0.25f, -0.25f, 0.5f, 2};
// The bounds a clamp case is asked over: a pair of ordinary values either side of zero, so that every
// class of the operand decides which of the two it is clamped to.
static float bounds[32] = {
    -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
    -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
    -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
    -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
};
static int32_t integerValues[4] = {7, -3, 11, 0};
static int32_t integerDivisors[4] = {2, 2, 4, -4};
static int32_t integerResult[4];

// The sixteen classes as MPSDataTypeFloat16 stores them: a positive and a negative, a positive zero
// and a negative zero, both infinities, a NaN of each sign, a denormal of each sign, the largest
// denormal, the smallest normal, and four ordinary values - 1, 1/2, 2^-10 and 1 + 2^-10, which is
// close enough to one for an approximation to show. The type of a class is what decides the shape of
// its writing, so it is written as bits here and as a value above.
// Measured against this host's own MPSGraph, macOS 27.0 build 26A428 (M4 Pro, Metal 4). The buffer
// is sixteen halves, which is 32 bytes: MPSNDArray refuses a shorter one ("buffer is not large
// enough. Must be 32 bytes", MPSNDArray.mm:893), so a half tensor here cannot be smaller.
static uint16_t halfValues[32] = {
    0x3c00, 0xbc00, 0x0000, 0x8000, 0x7c00, 0xfc00, 0x7e00, 0xfe00,
    0x0001, 0x8001, 0x03ff, 0x0400, 0x3800, 0x1400, 0x3c01, 0x3555,
    // The same sixteen ordinary values as the float vector, narrowed to a half. They are written as bits
    // because the rounding of each is the question: the sixteen values either side of 1.0 are the ones a
    // kernel's last bit is decided on.
    0x2800, 0xa800, 0x2c00, 0xac00, 0x3000, 0xb000, 0x3400, 0xb400,
    0x3c01, 0x3c02, 0x3c04, 0x3c08, 0xbc01, 0xbc02, 0xbc04, 0xbc08,
};
// The second operand, in halves, carrying the classes a divisor column needs - a positive zero, a
// negative zero, an infinity of each sign, a NaN, a denormal - and ordinary values elsewhere.
static uint16_t halfRightValues[32] = {
    0x0000, 0x8000, 0x7c00, 0xfc00, 0x7e00, 0xfe00, 0x0001, 0x4000,
    0xc000, 0x3800, 0x3555, 0x4400, 0x4800, 0x4200, 0x3c00, 0x3c00,
    0x2800, 0xa800, 0x2c00, 0xac00, 0x3000, 0xb000, 0x3400, 0xb400,
    0x4001, 0xc004, 0x3555, 0x4700,
};

// The unary family, over the classes above, so each one of them is answered for every operation of
// the family rather than for the one operation a difference happened to show up in. The square root
// is what the class of a negative pins: the release answers a NaN in float32 and a zero in float16,
// and both are measured rather than one being a bug.
static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *); } unary[] = {
    {"square", ^MPSGraphTensor *(MPSGraph *gg, MPSGraphTensor *a) { return [gg squareWithTensor:a name:@"sq"]; }},
    {"reciprocal", ^MPSGraphTensor *(MPSGraph *gg, MPSGraphTensor *a) { return [gg reciprocalWithTensor:a name:@"rec"]; }},
    {"sqrt", ^MPSGraphTensor *(MPSGraph *gg, MPSGraphTensor *a) { return [gg squareRootWithTensor:a name:@"sqrt"]; }},
    {"rsqrt", ^MPSGraphTensor *(MPSGraph *gg, MPSGraphTensor *a) { return [gg reverseSquareRootWithTensor:a name:@"rsqrt"]; }},
    {"log", ^MPSGraphTensor *(MPSGraph *gg, MPSGraphTensor *a) { return [gg logarithmWithTensor:a name:@"log"]; }},
    {"abs", ^MPSGraphTensor *(MPSGraph *gg, MPSGraphTensor *a) { return [gg absoluteWithTensor:a name:@"abs"]; }},
    {"sign", ^MPSGraphTensor *(MPSGraph *gg, MPSGraphTensor *a) { return [gg signWithTensor:a name:@"sign"]; }},
    {"identity", ^MPSGraphTensor *(MPSGraph *gg, MPSGraphTensor *a) { return [gg identityWithTensor:a name:@"id"]; }},
};

// The arithmetic family, element by element.
static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *); } binary[] = {
    {"add", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g additionWithPrimaryTensor:a secondaryTensor:b name:@"add"]; }},
    {"subtract", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g subtractionWithPrimaryTensor:a secondaryTensor:b name:@"sub"]; }},
    {"multiply", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g multiplicationWithPrimaryTensor:a secondaryTensor:b name:@"mul"]; }},
    {"divide", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g divisionWithPrimaryTensor:a secondaryTensor:b name:@"div"]; }},
    {"modulo", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g moduloWithPrimaryTensor:a secondaryTensor:b name:@"mod"]; }},
    {"floorModulo", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g floorModuloWithPrimaryTensor:a secondaryTensor:b name:@"fmod"]; }},
    {"power", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g powerWithPrimaryTensor:a secondaryTensor:b name:@"pow"]; }},
    {"atan2", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g atan2WithPrimaryTensor:a secondaryTensor:b name:@"atan2"]; }},
    {"divisionNoNaN", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g divisionNoNaNWithPrimaryTensor:a secondaryTensor:b name:@"divn"]; }},
    {"minimum", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g minimumWithPrimaryTensor:a secondaryTensor:b name:@"min"]; }},
    {"maximum", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g maximumWithPrimaryTensor:a secondaryTensor:b name:@"max"]; }},
    {"logicalAND", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g logicalANDWithPrimaryTensor:a secondaryTensor:b name:@"and"]; }},
    {"logicalOR", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g logicalORWithPrimaryTensor:a secondaryTensor:b name:@"or"]; }},
    {"logicalNAND", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g logicalNANDWithPrimaryTensor:a secondaryTensor:b name:@"nand"]; }},
    {"logicalNOR", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g logicalNORWithPrimaryTensor:a secondaryTensor:b name:@"nor"]; }},
    {"logicalXOR", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g logicalXORWithPrimaryTensor:a secondaryTensor:b name:@"xor"]; }},
    {"logicalXNOR", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g logicalXNORWithPrimaryTensor:a secondaryTensor:b name:@"xnor"]; }},
};

// The family of unary operations that are a rounding or a transcendental, asked over the same sixteen
// classes as the arithmetic above: each of them is a different question of a NaN, a zero and an
// infinity, and a case that only ever saw ordinary values would say nothing about the classes that
// decide the answer.
static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *); } transcendental[] = {
    {"expBase2", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g exponentBase2WithTensor:a name:@"e2"]; }},
    {"expBase10", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g exponentBase10WithTensor:a name:@"e10"]; }},
    {"logBase2", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g logarithmBase2WithTensor:a name:@"l2"]; }},
    {"logBase10", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g logarithmBase10WithTensor:a name:@"l10"]; }},
    {"negative", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g negativeWithTensor:a name:@"neg"]; }},
    {"signbit", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g signbitWithTensor:a name:@"sb"]; }},
    {"ceil", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g ceilWithTensor:a name:@"ceil"]; }},
    {"floor", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g floorWithTensor:a name:@"floor"]; }},
    {"round", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g roundWithTensor:a name:@"round"]; }},
    {"rint", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g rintWithTensor:a name:@"rint"]; }},
    {"sin", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g sinWithTensor:a name:@"sin"]; }},
    {"cos", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g cosWithTensor:a name:@"cos"]; }},
    {"tan", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g tanWithTensor:a name:@"tan"]; }},
    {"sinh", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g sinhWithTensor:a name:@"sinh"]; }},
    {"cosh", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g coshWithTensor:a name:@"cosh"]; }},
    {"tanh", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g tanhWithTensor:a name:@"tanh"]; }},
    {"asin", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g asinWithTensor:a name:@"asin"]; }},
    {"acos", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g acosWithTensor:a name:@"acos"]; }},
    {"atan", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g atanWithTensor:a name:@"atan"]; }},
    {"asinh", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g asinhWithTensor:a name:@"asinh"]; }},
    {"acosh", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g acoshWithTensor:a name:@"acosh"]; }},
    {"atanh", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g atanhWithTensor:a name:@"atanh"]; }},
    {"erf", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g erfWithTensor:a name:@"erf"]; }},
    {"not", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g notWithTensor:a name:@"not"]; }},
    {"reLU", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reLUWithTensor:a name:@"relu"]; }},
    {"sigmoid", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g sigmoidWithTensor:a name:@"sig"]; }},
};

// The unary predicates, whose result is a boolean and not a number: measured on this host's own MPSGraph,
// isNaN of a rank-3 float32 operand is MPSDataTypeBool where not of the same operand is MPSDataTypeFloat32.
// Their results are therefore one byte an element, and the case name carries that as its own data type.
static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *); } unaryPredicate[] = {
    {"isNaN", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g isNaNWithTensor:a name:@"nan"]; }},
    {"isFinite", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g isFiniteWithTensor:a name:@"fin"]; }},
    {"isInfinite", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g isInfiniteWithTensor:a name:@"inf"]; }},
};

// The two predicates over two operands, which are booleans on the same measurement.
static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *); } binaryPredicate[] = {
    {"equal", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g equalWithPrimaryTensor:a secondaryTensor:b name:@"eq"]; }},
    {"notEqual", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g notEqualWithPrimaryTensor:a secondaryTensor:b name:@"ne"]; }},
    {"lessThan", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g lessThanWithPrimaryTensor:a secondaryTensor:b name:@"lt"]; }},
    {"lessThanOrEqualTo", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g lessThanOrEqualToWithPrimaryTensor:a secondaryTensor:b name:@"le"]; }},
    {"greaterThan", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g greaterThanWithPrimaryTensor:a secondaryTensor:b name:@"gt"]; }},
    {"greaterThanOrEqualTo", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g greaterThanOrEqualToWithPrimaryTensor:a secondaryTensor:b name:@"ge"]; }},
};

// The operations with a third operand: a select takes the predicate, the value where it is true and the
// value where it is false, and a clamp takes the value and its two bounds. Both answer the first
// operand's type, measured on this host's own MPSGraph.
static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *, MPSGraphTensor *); } ternary[] = {
    {"select", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b, MPSGraphTensor *c) { return [g selectWithPredicateTensor:a truePredicateTensor:b falsePredicateTensor:c name:@"sel"]; }},
    {"clamp", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b, MPSGraphTensor *c) { return [g clampWithTensor:a minValueTensor:b maxValueTensor:c name:@"clamp"]; }},
};

// The two activations that take the value that was activated as well as the incoming gradient. The
// source of a sigmoid's gradient is the sigmoid's own answer, so the third feed is what a sigmoid of the
// left operand is, computed here in C: that is an input both sides are given, not an expectation.
static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *); } gradient[] = {
    {"reLUGradient", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g reLUGradientWithIncomingGradient:a sourceTensor:b name:@"drelu"]; }},
    {"sigmoidGradient", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g sigmoidGradientWithIncomingGradient:a sourceTensor:b name:@"dsig"]; }},
};

// The data type of a feed and the data type of a result are two questions, and a predicate's are two
// answers: the feed is the type its placeholder is, and the result is a boolean. The shaped type that
// describes a feed is the feed's own type, and the shaped type the result is read into is the result's.
static void run(MPSGraph *graph, NSArray<MPSGraphTensor *> *feeds, NSArray<MPSGraphTensorData *> *values,
                MPSGraphTensor *target, void *out, size_t bytes, MPSDataType feedType, MPSDataType resultType)
{
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:target.shape dataType:resultType];
    remember(buffer, out, bytes);
    MPSGraphShapedType *feedShape = [[MPSGraphShapedType alloc] initWithShape:target.shape dataType:feedType];
    NSMutableDictionary *shapedFeeds = [NSMutableDictionary dictionary];
    for (MPSGraphTensor *tensor in feeds) shapedFeeds[tensor] = feedShape;
    MPSGraphExecutable *executable = [graph compileWithDevice:gGraphDevice feeds:shapedFeeds
                                                 targetTensors:@[target] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:values resultsArray:@[destination] executionDescriptor:nil];
    memcpy(out, [buffer contents], bytes);
}

// One case of the unary family, in the type asked for. The case's own name carries the type, because
// the same operation over the same sixteen classes is a different question in each of them.
static void unary_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *),
                       MPSDataType type, const void *values)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:@[@8, @4] dataType:type name:@"a"];
    MPSGraphTensor *t = build(one, a);
    size_t bytes = 32 * MPSSizeofMPSDataType(type);
    memset(resultBytes, 0, sizeof(resultBytes));
    run(one, @[a], @[feed(values, @[@8, @4], type)], t, resultBytes, bytes, type, type);
    put(name, resultBytes, bytes);
}

// The same for a case of the arithmetic family, which takes a second operand.
static void binary_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *),
                        MPSDataType type, const void *left, const void *right)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:@[@8, @4] dataType:type name:@"a"];
    MPSGraphTensor *b = [one placeholderWithShape:@[@8, @4] dataType:type name:@"b"];
    MPSGraphTensor *t = build(one, a, b);
    size_t bytes = 32 * MPSSizeofMPSDataType(type);
    memset(resultBytes, 0, sizeof(resultBytes));
    run(one, @[a, b], @[feed(left, @[@8, @4], type), feed(right, @[@8, @4], type)], t, resultBytes, bytes, type, type);
    put(name, resultBytes, bytes);
}

// A case whose result is not the operand's own type: a predicate's is a boolean, one byte an element,
// measured on this host's own MPSGraph (MPSSizeofMPSDataType(MPSDataTypeBool) is 1). The result buffer is
// the operand's sixteen elements in the result's type, so a byte per element is the whole of it.
static void predicate_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *),
                           MPSDataType operandType, const void *values)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:@[@8, @4] dataType:operandType name:@"a"];
    MPSGraphTensor *t = build(one, a);
    memset(resultBytes, 0, sizeof(resultBytes));
    run(one, @[a], @[feed(values, @[@8, @4], operandType)], t, resultBytes, 32, operandType, MPSDataTypeBool);
    put(name, resultBytes, 16);
}

static void binary_predicate_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *),
                                  MPSDataType operandType, const void *left, const void *right)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:@[@8, @4] dataType:operandType name:@"a"];
    MPSGraphTensor *b = [one placeholderWithShape:@[@8, @4] dataType:operandType name:@"b"];
    MPSGraphTensor *t = build(one, a, b);
    memset(resultBytes, 0, sizeof(resultBytes));
    run(one, @[a, b], @[feed(left, @[@8, @4], operandType), feed(right, @[@8, @4], operandType)], t, resultBytes, 32, operandType, MPSDataTypeBool);
    put(name, resultBytes, 16);
}

// A case with three operands, which the select and the clamp are.
static void ternary_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *, MPSGraphTensor *),
                         MPSDataType type, const void *first, const void *second, const void *third)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:@[@8, @4] dataType:type name:@"a"];
    MPSGraphTensor *b = [one placeholderWithShape:@[@8, @4] dataType:type name:@"b"];
    MPSGraphTensor *c = [one placeholderWithShape:@[@8, @4] dataType:type name:@"c"];
    MPSGraphTensor *t = build(one, a, b, c);
    size_t bytes = 32 * MPSSizeofMPSDataType(type);
    memset(resultBytes, 0, sizeof(resultBytes));
    run(one, @[a, b, c], @[feed(first, @[@8, @4], type), feed(second, @[@8, @4], type),
                          feed(third, @[@8, @4], type)], t, resultBytes, bytes, type, type);
    put(name, resultBytes, bytes);
}

// THE REDUCTION FAMILY, and the one thing about it that the arithmetic cases above never had to answer:
// the result is not the operand's shape. A reduction over an axis of a 2x4 answers a 2x1 or a 1x4 and the
// feed is still the 2x4, so the case below gives the compile a feed of the operand's own shape and a
// destination of the result's own shape - run() above uses the target's shape for both, which is right for
// an elementwise operation and wrong for every one of these.
static void reduction_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *),
                           MPSDataType type, const void *values, NSArray<NSNumber *> *shape)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:shape dataType:type name:@"a"];
    MPSGraphTensor *t = build(one, a);
    NSUInteger count = 1;
    for (NSNumber *dimension in t.shape) count *= (NSUInteger)dimension.integerValue;
    size_t bytes = count * MPSSizeofMPSDataType(t.dataType);
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer
                                                                              shape:t.shape
                                                                            dataType:t.dataType];
    remember(buffer, resultBytes, bytes);
    MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:a.shape dataType:type];
    MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:@{a: shaped}
                                              targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:@[feed(values, shape, type)]
                           resultsArray:@[destination] executionDescriptor:nil];
    put(name, resultBytes, bytes);
}

// The same over a mean that was computed first, which is the form varianceOfTensor:meanTensor:axes: takes:
// the mean is a second placeholder of the graph that consumes it and the caller hands over what it has.
// The mean fed here is the one the framework itself answered for the same feed, read out of a run of the
// meanOfTensor case - it is an input to the case, not an expectation, and facts/MetalPerformanceShadersGraph/
// Core.md carries what both sides answer for it.
static void variance_with_mean_case(const char *name, MPSDataType type, const void *values,
                                    NSArray<NSNumber *> *shape, NSArray<NSNumber *> *axes,
                                    const void *meanValues)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:shape dataType:type name:@"a"];
    MPSGraphTensor *m = [one placeholderWithShape:@[@2, @1] dataType:type name:@"mean"];
    MPSGraphTensor *t = [one varianceOfTensor:a meanTensor:m axes:axes name:@"variance"];
    size_t bytes = 2 * MPSSizeofMPSDataType(type);
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer
                                                                              shape:@[@2, @1]
                                                                            dataType:type];
    remember(buffer, resultBytes, bytes);
    NSMutableDictionary *shaped = [NSMutableDictionary dictionary];
    shaped[a] = [[MPSGraphShapedType alloc] initWithShape:shape dataType:type];
    shaped[m] = [[MPSGraphShapedType alloc] initWithShape:@[@2, @1] dataType:type];
    MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:shaped
                                              targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:@[feed(values, shape, type), feed(meanValues, @[@2, @1], type)]
                           resultsArray:@[destination] executionDescriptor:nil];
    put(name, resultBytes, bytes);
}

// The reduction family, over a feed of eight values in a 2x4 and over the sixteen classes of the
// arithmetic cases, so every reduction is asked of the values that have shown every other difference:
// a NaN of each sign, both infinities, a denormal, and the ordinary values either side of one.
static void reduction_families(void)
{
    static NSArray<NSNumber *> *shape2x4;
    char name[64];
    unsigned i;
    struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *); } reducing[] = {
        {"reductionSum", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionSumWithTensor:a axis:1 name:@"sum"]; }},
        {"reductionProduct", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionProductWithTensor:a axis:1 name:@"prod"]; }},
        {"reductionMaximum", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionMaximumWithTensor:a axis:1 name:@"max"]; }},
        {"reductionMinimum", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionMinimumWithTensor:a axis:1 name:@"min"]; }},
        {"reductionMaximumPropagateNaN", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionMaximumPropagateNaNWithTensor:a axis:1 name:@"maxnan"]; }},
        {"reductionMinimumPropagateNaN", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionMinimumPropagateNaNWithTensor:a axis:1 name:@"minnan"]; }},
        {"mean", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g meanOfTensor:a axes:@[@1] name:@"mean"]; }},
        {"variance", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g varianceOfTensor:a axes:@[@1] name:@"var"]; }},
    };
    shape2x4 = @[@2, @4];
    // The eight over the sixteen classes of the arithmetic family, which is where a NaN, an infinity and
    // a denormal meet the sum and the product as well as the maximum and the mean.
    for (i = 0; i < sizeof(reducing) / sizeof(reducing[0]); i++) {
        snprintf(name, sizeof name, "%s float32", reducing[i].name);
        reduction_case(name, reducing[i].build, MPSDataTypeFloat32, leftValues, shape2x4);
    }
    // The shape questions, each its own case because each is a different rule about the set of axes. The
    // qualifier is part of the operation's own name and not a word of its own, because run.sh reads a case
    // line as exactly five fields - the marker, the operation, the data type, the length and the bytes -
    // and a sixth would move the length out from under it.
    reduction_case("reductionSum-axis0 float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionSumWithTensor:a axis:0 name:@"s0"]; },
                   MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("reductionSum-axisNeg1 float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionSumWithTensor:a axis:-1 name:@"sn1"]; },
                   MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("reductionSum-axisNeg2 float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionSumWithTensor:a axis:-2 name:@"sn2"]; },
                   MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("reductionSum-axesNil float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionSumWithTensor:a axes:nil name:@"snil"]; },
                   MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("reductionSum-axesEmpty float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionSumWithTensor:a axes:@[] name:@"sempty"]; },
                   MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("reductionSum-axesRepeated float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionSumWithTensor:a axes:@[@0, @0] name:@"sr"]; },
                   MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("reductionSum-axesDescending float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionSumWithTensor:a axes:@[@1, @0] name:@"sdesc"]; },
                   MPSDataTypeFloat32, rowFeed, shape2x4);
    // The other two data types, because a mean and a variance in integers are truncated quotients and a
    // half is a different accumulator: measured on this host's own MPSGraph, over the int32 feed the mean
    // of a row of four is the truncated sum over four and the variance the truncated mean of the squared
    // deviations.
    for (i = 0; i < sizeof(reducing) / sizeof(reducing[0]); i++) {
        snprintf(name, sizeof name, "%s int32", reducing[i].name);
        reduction_case(name, reducing[i].build, MPSDataTypeInt32, intFeed, shape2x4);
    }
    for (i = 0; i < sizeof(reducing) / sizeof(reducing[0]); i++) {
        snprintf(name, sizeof name, "%s float16", reducing[i].name);
        reduction_case(name, reducing[i].build, MPSDataTypeFloat16, halfFeed, shape2x4);
    }
    // The variance of a mean handed in, over the same feed and the mean of it.
    variance_with_mean_case("varianceOfMean float32", MPSDataTypeFloat32, rowFeed, shape2x4, @[@1],
                            meanFeed);
    variance_with_mean_case("varianceOfMean int32", MPSDataTypeInt32, intFeed, shape2x4, @[@1], intMeanFeed);
    // A reduced set of nothing but NaNs, which is the one answer of the four extremes that the arithmetic
    // cases cannot reach: every element of the row is a NaN, so what a maximum that skips them and one
    // that propagates them answer is decided here.
    reduction_case("reductionMaximum-allNaN float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionMaximumWithTensor:a axis:1 name:@"mx"]; },
                   MPSDataTypeFloat32, nanFeed, shape2x4);
    reduction_case("reductionMaximumPropagateNaN-allNaN float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionMaximumPropagateNaNWithTensor:a axis:1 name:@"mxn"]; },
                   MPSDataTypeFloat32, nanFeed, shape2x4);
    reduction_case("reductionMinimum-allNaN float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionMinimumWithTensor:a axis:1 name:@"mn"]; },
                   MPSDataTypeFloat32, nanFeed, shape2x4);
    reduction_case("reductionMinimumPropagateNaN-allNaN float32",
                   ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionMinimumPropagateNaNWithTensor:a axis:1 name:@"mnn"]; },
                   MPSDataTypeFloat32, nanFeed, shape2x4);
}

// The feeds the reduction family that arrived in 15.0 and 15.3 is asked over. The sixteen classes above
// are what an index reduction and a truth fold have to be asked of - a NaN of each sign, both infinities,
// both zeros, a denormal - and the ties are what decide whether an argument reduction answers the first
// or the last of several equal elements, so a row of (4, 4, 4, 9 | 9, 9, 1, 1) is asked as well: every
// element of it is in the answer twice.
static float tieFeed[8] = { 4.0f, 4.0f, 4.0f, 9.0f, 9.0f, 9.0f, 1.0f, 1.0f };

// THE CUMULATIVE FAMILY of 16.0, whose result is the operand's OWN shape - so unlike the reduction family
// this one needs no case helper of its own, and the elementwise run() above is right for it - and whose
// axis can be a number written down or a tensor fed at run time. The axis tensor is a second input of the
// same shape as the reduction family's operands are, so the case builds the compile with two feeds.
static void cumulative_axis_tensor_case(const char *name, MPSDataType type, NSArray<NSNumber *> *shape,
                                        const void *values, int32_t axis, int isMaximum, int isMinimum,
                                        BOOL exclusive, BOOL reverse)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:shape dataType:type name:@"a"];
    MPSGraphTensor *axisTensor = [one placeholderWithShape:@[@1] dataType:MPSDataTypeInt32 name:@"axis"];
    MPSGraphTensor *t;
    if (isMaximum)
        t = exclusive || reverse ? [one cumulativeMaximumWithTensor:a axisTensor:axisTensor
                                                          exclusive:exclusive reverse:reverse name:@"M"]
                                 : [one cumulativeMaximumWithTensor:a axisTensor:axisTensor name:@"M"];
    else if (isMinimum)
        t = exclusive || reverse ? [one cumulativeMinimumWithTensor:a axisTensor:axisTensor
                                                          exclusive:exclusive reverse:reverse name:@"m"]
                                 : [one cumulativeMinimumWithTensor:a axisTensor:axisTensor name:@"m"];
    else
        t = exclusive || reverse ? [one cumulativeSumWithTensor:a axisTensor:axisTensor
                                                      exclusive:exclusive reverse:reverse name:@"s"]
                                 : [one cumulativeSumWithTensor:a axisTensor:axisTensor name:@"s"];
    NSUInteger count = 1;
    for (NSNumber *dimension in t.shape) count *= (NSUInteger)dimension.integerValue;
    size_t bytes = count * MPSSizeofMPSDataType(t.dataType);
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:t.shape
                                                                            dataType:t.dataType];
    remember(buffer, resultBytes, bytes);
    NSMutableDictionary *shaped = [NSMutableDictionary dictionary];
    shaped[a] = [[MPSGraphShapedType alloc] initWithShape:shape dataType:type];
    shaped[axisTensor] = [[MPSGraphShapedType alloc] initWithShape:@[@1] dataType:MPSDataTypeInt32];
    MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:shaped
                                              targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:@[feed(values, shape, type), feed(&axis, @[@1], MPSDataTypeInt32)]
                           resultsArray:@[destination] executionDescriptor:nil];
    put(name, resultBytes, bytes);
}

// The four operations over the ordinary feed, each in all four flag combinations, in the type asked for.
// The ordinary feed is what tests the rule and the classes are what test the seeds: an exclusive answer
// starts at the seed, and a NaN, an infinity and a zero are what say which seed each operation has.
static void cumulative_families(MPSDataType type, const void *values, const char *label)
{
    NSArray<NSNumber *> *shape2x4 = @[@2, @4];
    static float ordinary[8] = { 1.0f, 2.0f, 3.0f, 4.0f, 10.0f, 20.0f, 30.0f, 40.0f };
    static int32_t integers[8] = { -3, -2, -1, 0, 1, 2, 3, 4 };
    static uint16_t halves[8] = { 0x3c00, 0x4000, 0x4200, 0x4400, 0x4500, 0x4600, 0x4700, 0x4800 };
    static float classes[8] = { 1.0f, -1.0f, -0.0f, 0.0f, INFINITY, -INFINITY, NAN, -NAN };
    static float allNaN[8] = { NAN, NAN, NAN, NAN, NAN, NAN, NAN, NAN };
    // The feed this case asks over, chosen by the data type so that each type reads the numbers it can hold.
    const void *fed = type == MPSDataTypeInt32 ? (const void *)integers
                     : type == MPSDataTypeFloat16 ? (const void *)halves : values;
    struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, NSInteger, BOOL, BOOL); } ops[] = {
        {"cumulativeSum", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, NSInteger axis, BOOL e, BOOL r) {
            return e || r ? [g cumulativeSumWithTensor:a axis:axis exclusive:e reverse:r name:@"s"]
                          : [g cumulativeSumWithTensor:a axis:axis name:@"s"]; }},
        {"cumulativeProduct", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, NSInteger axis, BOOL e, BOOL r) {
            return e || r ? [g cumulativeProductWithTensor:a axis:axis exclusive:e reverse:r name:@"p"]
                          : [g cumulativeProductWithTensor:a axis:axis name:@"p"]; }},
        {"cumulativeMaximum", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, NSInteger axis, BOOL e, BOOL r) {
            return e || r ? [g cumulativeMaximumWithTensor:a axis:axis exclusive:e reverse:r name:@"M"]
                          : [g cumulativeMaximumWithTensor:a axis:axis name:@"M"]; }},
        {"cumulativeMinimum", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, NSInteger axis, BOOL e, BOOL r) {
            return e || r ? [g cumulativeMinimumWithTensor:a axis:axis exclusive:e reverse:r name:@"m"]
                          : [g cumulativeMinimumWithTensor:a axis:axis name:@"m"]; }},
    };
    char name[96];
    unsigned i, f;
    for (i = 0; i < sizeof(ops) / sizeof(ops[0]); i++) {
        for (f = 0; f < 4; f++) {
            BOOL exclusive = (f & 1) != 0, reverse = (f & 2) != 0;
            MPSGraph *one = [MPSGraph new];
            MPSGraphTensor *a = [one placeholderWithShape:shape2x4 dataType:type name:@"a"];
            MPSGraphTensor *t = ops[i].build(one, a, 1, exclusive, reverse);
            size_t bytes = 8 * MPSSizeofMPSDataType(type);
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
            MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:t.shape
                                                                                    dataType:t.dataType];
            remember(buffer, resultBytes, bytes);
            MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:shape2x4 dataType:type];
            MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:@{a: shaped}
                                                      targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:@[feed(fed, shape2x4, type)]
                                   resultsArray:@[destination] executionDescriptor:nil];
            snprintf(name, sizeof name, "%s-e%d-r%d %s", ops[i].name, exclusive, reverse, label);
            put(name, resultBytes, bytes);
        }
    }
    // The other axis of the operand and a negative one, over the ordinary feed, which is where the two
    // answers have to be the two the reduction family's negative axis answers are read against.
    for (i = 0; i < 2; i++) {
        NSInteger axis = i == 0 ? 0 : -1;
        MPSGraph *one = [MPSGraph new];
        MPSGraphTensor *a = [one placeholderWithShape:shape2x4 dataType:type name:@"a"];
        MPSGraphTensor *t = i == 0 ? [one cumulativeSumWithTensor:a axis:0 name:@"s0"]
                                   : [one cumulativeSumWithTensor:a axis:-1 name:@"sn1"];
        size_t bytes = 8 * MPSSizeofMPSDataType(type);
        id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
        MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:t.shape
                                                                                dataType:t.dataType];
        remember(buffer, resultBytes, bytes);
        MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:shape2x4 dataType:type];
        MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:@{a: shaped}
                                                  targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
        [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                              inputsArray:@[feed(ordinary, shape2x4, type)]
                               resultsArray:@[destination] executionDescriptor:nil];
        snprintf(name, sizeof name, "cumulativeSum-axis%ld %s", (long)axis, label);
        put(name, resultBytes, bytes);
    }
    // The axis fed at run time, over the same feed and the same four flag combinations of one operation
    // each: the sum's plain form, the sum's flags, the maximum's plain form and the minimum's flags, which
    // between them are the two forms of the axis with and without the flags for three of the four.
    cumulative_axis_tensor_case("cumulativeSum-axisTensor-e0-r0 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 1, 0, 0, NO, NO);
    cumulative_axis_tensor_case("cumulativeSum-axisTensor-e1-r1 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 1, 0, 0, YES, YES);
    cumulative_axis_tensor_case("cumulativeProduct-axisTensor-e0-r0 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 1, 0, 0, NO, NO);
    cumulative_axis_tensor_case("cumulativeProduct-axisTensor-e0-r1 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 1, 0, 0, NO, YES);
    cumulative_axis_tensor_case("cumulativeMaximum-axisTensor-e0-r0 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 1, 1, 0, NO, NO);
    cumulative_axis_tensor_case("cumulativeMaximum-axisTensor-e1-r1 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 1, 1, 0, YES, YES);
    cumulative_axis_tensor_case("cumulativeMinimum-axisTensor-e0-r0 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 1, 0, 1, NO, NO);
    cumulative_axis_tensor_case("cumulativeMinimum-axisTensor-e1-r0 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 1, 0, 1, YES, NO);
    cumulative_axis_tensor_case("cumulativeMaximum-axisTensor-axis0 float32", MPSDataTypeFloat32, shape2x4,
                                 ordinary, 0, 1, 0, NO, NO);
    // The sixteen classes and a row of nothing but NaNs, which is where the seeds and the NaN rule are:
    // a NaN loses every comparison in a scan as it does in a reduction, so the position whose whole side of
    // the walk is NaN answers the seed rather than a NaN.
    for (i = 0; i < 2; i++) {
        for (f = 0; f < 4; f++) {
            BOOL exclusive = (f & 1) != 0, reverse = (f & 2) != 0;
            MPSGraph *one = [MPSGraph new];
            MPSGraphTensor *a = [one placeholderWithShape:shape2x4 dataType:MPSDataTypeFloat32 name:@"a"];
            MPSGraphTensor *t = (i == 0 ? [one cumulativeMaximumWithTensor:a axis:1 exclusive:exclusive reverse:reverse name:@"M"]
                                        : [one cumulativeMinimumWithTensor:a axis:1 exclusive:exclusive reverse:reverse name:@"m"]);
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:32 options:MTLResourceStorageModeShared];
            MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:@[@2, @4]
                                                                                    dataType:MPSDataTypeFloat32];
            remember(buffer, resultBytes, 32);
            MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:shape2x4
                                                                            dataType:MPSDataTypeFloat32];
            MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:@{a: shaped}
                                                      targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:@[feed(i == 0 ? (const void *)classes : (const void *)allNaN,
                                                     shape2x4, MPSDataTypeFloat32)]
                                   resultsArray:@[destination] executionDescriptor:nil];
            snprintf(name, sizeof name, "%s-e%d-r%d %s", i == 0 ? "cumulativeMaximum" : "cumulativeMinimum",
                     exclusive, reverse, i == 0 ? "float32" : "allNaN");
            put(name, resultBytes, 32);
        }
    }
}

// THE GATHER FAMILY - the sixteen methods whose result is the operand's elements in some other order or
// another extent - is six families here, and one process each, because within one process the release's own
// gather operations assert over the SECOND flatten even when the process holds nothing else: "Error: NDArray
// dimension length > INT_MAX" (MPSNDArray.mm:831). What is measured for each form is written down in
// facts/MetalPerformanceShadersGraph/Core.md, and the rules the walk in MPSGraphInterpreter14.m answers
// are:
//
//   - a transpose is the row-major transpose, in both forms and with a permutation, and a negative axis is
//     counted from the end;
//   - the squeeze, the expanded dimension and the flatten are ONE gather with the axes left alone - each
//     answers the operand's own bytes in the operand's own order;
//   - a broadcast aligns to the RIGHT of the shape given and wraps each axis the shape makes wider;
//   - a reverse flips the axes it is given and nothing else.
//
// The FED forms - the reshape's shape, the flatten's axis, the broadcast's shape and the reverse's,
// the squeeze's and the expanded dimension's set of axes - are NOT cases here where the release
// takes the process down over one (facts/MetalPerformanceShadersGraph/Core.md and refusals.txt
// carry each one's own assertion), so there is no answer of the release for a case to compare
// against and the port's answer is its header's. Which of them those are is a measurement and not
// a decision: refusals.txt names them, one process each, and run.sh fails a question whose answer
// changed.

// Every family below ends with the chain, which is defined with the rest of the cases at the end of this
// file - the six gather families come before it in the file's order because they come before the table of
// families in the run order, and a declaration here is what lets them end with it.
static void chain_case(void);
static void fed_shape_case(const char *name,
                           MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *),
                           NSArray<NSNumber *> *operandShape, NSArray<NSArray<NSNumber *> *> *fedShapes);
static void tile_gradient_cases(void);
static void tile_gradient_case(const char *name, NSArray<NSNumber *> *multiplier,
                               NSArray<NSNumber *> *shape, const void *gradient, const void *source,
                               size_t bytes, NSArray<NSNumber *> *types);

// The feeds the gather families are asked over. The ordinary one is the case file's own 2x4 of (1, 2, 3, 4 |
// 10, 20, 30, 40), whose answers a reader can work out by hand; the rank-3 one is the 1 to 24 a 2x3x4 holds
// in row-major order, which is the same: every answer below is either the operand's own bytes in another
// order or the same bytes at another extent, so the feed is what makes the answer readable rather than the
// shape alone.
static float cubeFeed[24] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
};
// The sixteen input classes' first row, as a 2x4: a positive and a negative, both zeros, both infinities and
// a NaN of each sign. A gather copies, so these are what says it copies - a NaN's sign and a negative zero's
// sign are the two things a walk that recomputes a value would lose.
static float gatherClasses[8] = { 1.0f, -1.0f, -0.0f, 0.0f, INFINITY, -INFINITY, NAN, -NAN };
// The feeds of a pad over an axis SHORTER than the result: one row of four and one 1x3x4 of the 1 to 12.
// They are the ordinary 1 to 4 and 1 to 12 rather than the sixteen classes because the question this shape
// asks is not what an element holds but WHERE the operand's row lands in a result three rows longer - and a
// feed whose elements are distinguishable by value is what tells one row from another.
static float thinFeed[4] = { 1.0f, 2.0f, 3.0f, 4.0f };
static float thinCubeFeed[12] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

// A gather's case: the compile is given a feed of the OPERAND's shape and a destination of the RESULT's,
// which the elementwise run() above cannot do - a reduction_case's arrangement, with the operand and the
// result named apart because a gather's result is a different shape at least as often as the same one.
//
// Two lines a case. The shape is printed as well as the bytes, because a gather's answer is its SHAPE as much
// as its elements and the two do not go together: dropping a unit axis never moves an element, so a squeeze's
// bytes cannot say whether the axis was dropped, and adding one neither. Reading a shaped type's EQUALITY takes
// the release down (it calls a selector its own MPSGraphTensor does not declare), but reading the shape off
// the tensor is what every other case here already does and it answers.
//
// `fill` is a byte the destination is filled with before the run, 0 for a fresh buffer. One case asks for it
// because the release writes zeros where a broadcast has no element to read, and a destination the caller had
// already filled is what tells a written zero from one that was simply never written.
static void gather_case_filled(const char *name, MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *),
                               MPSDataType type, NSArray<NSNumber *> *shape, const void *values,
                               unsigned char fill)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:shape dataType:type name:@"a"];
    MPSGraphTensor *t = build(one, a);
    NSUInteger count = 1;
    for (NSNumber *dimension in t.shape) count *= (NSUInteger)dimension.integerValue;
    size_t bytes = count * MPSSizeofMPSDataType(t.dataType);
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    if (fill) memset([buffer contents], fill, bytes);
    printf("#case %s-shape %s\n", name, [[t.shape componentsJoinedByString:@"x"] UTF8String]);
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:t.shape
                                                                             dataType:t.dataType];
    remember(buffer, resultBytes, bytes);
    MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:shape dataType:type];
    MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:@{a: shaped}
                                              targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:@[feed(values, shape, type)]
                           resultsArray:@[destination] executionDescriptor:nil];
    put(name, resultBytes, bytes);
}

static void gather_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *),
                        MPSDataType type, NSArray<NSNumber *> *shape, const void *values)
{
    gather_case_filled(name, build, type, shape, values, 0);
}

// A case over an operation of MORE THAN ONE input, which is what the slice's two other directions need: the
// update is fed a data tensor, an update and three index tensors, and the gradient a gradient and the shape
// of its forward input. Each input is a placeholder of its own shape and data type, the compile is given a
// feed for each of them, and the run is given them in the same order - which is the arrangement the
// one-operand gather_case above cannot ask.
//
// Two lines a case, the shape and the bytes, as every other case in this family prints. The result's shape
// is read off the result tensor, which is what a caller does and what the release can answer: a slice's
// gradient whose forward input's shape is a CONSTANT carries its result's shape when the graph is built,
// and one whose shape is fed carries none at all, which is the family's named divergence and is asked of the
// release in refusals.m rather than here.
//
// `fill` is a byte the destination is filled with before the run, and it is not decoration for this family:
// a gradient writes ZEROS over the elements no gradient reaches - measured, over a destination filled with
// the byte 0xbd - and a destination that starts as zero cannot tell a written zero from an unwritten one.
static void multi_case_filled(const char *name, MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *),
                              NSArray<NSArray<NSNumber *> *> *shapes, NSArray<NSData *> *bytes,
                              NSArray<NSNumber *> *types, unsigned char fill)
{
    MPSGraph *one = [MPSGraph new];
    NSMutableArray *operands = [NSMutableArray arrayWithCapacity:shapes.count];
    NSMutableDictionary *feeds = [NSMutableDictionary dictionary];
    NSMutableArray *inputs = [NSMutableArray arrayWithCapacity:shapes.count];
    for (NSUInteger i = 0; i < shapes.count; i++) {
        MPSDataType type = (MPSDataType)[types[i] unsignedIntValue];
        MPSGraphTensor *operand = [one placeholderWithShape:shapes[i] dataType:type name:@"i"];
        [operands addObject:operand];
        feeds[operand] = [[MPSGraphShapedType alloc] initWithShape:shapes[i] dataType:type];
        [inputs addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:
                           [gDevice newBufferWithBytes:bytes[i].bytes length:bytes[i].length
                                                options:MTLResourceStorageModeShared]
                                                     shape:shapes[i] dataType:type]];
    }
    MPSGraphTensor *t = build(one, operands);
    NSArray<NSNumber *> *shape = t.shape;
    if (shape == nil) {
        printf("#case %s-shape nil\n", name);
        return;
    }
    NSUInteger count = 1;
    for (NSNumber *dimension in shape) count *= (NSUInteger)dimension.integerValue;
    size_t width = MPSSizeofMPSDataType(t.dataType);
    size_t result = count * width;
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:result options:MTLResourceStorageModeShared];
    if (fill) memset([buffer contents], fill, result);
    remember(buffer, resultBytes, result);
    printf("#case %s-shape %s\n", name, [[shape componentsJoinedByString:@"x"] UTF8String]);
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:shape
                                                                             dataType:t.dataType];
    MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:feeds
                                              targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:inputs resultsArray:@[destination] executionDescriptor:nil];
    put(name, resultBytes, result);
}

// The shape of the forward input as a CONSTANT, which is how the release can be asked for a gradient at all:
// the shape of a slice's gradient is a tensor, and a tensor the caller feeds is one the release cannot build a
// graph over (measured: the result's shape is nil before and after the run, and the process writes one
// element). A constant is a value that is in the graph, so the release infers the result's type when the
// graph is built and answers the gradient - which is what these cases compare, and what
// `constantWithData:shape:dataType:` is here for.
static MPSGraphTensor *forwardShapeConstant(MPSGraph *g, NSArray<NSNumber *> *extents)
{
    NSUInteger count = extents.count;
    int32_t *numbers = calloc(count, sizeof(int32_t));
    for (NSUInteger i = 0; i < count; i++)
        numbers[i] = (int32_t)extents[i].integerValue;
    MPSGraphTensor *constant = [g constantWithData:[NSData dataWithBytes:numbers length:count * sizeof(int32_t)]
                                              shape:@[ @(count) ] dataType:MPSDataTypeInt32];
    free(numbers);
    return constant;
}

// The transpose, in both of the forms the family has: 14.0's two axes and 16.0's permutation. The rank-3
// cases are here because a two-axis transpose of a rank above two is a different question from a rank of
// two - the result keeps the operand's rank with two of its axes exchanged, and a permutation of a whole
// ordering is the same question written the other way round.
static void family_gather_transpose(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    gather_case("transpose-axes0-1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a dimension:0 withDimension:1 name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("transpose-axesNeg1-0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a dimension:(NSUInteger)-1 withDimension:0 name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("transpose-permutation10 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a permutation:@[@1, @0] name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("transpose-permutation01 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a permutation:@[@0, @1] name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("transpose-classes-permutation10 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a permutation:@[@1, @0] name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);
    // The 32 classes over a whole 8x4, where a NaN's sign and a denormal's bytes have to survive a walk of
    // the whole operand.
    gather_case("transpose-classes32-permutation10 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a permutation:@[@1, @0] name:@"t"]; },
                MPSDataTypeFloat32, @[@8, @4], leftValues);
    gather_case("transpose-axes0-2 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a dimension:0 withDimension:2 name:@"t"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("transpose-axes1-2 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a dimension:1 withDimension:2 name:@"t"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("transpose-permutation201 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a permutation:@[@2, @0, @1] name:@"t"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("transpose-permutation120 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g transposeTensor:a permutation:@[@1, @2, @0] name:@"t"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    chain_case();
}

// The slice, which is the same walk with an OFFSET and a STRIDE: the result's axis k reads the operand's axis
// k from the caller's start, stepping by the caller's stride. The header's two forms are the same walk.
static void family_gather_slice(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    gather_case("slice-axis1-start1-length2 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a dimension:1 start:1 length:2 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-axis1-startNeg2-length2 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a dimension:1 start:-2 length:2 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-axis0-start1-length1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a dimension:0 start:1 length:1 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-stride2 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @0] ends:@[@2, @4] strides:@[@1, @2] name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-strideNeg1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @3] ends:@[@2, @0] strides:@[@1, @-1] name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-endsPastEnd float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @2] ends:@[@2, @9] strides:@[@1, @1] name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-rank3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@1, @1, @1] ends:@[@2, @3, @4] strides:@[@1, @1, @2] name:@"s"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("slice-classes float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a dimension:1 start:1 length:3 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);
    gather_case("slice-all float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @0] ends:@[@2, @4] strides:@[@1, @1] name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    chain_case();
}

// THE REST OF THE SLICE FAMILY: the three masks of the written-down slice, the slice's GRADIENT, and the
// slice's UPDATE - the three directions of the one arithmetic the header's methods are written over, and the
// measurements behind them are in the header of MPSGraphTensorShapeOps174.m and in
// facts/MetalPerformanceShadersGraph/Core.md.
//
// A family of its own because one process cannot hold it: the four fed forms of 18.2 take the release down
// whatever else the process holds, and they are asked of the release in refusals.m for that reason, so what
// is compared here is every form the release answers.
static void family_gather_slice_rest(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];

    // THE THREE MASKS, over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40). A startMask bit means the start
    // written down is not read and the axis starts at zero, so a start of 5 and a start of -3 answer what a
    // start of 0 answers.
    gather_case("slice-mask-start float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@5, @0] ends:@[@1, @4] strides:@[@1, @1]
                              startMask:1 endMask:0 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-mask-start-negative float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@-3, @0] ends:@[@2, @4] strides:@[@1, @1]
                              startMask:1 endMask:0 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // An endMask bit means the end written down is not read either and the axis runs to its own last element:
    // three elements from a start of 1, whether the written end is 0 or -9.
    gather_case("slice-mask-end float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @1] ends:@[@2, @0] strides:@[@1, @1]
                              startMask:0 endMask:2 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-mask-end-past float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @1] ends:@[@2, @-9] strides:@[@1, @1]
                              startMask:0 endMask:2 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // With a NEGATIVE stride the masked end is the one before the axis begins, so the count reaches index 0.
    gather_case("slice-mask-end-negative-stride float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @3] ends:@[@2, @0] strides:@[@1, @-1]
                              startMask:0 endMask:2 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // Both masks and a stride above one: the count is the number of steps that reach the masked end.
    gather_case("slice-mask-both-stride2 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@7, @7] ends:@[@0, @0] strides:@[@2, @2]
                              startMask:3 endMask:3 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-mask-both-stride2-rank3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@9, @9, @9] ends:@[@0, @0, @0] strides:@[@2, @3, @2]
                              startMask:7 endMask:7 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    // A squeezeMask bit drops the axis from the RESULT's shape whatever its extent, and the elements are the
    // mapped walk's own in order: the first row, the first row again over two selected rows, the first column,
    // and the first element with both axes dropped.
    gather_case("slice-mask-squeeze-axis0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @0] ends:@[@1, @4] strides:@[@1, @1]
                              startMask:0 endMask:0 squeezeMask:1 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-mask-squeeze-axis0-two-rows float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @0] ends:@[@2, @4] strides:@[@1, @1]
                              startMask:0 endMask:0 squeezeMask:1 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-mask-squeeze-axis1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @0] ends:@[@2, @1] strides:@[@1, @1]
                              startMask:0 endMask:0 squeezeMask:2 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("slice-mask-squeeze-both float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @0] ends:@[@2, @4] strides:@[@1, @1]
                              startMask:3 endMask:3 squeezeMask:3 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // A squeezed axis of a rank of three, and a squeeze over an axis the walk reads with a stride.
    gather_case("slice-mask-squeeze-rank3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@1, @0, @0] ends:@[@2, @3, @4] strides:@[@1, @2, @1]
                              startMask:0 endMask:0 squeezeMask:1 name:@"s"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    // The sixteen classes through a mask, where a NaN's sign and a negative zero's sign are what a walk that
    // recomputed a value would lose.
    gather_case("slice-mask-classes float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@1, @1] ends:@[@2, @0] strides:@[@1, @2]
                              startMask:2 endMask:2 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);

    // THE GRADIENT, which writes into a tensor of the shape the forward pass's input had. The shape is fed as
    // a CONSTANT, because that is the only way the release answers it at all (measured, and the fed form is
    // refusals.m's `slice-gradient-fed-shape`). The destination is filled with the byte 0xbd first, because
    // the elements no gradient reaches are written zeros and a destination that started as zero could not
    // tell a written zero from an unwritten one.
    {
        NSArray<NSNumber *> *forwardShape = @[@2, @4];
        float gradient[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
        float three[3] = { -1, -2, -3 };
        float two[2] = { -1, -2 };
        multi_case_filled("slice-gradient-all float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShapeConstant(g, forwardShape)
                                                  starts:@[@0, @0] ends:@[@2, @4] strides:@[@1, @1] name:@"grad"]; },
                          @[@[@2, @4]], @[[NSData dataWithBytes:gradient length:sizeof gradient]], @[@(MPSDataTypeFloat32)],
                          0xbd);
        multi_case_filled("slice-gradient-row0 float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShapeConstant(g, forwardShape)
                                                  starts:@[@0, @0] ends:@[@1, @3] strides:@[@1, @1] name:@"grad"]; },
                          @[@[@1, @3]], @[[NSData dataWithBytes:three length:sizeof three]], @[@(MPSDataTypeFloat32)],
                          0xbd);
        multi_case_filled("slice-gradient-cols12 float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShapeConstant(g, forwardShape)
                                                  starts:@[@0, @1] ends:@[@1, @3] strides:@[@1, @1] name:@"grad"]; },
                          @[@[@1, @2]], @[[NSData dataWithBytes:two length:sizeof two]], @[@(MPSDataTypeFloat32)],
                          0xbd);
        // The masked form of the same thing: the three masks are the slice's own, and an endMask over axis 1
        // runs that axis to its own last element.
        multi_case_filled("slice-gradient-mask-end float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShapeConstant(g, forwardShape)
                                                  starts:@[@0, @0] ends:@[@2, @0] strides:@[@1, @1]
                                                  startMask:0 endMask:2 squeezeMask:0 name:@"grad"]; },
                          @[@[@2, @4]], @[[NSData dataWithBytes:gradient length:sizeof gradient]], @[@(MPSDataTypeFloat32)],
                          0xbd);
        // The masked gradient of a WHOLE axis: with a startMask over axis 0 the region is two rows, so the
        // gradient is of two rows. The release says so in its own words when it is not - "'mps.
        // strided_slice_gradient' op `grad_input`[0] = 1 should match dimension size: 2 deduced from
        // `fwd_shape`" - which is the check this port makes at build time and refusals.m holds.
        float bothRows[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
        multi_case_filled("slice-gradient-mask-start float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShapeConstant(g, forwardShape)
                                                  starts:@[@1, @0] ends:@[@2, @4] strides:@[@1, @1]
                                                  startMask:1 endMask:0 squeezeMask:0 name:@"grad"]; },
                          @[@[@2, @4]], @[[NSData dataWithBytes:bothRows length:sizeof bothRows]],
                          @[@(MPSDataTypeFloat32)], 0xbd);
    }

    // THE UPDATE, which is the data tensor's own elements with the update written OVER the region the slice
    // selects: it replaces and it does not add, and the data is byte for byte what it was everywhere else.
    // The data is of (100, 200, 300, 400 | 500, 600, 700, 800) and the update of (-1, -2, -3, -4).
    {
        float data[8] = { 100, 200, 300, 400, 500, 600, 700, 800 };
        float two[2] = { -1, -2 };
        float four[4] = { -1, -2, -3, -4 };
        float eight[8] = { -1, -2, -3, -4, -5, -6, -7, -8 };
        // One data type per INPUT, not per kind of value in the case: the two-input updates are a data tensor
        // and an update, and the five-input fed ones are those two and three index tensors.
        NSArray<NSNumber *> *twoFloats = @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32)];
        int32_t starts[2] = { 0, 1 };
        int32_t ends[2] = { 1, 3 };
        int32_t each[2] = { 1, 1 };
        int32_t rowStarts[2] = { 1, 0 };
        int32_t rowEnds[2] = { 2, 4 };
        NSArray<NSArray<NSNumber *> *> *fedShape = @[@[@2, @4], @[@1, @2], @[@2], @[@2], @[@2]];

        multi_case_filled("slice-update-written float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] starts:@[@0, @1]
                                                      ends:@[@1, @3] strides:@[@1, @1] name:@"upd"]; },
                          @[@[@2, @4], @[@1, @2]],
                          @[[NSData dataWithBytes:data length:sizeof data],
                            [NSData dataWithBytes:two length:sizeof two]], twoFloats, 0);
        multi_case_filled("slice-update-all float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] starts:@[@0, @0]
                                                      ends:@[@2, @4] strides:@[@1, @1] name:@"upd"]; },
                          @[@[@2, @4], @[@2, @4]],
                          @[[NSData dataWithBytes:data length:sizeof data],
                            [NSData dataWithBytes:eight length:sizeof eight]], twoFloats, 0);
        // The masked form of 17.4: a startMask over axis 0 with a start of 1 and an end of 2 writes the WHOLE
        // axis, which is what a start of zero and an end of two say.
        multi_case_filled("slice-update-mask-start float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] starts:@[@1, @0]
                                                      ends:@[@2, @4] strides:@[@1, @1] startMask:1 endMask:0
                                                      squeezeMask:0 name:@"upd"]; },
                          @[@[@2, @4], @[@2, @4]],
                          @[[NSData dataWithBytes:data length:sizeof data],
                            [NSData dataWithBytes:eight length:sizeof eight]], twoFloats, 0);
        // A NEGATIVE stride writes the update's elements along the region's own order: the region walks axis
        // 1 from 3 with a stride of -1, so the update's first element goes to index 3.
        multi_case_filled("slice-update-negative-stride float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] starts:@[@0, @3]
                                                      ends:@[@2, @1] strides:@[@1, @-1] name:@"upd"]; },
                          @[@[@2, @4], @[@2, @2]],
                          @[[NSData dataWithBytes:data length:sizeof data],
                            [NSData dataWithBytes:four length:sizeof four]], twoFloats, 0);
        // The FED forms, which the release answers because the result's shape is the data tensor's own and
        // the graph knows it when the graph is built: a fed start, end and stride are the one fed parameter
        // of this family the release takes, measured over int32 of shape [2] for all three.
        multi_case_filled("slice-update-fed float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] startsTensor:in[2]
                                                      endsTensor:in[3] stridesTensor:in[4] name:@"upd"]; },
                          fedShape,
                          @[[NSData dataWithBytes:data length:sizeof data],
                            [NSData dataWithBytes:two length:sizeof two],
                            [NSData dataWithBytes:starts length:sizeof starts],
                            [NSData dataWithBytes:ends length:sizeof ends],
                            [NSData dataWithBytes:each length:sizeof each]],
                          @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32), @(MPSDataTypeInt32),
                            @(MPSDataTypeInt32), @(MPSDataTypeInt32)], 0);
        multi_case_filled("slice-update-fed-mask-start float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] startsTensor:in[2]
                                                      endsTensor:in[3] stridesTensor:in[4] startMask:1 endMask:0
                                                      squeezeMask:0 name:@"upd"]; },
                          @[@[@2, @4], @[@2, @4], @[@2], @[@2], @[@2]],
                          @[[NSData dataWithBytes:data length:sizeof data],
                            [NSData dataWithBytes:eight length:sizeof eight],
                            [NSData dataWithBytes:rowStarts length:sizeof rowStarts],
                            [NSData dataWithBytes:rowEnds length:sizeof rowEnds],
                            [NSData dataWithBytes:each length:sizeof each]],
                          @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32), @(MPSDataTypeInt32),
                            @(MPSDataTypeInt32), @(MPSDataTypeInt32)], 0);
    }
    // THE SLICE'S GRADIENT with the forward input's shape fed, which is the one fed parameter whose result
    // the release's own tensor carries NO shape on at all: nil, before the run and after it, and the two
    // forms of the row are the same measurement. Nothing else about them is asked here - what the run writes
    // is refusals.m's slice-gradient-fed-shape and slice-gradient-fed.
    fed_shape_case("fed-gradient-shape-14",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g sliceGradientTensor:in[0] fwdInShapeTensor:in[1] starts:@[@0, @1]
                                               ends:@[@1, @3] strides:@[@1, @1] name:@"grad"]; },
                   @[@1, @2], @[@[@2]]);
    fed_shape_case("fed-gradient-shape-182",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g sliceGradientTensor:in[0] fwdInShapeTensor:in[1] startTensor:in[2]
                                              endTensor:in[3] strideTensor:in[4] startMask:0 endMask:0
                                           squeezeMask:0 name:@"grad"]; },
                   @[@1, @2], @[@[@2], @[@2], @[@2], @[@2]]);

    chain_case();
}

// THE RUN, ASYNC AND ENCODE FORMS, which are all one walk - the graph's own over its operations - and the
// only difference between them is where the answer goes. Measured on this host's own MPSGraph over a 2x4 of
// (1, 2, 3, 4 | 10, 20, 30, 40) added to itself: the form that takes a RESULTS DICTIONARY writes the answer
// into the tensor data the caller put in it (2, 4, 6, 8 | 20, 40, 60, 80), and the form that RETURNS a
// dictionary hands back the release's OWN tensor data and leaves the caller's buffer untouched - which is
// what the two cases below read, one for each shape of answer, through every form that has it.
static void run_case(const char *name, void (^ask)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *, NSDictionary *))
{
    MPSGraph *one = [MPSGraph new];
    NSArray<NSNumber *> *shape = @[@2, @4];
    float row[8] = { 1, 2, 3, 4, 10, 20, 30, 40 };
    MPSGraphTensor *a = [one placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:@"a"];
    MPSGraphTensor *t = [one additionWithPrimaryTensor:a secondaryTensor:a name:@"sum"];
    id<MTLBuffer> in = [gDevice newBufferWithBytes:row length:32 options:MTLResourceStorageModeShared];
    id<MTLBuffer> out = [gDevice newBufferWithLength:32 options:MTLResourceStorageModeShared];
    memset([out contents], 0xbd, 32);
    MPSGraphTensorData *input = [[MPSGraphTensorData alloc] initWithMTLBuffer:in shape:shape dataType:MPSDataTypeFloat32];
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:out shape:shape
                                                                        dataType:MPSDataTypeFloat32];
    remember(out, resultBytes, 32);
    ask(one, a, t, @{a: input, t: destination});
    put(name, resultBytes, 32);
}

static void family_run_forms(void)
{
    id<MTLCommandQueue> queue = [gDevice newCommandQueue];
    NSArray<NSNumber *> *shape = @[@2, @4];

    // THE FORMS THAT WRITE INTO THE DICTIONARY THE CALLER GAVE, which is where the answer lands.
    run_case("run-dictionary float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        [g runWithMTLCommandQueue:queue feeds:@{a: both[a]} targetOperations:nil
             resultsDictionary:@{t: both[t]}];
    });
    // THE ASYNC FORMS ARE ASKED WITH THE DESCRIPTOR'S OWN waitUntilCompleted, which is the header's own way of
    // saying the call returns after the work is done - so the answer is in the caller's buffer when it returns
    // and there is nothing to wait for afterwards. That is the coordinator's correction and it is right: the
    // previous pass of this family asked a COMMAND QUEUE for -waitUntilCompleted, which is a method of the
    // command BUFFER, and read a buffer the release had not written yet and called that a host limit.
    //
    // THE ENCODE FORMS ARE CASES, and the buffer they encode into is MPSGraph's OWN MPSCommandBuffer, made the
    // way the SDK declares it: +commandBufferFromCommandQueue: in
    // MetalPerformanceShaders.framework/Frameworks/MPSCore.framework/Headers/MPSCommandBuffer.h, INSIDE the
    // MetalPerformanceShaders umbrella. The class adopts MTLCommandBuffer, so -commit and -waitUntilCompleted
    // are its own methods and the wait is on the BUFFER: encode, [buffer commit], [buffer waitUntilCompleted],
    // and then the caller's own buffer is read. Two earlier passes of this file concluded that the class
    // could not be made, from a bare alloc raising "-[MPSCommandBuffer device]: unrecognized selector", which
    // measures -init (the header marks it NS_UNAVAILABLE and says to use -initWithCommandBuffer:) and not the
    // factory. Measured on this host: the class is MPSCommandBuffer, +commandBufferFromCommandQueue: answers
    // one, and it answers -waitUntilCompleted, on the object itself and on its -rootCommandBuffer alike.
    run_case("run-async-dictionary float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSGraphExecutionDescriptor *descriptor = [MPSGraphExecutionDescriptor new];
        descriptor.waitUntilCompleted = YES;
        [g runAsyncWithMTLCommandQueue:queue feeds:@{a: both[a]} targetOperations:nil
                   resultsDictionary:@{t: both[t]} executionDescriptor:descriptor];
    });
    run_case("run-async-tensors-waited float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSGraphExecutionDescriptor *descriptor = [MPSGraphExecutionDescriptor new];
        descriptor.waitUntilCompleted = YES;
        NSDictionary *got = [g runAsyncWithMTLCommandQueue:queue feeds:@{a: both[a]} targetTensors:@[t]
                                targetOperations:nil executionDescriptor:descriptor];
        printf("#case run-async-tensors-waited-entries %lu\n", (unsigned long)got.count);
    });
    run_case("run-async-feeds-waited float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSGraphExecutionDescriptor *descriptor = [MPSGraphExecutionDescriptor new];
        descriptor.waitUntilCompleted = YES;
        NSDictionary *got = [g runAsyncWithFeeds:@{a: both[a]} targetTensors:@[t] targetOperations:nil
                             executionDescriptor:descriptor];
        printf("#case run-async-feeds-waited-entries %lu\n", (unsigned long)got.count);
    });

    // THE EXECUTABLE'S ASYNC AND ENCODE FORMS, asked the same two ways: its descriptor carries the same
    // waitUntilCompleted and the same completion handler, and the buffer's wait is on the buffer.
    run_case("executable-async-waited float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSGraphExecutable *e = [g compileWithDevice:gGraphDevice feeds:@{a: [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32]}
                                         targetTensors:@[t] targetOperations:nil compilationDescriptor:nil];
        MPSGraphExecutableExecutionDescriptor *descriptor = [MPSGraphExecutableExecutionDescriptor new];
        descriptor.waitUntilCompleted = YES;
        [e runAsyncWithMTLCommandQueue:queue inputsArray:@[both[a]] resultsArray:@[both[t]]
                  executionDescriptor:descriptor];
    });
    // THE FORMS THAT RETURN A DICTIONARY: measured, they leave the caller's buffer as it was, so the case
    // reads the buffer the port and the release both left alone - the byte 0xbd the destination was filled
    // with is what a form that writes nothing leaves behind.
    run_case("run-returns-dictionary float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        NSDictionary *got = [g runWithMTLCommandQueue:queue feeds:@{a: both[a]} targetTensors:@[t]
                                targetOperations:nil];
        printf("#case run-returns-dictionary-entries %lu\n", (unsigned long)got.count);
    });
    run_case("run-async-returns-dictionary float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        NSDictionary *got = [g runAsyncWithFeeds:@{a: both[a]} targetTensors:@[t] targetOperations:nil
                             executionDescriptor:nil];
        printf("#case run-async-returns-dictionary-entries %lu\n", (unsigned long)got.count);
    });
    run_case("run-encode-dictionary float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSCommandBuffer *buffer = [MPSCommandBuffer commandBufferFromCommandQueue:queue];
        [g encodeToCommandBuffer:buffer feeds:@{a: both[a]} targetOperations:nil
             resultsDictionary:@{t: both[t]} executionDescriptor:nil];
        [buffer commit];
        [buffer waitUntilCompleted];
    });
    run_case("run-encode-returns-dictionary float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSCommandBuffer *buffer = [MPSCommandBuffer commandBufferFromCommandQueue:queue];
        NSDictionary *got = [g encodeToCommandBuffer:buffer feeds:@{a: both[a]} targetTensors:@[t]
                                targetOperations:nil executionDescriptor:nil];
        [buffer commit];
        [buffer waitUntilCompleted];
        printf("#case run-encode-returns-dictionary-entries %lu\n", (unsigned long)got.count);
    });
    // The executable's own encode form, over the same buffer: its resultsArray is where its answer lands, and
    // it is asked with the same commit and the same wait.
    run_case("executable-encode float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSGraphExecutable *e = [g compileWithDevice:gGraphDevice feeds:@{a: [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32]}
                                         targetTensors:@[t] targetOperations:nil compilationDescriptor:nil];
        MPSCommandBuffer *buffer = [MPSCommandBuffer commandBufferFromCommandQueue:queue];
        [e encodeToCommandBuffer:buffer inputsArray:@[both[a]] resultsArray:@[both[t]]
                executionDescriptor:nil];
        [buffer commit];
        [buffer waitUntilCompleted];
    });

    // THE SPECIALIZATION AND THE OUTPUT TYPES: the output types are the targets' own shapes, printed one per
    // line, which is the whole of what a caller can read off them.
    {
        MPSGraph *g = [MPSGraph new];
        MPSGraphTensor *a = [g placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:@"a"];
        MPSGraphTensor *t = [g additionWithPrimaryTensor:a secondaryTensor:a name:@"sum"];
        MPSGraphShapedType *input = [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32];
        MPSGraphExecutable *e = [g compileWithDevice:gGraphDevice feeds:@{a: input} targetTensors:@[t]
                                     targetOperations:nil compilationDescriptor:nil];
        [e specializeWithDevice:gGraphDevice inputTypes:@[input] compilationDescriptor:nil];
        NSArray<MPSGraphShapedType *> *types = [e getOutputTypesWithDevice:gGraphDevice inputTypes:@[input]
                                                   compilationDescriptor:nil];
        printf("#case output-types-count %lu\n", (unsigned long)types.count);
        for (MPSGraphShapedType *type in types)
            printf("#case output-type-shape %s\n", [[type.shape componentsJoinedByString:@"x"] UTF8String]);
    }

    // THE TWO SHARED-EVENT METHODS, and what a run does with them: measured, a fresh event's signaledValue is
    // 0 and naming it does not change it, so a run with a descriptor that SIGNALS one writes the value into
    // it - and the case reads the event's own value after the run, which is the only thing a caller can read.
    {
        id<MTLSharedEvent> event = [gDevice newSharedEvent];
        MPSGraphExecutableExecutionDescriptor *descriptor = [MPSGraphExecutableExecutionDescriptor new];
        [descriptor signalEvent:event atExecutionEvent:MPSGraphExecutionStageCompleted value:42];
        printf("#case event-before-run %llu\n", (unsigned long long)event.signaledValue);
        run_case("event-signalled float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
            MPSGraphExecutable *e = [g compileWithDevice:gGraphDevice feeds:@{a: [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32]}
                                             targetTensors:@[t] targetOperations:nil compilationDescriptor:nil];
            // The SYNCHRONOUS form of the run, which is the one whose answer this host can be asked for: the
            // async one returns before the GPU work is done and the queue cannot be waited on, so a case
            // through it would be reading nothing. The descriptor's events are honoured by both.
            [e runWithMTLCommandQueue:queue inputsArray:@[both[a]] resultsArray:@[both[t]]
                  executionDescriptor:descriptor];
        });
        printf("#case event-after-run %llu\n", (unsigned long long)event.signaledValue);
    }
    chain_case();
}

// PAD AND TILE, which are the gather walk with two more rules: a TILE repeats every axis, and a PAD is the
// walk with an offset per axis and the space outside the operand filled by the padding mode. The pad's
// gradient is the walk's other direction - a scatter, with the left padding as its offset - and the
// measurements behind every rule are in the pad block of MPSGraph14.m and in
// facts/MetalPerformanceShadersGraph/Core.md.
static void family_gather_padtile(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    NSArray<NSNumber *> *oneByFour = @[@1, @4];
    NSArray<NSNumber *> *oneByThreeByFour = @[@1, @3, @4];

    // THE FIVE MODES THE RELEASE ANSWERS, over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) with one element of
    // padding at the front and the back of axis 0 and two at the front of axis 1.
    gather_case("pad-constant float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeConstant leftPadding:@[@1, @2]
                          rightPadding:@[@1, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("pad-zero float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeZero leftPadding:@[@1, @2]
                          rightPadding:@[@1, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("pad-clamp float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeClampToEdge leftPadding:@[@1, @2]
                          rightPadding:@[@1, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("pad-reflect float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeReflect leftPadding:@[@1, @2]
                          rightPadding:@[@1, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("pad-symmetric float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeSymmetric leftPadding:@[@1, @2]
                          rightPadding:@[@1, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // One element at each end of both axes, which is where the two mirrors differ from one another by one
    // element and from a repeat of the edge: measured (2, 1, 2, 3, 4, 3) for the reflect and (1, 1, 2, 3, 4, 4)
    // for the symmetric.
    gather_case("pad-reflect-one float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeReflect leftPadding:@[@1, @1]
                          rightPadding:@[@1, @1] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("pad-symmetric-one float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeSymmetric leftPadding:@[@1, @1]
                          rightPadding:@[@1, @1] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // Three elements at the front of axis 1 and two at the back, which is a mirror of more than half an axis.
    // A rank of three IS asked below, over an axis of extent one: measured on this host's own MPSGraph, a
    // pad of a 2x3x4 into a destination of the RESULT's own shape answers in every mode, and the entries in
    // refusals.txt that say otherwise are this file's own question asked into the wrong shape.
    gather_case("pad-reflect-three float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeReflect leftPadding:@[@1, @3]
                          rightPadding:@[@1, @2] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // A PADDED AXIS SHORTER THAN THE RESULT, which nothing above reached: the operand is ONE row and the
    // result is four, with the three at the front for the mode to fill. This is the shape the tile
    // gradient's own shifts ask for - a window of five over a leading block of four pads a row of one back
    // out to four - and the differential carried no case that reached it, so what a pad's fill does over a
    // thin axis was unmeasured. Measured on this host's own MPSGraph, in every mode it answers:
    //   - the zero and the constant write the operand's row at the row the offset puts it in and the three
    //     at the front hold the mode's own value, which is what "a row of one padded out to four" means;
    //   - the clamp answers the operand's own row at EVERY row of the result, because clamping a length-one
    //     axis has no other element to clamp to (measured 1, 2, 3, 4 four times over);
    //   - padded on the RIGHT instead, the operand's row lands at the first row and the three at the back
    //     hold - the same walk read from the other end;
    //   - a rank of three of the same shape answers too, over the leading axis and over the axis just below
    //     it, so the fill is chosen on every axis at once and not only on the first.
    // The two mirrors do NOT answer this shape and are refusals.m's pad-thin-reflect and pad-thin-symmetric:
    // they reach the axis and this axis is one element long.
    gather_case("pad-thin-zero float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeZero leftPadding:@[@3, @0]
                          rightPadding:@[@0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByFour, thinFeed);
    gather_case("pad-thin-constant float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeConstant leftPadding:@[@3, @0]
                          rightPadding:@[@0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByFour, thinFeed);
    gather_case("pad-thin-clamp float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeClampToEdge leftPadding:@[@3, @0]
                          rightPadding:@[@0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByFour, thinFeed);
    gather_case("pad-thin-right-zero float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeZero leftPadding:@[@0, @0]
                          rightPadding:@[@3, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByFour, thinFeed);
    gather_case("pad-thin-rank3-zero float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeZero leftPadding:@[@3, @0, @0]
                          rightPadding:@[@0, @0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByThreeByFour, thinCubeFeed);
    gather_case("pad-thin-rank3-clamp float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeClampToEdge
                           leftPadding:@[@3, @0, @0] rightPadding:@[@0, @0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByThreeByFour, thinCubeFeed);
    gather_case("pad-thin-rank3-axis1-zero float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeZero leftPadding:@[@0, @3, @0]
                          rightPadding:@[@0, @0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByThreeByFour, thinCubeFeed);
    // HOW FAR EACH MIRROR REACHES, which is the two modes' own limit and not one number for both. Measured
    // on this host's own MPSGraph at extents one, two and three, left and right, over every padding from one
    // to five: a REFLECT answers up to the axis LESS ONE and a SYMMETRIC up to the axis ITSELF, and one
    // element more of either is refused by the release's compiler with its own words - "'mps.pad' op padding
    // values too large at axis 0, max padding is 1, got 3" (MPSGraphUtilities.mm:956) - where the maximum it
    // prints is 1 for a reflect on an axis of two and 2 for a symmetric on the same axis. So the symmetric
    // boundary below ANSWERS, with the mirror at both ends of the axis, and the port refused it.
    gather_case("pad-symmetric-boundary float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeSymmetric leftPadding:@[@2, @0]
                          rightPadding:@[@0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("pad-symmetric-boundary-both float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeSymmetric leftPadding:@[@2, @0]
                          rightPadding:@[@2, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // The symmetric over an axis of extent one at its own limit, which is the one element of padding a
    // length-one axis admits and the mirror's own edge (measured: the operand's row repeated), and the same
    // over the axis just below the last of a rank of three, where the extent is three and the padding is its
    // own limit.
    gather_case("pad-symmetric-thin float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeSymmetric leftPadding:@[@1, @0]
                          rightPadding:@[@1, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByFour, thinFeed);
    gather_case("pad-symmetric-thin-rank3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeSymmetric
                           leftPadding:@[@1, @0, @0] rightPadding:@[@0, @0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByThreeByFour, thinCubeFeed);
    gather_case("pad-symmetric-thin-axis1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeSymmetric
                           leftPadding:@[@0, @3, @0] rightPadding:@[@0, @0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, oneByThreeByFour, thinCubeFeed);
    gather_case("pad-reflect-axis0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeReflect leftPadding:@[@1, @0]
                          rightPadding:@[@1, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // A rank of THREE, over the whole of it at once, which the entries in refusals.txt used to call a refusal.
    // Measured on this host's own MPSGraph with a destination of the RESULT's own shape, a 2x3x4 of (1 ... 24)
    // padded by one at each end of every axis answers a 4x5x6 in every mode - and the clamp and the
    // symmetric answer the same bytes here, because one element of padding on an axis of two or more is where
    // the two mirrors and the clamp agree.
    gather_case("pad-rank3-clamp float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeClampToEdge leftPadding:@[@1, @1, @1]
                          rightPadding:@[@1, @1, @1] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("pad-rank3-symmetric float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeSymmetric leftPadding:@[@1, @1, @1]
                          rightPadding:@[@1, @1, @1] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    // A padding of nothing at all is the identity, and the sixteen classes through it say so byte for byte.
    gather_case("pad-nopad float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeConstant leftPadding:@[@0, @0]
                          rightPadding:@[@0, @0] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);
    gather_case("pad-clamp-classes float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeClampToEdge leftPadding:@[@1, @1]
                          rightPadding:@[@1, @0] constantValue:-1.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);

    // THE TILE, and the multiplier that touches one axis and not the other.
    gather_case("tile-2x3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g tileTensor:a withMultiplier:@[@2, @3] name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("tile-axis1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g tileTensor:a withMultiplier:@[@1, @3] name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("tile-axis0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g tileTensor:a withMultiplier:@[@2, @1] name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // A rank of three, which the release answers: a 2x3x4 tiled by two on every axis is a 4x6x8 of 192
    // elements, which is also what this file's own result buffer had to grow for.
    gather_case("tile-rank3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g tileTensor:a withMultiplier:@[@2, @2, @2] name:@"t"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("tile-one float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g tileTensor:a withMultiplier:@[@1, @1] name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);

    // THE TWO GRADIENTS, each over a destination filled with the byte 0xbd, because a gradient's answer is
    // the sum over the copies that land on each element and the zeros it writes where none lands are written
    // and not left.
    {
        float padded[24];
        for (int i = 0; i < 24; i++) padded[i] = (float)(i + 1);
        float tiled[48];
        for (int i = 0; i < 48; i++) tiled[i] = (float)(i + 1);
        multi_case_filled("pad-gradient float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g padGradientWithIncomingGradientTensor:in[0] sourceTensor:in[1]
                                       paddingMode:MPSGraphPaddingModeConstant leftPadding:@[@1, @2]
                                       rightPadding:@[@1, @0] name:@"pg"]; },
                          @[@[@4, @6], @[@2, @4]],
                          @[[NSData dataWithBytes:padded length:sizeof padded],
                            [NSData dataWithBytes:rowFeed length:32]],
                          @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32)], 0xbd);
        multi_case_filled("pad-gradient-zero-mode float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g padGradientWithIncomingGradientTensor:in[0] sourceTensor:in[1]
                                       paddingMode:MPSGraphPaddingModeZero leftPadding:@[@1, @2]
                                       rightPadding:@[@1, @0] name:@"pg"]; },
                          @[@[@4, @6], @[@2, @4]],
                          @[[NSData dataWithBytes:padded length:sizeof padded],
                            [NSData dataWithBytes:rowFeed length:32]],
                          @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32)], 0xbd);
    }
    tile_gradient_cases();
    chain_case();
}

// THE TILE'S GRADIENT, the tile's own other direction, and the family carries it now - but only where the
// release's answer is a function of the graph. Measured on this host's own MPSGraph, a window of m[j + 1]
// terms along axis j that RUNS OFF THE END of that axis makes the release read past the end of the caller's
// gradient buffer, so its answer there is whatever memory follows the operand: the same 4x4 of (1 ... 16)
// with a multiplier of (1, 2) and 1000 planted immediately after the operand answers 6, 8, 10, 12 | 14, 16,
// 18, 20 | 22, 24, 26, 28 | 13, 15, 17, 19 and with zeros planted there answers 6, 8, 10, 12 | 14, 16, 18,
// 20 | 22, 24, 26, 28 | 13, 14, 15, 16 - the same graph, the same values, the same shape, and a last row
// that is a function of memory this repository does not own. So a window is not comparable and is asked of
// the release over a planted sentinel instead, in refusals.txt's six `tilegrad-` questions, which is where
// the rule below is recorded. What is comparable is every multiplier whose windows all stay inside the axes,
// and these five cases are all of them: the identity, the leading multiplier read as nothing at and below the
// leading extent, and the two positions of a zero.
//
// The rule the release does follow where it stays inside the operand, measured over a gradient of (1 ... N)
// at four shapes and about thirty multipliers and written down in full in
// facts/MetalPerformanceShadersGraph/Core.md: for each axis j below the last, multiplier[j + 1] is a window
// of that many terms along axis j at axis j's OWN STRIDE, weighted one each; the windows compose across
// axes, and each is a window of the INCOMING GRADIENT and not of the sum so far; multiplier[0] is not read
// while it is at most the leading extent; and an entry of zero anywhere answers zeros. The source is fed
// ONES beside every gradient here, so an answer that read the source instead of the gradient would be ones
// and the case would fail.
static void tile_gradient_cases(void)
{
    float feed16[16], ones16[16], feed4[4], ones4[4];
    for (int i = 0; i < 16; i++) { feed16[i] = (float)(i + 1); ones16[i] = 1.0f; }
    for (int i = 0; i < 4; i++) { feed4[i] = (float)(i + 1); ones4[i] = 1.0f; }
    NSArray<NSNumber *> *fourByFour = @[@4, @4];
    NSArray<NSNumber *> *four = @[@4];
    NSArray<NSNumber *> *floatTypes = @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32)];
    // A multiplier of one on every axis is the gradient unchanged: no window, so nothing is read past the
    // operand and both sides answer.
    tile_gradient_case("tile-gradient-identity float32", @[@1, @1], fourByFour, feed16, ones16, 64, floatTypes);
    // A rank of one, which has no axis below the last and so no window at all: the one entry of its
    // multiplier is the leading one, and a leading entry above one reads past the end of the gradient here as
    // it does everywhere else - measured, a multiplier of (4) over a 4 answers 30, 32, 34, 36. So it is asked
    // with a multiplier of one, which is the only leading entry whose answer is a function of the graph.
    tile_gradient_case("tile-gradient-rank1 float32", @[@1], four, feed4, ones4, 16, floatTypes);
    // An entry of zero is an empty window and an empty sum: written zeros, which a destination filled with
    // the byte 0xbd tells apart from an answer that was never written. Both positions of the zero.
    tile_gradient_case("tile-gradient-zero float32", @[@1, @0], fourByFour, feed16, ones16, 64, floatTypes);
    tile_gradient_case("tile-gradient-zero-leading float32", @[@0, @1], fourByFour, feed16, ones16, 64, floatTypes);
}

// The tile's gradient's case, which is multi_case_filled with the two operands a gradient of a tile has - the
// incoming gradient and the source - and the destination filled with the byte 0xbd, because an empty window
// answers WRITTEN zeros and a destination that starts as zero cannot tell a written zero from an unwritten
// one. Both operands are of the SOURCE'S OWN SHAPE, which is what a gradient of a tile is fed.
static void tile_gradient_case(const char *name, NSArray<NSNumber *> *multiplier,
                               NSArray<NSNumber *> *shape, const void *gradient, const void *source,
                               size_t bytes, NSArray<NSNumber *> *types)
{
    multi_case_filled(name,
                      ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                          return [g tileGradientWithIncomingGradientTensor:in[0] sourceTensor:in[1]
                                                        withMultiplier:multiplier name:@"tg"]; },
                      @[shape, shape],
                      @[[NSData dataWithBytes:gradient length:bytes],
                        [NSData dataWithBytes:source length:bytes]],
                      types, 0xbd);
}

// The reshape, which is the same walk with the axes left alone and the result's shape the caller's: the
// operand's elements in the same row-major order at another extent. A dynamic extent is the header's -1 and
// is the element count over the product of the extents written down.
static void family_gather_reshape(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    gather_case("reshape-4x2 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@4, @2] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reshape-1x8 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@1, @8] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reshape-own-shape float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@2, @4] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reshape-dynamic0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@4, @-1] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reshape-dynamic1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@-1, @4] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reshape-rank1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@8] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reshape-24-6x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@6, @4] name:@"r"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("reshape-24-2x3x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@2, @3, @4] name:@"r"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("reshape-24-24x1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@24, @1] name:@"r"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("reshape-classes-4x8 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@4, @8] name:@"r"]; },
                MPSDataTypeFloat32, @[@8, @4], leftValues);
    gather_case("reshape-rank2-identity float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reshapeTensor:a withShape:@[@2, @4] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // The fed form of the reshape, whose result's shape is the fed tensor's own rank with -1 for every
    // extent, and - for a fed shape of no rank - no shape at all. Measured on this host's own MPSGraph.
    fed_shape_case("fed-reshape-shape-rank2",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g reshapeTensor:in[0] withShapeTensor:in[1] name:@"r"]; },
                   @[@2, @4], @[@[@2]]);
    fed_shape_case("fed-reshape-shape-rank1",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g reshapeTensor:in[0] withShapeTensor:in[1] name:@"r"]; },
                   @[@2, @4], @[@[@1]]);
    fed_shape_case("fed-reshape-shape-unranked",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g reshapeTensor:in[0] withShapeTensor:in[1] name:@"r"]; },
                   @[@2, @4], @[@[]]);

    chain_case();
}

// The flatten, which collapses every axis from the one named on into a single axis. A rank of three is where
// the collapse covers more than one axis, so the axes of the result there read two and three of the operand's
// at once - which is the one thing in this family that is not a copy of the operand's bytes in order.
static void family_gather_flatten(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    gather_case("flatten-axis0-2x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g flatten2DTensor:a axis:0 name:@"f"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("flatten-axis1-2x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g flatten2DTensor:a axis:1 name:@"f"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("flatten-axis0-2x3x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g flatten2DTensor:a axis:0 name:@"f"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("flatten-axis1-2x3x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g flatten2DTensor:a axis:1 name:@"f"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("flatten-axis2-2x3x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g flatten2DTensor:a axis:2 name:@"f"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("flatten-classes-axis0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g flatten2DTensor:a axis:0 name:@"f"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);
    // A flatten2D's result is of rank two whatever axis the walk collapses, so the release's own tensor
    // carries two -1s over a fed axis of any rank - measured, over a fed axis of shape [1], of shape [2]
    // and of no rank at all.
    fed_shape_case("fed-flatten-shape-rank1",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g flatten2DTensor:in[0] axisTensor:in[1] name:@"f"]; },
                   @[@2, @4], @[@[@1]]);
    fed_shape_case("fed-flatten-shape-unranked",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g flatten2DTensor:in[0] axisTensor:in[1] name:@"f"]; },
                   @[@2, @3, @4], @[@[]]);

    chain_case();
}

// The broadcast, which aligns the operand to the RIGHT of the shape given and wraps each axis that shape
// makes wider. The three cases are the three shapes there are: wider on one axis, an axis added at the front,
// and the operand's own shape.
static void family_gather_broadcast(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    gather_case("broadcast-4x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@4, @4] name:@"b"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("broadcast-2x2x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@2, @2, @4] name:@"b"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("broadcast-own-shape float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@2, @4] name:@"b"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("broadcast-classes-4x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@4, @4] name:@"b"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);
    // A rank of three on both sides, where the axis the shape adds is the one the operand has no axis for.
    gather_case("broadcast-2x3x4-4x3x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@4, @3, @4] name:@"b"]; },
                MPSDataTypeFloat32, @[@2, @3, @4], cubeFeed);
    gather_case("broadcast-1x2x4-2x2x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@2, @2, @4] name:@"b"]; },
                MPSDataTypeFloat32, @[@1, @2, @4], cubeFeed);
    // The two axes the shape makes wider than the operand's are the ones the release answers a ZERO at, so
    // this case is asked over a destination filled with a pattern: the answer has to be the release's zeros and
    // not the bytes the caller happened to leave there.
    gather_case_filled("broadcast-4x4-prefilled float32",
                       ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                           return [g broadcastTensor:a toShape:@[@4, @4] name:@"b"]; },
                       MPSDataTypeFloat32, twoByFour, rowFeed, 0xbd);
    // And a broadcast that narrows, which is not a broadcast at all: the release keeps the operand's own extent
    // on that axis and answers the operand's bytes, so the result's shape is the case that says so.
    gather_case("broadcast-narrower float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@1, @4] name:@"b"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // The broadcast is the one fed form whose result the release's own tensor DOES carry a real shape on:
    // over a fed shape of the operand's own rank it carries the operand's own shape whatever the fed
    // numbers are, so this line is the operand's. At a higher rank of operand it carries a vector of -1
    // instead, which the row names with the measurement.
    fed_shape_case("fed-broadcast-shape-rank2",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g broadcastTensor:in[0] toShapeTensor:in[1] name:@"b"]; },
                   @[@2, @4], @[@[@2]]);

    chain_case();
}

// The reverse, which flips the axes it is given and nothing else. The cases are each axis on its own, both,
// neither (the form with no axes at all) and a nil, which is the same question asked the other way round.
static void family_gather_reverse(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    gather_case("reverse-none float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reverseTensor:a name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reverse-axesNil float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reverseTensor:a axes:nil name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reverse-axis0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reverseTensor:a axes:@[@0] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reverse-axis1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reverseTensor:a axes:@[@1] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reverse-axes01 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reverseTensor:a axes:@[@1, @0] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reverse-negative-axis float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reverseTensor:a axes:@[@-1] name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("reverse-classes-none float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reverseTensor:a name:@"r"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);
    gather_case("reverse-rank3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g reverseTensor:a name:@"r"]; },
                MPSDataTypeFloat32, @[@1, @2, @4], cubeFeed);
    // A reverse's result is the operand's own shape whatever axes it is given, so over fed axes the
    // release's own tensor carries the operand's shape too - measured over fed axes of one and of two
    // numbers, at ranks of operand two and three.
    fed_shape_case("fed-reverse-shape-rank3",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g reverseTensor:in[0] axesTensor:in[1] name:@"r"]; },
                   @[@1, @2, @4], @[@[@1]]);

    chain_case();
}

// The squeeze, which drops the axes of extent one it is given - every unit axis when it is given none - and
// keeps the rest in order. The cases are the two forms with no axes (an operand that has a unit axis and one
// that has none), one axis, a set of axes, a negative axis and a nil.
static void family_gather_squeeze(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *oneByTwoByFour = @[@1, @2, @4];
    NSArray<NSNumber *> *oneByOneByFour = @[@1, @1, @4];
    NSArray<NSNumber *> *twoByFourByOne = @[@2, @4, @1];
    gather_case("squeeze-none-1x2x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a name:@"s"]; },
                MPSDataTypeFloat32, oneByTwoByFour, cubeFeed);
    gather_case("squeeze-none-2x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("squeeze-axis0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a axis:0 name:@"s"]; },
                MPSDataTypeFloat32, oneByTwoByFour, cubeFeed);
    gather_case("squeeze-axes0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a axes:@[@0] name:@"s"]; },
                MPSDataTypeFloat32, oneByTwoByFour, cubeFeed);
    gather_case("squeeze-axes01 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a axes:@[@0, @1] name:@"s"]; },
                MPSDataTypeFloat32, oneByOneByFour, cubeFeed);
    gather_case("squeeze-axesNil float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a axes:nil name:@"s"]; },
                MPSDataTypeFloat32, oneByTwoByFour, cubeFeed);
    gather_case("squeeze-negative-axis float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a axis:-1 name:@"s"]; },
                MPSDataTypeFloat32, twoByFourByOne, cubeFeed);
    gather_case("squeeze-classes float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a name:@"s"]; },
                MPSDataTypeFloat32, oneByTwoByFour, gatherClasses);
    // A unit axis in the MIDDLE, where dropping it moves no element: the eight values of a 2x1x4 read the same
    // whether the axis is there or not, so this case is about the shape line and about nothing else - which is
    // what the shape line is in this file for.
    gather_case("squeeze-none-2x1x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a name:@"s"]; },
                MPSDataTypeFloat32, @[@2, @1, @4], cubeFeed);
    gather_case("squeeze-axesNil-2x1x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a axes:nil name:@"s"]; },
                MPSDataTypeFloat32, @[@2, @1, @4], cubeFeed);
    gather_case("squeeze-axesEmpty-2x1x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g squeezeTensor:a axes:@[] name:@"s"]; },
                MPSDataTypeFloat32, @[@2, @1, @4], cubeFeed);
    // A squeeze over fed axes takes one axis off the result's rank per axis the fed tensor names, so the
    // release's own tensor carries that many -1s: one axis of a 1x2x4 is two of them, two axes of a 1x1x2x4
    // are two of them again.
    fed_shape_case("fed-squeeze-shape-rank1",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g squeezeTensor:in[0] axesTensor:in[1] name:@"s"]; },
                   @[@1, @2, @4], @[@[@1]]);
    fed_shape_case("fed-squeeze-shape-rank2",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g squeezeTensor:in[0] axesTensor:in[1] name:@"s"]; },
                   @[@1, @1, @2, @4], @[@[@2]]);

    chain_case();
}

// The expanded dimension, which adds an axis of extent one where it is asked for. A negative axis is counted
// from the end and may be the rank itself, which is the trailing unit axis, so the last case is that one.
static void family_gather_expand(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    gather_case("expand-axis0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axis:0 name:@"e"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("expand-axis2 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axis:2 name:@"e"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("expand-axisNeg1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axis:-1 name:@"e"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("expand-axes02 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axes:@[@0, @2] name:@"e"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    // Two more sets of two axes, which is where "an axis at each index named" and "one axis inserted after
    // another" come apart: over a 2x4 the release answers a 1x1x2x4 and a 2x1x1x4, and inserting each axis
    // into the result of the last would answer a 1x1x2x4 and a 2x1x1x4 for the second and a different shape
    // again for the first.
    gather_case("expand-axes01 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axes:@[@0, @1] name:@"e"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("expand-axes12 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axes:@[@1, @2] name:@"e"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("expand-axesNil float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axes:nil name:@"e"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    gather_case("expand-classes-axis0 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axis:0 name:@"e"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);
    gather_case("expand-rank3-axis1 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g expandDimsOfTensor:a axis:1 name:@"e"]; },
                MPSDataTypeFloat32, @[@2, @3, @4], cubeFeed);
    // An expanded dimension over fed axes carries as many -1s as the fed tensor names - measured at ranks of
    // operand two, three and four - which is not the rank the axis would give and is the release's own.
    fed_shape_case("fed-expand-shape-rank1",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g expandDimsOfTensor:in[0] axesTensor:in[1] name:@"e"]; },
                   @[@2, @3, @4], @[@[@1]]);
    fed_shape_case("fed-expand-shape-rank2",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g expandDimsOfTensor:in[0] axesTensor:in[1] name:@"e"]; },
                   @[@2, @3, @4], @[@[@2]]);

    chain_case();
}

// THE CONCAT AND STACK FAMILY, which is the one walk of this library whose result is SEVERAL operands, so it
// cannot be a gather of one: a region of ONE axis of the result per operand, laid end to end, or one new axis
// that says which operand an element came from. The three concatenations arrived with MPSGraph in 14.0 and
// the stack in 15.4; all four are measured here against this host's own MPSGraph.
//
// Every case below feeds TWO or THREE operands of the SAME shape out of the family's own feeds, so an answer
// says which operand an element came from and which axis it was put on. The destination is filled with the
// byte 0xbd first, because a concatenation writes every element of its result and a destination that starts
// as zero could not tell one it wrote from one it did not.
static float secondFeed[8] = { 5.0f, 6.0f, 7.0f, 8.0f, 50.0f, 60.0f, 70.0f, 80.0f };
static float thirdFeed[8] = { 9.0f, 10.0f, 11.0f, 12.0f, 90.0f, 100.0f, 110.0f, 120.0f };
static float secondCubeFeed[24] = {
    101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112,
    113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124,
};
// The row of four the one-element-on-the-concat-axis case is asked over: distinguishable by value from the
// 2x4 it is laid beside, so an answer says which operand an element came from.
static float thinRow2[4] = { 101.0f, 102.0f, 103.0f, 104.0f };
static float rankOneFeed[3] = { 71.0f, 72.0f, 73.0f };
static float rankOneSecond[3] = { 81.0f, 82.0f, 83.0f };

static void concat_filled(const char *name, NSArray<NSArray<NSNumber *> *> *shapes, NSArray<NSData *> *values,
                          MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *))
{
    multi_case_filled(name, build, shapes, values,
                      @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32), @(MPSDataTypeFloat32)], 0xbd);
}

// The two feeds of every two-operand case of the family, and the three of every three-operand case, as the
// data a case hands the harness.
static NSArray<NSData *> *pairOf(const void *first, const void *second, size_t bytes)
{
    return @[[NSData dataWithBytes:first length:bytes], [NSData dataWithBytes:second length:bytes]];
}

static NSArray<NSData *> *tripleOf(const void *first, const void *second, const void *third, size_t bytes)
{
    return @[[NSData dataWithBytes:first length:bytes], [NSData dataWithBytes:second length:bytes],
             [NSData dataWithBytes:third length:bytes]];
}

static void empty_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *));

static void family_gather_concat(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    NSArray<NSNumber *> *three = @[@3];
    NSArray<NSData *> *pair = pairOf(rowFeed, secondFeed, 32);
    NSArray<NSData *> *triple = tripleOf(rowFeed, secondFeed, thirdFeed, 32);

    // END TO END along the axis, in the order the caller wrote them: axis 0 of two 2x4s is a 4x4 of
    // (1, 2, 3, 4, 10, 20, 30, 40 | 5, 6, 7, 8, 50, 60, 70, 80) and axis 1 a 2x8 of the same eight values
    // each - which is the same walk with the extents added rather than the rows beside one another.
    concat_filled("concat-axis0 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
    concat_filled("concat-axis1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 name:@"c"];
                  });
    // A NEGATIVE axis counted from the end, which answers what its positive does on both axes: measured on
    // this host's own MPSGraph, axis -2 of two 2x4s answers what axis 0 answers and axis -1 what axis 1
    // answers, and the release's own compiler takes the range as -rank <= axis < rank.
    concat_filled("concat-axisNeg1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:-1 name:@"c"];
                  });
    concat_filled("concat-axisNeg2 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:-2 name:@"c"];
                  });
    // The header's TWO-TENSOR form, which is the many-operand one over two and answers the same bytes.
    concat_filled("concat-two-axis0 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensor:in[0] withTensor:in[1] dimension:0 name:@"c"];
                  });
    concat_filled("concat-two-axis1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensor:in[0] withTensor:in[1] dimension:1 name:@"c"];
                  });
    // THREE operands, whose regions are the caller's order down the axis and across it. The 6x4 of axis 0
    // is the three 2x4s one under another; the 2x12 of axis 1 is their rows side by side.
    concat_filled("concat3-axis0 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
    concat_filled("concat3-axis1 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 name:@"c"];
                  });
    concat_filled("concat3-axisNeg1 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:-1 name:@"c"];
                  });
    // ONE operand is the identity: measured on this host's own MPSGraph, a 2x4 on its own is a 2x4 of its
    // own eight values, and not a 3x4 or anything with an element of it missing.
    concat_filled("concat-one-axis0 float32", @[twoByFour], @[pair[0]],
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
    // INTERLEAVED along the axis, which is the header's third form: operand i's coordinate c lands at the
    // result's coordinate i + c * (the number of operands). Measured on this host's own MPSGraph, axis 1 of
    // two is a 2x8 of (1, 5, 2, 6, 3, 7, 4, 8 | 10, 50, 20, 60, 30, 70, 40, 80), and axis 1 of three a 2x12
    // of (1, 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12 | 10, 50, 90, 20, 60, 100, 30, 70, 110, 40, 80, 120).
    concat_filled("concat-interleave-axis1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 interleave:YES name:@"c"];
                  });
    concat_filled("concat-interleave-axis0 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 interleave:YES name:@"c"];
                  });
    concat_filled("concat3-interleave-axis1 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 interleave:YES name:@"c"];
                  });
    // The interleave form with NO is exactly the many-operand form, byte for byte, which is what the header
    // says of it ("When interleave is specified, all tensors will be interleaved") and what makes the flag
    // one bit rather than a second walk.
    concat_filled("concat3-interleave-no-axis1 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 interleave:NO name:@"c"];
                  });
    // A RANK OF THREE, where the axis named is neither the first nor the last, so that the mapping of the
    // axes below and above the one laid along is asked at a rank where there is one of each.
    concat_filled("concat-rank3-axis0 float32", @[twoByThreeByFour, twoByThreeByFour],
                  pairOf(cubeFeed, secondCubeFeed, 96),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
    concat_filled("concat-rank3-axis1 float32", @[twoByThreeByFour, twoByThreeByFour],
                  pairOf(cubeFeed, secondCubeFeed, 96),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 name:@"c"];
                  });
    // AN EXTENT OF ONE ON THE AXIS LAID ALONG is not a broadcast: it is one element of the result, and the
    // two extents are added. Measured on this host's own MPSGraph, a 1x4 of (101, 102, 103, 104) laid along
    // axis 0 beside a 2x4 is a 3x4 of (101, 102, 103, 104 | 5, 6, 7, 8 | 50, 60, 70, 80) and not a 2x4 with
    // the row repeated. The same two operands with axis 1 the one laid along are REFUSED, because then the
    // extent that differs is one the concatenation does not touch - refusals.m's concat-shapes-differ.
    // THE OPERANDS OF DIFFERING LENGTH ON THE AXIS LAID ALONG, which is the one shape where the axis's own
    // extent is allowed to differ between them, and where the answer is NOT one of the operands' lengths: a
    // 2x4 laid along axis 1 beside a 2x1 of (5, 6) is a 2x5 of (1, 2, 3, 4, 10 | 20, 30, 40, 5, 6), measured.
    // The extent that differs is on the axis the operands ARE laid along, so the refusal above does not apply
    // and the region of the shorter one is one element of the result - which is why the interleave form of
    // this very shape is refused with a different sentence, refusals.m's concat-interleave-unequal.
    concat_filled("concat-unequal-axis1 float32", @[twoByFour, @[@2, @1]],
                  @[pair[0], [NSData dataWithBytes:secondFeed length:8]],
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 name:@"c"];
                  });
    concat_filled("concat-unequal-axis0 float32", @[@[@2, @4], @[@1, @4]],
                  @[pair[0], [NSData dataWithBytes:thinRow2 length:16]],
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
    concat_filled("concat-thin-axis0 float32", @[@[@1, @4], twoByFour],
                  @[[NSData dataWithBytes:thinRow2 length:16], pair[1]],
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
    // THE SIXTEEN CLASSES through it, because a concatenation copies and a copy that recomputed a value would
    // lose a NaN's sign and a negative zero's - the two things the classes exist for.
    concat_filled("concat-classes-axis0 float32", @[twoByFour, twoByFour],
                  pairOf(gatherClasses, gatherClasses, 32),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
    concat_filled("concat-classes-axis1 float32", @[twoByFour, twoByFour],
                  pairOf(gatherClasses, gatherClasses, 32),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 name:@"c"];
                  });

    // THE STACK, which is the same walk with one axis ADDED: the result's axis of extent as many operands
    // says which operand an element came from, and the axes around it are the operands' own. Measured on
    // this host's own MPSGraph, axis 1 of two 2x4s is a 2x2x4 of (1, 2, 3, 4, 5, 6, 7, 8 | 10, 20, 30, 40,
    // 50, 60, 70, 80) and axis 2 a 2x4x2 of (1, 5, 2, 6, 3, 7, 4, 8 | 10, 50, 20, 60, 30, 70, 40, 80).
    concat_filled("stack-axis0 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:0 name:@"s"];
                  });
    concat_filled("stack-axis1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:1 name:@"s"];
                  });
    concat_filled("stack-axis2 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:2 name:@"s"];
                  });
    // A NEGATIVE axis counted from the end of the RESULT's rank, which is one more than the operands' -
    // so axis -3 answers what axis 0 answers and axis -1 what axis 2 does, which is what the header's own
    // range says (`-rank + 1 <= dimension < rank + 1`).
    concat_filled("stack-axisNeg1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:-1 name:@"s"];
                  });
    concat_filled("stack-axisNeg2 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:-2 name:@"s"];
                  });
    concat_filled("stack-axisNeg3 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:-3 name:@"s"];
                  });
    // THREE operands, whose new axis is of extent three, and a stack of ONE, which is the operand itself
    // with that axis of extent one - measured, a 2x4 on its own is a 1x2x4 of its own eight values.
    concat_filled("stack3-axis0 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:0 name:@"s"];
                  });
    concat_filled("stack3-axis1 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:1 name:@"s"];
                  });
    concat_filled("stack3-axis2 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:2 name:@"s"];
                  });
    concat_filled("stack-one-axis0 float32", @[twoByFour], @[pair[0]],
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:0 name:@"s"];
                  });
    // A RANK OF ONE, where the new axis is the only axis of the result and the operands' own has nowhere to
    // go: measured, two 3s stacked at axis 0 are a 2x3 of (71, 72, 73 | 81, 82, 83) and at axis -1 a 3x2 of
    // (71, 81, 72, 82, 73, 83), which is the same walk with the operands' axis on the other side of it.
    concat_filled("stack-rank1-axis0 float32", @[three, three], pairOf(rankOneFeed, rankOneSecond, 12),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:0 name:@"s"];
                  });
    concat_filled("stack-rank1-axisNeg1 float32", @[three, three],
                  pairOf(rankOneFeed, rankOneSecond, 12),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:-1 name:@"s"];
                  });
    // A RANK OF THREE at two different axes of the new rank, so that the mapping of the axes below and
    // above the new one is asked at a rank where there is one of each.
    concat_filled("stack-rank3-axis1 float32", @[twoByThreeByFour, twoByThreeByFour],
                  pairOf(cubeFeed, secondCubeFeed, 96),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:1 name:@"s"];
                  });
    concat_filled("stack-rank3-axis2 float32", @[twoByThreeByFour, twoByThreeByFour],
                  pairOf(cubeFeed, secondCubeFeed, 96),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:2 name:@"s"];
                  });
    concat_filled("stack-classes-axis0 float32", @[twoByFour, twoByFour],
                  pairOf(gatherClasses, gatherClasses, 32),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:0 name:@"s"];
                  });
    concat_filled("stack-classes-axis1 float32", @[twoByFour, twoByFour],
                  pairOf(gatherClasses, gatherClasses, 32),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:1 name:@"s"];
                  });
    // AN EMPTY ARRAY OF OPERANDS, which is NOT a refusal and which this family first got wrong by treating
    // it as one. Measured on this host's own MPSGraph over the whole path: `[g concatTensors:@[] dimension:0]`
    // and `[g stackTensors:@[] axis:0]` both BUILD the result tensor, its shape is nil and its data type is
    // float32 (0x10000020), `compileWithDevice:feeds:@{} targetTensors:@[t]` returns an executable, and the
    // run leaves the caller's destination as it was. So there are no bytes to compare and the two cases below
    // print the SHAPE and the DATA TYPE, which is what the release answers and what the port has to answer
    // with it - a result tensor of nil shape here would make a case that crashes the family run.
    empty_case("concat-empty", ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g concatTensors:@[] dimension:0 name:@"c"];
    });
    empty_case("stack-empty", ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g stackTensors:@[] axis:0 name:@"s"];
    });
    chain_case();
}

// A case over an operation of NO operands, which is the only one in this family whose result is a tensor of
// no shape. There is nothing to run and nothing to compare, so the case prints the two things the release
// does answer about it - the shape, which is nil, and the data type, which is float32 - and the differential
// compares those two lines like any other. `multi_case_filled` cannot ask it: it allocates a result buffer
// from the shape and a nil shape is not a shape.
static void empty_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *))
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *t = build(one, @[]);
    printf("#case %s-shape %s\n", name,
           t.shape == nil ? "nil" : [[t.shape componentsJoinedByString:@"x"] UTF8String]);
    printf("#case %s-datatype 0x%x\n", name, (unsigned)t.dataType);
}

// THE RESULT TENSOR'S SHAPE AND NOTHING ELSE, over a parameter the caller FEEDS: the axis, the axes, the
// shape, or the shape of the slice's forward input. Nothing is compiled and nothing is run, and that is the
// whole of the question: over a fed parameter the release infers the result's type as far as the graph
// already knows and writes -1 for every extent the fed value decides, before the run and after it, and for
// the slice's gradient there is no shape at all. What the RUN writes into a destination the caller names is
// a different question and is measured in refusals.m.
//
// The line has fewer than five fields, so the comparison reads it as the whole line, which is what a shape
// is: there is no result buffer here and the red control's plant, which perturbs what a kernel stores, does
// not reach a line of this kind. What proves these lines can fail is in the hand-over of the band that added
// them, where the one line that puts the shape on is reverted and the families go red.
static void fed_shape_case(const char *name,
                           MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *),
                           NSArray<NSNumber *> *operandShape, NSArray<NSArray<NSNumber *> *> *fedShapes)
{
    MPSGraph *one = [MPSGraph new];
    NSMutableArray<MPSGraphTensor *> *operands = [NSMutableArray arrayWithCapacity:fedShapes.count + 1];
    [operands addObject:[one placeholderWithShape:operandShape dataType:MPSDataTypeFloat32 name:@"a"]];
    for (NSUInteger i = 0; i < fedShapes.count; i++)
        [operands addObject:[one placeholderWithShape:fedShapes[i] dataType:MPSDataTypeInt32 name:@"p"]];
    MPSGraphTensor *t = build(one, operands);
    printf("#case %s result-shape %s\n", name,
           t.shape == nil ? "nil" : [[t.shape componentsJoinedByString:@"x"] UTF8String]);
}

// The data types the two NaN-propagating binaries do not answer, and the feeds they are asked over: eight
// ascending bytes against eight descending ones, so every type here reads the same two numbers.
static unsigned char refusedBytes[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
static unsigned char reversedBytes[8] = { 8, 7, 6, 5, 4, 3, 2, 1 };
static struct { const char *name; MPSDataType type; } refused[] = {
    {"int8", MPSDataTypeInt8}, {"int16", MPSDataTypeInt16}, {"int32", MPSDataTypeInt32},
    {"int64", MPSDataTypeInt64}, {"uint8", MPSDataTypeUInt8}, {"uint16", MPSDataTypeUInt16},
    {"uint32", MPSDataTypeUInt32}, {"uint64", MPSDataTypeUInt64}, {"bool", MPSDataTypeBool},
};

// The refusal of the pair above, asked the way a differential asks one: the graph is built and run inside
// the @try, because that is where the release raises, and what is printed is the name of the exception
// rather than the framework's own message about its kernel table, which is not a contract.
//
// Every data type that is not a floating point one is asked, because the set the release refuses is the
// question and one type is not the set: measured on this host's own MPSGraph, int8, int16, int32, int64,
// uint8, uint16, uint32, uint64 and bool each raise, and float16 and float32 each answer. The kernel the
// release reaches for is named in the exception and it names the type - isNaN_i8, isNaN_i16_i8, isNaN_i_i8,
// isNaN_i64_i8, isNaN_u8_i8, isNaN_u16_i8, isNaN_u_i8, isNaN_u64_i8, and for a boolean isNaN_i8 again -
// which is the whole of what it is refusing: there is no NaN kernel for an integer type, and a boolean is
// an integer type to it. The feeds are eight ascending and eight descending bytes, which every one of
// those types can hold, so nothing in the answer is the feed's own fault.
static void nan_propagation_refusal_case(const char *label, const char *typeName, MPSDataType type,
                                         const void *left, const void *right)
{
    for (int isMaximum = 0; isMaximum < 2; isMaximum++) {
        char name[96];
        snprintf(name, sizeof name, "%sWithNaNPropagation-%s", isMaximum ? "maximum" : "minimum", typeName);
        @try {
            MPSGraph *one = [MPSGraph new];
            MPSGraphTensor *a = [one placeholderWithShape:@[@2, @4] dataType:type name:@"a"];
            MPSGraphTensor *b = [one placeholderWithShape:@[@2, @4] dataType:type name:@"b"];
            MPSGraphTensor *t = isMaximum
                ? [one maximumWithNaNPropagationWithPrimaryTensor:a secondaryTensor:b name:@"M"]
                : [one minimumWithNaNPropagationWithPrimaryTensor:a secondaryTensor:b name:@"m"];
            size_t bytes = 8 * MPSSizeofMPSDataType(type);
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
            MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:@[@2, @4]
                                                                                  dataType:type];
            remember(buffer, integerResult, sizeof(integerResult));
            MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:@[@2, @4] dataType:type];
            MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:@{a: shaped, b: shaped}
                                                      targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:@[feed(left, @[@2, @4], type), feed(right, @[@2, @4], type)]
                                   resultsArray:@[destination] executionDescriptor:nil];
            printf("#case %s %s answered-rather-than-raised\n", name, label);
        } @catch (NSException *raised) {
            // One field for the answer and no spaces in it: run.sh reads a case line of five fields as a
            // case with a result buffer and this one has none, so the answer is printed as the third field
            // and the whole line is compared as it stands.
            printf("#case %s %s raised-%s\n", name, label, raised.name.UTF8String);
        }
    }
}

// The four reductions and the two binary extremes that arrived after 14.0, asked over the feeds of the
// reduction family above.
//
// The case name of an argument reduction carries the type its ANSWER is stored in and where that type
// came from, because the result is not the operand's type: measured, an argument reduction answers
// MPSDataTypeInt32 whatever the operand was, so "int32-from-float32" is four bytes an element in the
// result buffer and eight hex characters, which is what run.sh reads it at. A truth fold is the other
// way round - it answers the operand's own type, measured - so it is named for that type as the rest of
// this file is.
static void reduction_rest_families(void)
{
    NSArray<NSNumber *> *shape2x4 = @[@2, @4];
    // The two argument reductions, over the sixteen classes first: a row holding a NaN of each sign, both
    // infinities and both zeros, and over the ordinary row and the tied row beside it.
    reduction_case("argMaximum int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat32, leftValues, shape2x4);
    reduction_case("argMinimum int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat32, leftValues, shape2x4);
    reduction_case("argMaximum-rowFeed int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMinimum-rowFeed int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    // The tied row: every element of it is the answer twice, so this is the case that says whether the
    // release answers the first of the equal elements or the last.
    reduction_case("argMaximum-ties int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat32, tieFeed, shape2x4);
    reduction_case("argMinimum-ties int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat32, tieFeed, shape2x4);
    // A reduced set of nothing but NaNs, which is the one answer of the two that is not an index at all.
    reduction_case("argMaximum-allNaN int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat32, nanFeed, shape2x4);
    reduction_case("argMinimum-allNaN int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat32, nanFeed, shape2x4);
    // The other two data types, because an index is an index over an integer operand too: measured, an
    // argument reduction over an int32 and over a float16 answers the same int32 indices.
    reduction_case("argMaximum int32-from-int32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeInt32, intFeed, shape2x4);
    reduction_case("argMinimum int32-from-int32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeInt32, intFeed, shape2x4);
    reduction_case("argMaximum int32-from-float16", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat16, halfFeed, shape2x4);
    reduction_case("argMinimum int32-from-float16", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat16, halfFeed, shape2x4);
    // The two axis questions, which are the family's own and are measured over the ordinary row: an axis
    // of the other kind of the operand's, and a negative one counted from the end. Both answer a 1x4 of
    // four indices here, which is a different length from the 2x1 of two the axis-1 cases carry.
    reduction_case("argMaximum-axis0 int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:0 name:@"am"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMinimum-axis0 int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:0 name:@"an"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMaximum-axisNeg1 int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:-1 name:@"am"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMinimum-axisNeg1 int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:-1 name:@"an"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);

    // The two truth folds over the same feeds. An "and" of a row holding a zero answers 0 and an "or" of
    // it answers 1, and the sixteen classes hold a zero of each sign in the first row and none in the
    // second, so the two rows of the answer differ.
    unsigned i;
    struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *); } truth[] = {
        {"reductionAnd", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionAndWithTensor:a axis:1 name:@"a"]; }},
        {"reductionOr", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g reductionOrWithTensor:a axis:1 name:@"o"]; }},
    };
    char name[64];
    for (i = 0; i < sizeof(truth) / sizeof(truth[0]); i++) {
        snprintf(name, sizeof name, "%s float32", truth[i].name);
        reduction_case(name, truth[i].build, MPSDataTypeFloat32, leftValues, shape2x4);
        snprintf(name, sizeof name, "%s int32", truth[i].name);
        reduction_case(name, truth[i].build, MPSDataTypeInt32, intFeed, shape2x4);
        snprintf(name, sizeof name, "%s float16", truth[i].name);
        reduction_case(name, truth[i].build, MPSDataTypeFloat16, halfFeed, shape2x4);
    }
    // A reduced set of nothing but NaNs, where the two of them differ: a NaN is a nonzero like any other
    // value, so an "and" of one is true and an "or" of one is true too.
    reduction_case("reductionAnd-allNaN float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionAndWithTensor:a axis:1 name:@"a"]; }, MPSDataTypeFloat32, nanFeed, shape2x4);
    reduction_case("reductionOr-allNaN float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionOrWithTensor:a axis:1 name:@"o"]; }, MPSDataTypeFloat32, nanFeed, shape2x4);
    // The axes of the family over the two truth folds, which is what the second form of each of them
    // takes: nil reduces every axis and answers a 1x1, an empty array reduces none and answers the
    // operand byte for byte, and a descending set is still a set.
    reduction_case("reductionAnd-axesNil float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionAndWithTensor:a axes:nil name:@"an"]; }, MPSDataTypeFloat32, leftValues, shape2x4);
    reduction_case("reductionOr-axesNil float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionOrWithTensor:a axes:nil name:@"on"]; }, MPSDataTypeFloat32, leftValues, shape2x4);
    reduction_case("reductionAnd-axesEmpty float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionAndWithTensor:a axes:@[] name:@"ae"]; }, MPSDataTypeFloat32, leftValues, shape2x4);
    reduction_case("reductionOr-axesEmpty float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionOrWithTensor:a axes:@[] name:@"oe"]; }, MPSDataTypeFloat32, leftValues, shape2x4);
    reduction_case("reductionAnd-axesDescending float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionAndWithTensor:a axes:@[@1, @0] name:@"ad"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("reductionOr-axesDescending float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionOrWithTensor:a axes:@[@1, @0] name:@"od"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);

    // The two binary extremes that propagate a NaN, over the same feeds the arithmetic family is asked
    // over and in both types it is asked in. These are the two cases where the 14.0 pair and this pair
    // differ, and they differ only where an operand is a NaN: over the sixteen classes the four NaN
    // positions of the propagating pair answer a NaN each, where the 14.0 pair answers the other side.
    binary_case("minimumWithNaNPropagation float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) {
        return [g minimumWithNaNPropagationWithPrimaryTensor:a secondaryTensor:b name:@"m"]; },
               MPSDataTypeFloat32, leftValues, rightValues);
    binary_case("maximumWithNaNPropagation float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) {
        return [g maximumWithNaNPropagationWithPrimaryTensor:a secondaryTensor:b name:@"M"]; },
               MPSDataTypeFloat32, leftValues, rightValues);
    binary_case("minimumWithNaNPropagation float16", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) {
        return [g minimumWithNaNPropagationWithPrimaryTensor:a secondaryTensor:b name:@"m"]; },
               MPSDataTypeFloat16, halfValues, halfRightValues);
    binary_case("maximumWithNaNPropagation float16", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) {
        return [g maximumWithNaNPropagationWithPrimaryTensor:a secondaryTensor:b name:@"M"]; },
               MPSDataTypeFloat16, halfValues, halfRightValues);
    // And the one operand the release does not answer at all: measured, an int32 operand raises out of the
    // framework's own kernel table, which has no NaN kernel for an integer type to ask with. Asked
    // through @try on both sides and printed as the exception's name, which is a differential like any
    // other answer: the 14.0 pair over the same feed answers numbers, and this one does not.
    for (i = 0; i < sizeof(refused) / sizeof(refused[0]); i++)
        nan_propagation_refusal_case("over", refused[i].name, refused[i].type, refusedBytes, reversedBytes);
}

static void families(MPSDataType type, const void *left, const void *right, const char *label)
{
    unsigned i;
    char name[64];
    for (i = 0; i < sizeof(unary) / sizeof(unary[0]); i++) {
        snprintf(name, sizeof name, "%s %s", unary[i].name, label);
        unary_case(name, unary[i].build, type, left);
    }
    for (i = 0; i < sizeof(transcendental) / sizeof(transcendental[0]); i++) {
        snprintf(name, sizeof name, "%s %s", transcendental[i].name, label);
        unary_case(name, transcendental[i].build, type, left);
    }
    for (i = 0; i < sizeof(binary) / sizeof(binary[0]); i++) {
        snprintf(name, sizeof name, "%s %s", binary[i].name, label);
        binary_case(name, binary[i].build, type, left, right);
    }
    // The predicates carry their own data type in the case name, because their result is not the
    // operand's: "equal bool-from-float32" is a boolean over the float32 classes above.
    for (i = 0; i < sizeof(unaryPredicate) / sizeof(unaryPredicate[0]); i++) {
        snprintf(name, sizeof name, "%s bool-from-%s", unaryPredicate[i].name, label);
        predicate_case(name, unaryPredicate[i].build, type, left);
    }
    for (i = 0; i < sizeof(binaryPredicate) / sizeof(binaryPredicate[0]); i++) {
        snprintf(name, sizeof name, "%s bool-from-%s", binaryPredicate[i].name, label);
        binary_predicate_case(name, binaryPredicate[i].build, type, left, right);
    }
    // The select and the clamp read a third operand, and the bounds of a clamp are a third tensor of the
    // operand's own shape here: a clamp over the classes above with the bounds at -0.5 and 0.5 answers
    // something for every class, and a select over the left operand as the predicate answers the right
    // operand where the class is true and the third where it is false.
    snprintf(name, sizeof name, "select %s", label);
    ternary_case(name, ternary[0].build, type, left, right, right);
    snprintf(name, sizeof name, "clamp %s", label);
    ternary_case(name, ternary[1].build, type, left, bounds, bounds);
    // The two gradients read the incoming gradient and the value that was activated, in that order, so
    // the class vectors are given as both operands: a ReLU's branch is decided by the source and a
    // sigmoid's by the source's own value, and every class of the second vector decides one of them.
    for (i = 0; i < sizeof(gradient) / sizeof(gradient[0]); i++) {
        snprintf(name, sizeof name, "%s %s", gradient[i].name, label);
        binary_case(name, gradient[i].build, type, left, right);
    }
}

// The three cases that are not a family of operations, each asked last by the family that holds it.
//
// THE CHAIN is three operations in the order they were added - an addition, its product with itself and
// a square root of the result - so it is the walk over the operations in order that every family runs its
// last case through. It is asked last on purpose: a family whose last case on either side is not the chain
// is a family whose process did not reach the end, and run.sh fails it. "misc" is the one family that
// cannot end with it, because the case below is asked after it.
//
// THE CONSTANT is -[MPSGraph constantWithShape:dataType:values:name:], which aborts the host of this
// machine, so it is asked after everything the host does answer - in one family of its own end, not in the
// middle of the unary family, where it was taking seven cases down with it.
static void chain_case(void)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:@[@8, @4] dataType:MPSDataTypeFloat32 name:@"a"];
    MPSGraphTensor *b = [one placeholderWithShape:@[@8, @4] dataType:MPSDataTypeFloat32 name:@"b"];
    MPSGraphTensor *sum = [one additionWithPrimaryTensor:a secondaryTensor:b name:@"sum"];
    MPSGraphTensor *doubled = [one multiplicationWithPrimaryTensor:sum secondaryTensor:sum name:@"doubled"];
    MPSGraphTensor *root = [one squareRootWithTensor:doubled name:@"root"];
    memset(resultBytes, 0, sizeof(resultBytes));
    run(one, @[a, b], @[feed(&leftValues[0], @[@8, @4], MPSDataTypeFloat32), feed(&rightValues[0], @[@8, @4], MPSDataTypeFloat32)], root, resultBytes, 32 * MPSSizeofMPSDataType(MPSDataTypeFloat32), MPSDataTypeFloat32, MPSDataTypeFloat32);
    put("chain", resultBytes, 16 * MPSSizeofMPSDataType(MPSDataTypeFloat32));
}

static void constant_case(void)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:@[@8, @4] dataType:MPSDataTypeFloat32 name:@"a"];
    MPSGraphTensor *c = [one constantWithShape:@[@8, @4] dataType:MPSDataTypeFloat32
                                     values:[NSData dataWithBytes:&constantValues[0] length:sizeof(constantValues)] name:@"c"];
    MPSGraphTensor *t = [one additionWithPrimaryTensor:a secondaryTensor:c name:@"withConstant"];
    memset(resultBytes, 0, sizeof(resultBytes));
    run(one, @[a], @[feed(&leftValues[0], @[@8, @4], MPSDataTypeFloat32)], t, resultBytes, 32 * MPSSizeofMPSDataType(MPSDataTypeFloat32), MPSDataTypeFloat32, MPSDataTypeFloat32);
    put("constant", resultBytes, 16 * MPSSizeofMPSDataType(MPSDataTypeFloat32));
}

// An integer division, which is the only case in this file whose feed is not a class vector: four
// integers over four divisors, so the truncated quotients and the zero divisor are both in it.
static void integer_divide_case(void)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:@[@2, @2] dataType:MPSDataTypeInt32 name:@"a"];
    MPSGraphTensor *b = [one placeholderWithShape:@[@2, @2] dataType:MPSDataTypeInt32 name:@"b"];
    MPSGraphTensor *t = [one divisionWithPrimaryTensor:a secondaryTensor:b name:@"idiv"];
    memset(integerResult, 0, sizeof(integerResult));
    run(one, @[a, b], @[feed(&integerValues[0], @[@2, @2], MPSDataTypeInt32),
                        feed(&integerDivisors[0], @[@2, @2], MPSDataTypeInt32)], t, &integerResult[0], sizeof(integerResult), MPSDataTypeInt32, MPSDataTypeInt32);
    put("integer-divide", &integerResult[0], sizeof(integerResult));
}

// The builder side, as far as the release answers it on this host, and it is compared like every other
// answer here: two lines of no result buffer, each of them the whole of what the release answers.
// Reading a shaped type's equality and a placeholder's data type both make the framework call a selector
// its own MPSGraphTensor does not declare -[MPSGraphTensor tensorDataType] - and take the process down,
// so the device's type, the shape and the data type are what is compared, and the rest of the builder
// side is checked in a program of its own.
static void builder_side(void)
{
    printf("#case graph-device %d\n", (int)gGraphDevice.type);
    MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:@[@8, @4] dataType:MPSDataTypeFloat32];
    printf("#case shaped-dataType %d\n", (int)shaped.dataType);
}

// THE FAMILIES, each of which is a process of its own.
//
// One family per process because the release makes it necessary, and the measurement is in
// facts/MetalPerformanceShadersGraph/Core.md: in a process that holds three hundred graphs the release's
// own gather operations start asserting partway through the family - "Error: NDArray dimension length >
// INT_MAX" (MPSNDArray.mm:831) over a flatten of a 2x4 that answers in a program of its own - and every
// FED gather parameter takes the process down whatever else it holds. So this file is asked for one family
// at a time, run.sh runs and judges each of them separately, and the comparison of the recorded cells is
// scoped to the cases the family actually ran: a cell another family recorded is not in these two runs and
// is not a divergence that has gone away.
//
// Every family ends with the chain, so a family's two runs both reaching it is what says the process ran
// to the end of the family rather than dying at a case whose lines happened to be there.
static void family_misc(void)
{
    chain_case();
    constant_case();
}

static void family_arithmetic(void)
{
    // The unary family and the arithmetic family, over the sixteen classes above, in float32 and then in
    // float16. Both are asked for every operation of the family, because the two types do not answer alike
    // and a case in one of them says nothing about the other.
    families(MPSDataTypeFloat32, &leftValues[0], &rightValues[0], "float32");
    families(MPSDataTypeFloat16, &halfValues[0], &halfRightValues[0], "float16");
    integer_divide_case();
    chain_case();
}

// The reduction family of 14.0, which is the first thing in this file whose result is not the operand's
// shape, so it is asked of its own feeds and of the sixteen classes above.
static void family_reduction(void)
{
    reduction_families();
    chain_case();
}

// The rest of the reduction family: the two argument reductions and the two binary NaN-propagating
// extremes of 15.0, the two truth folds of 15.3 and the set of data types the propagating pair refuses.
static void family_reduction_rest(void)
{
    reduction_rest_families();
    chain_case();
}

// The cumulative family of 16.0, whose result is the operand's own shape, in float32 and float16 - and the
// seeds and the NaN rule are asked of the sixteen classes and a row of NaNs inside it.
static void family_cumulative(void)
{
    cumulative_families(MPSDataTypeFloat32, &leftValues[0], "float32");
    cumulative_families(MPSDataTypeFloat16, &halfValues[0], "float16");
    chain_case();
}

typedef struct { const char *name; void (*cases)(void); } Family;

// The table run.sh walks, and the one place a family is named: it prints the list on an unknown argument
// so a family that is renamed here is renamed there or nowhere.
// THE SPLIT, which is the one operation of this library whose result is SEVERAL TENSORS, and the coordinate
// along an axis, which is the one walk of it with no operand at all. Both need a case of their own shape:
// multi_case_filled reads ONE result buffer back, and a split has one buffer per output - so this helper
// prints the shapes and data types of every target on one line and then every target's bytes on a line of
// its own, each in a buffer the case owns and fills with the byte 0xbd first.
//
// The shapes are printed with the data type in hex beside them because a split's results all carry the
// OPERAND's type (measured, 0x10000020 float32 for every case below) while a coordinate's is its own and not
// the caller's at all (measured, MPSDataTypeInt32, 0x20000020, over every shape asked of it), and the two
// lines are compared as they stand.
static void multi_targets_shaped_case(const char *name,
                                      NSArray<MPSGraphTensor *> *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *),
                                      NSArray<NSArray<NSNumber *> *> *shapes, NSArray<NSData *> *values,
                                      NSArray<NSNumber *> *types, NSArray<NSArray<NSNumber *> *> *resultShapes,
                                      NSArray<NSNumber *> *resultTypes, unsigned char fill);

static void multi_targets_case(const char *name,
                               NSArray<MPSGraphTensor *> *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *),
                               NSArray<NSArray<NSNumber *> *> *shapes, NSArray<NSData *> *values,
                               NSArray<NSNumber *> *types, unsigned char fill)
{
    // Every case but one sizes its own destination out of the shape its target carries, which is what a
    // result the release could infer is for; the one that cannot - a result whose shape arrives with the run -
    // names the destination itself, through the helper below.
    multi_targets_shaped_case(name, build, shapes, values, types, nil, nil, fill);
}

// THE SAME HELPER over a destination the CASE names, which is the only way to compare a result the release
// could not infer the type of: measured, over three fed axes of the block-moving pair the release builds the
// graph with the result carrying NO shape and hands back an executable, and its run writes into the tensor
// data the caller gave it - so the shape and the data type of that buffer are the case's to say, and the
// shape the target carries is printed as nil on both sides and compared as the line it is.
static void multi_targets_shaped_case(const char *name,
                                      NSArray<MPSGraphTensor *> *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *),
                                      NSArray<NSArray<NSNumber *> *> *shapes, NSArray<NSData *> *values,
                                      NSArray<NSNumber *> *types, NSArray<NSArray<NSNumber *> *> *resultShapes,
                                      NSArray<NSNumber *> *resultTypes, unsigned char fill)
{
    MPSGraph *one = [MPSGraph new];
    NSMutableArray *operands = [NSMutableArray arrayWithCapacity:shapes.count];
    NSMutableDictionary *feeds = [NSMutableDictionary dictionary];
    NSMutableArray *inputs = [NSMutableArray arrayWithCapacity:shapes.count];
    for (NSUInteger i = 0; i < shapes.count; i++) {
        MPSDataType type = (MPSDataType)[types[i] unsignedIntValue];
        MPSGraphTensor *operand = [one placeholderWithShape:shapes[i] dataType:type name:@"i"];
        [operands addObject:operand];
        feeds[operand] = [[MPSGraphShapedType alloc] initWithShape:shapes[i] dataType:type];
        [inputs addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:
                           [gDevice newBufferWithBytes:values[i].bytes length:values[i].length
                                                options:MTLResourceStorageModeShared]
                                                     shape:shapes[i] dataType:type]];
    }
    NSArray<MPSGraphTensor *> *targets = build(one, operands);
    // The shapes of every target on ONE field, joined by a +: run.sh's comparison reads a case line of five
    // fields as a case with a result buffer in it - the marker, the operation, the data type, the length and
    // the bytes - and a line with two shapes as two fields would be read as one of those, with the length
    // field holding a shape. So the shapes go in one field and the line is compared as the whole line it is,
    // which is what a line without a result buffer is.
    printf("#case %s-shape ", name);
    for (NSUInteger i = 0; i < targets.count; i++)
        printf("%s%s/0x%x", i ? "+" : "",
               targets[i].shape ? [[targets[i].shape componentsJoinedByString:@"x"] UTF8String] : "nil",
               (unsigned)targets[i].dataType);
    printf("\n");
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:targets.count];
    NSMutableArray *buffers = [NSMutableArray arrayWithCapacity:targets.count];
    NSMutableArray *sizes = [NSMutableArray arrayWithCapacity:targets.count];
    for (NSUInteger i = 0; i < targets.count; i++) {
        MPSGraphTensor *t = targets[i];
        NSArray<NSNumber *> *shape = resultShapes ? resultShapes[i] : t.shape;
        MPSDataType dataType = resultTypes ? (MPSDataType)[resultTypes[i] unsignedIntValue] : t.dataType;
        NSUInteger count = 1;
        for (NSNumber *d in shape) count *= (NSUInteger)d.integerValue;
        size_t bytes = count * MPSSizeofMPSDataType(dataType);
        id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
        if (fill) memset([buffer contents], fill, bytes);
        [buffers addObject:buffer];
        [sizes addObject:@(bytes)];
        [results addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:shape dataType:dataType]];
    }
    MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:feeds
                                              targetTensors:targets targetOperations:@[]
                                     compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:inputs resultsArray:results executionDescriptor:nil];
    for (NSUInteger i = 0; i < buffers.count; i++) {
        pullResults();
        memcpy(resultBytes, [buffers[i] contents], (size_t)[sizes[i] unsignedIntegerValue]);
        put(name, resultBytes, (size_t)[sizes[i] unsignedIntegerValue]);
    }
}

// A coordinate has no operand, so its case hands the helper no operands at all: the shapes and values are
// empty and the build block makes the whole graph itself.
static void coordinate_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *))
{
    multi_targets_case(name, ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        (void)in;
        return @[build(g)];
    }, @[], @[], @[@(MPSDataTypeFloat32)], 0xbd);
}

// The four feeds the numSplits cases are asked over, each of an extent the count does NOT divide evenly,
// because that is where the release's rule is not dividing evenly either: 5 into 3 is 2 2 1, 7 into 4 is
// 2 2 2 1, and 8 into 3 is 3 3 2. Each element is its own index, so an answer says which of the operand's
// elements each region holds.
static float fiveWide[10] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
static float sevenWide[14] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 };
static float fiveValues[5] = { 1, 2, 3, 4, 5 };
static float eightValues[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };

static void family_gather_split(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    NSArray<NSNumber *> *three = @[@3];
    NSData *twoByFourFeed = [NSData dataWithBytes:rowFeed length:sizeof rowFeed];
    NSData *cubeData = [NSData dataWithBytes:cubeFeed length:sizeof cubeFeed];
    NSData *rankOneData = [NSData dataWithBytes:rankOneFeed length:sizeof rankOneFeed];

    // THE SIZES FORM, which cuts the operand's own regions in the order the caller wrote them. Every case
    // here is compared cell for cell, so the shapes line says how the regions were cut and the byte line
    // which operand's elements each one holds.
    multi_targets_case("split-sizes-axis0 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @1] axis:0 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-axis1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @3] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-axisNeg1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @3] axis:-1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-axisNeg2 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @1] axis:-2 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    // The regions follow the ORDER the sizes were written in, which is what makes them regions rather than
    // equal parts: @[@3, @1] is a 2x3 of the first three columns and then a 2x1 of the fourth.
    multi_targets_case("split-sizes-order float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@3, @1] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-equal float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@2, @2] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    // THREE regions, and the case that says a split is not a division: the sizes here are 1, 1 and 2.
    multi_targets_case("split-sizes-three float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @1, @2] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    // ONE region is the operand itself, which is what the one-operand concatenation of 14.0 answers too.
    multi_targets_case("split-sizes-one float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@4] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    // A RANK OF ONE, and a rank of three on each of its axes.
    multi_targets_case("split-sizes-rank1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @2] axis:0 name:@"sp"]; },
                      @[three], @[rankOneData], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-rank1Neg1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @2] axis:-1 name:@"sp"]; },
                      @[three], @[rankOneData], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-rank3-axis1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @2] axis:1 name:@"sp"]; },
                      @[twoByThreeByFour], @[cubeData], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-rank3-axis0 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @1] axis:0 name:@"sp"]; },
                      @[twoByThreeByFour], @[cubeData], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-rank3-axis2 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@2, @1, @1] axis:2 name:@"sp"]; },
                      @[twoByThreeByFour], @[cubeData], @[@(MPSDataTypeFloat32)], 0xbd);
    // The sizes as a CONSTANT, which is the only fed form the release answers at all: these answer exactly
    // what the written-down sizes above answer, over the same operand.
    multi_targets_case("split-fedconst-axis1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizesTensor:forwardShapeConstant(g, @[@1, @3]) axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-fedconst-order float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizesTensor:forwardShapeConstant(g, @[@3, @1]) axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-fedconst-three float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizesTensor:forwardShapeConstant(g, @[@1, @1, @2]) axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-fedconst-axis0 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizesTensor:forwardShapeConstant(g, @[@1, @1]) axis:0 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);

    // THE numSplits FORM, whose rule is measured and is not dividing evenly: over an extent E and a count N
    // the first N-1 sizes are ceil(E/N) and the last is what is left. These four are the cases where the two
    // rules differ - 4 into 3 is refused while 5 into 3 is 2 2 1, and 7 into 4 is 2 2 2 1 while 8 into 3 is
    // 3 3 2 - so a walk that divided evenly would fail every one of them.
    multi_targets_case("split-num2-axis1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] numSplits:2 axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-num2-axis0 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] numSplits:2 axis:0 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-num3-axis1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] numSplits:3 axis:1 name:@"sp"]; },
                      @[@[@2, @5]], @[[NSData dataWithBytes:fiveWide length:sizeof fiveWide]],
                      @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-num4-axis1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] numSplits:4 axis:1 name:@"sp"]; },
                      @[@[@2, @7]], @[[NSData dataWithBytes:sevenWide length:sizeof sevenWide]],
                      @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-num1-axis1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] numSplits:1 axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-num3-rank1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] numSplits:3 axis:0 name:@"sp"]; },
                      @[@[@5]], @[[NSData dataWithBytes:fiveValues length:sizeof fiveValues]],
                      @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-num3-rank8 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] numSplits:3 axis:0 name:@"sp"]; },
                      @[@[@8]], @[[NSData dataWithBytes:eightValues length:sizeof eightValues]],
                      @[@(MPSDataTypeFloat32)], 0xbd);

    // THE COORDINATE ALONG AN AXIS, whose value is the coordinate itself: the result's data type is int32
    // whatever the shape is, which is on the shapes line of every case here, and the bytes are the
    // coordinates in the result's own row-major order.
    coordinate_case("coord-axis0-2x3 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:0 withShape:@[@2, @3] name:@"c"]; });
    coordinate_case("coord-axis1-2x3 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:1 withShape:@[@2, @3] name:@"c"]; });
    coordinate_case("coord-axisNeg1-2x3 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:-1 withShape:@[@2, @3] name:@"c"]; });
    coordinate_case("coord-axisNeg2-2x3 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:-2 withShape:@[@2, @3] name:@"c"]; });
    coordinate_case("coord-axis0-5 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:0 withShape:@[@5] name:@"c"]; });
    coordinate_case("coord-axis0-1x1 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:0 withShape:@[@1, @1] name:@"c"]; });
    coordinate_case("coord-axis1-1x1x1 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:1 withShape:@[@1, @1, @1] name:@"c"]; });
    coordinate_case("coord-axis0-2x3x4 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:0 withShape:@[@2, @3, @4] name:@"c"]; });
    coordinate_case("coord-axis1-2x3x4 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:1 withShape:@[@2, @3, @4] name:@"c"]; });
    coordinate_case("coord-axis2-2x3x4 int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:2 withShape:@[@2, @3, @4] name:@"c"]; });
    // The shape as a CONSTANT, and the axis as a CONSTANT: the two fed forms the release answers, and they
    // answer exactly what the written-down forms answer.
    coordinate_case("coord-fedshape-const int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:1 withShapeTensor:forwardShapeConstant(g, @[@2, @4]) name:@"c"]; });
    coordinate_case("coord-fedaxis-const int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxisTensor:forwardShapeConstant(g, @[@1]) withShape:@[@2, @4] name:@"c"]; });
    coordinate_case("coord-fedaxis-const-neg int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxisTensor:forwardShapeConstant(g, @[@-1]) withShape:@[@2, @4] name:@"c"]; });
    chain_case();
}

// THE SPACE-TO-DEPTH FAMILY: the four operations of 15.0 and 16.1 that move a block of the spatial axes into
// the batch axis or out of it. They are asked here over the case file's own feeds, and the case list is
// ordered so that the pairs which must agree byte for byte are asked over the same operand: the 2D form and
// the general form of the same walk, the two orders of the flag, and the round trip that is the header's own
// "This operation is the inverse of" sentence.
static float blockFeed[72] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72,
};

static void family_gather_spacebatch(void)
{
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    NSData *cubeData = [NSData dataWithBytes:cubeFeed length:sizeof cubeFeed];
    // The operand every case here is asked over where it fits: a [3, 4, 6] of 1 to 72 with a 2x2 block,
    // whose result is a [12, 2, 3]. No two of its extents are the same, so an answer says which operand axis
    // each coordinate of the result came from.
    NSArray<NSNumber *> *threeByFourBySix = @[@3, @4, @6];
    NSData *wide = [NSData dataWithBytes:blockFeed length:sizeof blockFeed];
    // Thirty-two of the same values, for the two three-spatial-axis cases: a [2, 2, 4, 2] holds thirty-two
    // elements and the case file's own 2x3x4 cube holds twenty-four, which the release refuses with "buffer is
    // not large enough. Must be 128 bytes" - the harness's own mismatch, not an answer of anything.
    NSData *thirtyTwo = [NSData dataWithBytes:blockFeed length:32 * sizeof(float)];
    // The 2D form over the same operand: the width axis is the fastest running dimension WITHIN the block
    // and the height axis the second, so its (widthAxis, heightAxis) is the general form's
    // spatialAxes=@[@heightAxis, @widthAxis] - and the two cases below are the same walk asked twice.
    multi_targets_case("spaceToDepth2D-wide float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToDepth2DTensor:in[0] widthAxis:2 heightAxis:1 depthAxis:0 blockSize:2
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToDepth2D-wide-shuffle float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToDepth2DTensor:in[0] widthAxis:2 heightAxis:1 depthAxis:0 blockSize:2
                 usePixelShuffleOrder:YES name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-wide float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-wide-shuffle float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:YES name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    // The other direction, over the result those build, and the ROUND TRIP - which is the header's inverse
    // sentence measured: the second operation of the same flag must give the first one's operand back.
    NSArray<NSNumber *> *twelveByTwoByThree = @[@12, @2, @3];
    multi_targets_case("depthToSpace2D-wide float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g depthToSpace2DTensor:in[0] widthAxis:2 heightAxis:1 depthAxis:0 blockSize:2
                 usePixelShuffleOrder:NO name:@"d"] ]; },
                      @[twelveByTwoByThree], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("depthToSpace2D-wide-shuffle float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g depthToSpace2DTensor:in[0] widthAxis:2 heightAxis:1 depthAxis:0 blockSize:2
                 usePixelShuffleOrder:YES name:@"d"] ]; },
                      @[twelveByTwoByThree], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("batchToSpace-wide float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g batchToSpaceTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"b"] ]; },
                      @[twelveByTwoByThree], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("batchToSpace-wide-shuffle float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g batchToSpaceTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:YES name:@"b"] ]; },
                      @[twelveByTwoByThree], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-roundtrip float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        MPSGraphTensor *s = [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0
                             blockDimensions:@[@2, @2] usePixelShuffleOrder:NO name:@"s"];
        return @[ [g batchToSpaceTensor:s spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"b"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-roundtrip-shuffle float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        MPSGraphTensor *s = [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0
                             blockDimensions:@[@2, @2] usePixelShuffleOrder:YES name:@"s"];
        return @[ [g batchToSpaceTensor:s spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:YES name:@"b"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    // A block of ONE is the identity, over the case file's own 2x3x4.
    multi_targets_case("spaceToBatch-block1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@1, @1]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[twoByThreeByFour], @[cubeData], @[@(MPSDataTypeFloat32)], 0xbd);
    // ONE spatial axis, which is the general form without the 2D names, and a NEGATIVE batch axis counted
    // from the end (measured: -3 of a rank of three answers what 0 answers).
    multi_targets_case("spaceToBatch-one-axis float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@2] batchAxis:0 blockDimensions:@[@2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-negative-batch float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:-3 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    // The spatial list written the other way round over the case file's [2, 2, 4], whose answer is a
    // different one with the same shape - which is what says the block list is read in the order it is
    // written while the result's axes keep the operand's own order.
    NSArray<NSNumber *> *twoByTwoByFour = @[@2, @2, @4];
    // The [2, 2, 4] holds SIXTEEN values, so the feed is sixteen of them - the first version of this case
    // passed eight and the release took the process down on the mismatch, which is the harness's own bug and
    // not an answer of anything.
    NSData *small = [NSData dataWithBytes:blockFeed length:16 * sizeof(float)];
    multi_targets_case("spaceToBatch-order-reversed float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@2, @1] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[twoByTwoByFour], @[small], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-order-forward float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[twoByTwoByFour], @[small], @[@(MPSDataTypeFloat32)], 0xbd);
    // THREE spatial axes, which is the case that says the LAST of them is the fastest inside the block, over
    // the case file's [2, 2, 4, 2] of 32 values.
    multi_targets_case("spaceToBatch-three-axes float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@0, @1, @2] batchAxis:3 blockDimensions:@[@2, @2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[@[@2, @2, @4, @2]], @[thirtyTwo], @[@(MPSDataTypeFloat32)], 0xbd);
    // The other direction over three spatial axes, where the batch axis has to be an AXIS OF ITS OWN: the
    // first version of this case put the batch axis at 0 with the spatial axes @[@0, @1, @2] and the release
    // refused it with "`batch_axis` = 0 must be unique from `spatial_axes`" - which is the family's own
    // refusal and is measured in refusals.txt, so the case keeps its axis where the release accepts it.
    multi_targets_case("batchToSpace-three-axes float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g batchToSpaceTensor:in[0] spatialAxes:@[@1, @2, @3] batchAxis:0
                 blockDimensions:@[@2, @2, @2] usePixelShuffleOrder:NO name:@"b"] ]; },
                      @[@[@16, @1, @1, @2]], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    // The FED forms over CONSTANTS of the same values, which are the only fed forms the release answers - and
    // they answer exactly what the written-down forms answer over the same operand.
    multi_targets_case("spaceToBatch-fed-constants float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0]
                 spatialAxesTensor:forwardShapeConstant(g, @[@1, @2])
                   batchAxisTensor:forwardShapeConstant(g, @[@0])
             blockDimensionsTensor:forwardShapeConstant(g, @[@2, @2])
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    // The FED pair of 15.0, whose THREE axes arrive as tensors and whose block size is still written down -
    // measured over the same [3, 4, 6] and the same axes of 2, 1 and 0 with the same block of 2: an int32
    // constant of shape [1] answers exactly what the written-down forms above answer over the same operand,
    // byte for byte, in both directions and under both flags. A placeholder answers nothing at all and does
    // not take the process down (the graph builds with the result carrying no shape and the compile still
    // hands back an executable), which is measured in refusals.txt.
    multi_targets_case("spaceToDepth2D-fed-constants float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToDepth2DTensor:in[0]
                          widthAxisTensor:forwardShapeConstant(g, @[@2])
                         heightAxisTensor:forwardShapeConstant(g, @[@1])
                          depthAxisTensor:forwardShapeConstant(g, @[@0])
                                blockSize:2
                     usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToDepth2D-fed-constants-shuffle float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToDepth2DTensor:in[0]
                          widthAxisTensor:forwardShapeConstant(g, @[@2])
                         heightAxisTensor:forwardShapeConstant(g, @[@1])
                          depthAxisTensor:forwardShapeConstant(g, @[@0])
                                blockSize:2
                     usePixelShuffleOrder:YES name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("depthToSpace2D-fed-constants float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g depthToSpace2DTensor:in[0]
                          widthAxisTensor:forwardShapeConstant(g, @[@2])
                         heightAxisTensor:forwardShapeConstant(g, @[@1])
                          depthAxisTensor:forwardShapeConstant(g, @[@0])
                                blockSize:2
                     usePixelShuffleOrder:NO name:@"d"] ]; },
                      @[twelveByTwoByThree], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("depthToSpace2D-fed-constants-shuffle float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g depthToSpace2DTensor:in[0]
                          widthAxisTensor:forwardShapeConstant(g, @[@2])
                         heightAxisTensor:forwardShapeConstant(g, @[@1])
                          depthAxisTensor:forwardShapeConstant(g, @[@0])
                                blockSize:2
                     usePixelShuffleOrder:YES name:@"d"] ]; },
                      @[twelveByTwoByThree], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    // And the fed pair's own inverse claim: the same three constants into both directions is the identity,
    // which is what the header's "This operation is the inverse of" sentence says of the FED pair.
    multi_targets_case("spaceToDepth2D-fed-roundtrip float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        MPSGraphTensor *s = [g spaceToDepth2DTensor:in[0]
                                   widthAxisTensor:forwardShapeConstant(g, @[@2])
                                  heightAxisTensor:forwardShapeConstant(g, @[@1])
                                   depthAxisTensor:forwardShapeConstant(g, @[@0])
                                         blockSize:2
                              usePixelShuffleOrder:NO name:@"s"];
        return @[ [g depthToSpace2DTensor:s
                          widthAxisTensor:forwardShapeConstant(g, @[@2])
                         heightAxisTensor:forwardShapeConstant(g, @[@1])
                          depthAxisTensor:forwardShapeConstant(g, @[@0])
                                blockSize:2
                     usePixelShuffleOrder:NO name:@"d"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    // THE FED PAIR over three PLACEHOLDERS, which is the answer the release gives at RUN time and the one
    // the port could not give at all before: measured, the graph builds with the result carrying no shape, the
    // compile still hands back an executable, and the run writes into the destination the caller gave it
    // exactly what the written-down axes write into theirs - so each of these four cases is compared against
    // the release's own bytes over the same operand and the same destination, and the shape line above it
    // prints nil on both sides.
    int32_t width = 2, height = 1, depth = 0;
    NSData *axisWidth = [NSData dataWithBytes:&width length:sizeof width];
    NSData *axisHeight = [NSData dataWithBytes:&height length:sizeof height];
    NSData *axisDepth = [NSData dataWithBytes:&depth length:sizeof depth];
    NSArray<NSArray<NSNumber *> *> *fourInputs = @[threeByFourBySix, @[@1], @[@1], @[@1]];
    NSArray<NSData *> *fourValues = @[wide, axisWidth, axisHeight, axisDepth];
    NSArray<NSNumber *> *floatThenAxes = @[@(MPSDataTypeFloat32), @(MPSDataTypeInt32), @(MPSDataTypeInt32),
                                           @(MPSDataTypeInt32)];
    NSArray<NSArray<NSNumber *> *> *twelveByTwoByThreeShape = @[@[@12, @2, @3]];
    multi_targets_shaped_case("spaceToDepth2D-fed-placeholders float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToDepth2DTensor:in[0] widthAxisTensor:in[1] heightAxisTensor:in[2]
                            depthAxisTensor:in[3] blockSize:2 usePixelShuffleOrder:NO name:@"s"] ]; },
                              fourInputs, fourValues, floatThenAxes, twelveByTwoByThreeShape,
                              @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_shaped_case("spaceToDepth2D-fed-placeholders-shuffle float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToDepth2DTensor:in[0] widthAxisTensor:in[1] heightAxisTensor:in[2]
                            depthAxisTensor:in[3] blockSize:2 usePixelShuffleOrder:YES name:@"s"] ]; },
                              fourInputs, fourValues, floatThenAxes, twelveByTwoByThreeShape,
                              @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_shaped_case("depthToSpace2D-fed-placeholders float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g depthToSpace2DTensor:in[0] widthAxisTensor:in[1] heightAxisTensor:in[2]
                            depthAxisTensor:in[3] blockSize:2 usePixelShuffleOrder:NO name:@"n"] ]; },
                              @[twelveByTwoByThreeShape[0], @[@1], @[@1], @[@1]], fourValues, floatThenAxes,
                              @[threeByFourBySix], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_shaped_case("depthToSpace2D-fed-placeholders-shuffle float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g depthToSpace2DTensor:in[0] widthAxisTensor:in[1] heightAxisTensor:in[2]
                            depthAxisTensor:in[3] blockSize:2 usePixelShuffleOrder:YES name:@"n"] ]; },
                              @[twelveByTwoByThreeShape[0], @[@1], @[@1], @[@1]], fourValues, floatThenAxes,
                              @[threeByFourBySix], @[@(MPSDataTypeFloat32)], 0xbd);
    // THE 16.1 GENERAL FORM over its THREE FED LISTS, which is the same arrangement with the lists the
    // general form hands over: the result tensor carries no shape at the build, the compile hands back an
    // executable, and the run writes the written-down form's own answer into the destination the case names.
    // All three lists fed at once here; refusals.txt holds the six questions that feed them one at a time, in
    // both directions, because a case that fed only one of them would not say that the port reads the others.
    int32_t generalAxes[2] = { 1, 2 };
    int32_t generalBatch = 0;
    int32_t generalBlock[2] = { 2, 2 };
    NSData *axesList = [NSData dataWithBytes:generalAxes length:sizeof generalAxes];
    NSData *batchOne = [NSData dataWithBytes:&generalBatch length:sizeof generalBatch];
    NSData *blockList = [NSData dataWithBytes:generalBlock length:sizeof generalBlock];
    NSArray<NSArray<NSNumber *> *> *generalInputs =
        @[threeByFourBySix, @[@2], @[@1], @[@2]];
    NSArray<NSData *> *generalValues = @[wide, axesList, batchOne, blockList];
    multi_targets_shaped_case("spaceToBatch-fed-lists float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxesTensor:in[1] batchAxisTensor:in[2]
                            blockDimensionsTensor:in[3] usePixelShuffleOrder:NO name:@"s"] ]; },
                              generalInputs, generalValues, floatThenAxes, twelveByTwoByThreeShape,
                              @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_shaped_case("spaceToBatch-fed-lists-shuffle float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxesTensor:in[1] batchAxisTensor:in[2]
                            blockDimensionsTensor:in[3] usePixelShuffleOrder:YES name:@"s"] ]; },
                              generalInputs, generalValues, floatThenAxes, twelveByTwoByThreeShape,
                              @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_shaped_case("batchToSpace-fed-lists float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g batchToSpaceTensor:in[0] spatialAxesTensor:in[1] batchAxisTensor:in[2]
                            blockDimensionsTensor:in[3] usePixelShuffleOrder:NO name:@"b"] ]; },
                              @[twelveByTwoByThreeShape[0], @[@2], @[@1], @[@2]], generalValues, floatThenAxes,
                              @[threeByFourBySix], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_shaped_case("batchToSpace-fed-lists-shuffle float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g batchToSpaceTensor:in[0] spatialAxesTensor:in[1] batchAxisTensor:in[2]
                            blockDimensionsTensor:in[3] usePixelShuffleOrder:YES name:@"b"] ]; },
                              @[twelveByTwoByThreeShape[0], @[@2], @[@1], @[@2]], generalValues, floatThenAxes,
                              @[threeByFourBySix], @[@(MPSDataTypeFloat32)], 0xbd);
    // ONE AXIS FED AND THE OTHER TWO CONSTANTS, which is the mixed case the release also answers (measured:
    // a constant width with the height and the depth fed answers the same bytes as all three fed, in both
    // directions), and it is what says the port reads only the tensors the caller fed - the constants are
    // read when the graph is built, where the release reads them too.
    multi_targets_shaped_case("spaceToDepth2D-fed-depth-only float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToDepth2DTensor:in[0]
                            widthAxisTensor:forwardShapeConstant(g, @[@2])
                           heightAxisTensor:forwardShapeConstant(g, @[@1])
                            depthAxisTensor:in[1] blockSize:2 usePixelShuffleOrder:NO name:@"s"] ]; },
                              @[threeByFourBySix, @[@1]], @[wide, axisDepth],
                              @[@(MPSDataTypeFloat32), @(MPSDataTypeInt32)], twelveByTwoByThreeShape,
                              @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_shaped_case("depthToSpace2D-fed-width-only float32",
                              ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g depthToSpace2DTensor:in[0] widthAxisTensor:in[1]
                           heightAxisTensor:forwardShapeConstant(g, @[@1])
                            depthAxisTensor:forwardShapeConstant(g, @[@0]) blockSize:2
                            usePixelShuffleOrder:NO name:@"n"] ]; },
                              @[twelveByTwoByThreeShape[0], @[@1]], @[wide, axisWidth],
                              @[@(MPSDataTypeFloat32), @(MPSDataTypeInt32)], @[threeByFourBySix],
                              @[@(MPSDataTypeFloat32)], 0xbd);
    chain_case();
}

// THE NON-ZERO INDICES of 17.0, the one operation of this library whose result is a LIST: one row of the
// operand's own rank for each element of it that is not a zero, in row-major order, and the LENGTH of that
// list is the count of those elements, which nothing in the graph knows. So the destination is the CASE's and
// not the result tensor's, which is the arrangement multi_targets_shaped_case already exists for: the
// result's own shape and data type are printed on a line of their own (they are `-1` and the operand's rank,
// and MPSDataTypeInt32, measured on this host) and the run is given a destination the case names.
//
// The destination is filled with the byte 0xbd before every run, because this family WRITES the whole of it:
// every row the answer does not reach is a written zero, and an answer of exactly one row is written into
// every row - which is why several of the cases below put their one non-zero element away from the first
// coordinate: (0,0,0) is the same bytes as the zero an unreached row is given.
//
// AND WHY EACH CASE IS A PROCESS OF ITS OWN. Measured on this host's own MPSGraph, over the twenty-four
// cases of this family run in one process - which is what every other family here does - the answers of SEVEN
// of them carry rows that are not this operation's answer at all: `two-ends` answers its two own rows and
// then a (3, 0, 0) at row sixty-five, `rank1` of a [6] answers 0 and 5 and then 3, 2 and 5 in its last three
// rows, and `rank2` of a [4, 6] answers its two own rows and then fifteen more that are coordinates of no
// element of its operand. Three runs of the whole family print byte-identical answers, so it is not a race -
// and the same case asked as the ONLY non-zero graph in a process of its own answers exactly what it should
// (measured for every case below, and the harness re-runs it that way on every run). So the family asks each
// case through a fresh process, which is the arrangement run.sh already uses for the whole differential and
// the one this measurement makes necessary here.
static char *gProgram;

// The one case of this family, asked by name so that a process of its own can be told which one to run.
static void nonzero_case(const char *name, MPSDataType type, NSArray<NSNumber *> *shape, const void *values,
                         NSArray<NSNumber *> *destinationShape)
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *a = [one placeholderWithShape:shape dataType:type name:@"a"];
    MPSGraphTensor *t = [one nonZeroIndicesOfTensor:a name:@"nz"];
    printf("#case %s-shape %s/0x%x\n", name,
           t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil", (unsigned)t.dataType);
    NSUInteger rows = 1;
    for (NSNumber *dimension in destinationShape) rows *= (NSUInteger)dimension.integerValue;
    size_t result = rows * MPSSizeofMPSDataType(MPSDataTypeInt32);
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:result options:MTLResourceStorageModeShared];
    memset([buffer contents], 0xbd, result);
    remember(buffer, resultBytes, result);
    MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice
                                              feeds:@{a: [[MPSGraphShapedType alloc] initWithShape:shape
                                                                                  dataType:type]}
                                       targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:@[feed(values, shape, type)]
                           resultsArray:@[[[MPSGraphTensorData alloc] initWithMTLBuffer:buffer
                                                                                   shape:destinationShape
                                                                                dataType:MPSDataTypeInt32]]
                   executionDescriptor:nil];
    put(name, resultBytes, result);
}

// The [3, 4, 6] of 1 to 72 that most of the cases are asked over, and a zeroed copy of it: the count of the
// answer is then exactly the number of elements a case makes non-zero, and no case can be answered by an
// operand left as it was.
static float nonzeroCube[72] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72,
};
// The classes, one candidate at a time and each placed away from the first coordinate, because a coordinate
// of (0,0,0) cannot be told from a zero row. Measured on this host: a NaN and an infinity are non-zero
// elements; a NEGATIVE zero is not, and neither is a float32 DENORMAL - this library reads a float32
// denormal as a zero of the same sign, and a HALF denormal is kept and is a non-zero element.
static float nonzeroCubeClasses[72] = { 0 };
static uint16_t nonzeroHalfNan[72] = { 0 };
static uint16_t nonzeroHalfDenormal[72] = { 0 };
static int32_t nonzeroIntCube[72] = { 0 };

static void nonzero_empty(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzero_case("nonzero-empty int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

static void nonzero_one_first(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[0] = 1.0f;
    nonzero_case("nonzero-one-first int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

static void nonzero_one_middle(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[36] = 1.0f;
    nonzero_case("nonzero-one-middle int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

static void nonzero_one_last(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[71] = 1.0f;
    nonzero_case("nonzero-one-last int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

// The same single row into twelve rows and into two, which says the broadcast is over the destination's own
// rows rather than a fixed number of them.
static void nonzero_one_last_twelve(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[71] = 1.0f;
    nonzero_case("nonzero-one-last-12rows int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@12, @3]);
}

static void nonzero_one_last_two(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[71] = 1.0f;
    nonzero_case("nonzero-one-last-2rows int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@2, @3]);
}

// TWO non-zero elements at the two ends: a count of two is NOT broadcast, which is what makes the one-row
// case above a rule of its own and not the general one.
static void nonzero_two_ends(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[0] = 1.0f;
    nonzeroCube[71] = 1.0f;
    nonzero_case("nonzero-two-ends int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

// THREE of them named out of order and FIVE more: the answer is the operand's own row-major order and not the
// order the case happens to write them down in.
static void nonzero_three(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[26] = 1.0f;
    nonzeroCube[0] = 1.0f;
    nonzeroCube[13] = 1.0f;
    nonzero_case("nonzero-three int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

static void five_non_zero(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[41] = 1.0f;
    nonzeroCube[1] = 1.0f;
    nonzeroCube[23] = 1.0f;
    nonzeroCube[5] = 1.0f;
    nonzeroCube[2] = 1.0f;
}

static void nonzero_five(void)
{
    five_non_zero();
    nonzero_case("nonzero-five int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

static void nonzero_all(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = (float)(i + 1);
    nonzero_case("nonzero-all int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

// THE DESTINATION'S OWN ROWS, three ways over the same five non-zero elements: fewer rows than the answer
// has, which cuts the answer short; exactly as many; and many more, which is where the written zeros are.
static void nonzero_five_two_rows(void)
{
    five_non_zero();
    nonzero_case("nonzero-five-2rows int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@2, @3]);
}

static void nonzero_five_five_rows(void)
{
    five_non_zero();
    nonzero_case("nonzero-five-5rows int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@5, @3]);
}

static void nonzero_five_ten_rows(void)
{
    five_non_zero();
    nonzero_case("nonzero-five-10rows int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@10, @3]);
}

// A destination whose LAST EXTENT is not the operand's rank, and one of rank one: the rows are written
// `rank` cells apart in the destination's own last extent, so the cells beside them keep 0xbd.
static void nonzero_three_rank4(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[26] = 1.0f;
    nonzeroCube[0] = 1.0f;
    nonzeroCube[13] = 1.0f;
    nonzero_case("nonzero-three-rank4 int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@3, @4]);
}

static void nonzero_three_rank1(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[26] = 1.0f;
    nonzeroCube[0] = 1.0f;
    nonzeroCube[13] = 1.0f;
    nonzero_case("nonzero-three-rank1 int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@9]);
}

// THE CLASSES over one destination of ten rows, so that a count of two is visible as two rows and a count of
// one as one row written into all ten. The first case names all four candidates and the second names only the
// two that are non-zero elements, which is what says WHICH of the four they are.
static void nonzero_classes(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCubeClasses[i] = 0.0f;
    nonzeroCubeClasses[30] = NAN;
    nonzeroCubeClasses[31] = -0.0f;
    nonzeroCubeClasses[32] = INFINITY;
    nonzeroCubeClasses[33] = 0x1p-149f;
    nonzero_case("nonzero-classes int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCubeClasses,
                 @[@10, @3]);
}

static void nonzero_classes_two(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCubeClasses[i] = 0.0f;
    nonzeroCubeClasses[31] = NAN;
    nonzeroCubeClasses[32] = INFINITY;
    nonzero_case("nonzero-classes-nan-inf int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6],
                 nonzeroCubeClasses, @[@10, @3]);
}

// A float32 DENORMAL and nothing else, and then a float32 NEGATIVE zero and nothing else: each is the only
// candidate of its operand and neither is counted, which the ten rows of the destination say by being all
// zeros - an answer of one row would have put a coordinate in every one of them.
static void nonzero_float_denormal(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCubeClasses[i] = 0.0f;
    nonzeroCubeClasses[31] = 0x1p-149f;
    nonzero_case("nonzero-denormal-float32 int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6],
                 nonzeroCubeClasses, @[@10, @3]);
}

static void nonzero_float_negative_zero(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCubeClasses[i] = 0.0f;
    nonzeroCubeClasses[32] = -0.0f;
    nonzero_case("nonzero-negative-zero-float32 int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6],
                 nonzeroCubeClasses, @[@10, @3]);
}

// The half classes, each the only candidate of its own operand: a NaN and a DENORMAL are both non-zero
// elements, which is the opposite of the float32 denormal above and the whole of what the two types differ
// in here.
static void nonzero_half_nan(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroHalfNan[i] = 0;
    nonzeroHalfNan[30] = 0x7e00;
    nonzero_case("nonzero-half-nan int32-from-float16", MPSDataTypeFloat16, @[@3, @4, @6], nonzeroHalfNan,
                 @[@10, @3]);
}

static void nonzero_half_denormal(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroHalfDenormal[i] = 0;
    nonzeroHalfDenormal[31] = 0x0001;
    nonzero_case("nonzero-half-denormal int32-from-float16", MPSDataTypeFloat16, @[@3, @4, @6],
                 nonzeroHalfDenormal, @[@10, @3]);
}

// An int32 operand: the test is against a zero and not against the operand's own type, and the answer is
// int32 either way - which is on the shape line of this case.
static void nonzero_int32(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroIntCube[i] = 0;
    nonzeroIntCube[13] = 1;
    nonzeroIntCube[0] = 1;
    nonzeroIntCube[26] = 1;
    nonzero_case("nonzero-three int32-from-int32", MPSDataTypeInt32, @[@3, @4, @6], nonzeroIntCube,
                 @[@10, @3]);
}

// A RANK OF ONE and a rank of two: the result's own width is the operand's rank, so the answer of a [6] is a
// list of single numbers and of a [4, 6] a list of pairs.
static float nonzeroSix[6] = { 0 };
static float nonzeroTwentyFour[24] = { 0 };

static void nonzero_rank1(void)
{
    for (NSUInteger i = 0; i < 6; i++)
        nonzeroSix[i] = 0.0f;
    nonzeroSix[0] = 1.0f;
    nonzeroSix[5] = 1.0f;
    nonzero_case("nonzero-rank1 int32-from-float32", MPSDataTypeFloat32, @[@6], nonzeroSix, @[@6, @1]);
}

static void nonzero_rank2(void)
{
    for (NSUInteger i = 0; i < 24; i++)
        nonzeroTwentyFour[i] = 0.0f;
    nonzeroTwentyFour[0] = 1.0f;
    nonzeroTwentyFour[23] = 1.0f;
    nonzero_case("nonzero-rank2 int32-from-float32", MPSDataTypeFloat32, @[@4, @6], nonzeroTwentyFour,
                 @[@24, @2]);
}

typedef struct { const char *name; void (*ask)(void); } NonzeroCase;

static const NonzeroCase kNonzeroCases[] = {
    { "empty", nonzero_empty },
    { "one-first", nonzero_one_first },
    { "one-middle", nonzero_one_middle },
    { "one-last", nonzero_one_last },
    { "one-last-12rows", nonzero_one_last_twelve },
    { "one-last-2rows", nonzero_one_last_two },
    { "two-ends", nonzero_two_ends },
    { "three", nonzero_three },
    { "five", nonzero_five },
    { "all", nonzero_all },
    { "five-2rows", nonzero_five_two_rows },
    { "five-5rows", nonzero_five_five_rows },
    { "five-10rows", nonzero_five_ten_rows },
    { "three-rank4", nonzero_three_rank4 },
    { "three-rank1", nonzero_three_rank1 },
    { "classes", nonzero_classes },
    { "classes-two", nonzero_classes_two },
    { "float-denormal", nonzero_float_denormal },
    { "float-negative-zero", nonzero_float_negative_zero },
    { "half-nan", nonzero_half_nan },
    { "half-denormal", nonzero_half_denormal },
    { "int32", nonzero_int32 },
    { "rank1", nonzero_rank1 },
    { "rank2", nonzero_rank2 },
};

// THE FAMILY, which asks each of those through a process of its own and ends with the chain every family
// ends with. posix_spawn rather than fork, because a fork would hand the child a copy of this process's Metal
// device and of everything this process has already built, and the measurement above is about exactly that
// state; a spawned process starts from nothing. The child's own case lines go to the same standard output, in
// the order the table names them, and the parent waits for each before starting the next so that the order
// run.sh reads is the order the table is in.
static void family_gather_nonzero_one(const char *which);

static void family_gather_nonzero(void)
{
    unsigned i;
    for (i = 0; i < sizeof(kNonzeroCases) / sizeof(kNonzeroCases[0]); i++) {
        pid_t child = 0;
        char *arguments[4] = { gProgram, (char *)"gather_nonzero_one", (char *)kNonzeroCases[i].name, NULL };
        int made = posix_spawn(&child, gProgram, NULL, NULL, arguments, environ);
        if (made != 0 || child == 0) {
            fprintf(stderr, "graph-cases.m: could not start a process for the non-zero case %s: %s\n",
                    kNonzeroCases[i].name, strerror(made));
            continue;
        }
        int status = 0;
        waitpid(child, &status, 0);
        if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
            fprintf(stderr, "graph-cases.m: the non-zero case %s ended with status %d\n",
                    kNonzeroCases[i].name, status);
    }
    chain_case();
}

// THE ONE CASE, named on the command line: what a spawned process above runs. Nothing else is built in that
// process - not even the builder side - so the release's answer is the answer of this one graph.
static void family_gather_nonzero_one(const char *which)
{
    unsigned i;
    for (i = 0; i < sizeof(kNonzeroCases) / sizeof(kNonzeroCases[0]); i++) {
        if (strcmp(which, kNonzeroCases[i].name) != 0)
            continue;
        kNonzeroCases[i].ask();
        return;
    }
    fprintf(stderr, "graph-cases.m: unknown non-zero case '%s'\n", which);
    exit(3);
}

static const Family kFamilies[] = {
    { "misc", family_misc },
    { "arithmetic", family_arithmetic },
    { "reduction", family_reduction },
    { "reduction_rest", family_reduction_rest },
    { "cumulative", family_cumulative },
    { "gather_transpose", family_gather_transpose },
    { "gather_slice", family_gather_slice },
    { "gather_slice_rest", family_gather_slice_rest },
    { "gather_padtile", family_gather_padtile },
    { "run_forms", family_run_forms },
    { "gather_reshape", family_gather_reshape },
    { "gather_flatten", family_gather_flatten },
    { "gather_broadcast", family_gather_broadcast },
    { "gather_reverse", family_gather_reverse },
    { "gather_squeeze", family_gather_squeeze },
    { "gather_expand", family_gather_expand },
    { "gather_concat", family_gather_concat },
    { "gather_split", family_gather_split },
    { "gather_spacebatch", family_gather_spacebatch },
    { "gather_nonzero", family_gather_nonzero },
};

static void family_names(void)
{
    unsigned i;
    for (i = 0; i < sizeof(kFamilies) / sizeof(kFamilies[0]); i++)
        fprintf(stderr, "%s ", kFamilies[i].name);
    fprintf(stderr, "\n");
}

int main(int argc, const char *argv[])
{
    // Line buffering, and it is what makes the comparison trustworthy: the framework this file runs
    // against writes its own diagnostics to this same standard output, and with a block-buffered stream
    // one of them landed in the middle of a case line - a flush boundary split a line of sixteen halves
    // and "subtract float16" ended up carrying the tail of a warning and sixteen characters less. A line
    // buffered stream hands the whole line to one write, so a case is one line or nothing.
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        unsigned i;
        gProgram = argv[0];
        gDevice = MTLCreateSystemDefaultDevice();
        gGraphDevice = [MPSGraphDevice deviceWithMTLDevice:gDevice];
        // THE ONE NON-ZERO CASE, in a process of its own: nothing else is built in that process, which is the
        // whole of what the family needs - see the measurement above family_gather_nonzero.
        if (argc == 3 && strcmp(argv[1], "gather_nonzero_one") == 0) {
            family_gather_nonzero_one(argv[2]);
            return 0;
        }
        builder_side();
        if (argc < 2) {
            fprintf(stderr, "graph-cases.m: name the family to run; these are: ");
            family_names();
            return 2;
        }
        for (i = 0; i < sizeof(kFamilies) / sizeof(kFamilies[0]); i++) {
            if (strcmp(argv[1], kFamilies[i].name) != 0) continue;
            kFamilies[i].cases();
            return 0;
        }
        fprintf(stderr, "graph-cases.m: unknown family '%s'; these are: ", argv[1]);
        family_names();
        return 2;
    }
}
