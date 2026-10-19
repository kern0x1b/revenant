#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;
#include <stdlib.h>
#include <string.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>


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
- (MPSGraphTensor *)constantWithData:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)dataType;
- (MPSGraphTensor *)constantWithShape:(MPSShape *)shape
                            dataType:(MPSDataType)dataType
                              values:(NSData *)values
                                name:(NSString *)name;
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
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor startTensor:(MPSGraphTensor *)startTensor endTensor:(MPSGraphTensor *)endTensor strideTensor:(MPSGraphTensor *)strideTensor startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor startTensor:(MPSGraphTensor *)startTensor sizeTensor:(MPSGraphTensor *)sizeTensor squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor startTensor:(MPSGraphTensor *)startTensor endTensor:(MPSGraphTensor *)endTensor strideTensor:(MPSGraphTensor *)strideTensor startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor startTensor:(MPSGraphTensor *)startTensor sizeTensor:(MPSGraphTensor *)sizeTensor squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (void)setWaitUntilCompleted:(BOOL)waitUntilCompleted;
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
- (MPSGraphTensor *)padTensor:(MPSGraphTensor *)tensor withPaddingMode:(MPSGraphPaddingMode)paddingMode leftPadding:(NSArray<NSNumber *> *)leftPadding rightPadding:(NSArray<NSNumber *> *)rightPadding constantValue:(double)constantValue name:(NSString *)name;
- (MPSGraphTensor *)tileTensor:(MPSGraphTensor *)tensor withMultiplier:(NSArray<NSNumber *> *)multiplier name:(NSString *)name;
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
    return [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:shape dataType:type];
}

static float leftValues[32] = {
    1.0f, -1.0f, -0.0f, 0.0f, INFINITY, -INFINITY, NAN, -NAN,
    0x1p-149f, -0x1p-149f, 0x1.fffffep-127f, 0x1p-126f, 0x1p-20f, 0x1.fffffep-1f, -0x1p-20f, 1e-20f,
    0x1p-16f, -0x1p-16f, 0x1.8p-16f, -0x1.8p-16f, 0x1p-15f, -0x1p-15f, 0x1.8p-15f, -0x1.8p-15f,
    1.0f + 0x1p-16f, 1.0f + 0x1.8p-16f, 1.0f + 0x1p-15f, 1.0f + 0x1.8p-15f,
    -(1.0f + 0x1p-16f), -(1.0f + 0x1.8p-16f), -(1.0f + 0x1p-15f), -(1.0f + 0x1.8p-15f),
};
static float rightValues[32] = {
    0.0f, -0.0f, INFINITY, -INFINITY, NAN, -NAN, 0x1p-149f, 2.0f,
    4.0f, -4.0f, 0.5f, 8.0f, 16.0f, 3.0f, 1.0f, 1.0f,
    0x1p-16f, -0x1p-16f, 0x1.8p-16f, -0x1.8p-16f, 0x1p-15f, -0x1p-15f, 0x1.8p-15f, -0x1.8p-15f,
    2.0f + 0x1p-16f, -(2.0f + 0x1p-15f), 1.0f / 3.0f, 7.0f,
};
static unsigned char resultBytes[4096];
static float rowFeed[8] = { 1.0f, 2.0f, 3.0f, 4.0f, 10.0f, 20.0f, 30.0f, 40.0f };
static float meanFeed[2] = { 2.5f, 25.0f };
static float nanFeed[8] = { NAN, NAN, NAN, NAN, NAN, NAN, NAN, NAN };
static int32_t intFeed[8] = { -3, -2, -1, 0, 1, 2, 3, 4 };
static int32_t intMeanFeed[2] = { -1, 2 };
static uint16_t halfFeed[8] = { 0x3c00, 0x4000, 0x4200, 0x4400, 0x4500, 0x4600, 0x4700, 0x4800 };
static float constantValues[4] = {0.25f, -0.25f, 0.5f, 2};
static float bounds[32] = {
    -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
    -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
    -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
    -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
};
static int32_t integerValues[4] = {7, -3, 11, 0};
static int32_t integerDivisors[4] = {2, 2, 4, -4};
static int32_t integerResult[4];

static uint16_t halfValues[32] = {
    0x3c00, 0xbc00, 0x0000, 0x8000, 0x7c00, 0xfc00, 0x7e00, 0xfe00,
    0x0001, 0x8001, 0x03ff, 0x0400, 0x3800, 0x1400, 0x3c01, 0x3555,
    0x2800, 0xa800, 0x2c00, 0xac00, 0x3000, 0xb000, 0x3400, 0xb400,
    0x3c01, 0x3c02, 0x3c04, 0x3c08, 0xbc01, 0xbc02, 0xbc04, 0xbc08,
};
static uint16_t halfRightValues[32] = {
    0x0000, 0x8000, 0x7c00, 0xfc00, 0x7e00, 0xfe00, 0x0001, 0x4000,
    0xc000, 0x3800, 0x3555, 0x4400, 0x4800, 0x4200, 0x3c00, 0x3c00,
    0x2800, 0xa800, 0x2c00, 0xac00, 0x3000, 0xb000, 0x3400, 0xb400,
    0x4001, 0xc004, 0x3555, 0x4700,
};

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

static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *); } unaryPredicate[] = {
    {"isNaN", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g isNaNWithTensor:a name:@"nan"]; }},
    {"isFinite", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g isFiniteWithTensor:a name:@"fin"]; }},
    {"isInfinite", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) { return [g isInfiniteWithTensor:a name:@"inf"]; }},
};

static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *); } binaryPredicate[] = {
    {"equal", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g equalWithPrimaryTensor:a secondaryTensor:b name:@"eq"]; }},
    {"notEqual", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g notEqualWithPrimaryTensor:a secondaryTensor:b name:@"ne"]; }},
    {"lessThan", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g lessThanWithPrimaryTensor:a secondaryTensor:b name:@"lt"]; }},
    {"lessThanOrEqualTo", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g lessThanOrEqualToWithPrimaryTensor:a secondaryTensor:b name:@"le"]; }},
    {"greaterThan", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g greaterThanWithPrimaryTensor:a secondaryTensor:b name:@"gt"]; }},
    {"greaterThanOrEqualTo", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g greaterThanOrEqualToWithPrimaryTensor:a secondaryTensor:b name:@"ge"]; }},
};

static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *, MPSGraphTensor *); } ternary[] = {
    {"select", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b, MPSGraphTensor *c) { return [g selectWithPredicateTensor:a truePredicateTensor:b falsePredicateTensor:c name:@"sel"]; }},
    {"clamp", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b, MPSGraphTensor *c) { return [g clampWithTensor:a minValueTensor:b maxValueTensor:c name:@"clamp"]; }},
};

static struct { const char *name; MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *); } gradient[] = {
    {"reLUGradient", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g reLUGradientWithIncomingGradient:a sourceTensor:b name:@"drelu"]; }},
    {"sigmoidGradient", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g sigmoidGradientWithIncomingGradient:a sourceTensor:b name:@"dsig"]; }},
};

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
    for (i = 0; i < sizeof(reducing) / sizeof(reducing[0]); i++) {
        snprintf(name, sizeof name, "%s float32", reducing[i].name);
        reduction_case(name, reducing[i].build, MPSDataTypeFloat32, leftValues, shape2x4);
    }
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
    for (i = 0; i < sizeof(reducing) / sizeof(reducing[0]); i++) {
        snprintf(name, sizeof name, "%s int32", reducing[i].name);
        reduction_case(name, reducing[i].build, MPSDataTypeInt32, intFeed, shape2x4);
    }
    for (i = 0; i < sizeof(reducing) / sizeof(reducing[0]); i++) {
        snprintf(name, sizeof name, "%s float16", reducing[i].name);
        reduction_case(name, reducing[i].build, MPSDataTypeFloat16, halfFeed, shape2x4);
    }
    variance_with_mean_case("varianceOfMean float32", MPSDataTypeFloat32, rowFeed, shape2x4, @[@1],
                            meanFeed);
    variance_with_mean_case("varianceOfMean int32", MPSDataTypeInt32, intFeed, shape2x4, @[@1], intMeanFeed);
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

static float tieFeed[8] = { 4.0f, 4.0f, 4.0f, 9.0f, 9.0f, 9.0f, 1.0f, 1.0f };

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

static void cumulative_families(MPSDataType type, const void *values, const char *label)
{
    NSArray<NSNumber *> *shape2x4 = @[@2, @4];
    static float ordinary[8] = { 1.0f, 2.0f, 3.0f, 4.0f, 10.0f, 20.0f, 30.0f, 40.0f };
    static int32_t integers[8] = { -3, -2, -1, 0, 1, 2, 3, 4 };
    static uint16_t halves[8] = { 0x3c00, 0x4000, 0x4200, 0x4400, 0x4500, 0x4600, 0x4700, 0x4800 };
    static float classes[8] = { 1.0f, -1.0f, -0.0f, 0.0f, INFINITY, -INFINITY, NAN, -NAN };
    static float allNaN[8] = { NAN, NAN, NAN, NAN, NAN, NAN, NAN, NAN };
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

static void chain_case(void);
static void fed_shape_case(const char *name,
                           MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *),
                           NSArray<NSNumber *> *operandShape, NSArray<NSArray<NSNumber *> *> *fedShapes);
static void tile_gradient_cases(void);
static void tile_gradient_case(const char *name, NSArray<NSNumber *> *multiplier,
                               NSArray<NSNumber *> *shape, const void *gradient, const void *source,
                               size_t bytes, NSArray<NSNumber *> *types);

static float cubeFeed[24] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
};
static float gatherClasses[8] = { 1.0f, -1.0f, -0.0f, 0.0f, INFINITY, -INFINITY, NAN, -NAN };
static float thinFeed[4] = { 1.0f, 2.0f, 3.0f, 4.0f };
static float thinCubeFeed[12] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

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

static void family_gather_slice_rest(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];

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
    gather_case("slice-mask-end-negative-stride float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@0, @3] ends:@[@2, @0] strides:@[@1, @-1]
                              startMask:0 endMask:2 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
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
    gather_case("slice-mask-squeeze-rank3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@1, @0, @0] ends:@[@2, @3, @4] strides:@[@1, @2, @1]
                              startMask:0 endMask:0 squeezeMask:1 name:@"s"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("slice-mask-classes float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g sliceTensor:a starts:@[@1, @1] ends:@[@2, @0] strides:@[@1, @2]
                              startMask:2 endMask:2 squeezeMask:0 name:@"s"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);

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
        multi_case_filled("slice-gradient-mask-end float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShapeConstant(g, forwardShape)
                                                  starts:@[@0, @0] ends:@[@2, @0] strides:@[@1, @1]
                                                  startMask:0 endMask:2 squeezeMask:0 name:@"grad"]; },
                          @[@[@2, @4]], @[[NSData dataWithBytes:gradient length:sizeof gradient]], @[@(MPSDataTypeFloat32)],
                          0xbd);
        float bothRows[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
        multi_case_filled("slice-gradient-mask-start float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShapeConstant(g, forwardShape)
                                                  starts:@[@1, @0] ends:@[@2, @4] strides:@[@1, @1]
                                                  startMask:1 endMask:0 squeezeMask:0 name:@"grad"]; },
                          @[@[@2, @4]], @[[NSData dataWithBytes:bothRows length:sizeof bothRows]],
                          @[@(MPSDataTypeFloat32)], 0xbd);
    }

    {
        float data[8] = { 100, 200, 300, 400, 500, 600, 700, 800 };
        float two[2] = { -1, -2 };
        float four[4] = { -1, -2, -3, -4 };
        float eight[8] = { -1, -2, -3, -4, -5, -6, -7, -8 };
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
        multi_case_filled("slice-update-mask-start float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] starts:@[@1, @0]
                                                      ends:@[@2, @4] strides:@[@1, @1] startMask:1 endMask:0
                                                      squeezeMask:0 name:@"upd"]; },
                          @[@[@2, @4], @[@2, @4]],
                          @[[NSData dataWithBytes:data length:sizeof data],
                            [NSData dataWithBytes:eight length:sizeof eight]], twoFloats, 0);
        multi_case_filled("slice-update-negative-stride float32",
                          ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] starts:@[@0, @3]
                                                      ends:@[@2, @1] strides:@[@1, @-1] name:@"upd"]; },
                          @[@[@2, @4], @[@2, @2]],
                          @[[NSData dataWithBytes:data length:sizeof data],
                            [NSData dataWithBytes:four length:sizeof four]], twoFloats, 0);
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

    run_case("run-dictionary float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        [g runWithMTLCommandQueue:queue feeds:@{a: both[a]} targetOperations:nil
             resultsDictionary:@{t: both[t]}];
    });
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

    run_case("executable-async-waited float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSGraphExecutable *e = [g compileWithDevice:gGraphDevice feeds:@{a: [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32]}
                                         targetTensors:@[t] targetOperations:nil compilationDescriptor:nil];
        MPSGraphExecutableExecutionDescriptor *descriptor = [MPSGraphExecutableExecutionDescriptor new];
        descriptor.waitUntilCompleted = YES;
        [e runAsyncWithMTLCommandQueue:queue inputsArray:@[both[a]] resultsArray:@[both[t]]
                  executionDescriptor:descriptor];
    });
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
    run_case("executable-encode float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
        MPSGraphExecutable *e = [g compileWithDevice:gGraphDevice feeds:@{a: [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32]}
                                         targetTensors:@[t] targetOperations:nil compilationDescriptor:nil];
        MPSCommandBuffer *buffer = [MPSCommandBuffer commandBufferFromCommandQueue:queue];
        [e encodeToCommandBuffer:buffer inputsArray:@[both[a]] resultsArray:@[both[t]]
                executionDescriptor:nil];
        [buffer commit];
        [buffer waitUntilCompleted];
    });

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

    {
        id<MTLSharedEvent> event = [gDevice newSharedEvent];
        MPSGraphExecutableExecutionDescriptor *descriptor = [MPSGraphExecutableExecutionDescriptor new];
        [descriptor signalEvent:event atExecutionEvent:MPSGraphExecutionStageCompleted value:42];
        printf("#case event-before-run %llu\n", (unsigned long long)event.signaledValue);
        run_case("event-signalled float32", ^(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *t, NSDictionary *both) {
            MPSGraphExecutable *e = [g compileWithDevice:gGraphDevice feeds:@{a: [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32]}
                                             targetTensors:@[t] targetOperations:nil compilationDescriptor:nil];
            [e runWithMTLCommandQueue:queue inputsArray:@[both[a]] resultsArray:@[both[t]]
                  executionDescriptor:descriptor];
        });
        printf("#case event-after-run %llu\n", (unsigned long long)event.signaledValue);
    }
    chain_case();
}

static void family_gather_padtile(void)
{
    NSArray<NSNumber *> *twoByFour = @[@2, @4];
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    NSArray<NSNumber *> *oneByFour = @[@1, @4];
    NSArray<NSNumber *> *oneByThreeByFour = @[@1, @3, @4];

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
    gather_case("pad-reflect-three float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g padTensor:a withPaddingMode:MPSGraphPaddingModeReflect leftPadding:@[@1, @3]
                          rightPadding:@[@1, @2] constantValue:99.0 name:@"p"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
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
    gather_case("tile-rank3 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g tileTensor:a withMultiplier:@[@2, @2, @2] name:@"t"]; },
                MPSDataTypeFloat32, twoByThreeByFour, cubeFeed);
    gather_case("tile-one float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g tileTensor:a withMultiplier:@[@1, @1] name:@"t"]; },
                MPSDataTypeFloat32, twoByFour, gatherClasses);

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

static void tile_gradient_cases(void)
{
    float feed16[16], ones16[16], feed4[4], ones4[4];
    for (int i = 0; i < 16; i++) { feed16[i] = (float)(i + 1); ones16[i] = 1.0f; }
    for (int i = 0; i < 4; i++) { feed4[i] = (float)(i + 1); ones4[i] = 1.0f; }
    NSArray<NSNumber *> *fourByFour = @[@4, @4];
    NSArray<NSNumber *> *four = @[@4];
    NSArray<NSNumber *> *floatTypes = @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32)];
    tile_gradient_case("tile-gradient-identity float32", @[@1, @1], fourByFour, feed16, ones16, 64, floatTypes);
    tile_gradient_case("tile-gradient-rank1 float32", @[@1], four, feed4, ones4, 16, floatTypes);
    tile_gradient_case("tile-gradient-zero float32", @[@1, @0], fourByFour, feed16, ones16, 64, floatTypes);
    tile_gradient_case("tile-gradient-zero-leading float32", @[@0, @1], fourByFour, feed16, ones16, 64, floatTypes);
}

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
    gather_case("broadcast-2x3x4-4x3x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@4, @3, @4] name:@"b"]; },
                MPSDataTypeFloat32, @[@2, @3, @4], cubeFeed);
    gather_case("broadcast-1x2x4-2x2x4 float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@2, @2, @4] name:@"b"]; },
                MPSDataTypeFloat32, @[@1, @2, @4], cubeFeed);
    gather_case_filled("broadcast-4x4-prefilled float32",
                       ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                           return [g broadcastTensor:a toShape:@[@4, @4] name:@"b"]; },
                       MPSDataTypeFloat32, twoByFour, rowFeed, 0xbd);
    gather_case("broadcast-narrower float32",
                ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                    return [g broadcastTensor:a toShape:@[@1, @4] name:@"b"]; },
                MPSDataTypeFloat32, twoByFour, rowFeed);
    fed_shape_case("fed-broadcast-shape-rank2",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g broadcastTensor:in[0] toShapeTensor:in[1] name:@"b"]; },
                   @[@2, @4], @[@[@2]]);

    chain_case();
}

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
    fed_shape_case("fed-reverse-shape-rank3",
                   ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                       return [g reverseTensor:in[0] axesTensor:in[1] name:@"r"]; },
                   @[@1, @2, @4], @[@[@1]]);

    chain_case();
}

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

static float secondFeed[8] = { 5.0f, 6.0f, 7.0f, 8.0f, 50.0f, 60.0f, 70.0f, 80.0f };
static float thirdFeed[8] = { 9.0f, 10.0f, 11.0f, 12.0f, 90.0f, 100.0f, 110.0f, 120.0f };
static float secondCubeFeed[24] = {
    101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112,
    113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124,
};
static float thinRow2[4] = { 101.0f, 102.0f, 103.0f, 104.0f };
static float rankOneFeed[3] = { 71.0f, 72.0f, 73.0f };
static float rankOneSecond[3] = { 81.0f, 82.0f, 83.0f };

static void concat_filled(const char *name, NSArray<NSArray<NSNumber *> *> *shapes, NSArray<NSData *> *values,
                          MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *))
{
    multi_case_filled(name, build, shapes, values,
                      @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32), @(MPSDataTypeFloat32)], 0xbd);
}

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

    concat_filled("concat-axis0 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
    concat_filled("concat-axis1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 name:@"c"];
                  });
    concat_filled("concat-axisNeg1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:-1 name:@"c"];
                  });
    concat_filled("concat-axisNeg2 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:-2 name:@"c"];
                  });
    concat_filled("concat-two-axis0 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensor:in[0] withTensor:in[1] dimension:0 name:@"c"];
                  });
    concat_filled("concat-two-axis1 float32", @[twoByFour, twoByFour], pair,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensor:in[0] withTensor:in[1] dimension:1 name:@"c"];
                  });
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
    concat_filled("concat-one-axis0 float32", @[twoByFour], @[pair[0]],
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:0 name:@"c"];
                  });
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
    concat_filled("concat3-interleave-no-axis1 float32", @[twoByFour, twoByFour, twoByFour], triple,
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g concatTensors:in dimension:1 interleave:NO name:@"c"];
                  });
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
    concat_filled("stack-rank1-axis0 float32", @[three, three], pairOf(rankOneFeed, rankOneSecond, 12),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:0 name:@"s"];
                  });
    concat_filled("stack-rank1-axisNeg1 float32", @[three, three],
                  pairOf(rankOneFeed, rankOneSecond, 12),
                  ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g stackTensors:in axis:-1 name:@"s"];
                  });
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
    empty_case("concat-empty", ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g concatTensors:@[] dimension:0 name:@"c"];
    });
    empty_case("stack-empty", ^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g stackTensors:@[] axis:0 name:@"s"];
    });
    chain_case();
}

static void empty_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *))
{
    MPSGraph *one = [MPSGraph new];
    MPSGraphTensor *t = build(one, @[]);
    printf("#case %s-shape %s\n", name,
           t.shape == nil ? "nil" : [[t.shape componentsJoinedByString:@"x"] UTF8String]);
    printf("#case %s-datatype 0x%x\n", name, (unsigned)t.dataType);
}

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

static unsigned char refusedBytes[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
static unsigned char reversedBytes[8] = { 8, 7, 6, 5, 4, 3, 2, 1 };
static struct { const char *name; MPSDataType type; } refused[] = {
    {"int8", MPSDataTypeInt8}, {"int16", MPSDataTypeInt16}, {"int32", MPSDataTypeInt32},
    {"int64", MPSDataTypeInt64}, {"uint8", MPSDataTypeUInt8}, {"uint16", MPSDataTypeUInt16},
    {"uint32", MPSDataTypeUInt32}, {"uint64", MPSDataTypeUInt64}, {"bool", MPSDataTypeBool},
};

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
            printf("#case %s %s raised-%s\n", name, label, raised.name.UTF8String);
        }
    }
}

static void reduction_rest_families(void)
{
    NSArray<NSNumber *> *shape2x4 = @[@2, @4];
    reduction_case("argMaximum int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat32, leftValues, shape2x4);
    reduction_case("argMinimum int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat32, leftValues, shape2x4);
    reduction_case("argMaximum-rowFeed int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMinimum-rowFeed int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMaximum-ties int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat32, tieFeed, shape2x4);
    reduction_case("argMinimum-ties int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat32, tieFeed, shape2x4);
    reduction_case("argMaximum-allNaN int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat32, nanFeed, shape2x4);
    reduction_case("argMinimum-allNaN int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat32, nanFeed, shape2x4);
    reduction_case("argMaximum int32-from-int32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeInt32, intFeed, shape2x4);
    reduction_case("argMinimum int32-from-int32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeInt32, intFeed, shape2x4);
    reduction_case("argMaximum int32-from-float16", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:1 name:@"am"]; }, MPSDataTypeFloat16, halfFeed, shape2x4);
    reduction_case("argMinimum int32-from-float16", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:1 name:@"an"]; }, MPSDataTypeFloat16, halfFeed, shape2x4);
    reduction_case("argMaximum-axis0 int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:0 name:@"am"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMinimum-axis0 int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:0 name:@"an"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMaximum-axisNeg1 int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMaximumWithTensor:a axis:-1 name:@"am"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);
    reduction_case("argMinimum-axisNeg1 int32-from-float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionArgMinimumWithTensor:a axis:-1 name:@"an"]; }, MPSDataTypeFloat32, rowFeed, shape2x4);

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
    reduction_case("reductionAnd-allNaN float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionAndWithTensor:a axis:1 name:@"a"]; }, MPSDataTypeFloat32, nanFeed, shape2x4);
    reduction_case("reductionOr-allNaN float32", ^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
        return [g reductionOrWithTensor:a axis:1 name:@"o"]; }, MPSDataTypeFloat32, nanFeed, shape2x4);
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
    for (i = 0; i < sizeof(unaryPredicate) / sizeof(unaryPredicate[0]); i++) {
        snprintf(name, sizeof name, "%s bool-from-%s", unaryPredicate[i].name, label);
        predicate_case(name, unaryPredicate[i].build, type, left);
    }
    for (i = 0; i < sizeof(binaryPredicate) / sizeof(binaryPredicate[0]); i++) {
        snprintf(name, sizeof name, "%s bool-from-%s", binaryPredicate[i].name, label);
        binary_predicate_case(name, binaryPredicate[i].build, type, left, right);
    }
    snprintf(name, sizeof name, "select %s", label);
    ternary_case(name, ternary[0].build, type, left, right, right);
    snprintf(name, sizeof name, "clamp %s", label);
    ternary_case(name, ternary[1].build, type, left, bounds, bounds);
    for (i = 0; i < sizeof(gradient) / sizeof(gradient[0]); i++) {
        snprintf(name, sizeof name, "%s %s", gradient[i].name, label);
        binary_case(name, gradient[i].build, type, left, right);
    }
}

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

static void builder_side(void)
{
    printf("#case graph-device %d\n", (int)gGraphDevice.type);
    MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:@[@8, @4] dataType:MPSDataTypeFloat32];
    printf("#case shaped-dataType %d\n", (int)shaped.dataType);
}

static void family_misc(void)
{
    chain_case();
    constant_case();
}

static void family_arithmetic(void)
{
    families(MPSDataTypeFloat32, &leftValues[0], &rightValues[0], "float32");
    families(MPSDataTypeFloat16, &halfValues[0], &halfRightValues[0], "float16");
    integer_divide_case();
    chain_case();
}

static void family_reduction(void)
{
    reduction_families();
    chain_case();
}

static void family_reduction_rest(void)
{
    reduction_rest_families();
    chain_case();
}

static void family_cumulative(void)
{
    cumulative_families(MPSDataTypeFloat32, &leftValues[0], "float32");
    cumulative_families(MPSDataTypeFloat16, &halfValues[0], "float16");
    chain_case();
}

typedef struct { const char *name; void (*cases)(void); } Family;

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
    multi_targets_shaped_case(name, build, shapes, values, types, nil, nil, fill);
}

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

static void coordinate_case(const char *name, MPSGraphTensor *(^build)(MPSGraph *))
{
    multi_targets_case(name, ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        (void)in;
        return @[build(g)];
    }, @[], @[], @[@(MPSDataTypeFloat32)], 0xbd);
}

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
    multi_targets_case("split-sizes-order float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@3, @1] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-equal float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@2, @2] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-three float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@1, @1, @2] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("split-sizes-one float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return [g splitTensor:in[0] splitSizes:@[@4] axis:1 name:@"sp"]; },
                      @[twoByFour], @[twoByFourFeed], @[@(MPSDataTypeFloat32)], 0xbd);
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
    coordinate_case("coord-fedshape-const int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxis:1 withShapeTensor:forwardShapeConstant(g, @[@2, @4]) name:@"c"]; });
    coordinate_case("coord-fedaxis-const int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxisTensor:forwardShapeConstant(g, @[@1]) withShape:@[@2, @4] name:@"c"]; });
    coordinate_case("coord-fedaxis-const-neg int32", ^MPSGraphTensor *(MPSGraph *g) {
        return [g coordinateAlongAxisTensor:forwardShapeConstant(g, @[@-1]) withShape:@[@2, @4] name:@"c"]; });
    chain_case();
}

static float blockFeed[72] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72,
};

static void family_gather_spacebatch(void)
{
    NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
    NSData *cubeData = [NSData dataWithBytes:cubeFeed length:sizeof cubeFeed];
    NSArray<NSNumber *> *threeByFourBySix = @[@3, @4, @6];
    NSData *wide = [NSData dataWithBytes:blockFeed length:sizeof blockFeed];
    NSData *thirtyTwo = [NSData dataWithBytes:blockFeed length:32 * sizeof(float)];
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
    multi_targets_case("spaceToBatch-block1 float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@1, @1]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[twoByThreeByFour], @[cubeData], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-one-axis float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@2] batchAxis:0 blockDimensions:@[@2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-negative-batch float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:-3 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    NSArray<NSNumber *> *twoByTwoByFour = @[@2, @2, @4];
    NSData *small = [NSData dataWithBytes:blockFeed length:16 * sizeof(float)];
    multi_targets_case("spaceToBatch-order-reversed float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@2, @1] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[twoByTwoByFour], @[small], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-order-forward float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@1, @2] batchAxis:0 blockDimensions:@[@2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[twoByTwoByFour], @[small], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-three-axes float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0] spatialAxes:@[@0, @1, @2] batchAxis:3 blockDimensions:@[@2, @2, @2]
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[@[@2, @2, @4, @2]], @[thirtyTwo], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("batchToSpace-three-axes float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g batchToSpaceTensor:in[0] spatialAxes:@[@1, @2, @3] batchAxis:0
                 blockDimensions:@[@2, @2, @2] usePixelShuffleOrder:NO name:@"b"] ]; },
                      @[@[@16, @1, @1, @2]], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
    multi_targets_case("spaceToBatch-fed-constants float32", ^NSArray<MPSGraphTensor *> *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
        return @[ [g spaceToBatchTensor:in[0]
                 spatialAxesTensor:forwardShapeConstant(g, @[@1, @2])
                   batchAxisTensor:forwardShapeConstant(g, @[@0])
             blockDimensionsTensor:forwardShapeConstant(g, @[@2, @2])
                 usePixelShuffleOrder:NO name:@"s"] ]; },
                      @[threeByFourBySix], @[wide], @[@(MPSDataTypeFloat32)], 0xbd);
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

static char *gProgram;

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

static float nonzeroCube[72] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72,
};
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

static void nonzero_two_ends(void)
{
    for (NSUInteger i = 0; i < 72; i++)
        nonzeroCube[i] = 0.0f;
    nonzeroCube[0] = 1.0f;
    nonzeroCube[71] = 1.0f;
    nonzero_case("nonzero-two-ends int32-from-float32", MPSDataTypeFloat32, @[@3, @4, @6], nonzeroCube,
                 @[@72, @3]);
}

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
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        unsigned i;
        gProgram = argv[0];
        gDevice = MTLCreateSystemDefaultDevice();
        gGraphDevice = [MPSGraphDevice deviceWithMTLDevice:gDevice];
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
