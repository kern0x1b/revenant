// refusals.m - the gather family's questions that graph-cases.m cannot ask, one per process, run against the
// system's own MPSGraph only.
//
// Each question is asked in a process of its own because several of them take the release down, and what is
// being measured is exactly that: there is no answer of the release for a case to compare against, so the
// port's answer is its header's and the question belongs in the row of the method rather than among the
// cases. run.sh asks each of them, records the exit status and what was written to the error stream, and
// compares both against refusals.txt - so the measurement behind those rows is one a later reader re-runs
// rather than a line in a commit message, and a release that starts answering one of them fails this.
//
//   refusals.m <question>
//
// facts/MetalPerformanceShadersGraph/Core.md carries what each of them answers and which row it is in.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>

@interface MPSGraph (MPSGraph26)
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor dimension:(NSUInteger)dimensionIndex start:(NSInteger)start length:(NSInteger)length name:(NSString *)name;
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor starts:(NSArray<NSNumber *> *)starts ends:(NSArray<NSNumber *> *)ends strides:(NSArray<NSNumber *> *)strides name:(NSString *)name;
- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor withShape:(NSArray<NSNumber *> *)withShape name:(NSString *)name;
- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor withShapeTensor:(MPSGraphTensor *)withShapeTensor name:(NSString *)name;
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
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor starts:(NSArray<NSNumber *> *)starts ends:(NSArray<NSNumber *> *)ends strides:(NSArray<NSNumber *> *)strides startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor startTensor:(MPSGraphTensor *)startTensor endTensor:(MPSGraphTensor *)endTensor strideTensor:(MPSGraphTensor *)strideTensor startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor startTensor:(MPSGraphTensor *)startTensor sizeTensor:(MPSGraphTensor *)sizeTensor squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor starts:(NSArray<NSNumber *> *)starts ends:(NSArray<NSNumber *> *)ends strides:(NSArray<NSNumber *> *)strides name:(NSString *)name;
- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor starts:(NSArray<NSNumber *> *)starts ends:(NSArray<NSNumber *> *)ends strides:(NSArray<NSNumber *> *)strides startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor startTensor:(MPSGraphTensor *)startTensor endTensor:(MPSGraphTensor *)endTensor strideTensor:(MPSGraphTensor *)strideTensor startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)sliceUpdateDataTensor:(MPSGraphTensor *)dataTensor updateTensor:(MPSGraphTensor *)updateTensor starts:(NSArray<NSNumber *> *)starts ends:(NSArray<NSNumber *> *)ends strides:(NSArray<NSNumber *> *)strides startMask:(uint32_t)startMask endMask:(uint32_t)endMask squeezeMask:(uint32_t)squeezeMask name:(NSString *)name;
- (MPSGraphTensor *)constantWithData:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)dataType;
- (MPSGraphTensor *)spaceToDepth2DTensor:(MPSGraphTensor *)tensor widthAxis:(NSUInteger)widthAxis heightAxis:(NSUInteger)heightAxis depthAxis:(NSUInteger)depthAxis blockSize:(NSUInteger)blockSize usePixelShuffleOrder:(BOOL)usePixelShuffleOrder name:(NSString *)name;
- (MPSGraphTensor *)depthToSpace2DTensor:(MPSGraphTensor *)tensor widthAxis:(NSUInteger)widthAxis heightAxis:(NSUInteger)heightAxis depthAxis:(NSUInteger)depthAxis blockSize:(NSUInteger)blockSize usePixelShuffleOrder:(BOOL)usePixelShuffleOrder name:(NSString *)name;
- (MPSGraphTensor *)spaceToDepth2DTensor:(MPSGraphTensor *)tensor widthAxisTensor:(MPSGraphTensor *)widthAxisTensor heightAxisTensor:(MPSGraphTensor *)heightAxisTensor depthAxisTensor:(MPSGraphTensor *)depthAxisTensor blockSize:(NSUInteger)blockSize usePixelShuffleOrder:(BOOL)usePixelShuffleOrder name:(NSString *)name;
- (MPSGraphTensor *)depthToSpace2DTensor:(MPSGraphTensor *)tensor widthAxisTensor:(MPSGraphTensor *)widthAxisTensor heightAxisTensor:(MPSGraphTensor *)heightAxisTensor depthAxisTensor:(MPSGraphTensor *)depthAxisTensor blockSize:(NSUInteger)blockSize usePixelShuffleOrder:(BOOL)usePixelShuffleOrder name:(NSString *)name;
- (MPSGraphTensor *)spaceToBatchTensor:(MPSGraphTensor *)tensor spatialAxes:(NSArray<NSNumber *> *)spatialAxes batchAxis:(NSInteger)batchAxis blockDimensions:(NSArray<NSNumber *> *)blockDimensions usePixelShuffleOrder:(BOOL)usePixelShuffleOrder name:(NSString *)name;
- (MPSGraphTensor *)batchToSpaceTensor:(MPSGraphTensor *)tensor spatialAxes:(NSArray<NSNumber *> *)spatialAxes batchAxis:(NSInteger)batchAxis blockDimensions:(NSArray<NSNumber *> *)blockDimensions usePixelShuffleOrder:(BOOL)usePixelShuffleOrder name:(NSString *)name;
@end

static id<MTLDevice> gDevice;
static MPSGraphDevice *gGraphDevice;

// A feed whose buffer carries a SENTINEL immediately after the operand's own elements, which is the whole
// of how the tile's gradient is measured: an operation that reads one element past the end of the operand
// picks the sentinel up, and the bytes it answers with are then OURS and not the heap's. The sentinel is
// 1000 and up, so an answer holding 1013 is a read past the end and not an arithmetic result.
static MPSGraphTensorData *sentinelFeed(const float *values, NSArray<NSNumber *> *shape, NSUInteger wide,
                                         BOOL mark)
{
    NSUInteger count = 1;
    for (NSNumber *dimension in shape) count *= (NSUInteger)dimension.integerValue;
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:count * (wide ? 4 : 2) * sizeof(float)
                                              options:MTLResourceStorageModeShared];
    float *bytes = (float *)[buffer contents];
    for (NSUInteger i = 0; i < count; i++) bytes[i] = values[i];
    // How far past the end a read went is then readable off the answer: 1000 and up is one operand's length
    // past, 2000 and up is two, 3000 is three. An answer holding none of them read nothing it should not.
    for (NSUInteger i = count; i < count * (wide ? 4 : 2); i++)
        bytes[i] = mark ? 1000.0f * (float)((i - count) / count) + (float)((i - count) % count) : 0.0f;
    return [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:shape dataType:MPSDataTypeFloat32];
}

static void put(const char *name, id<MTLBuffer> buffer, size_t bytes)
{
    printf("%s %zu ", name, bytes);
    const unsigned char *p = (const unsigned char *)[buffer contents];
    for (size_t i = 0; i < bytes; i++) printf("%02x", p[i]);
    printf("\n");
}

// The destination's own bytes before the run are a question of their own, so the buffer is filled with one
// pattern before every case here: an element the release does not write keeps it, an element it writes
// zeroes or does not can be told apart from it.
static unsigned char gPattern = 0xbd;

static MPSGraphTensorData *feed(const void *values, NSArray<NSNumber *> *shape, MPSDataType type)
{
    NSUInteger count = 1;
    for (NSNumber *dimension in shape) count *= (NSUInteger)dimension.integerValue;
    size_t bytes = count * MPSSizeofMPSDataType(type);
    id<MTLBuffer> buffer = [gDevice newBufferWithBytes:values length:bytes options:MTLResourceStorageModeShared];
    return [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:shape dataType:type];
}

// The feed's shape is the OPERAND's and not the result's, which is the one thing this harness has to get
// right for a gather: the compile is told what the caller is handing it, and the result's shape is its own.
static void run(MPSGraph *graph, NSArray<MPSGraphTensor *> *feeds, NSArray<MPSGraphTensorData *> *values,
                MPSGraphTensor *target, MPSGraphTensorData *destination, NSArray<NSNumber *> *operandShape)
{
    MPSGraphShapedType *shaped = [[MPSGraphShapedType alloc] initWithShape:operandShape dataType:MPSDataTypeFloat32];
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    for (MPSGraphTensor *tensor in feeds) all[tensor] = shaped;
    MPSGraphExecutable *executable = [graph compileWithDevice:gGraphDevice feeds:all
                                              targetTensors:@[target] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:values resultsArray:@[destination] executionDescriptor:nil];
}

static void one(MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *), NSArray<NSNumber *> *shape,
                const void *values, const char *name)
{
    MPSGraph *one_ = [MPSGraph new];
    MPSGraphTensor *a = [one_ placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:@"a"];
    MPSGraphTensor *t = build(one_, a);
    if (t == nil) { printf("%s nil-tensor\n", name); return; }
    printf("%s-shape %s\n", name, [[t.shape componentsJoinedByString:@"x"] UTF8String]);
    NSUInteger count = 1;
    for (NSNumber *dimension in t.shape) count *= (NSUInteger)dimension.integerValue;
    size_t bytes = count * MPSSizeofMPSDataType(MPSDataTypeFloat32);
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    memset([buffer contents], gPattern, bytes);
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:t.shape
                                                                             dataType:MPSDataTypeFloat32];
    run(one_, @[a], @[feed(values, shape, MPSDataTypeFloat32)], t, destination, shape);
    put(name, buffer, bytes);
}

// A parameter fed at run time: the axis, the axes or the shape arrives as the operation's second input, and
// its own value is fed beside the operand's.
//
// THE DESTINATION IS ONE THE CALLER GIVES, never one derived from the result's own shape, and that is the
// whole of what this helper had wrong: over a fed parameter the release cannot resolve the result's shape and
// carries a vector of -1 for it (measured, and printed below), so a destination sized off that vector is a
// buffer of ONE element asked to hold the result, and the release's own NDArray then asserts what it asserts
// about any short buffer - "Error: NDArray dimension length > INT_MAX" - which is a fact about the question
// and not about the operation. Measured with a destination of the written-down form's own shape, four of the
// six fed forms ANSWER (exit 0) and write zeros over the destination; the two that do not are refused where
// they always were.
static void fed(MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *),
               NSArray<NSNumber *> *shape, const void *values, int32_t fed0, MPSDataType fedType,
               NSArray<NSNumber *> *fedShape, NSArray<NSNumber *> *destinationShape, const char *name)
{
    MPSGraph *one_ = [MPSGraph new];
    MPSGraphTensor *a = [one_ placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:@"a"];
    MPSGraphTensor *p = [one_ placeholderWithShape:fedShape dataType:fedType name:@"p"];
    MPSGraphTensor *t = build(one_, a, p);
    printf("%s result-shape %s\n", name,
           t.shape == nil ? "nil" : [[t.shape componentsJoinedByString:@"x"] UTF8String]);
    NSUInteger count = 1;
    for (NSNumber *dimension in destinationShape) count *= (NSUInteger)dimension.integerValue;
    size_t bytes = count * MPSSizeofMPSDataType(MPSDataTypeFloat32);
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    memset([buffer contents], gPattern, bytes);
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:destinationShape
                                                                             dataType:MPSDataTypeFloat32];
    // The fed tensor is fed its OWN shape's worth of bytes. One number into a fed tensor of two is the
    // release's own NDArray saying "buffer is not large enough, must be 8 bytes", which says nothing about the
    // gather - and a fed shape read out of a buffer that holds one number answers zeros, because a zero is a
    // perfectly good extent. Measured, both of those, and both of them were this file's own question before.
    MPSGraphTensorData *fedData = [[MPSGraphTensorData alloc] initWithMTLBuffer:
                                      [gDevice newBufferWithBytes:&fed0
                                                          length:fedShape.count * MPSSizeofMPSDataType(fedType)
                                                        options:MTLResourceStorageModeShared]
                                               shape:fedShape dataType:fedType];
    NSMutableDictionary *shaped = [NSMutableDictionary dictionary];
    shaped[a] = [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32];
    shaped[p] = [[MPSGraphShapedType alloc] initWithShape:fedShape dataType:fedType];
    MPSGraphExecutable *executable = [one_ compileWithDevice:gGraphDevice feeds:shaped
                                              targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:@[feed(values, shape, MPSDataTypeFloat32), fedData]
                           resultsArray:@[destination] executionDescriptor:nil];
    put(name, buffer, bytes);
}

// THE SAME GRAPH RUN SO THAT THE RELEASE ALLOCATES THE RESULT, which is the one run path where nothing about
// the destination the caller chose can be the reason for what comes back. Its SHAPE is what can be read: the
// VALUES of a result the release allocated are not reachable through any public accessor on this host, measured
// - class_copyPropertyList on MPSGraphTensorData gives `shape`, `dataType` and `device` and nothing that
// reaches the buffer, and MPSNDArray's own headers are fifteen lines of imports in both the 16.4 and the 26.2
// SDK. So this prints the shape the release itself allocated, which is the whole of what the caller has to size
// its own destination from.
static void fedOwn(MPSGraphTensor *(^build)(MPSGraph *, MPSGraphTensor *, MPSGraphTensor *),
                   NSArray<NSNumber *> *shape, const void *values, int32_t fed0, MPSDataType fedType,
                   NSArray<NSNumber *> *fedShape, const char *name)
{
    MPSGraph *one_ = [MPSGraph new];
    MPSGraphTensor *a = [one_ placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:@"a"];
    MPSGraphTensor *p = [one_ placeholderWithShape:fedShape dataType:fedType name:@"p"];
    MPSGraphTensor *t = build(one_, a, p);
    printf("%s tensor-shape %s\n", name,
           t.shape == nil ? "nil" : [[t.shape componentsJoinedByString:@"x"] UTF8String]);
    NSDictionary *results = [one_ runWithFeeds:@{a: feed(values, shape, MPSDataTypeFloat32),
                                                 p: [[MPSGraphTensorData alloc] initWithMTLBuffer:
                                                        [gDevice newBufferWithBytes:&fed0
                                                                            length:fedShape.count
                                                                                      * MPSSizeofMPSDataType(fedType)
                                                                           options:MTLResourceStorageModeShared]
                                                             shape:fedShape dataType:fedType]}
                                targetTensors:@[t] targetOperations:@[]];
    printf("%s own-results %lu\n", name, (unsigned long)results.count);
    for (MPSGraphTensorData *one in results.allValues)
        printf("%s own-shape %s\n", name,
               one.shape == nil ? "nil" : [[one.shape componentsJoinedByString:@"x"] UTF8String]);
}

// An operation of MORE THAN ONE input, which is what the slice's gradient and the slice's update are: a
// gradient and the shape of its forward input, or a data tensor and an update, and beside them the index
// tensors of the fed forms. Each input is fed its own bytes, and the result is asked into a destination of
// the shape the CALLER gives - which is the only way to ask the questions whose result the release leaves
// unshaped, and it is what tells a written element from an unwritten one.
static void multi(MPSGraphTensor *(^build)(MPSGraph *, NSArray<MPSGraphTensor *> *),
                  NSArray<NSArray<NSNumber *> *> *shapes, NSArray<NSData *> *bytes,
                  NSArray<NSNumber *> *types, NSArray<NSNumber *> *resultShape, const char *name)
{
    MPSGraph *one_ = [MPSGraph new];
    NSMutableArray *operands = [NSMutableArray arrayWithCapacity:shapes.count];
    NSMutableDictionary *shaped = [NSMutableDictionary dictionary];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:shapes.count];
    for (NSUInteger i = 0; i < shapes.count; i++) {
        MPSDataType type = (MPSDataType)[types[i] unsignedIntValue];
        MPSGraphTensor *operand = [one_ placeholderWithShape:shapes[i] dataType:type name:@"i"];
        [operands addObject:operand];
        shaped[operand] = [[MPSGraphShapedType alloc] initWithShape:shapes[i] dataType:type];
        [values addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:
                           [gDevice newBufferWithBytes:bytes[i].bytes length:bytes[i].length
                                                options:MTLResourceStorageModeShared]
                                                     shape:shapes[i] dataType:type]];
    }
    MPSGraphTensor *t = build(one_, operands);
    // What the release's own tensor says about the result's shape, printed whether or not it has one: a
    // result whose type the release could not infer is a measurement of its own and not of anything written.
    printf("%s result-shape %s\n", name, t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
    NSUInteger count = 1;
    for (NSNumber *dimension in resultShape) count *= (NSUInteger)dimension.integerValue;
    size_t howMany = count * MPSSizeofMPSDataType(MPSDataTypeFloat32);
    id<MTLBuffer> buffer = [gDevice newBufferWithLength:howMany options:MTLResourceStorageModeShared];
    memset([buffer contents], gPattern, howMany);
    MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:resultShape
                                                                             dataType:MPSDataTypeFloat32];
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    for (MPSGraphTensor *tensor in operands) all[tensor] = shaped[tensor];
    MPSGraphExecutable *executable = [one_ compileWithDevice:gGraphDevice feeds:all
                                              targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
    [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                          inputsArray:values resultsArray:@[destination] executionDescriptor:nil];
    put(name, buffer, howMany);
}

// The shape of a slice's forward input as a CONSTANT, which is the only way the release can be asked for a
// gradient: the shape arrives as a tensor, and a tensor that is fed is one the release cannot build a graph
// over (measured: no shape on the result, before or after the run, and one element written).
static MPSGraphTensor *forwardShape(MPSGraph *g, int32_t a, int32_t b)
{
    int32_t extents[2] = { a, b };
    return [g constantWithData:[NSData dataWithBytes:extents length:sizeof extents]
                         shape:@[@2] dataType:MPSDataTypeInt32];
}

static float rowFeed[8] = { 1.0f, 2.0f, 3.0f, 4.0f, 10.0f, 20.0f, 30.0f, 40.0f };
// The row of four the thin-axis pad questions are asked over: an axis of extent one is an axis a mirror
// reaches nothing into, which is what makes it the sharpest of the two mirror limits.
static float thinRow[4] = { 1.0f, 2.0f, 3.0f, 4.0f };
static float twoByThreeByFour[24] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
};
// The [3, 4, 6] of 1 to 72 the block-moving family's questions are asked over, whose extents are all
// different - which is what makes an answer say which operand axis each coordinate of the result came from.
static float wideFeed[72] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72,
};

int main(int argc, const char *argv[])
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    if (argc < 2) {
        // The list is printed here so that a question added to the file and not to refusals.txt is a question
        // run.sh never asks, and refusals.txt is read against this list for the same reason.
        fprintf(stderr, "name the question; these are: ");
        static const char *const kQuestions[] = {
            "broadcast-wider", "broadcast-added", "broadcast-narrower", "broadcast-zero-extent",
            "reshape-fed-shape", "reshape-volume-mismatch", "reshape-two-dynamic", "reshape-dynamic-only",
            "slice-length-zero", "slice-start-past-end", "slice-stride-zero", "slice-length-past-end",
            "fed-flatten-axis", "fed-broadcast-shape", "fed-reverse-axes", "fed-squeeze-axes",
            "fed-expand-axes", "fed-flatten-axis-own", "fed-broadcast-shape-own", "fed-squeeze-axes-own",
            "fed-expand-axes-own", "reshape-fed-shape-own",
            "squeeze-not-unit", "flatten-axis-outside", "expand-axis-outside",
            "transpose-axis-outside", "reverse-axis-outside", "reverse-axes-empty", "squeeze-axes-empty",
            "expand-axes-empty", "transpose-same-axis", "transpose-short-permutation",
            "slice-mask-start-empty", "slice-fed-ends", "slice-fed-sizes", "slice-fed-float32",
            "slice-gradient-fed-shape", "slice-gradient-fed", "slice-gradient-squeeze",
            "slice-gradient-stride2", "slice-gradient-shape-mismatch",
            "slice-update-end-mask", "slice-update-squeeze-mask", "slice-update-shape-wide",
            "slice-update-shape-narrow", "slice-update-fed-answer",
            "tilegrad-1x1", "tilegrad-1x2", "tilegrad-1x2-zero", "tilegrad-1x3", "tilegrad-1x5",
            "tilegrad-1x3-short",
            "pad-destination-narrower-rank3-clamp", "pad-destination-narrower-rank3-constant",
            "pad-destination-narrower-rank2",
            "pad-periodic", "pad-antiperiodic", "pad-reflect-past-extent",
            "pad-thin-reflect", "pad-thin-symmetric",
            "concat-axis-outside", "concat-shapes-differ", "concat-interleave-axis-outside",
            "concat-interleave-unequal", "concat-zero-extent",
            "stack-axis-outside", "stack-shapes-differ",
            "concat-mixed-types",
            "split-sizes-sum-short", "split-sizes-sum-long", "split-sizes-zero", "split-sizes-negative",
            "split-sizes-axis-outside", "split-sizes-axis-negoutside", "split-sizes-fed-placeholder",
            "split-num-divisible", "split-num-six-into-four", "split-num0",
            "coord-axis-outside", "coord-axis-negoutside", "coord-rank-one-axis1", "coord-zero-extent",
            "coord-fed-axis-placeholder", "coord-fed-axis-float", "coord-fed-shape-placeholder",
            "block-s2b-axis-outside", "block-s2b-axis-duplicate", "block-s2b-batch-among-spatial",
            "block-s2b-block-list-short", "block-s2b-block-does-not-divide",
            "block-b2s-batch-among-spatial", "block-b2s-block-list-short",
            "block-s2b-batch-outside", "block-s2b-batch-negoutside",
            "block-b2s-batch-outside", "block-b2s-batch-negoutside",
            "block-s2b-fed-axes", "block-s2b-fed-batch", "block-s2b-fed-block",
            "block-b2s-fed-axes", "block-b2s-fed-batch", "block-b2s-fed-block",
            "block-s2d-axis-outside", "block-s2d-axis-negoutside", "block-s2d-degenerate-axes",
            "block-s2d-block-does-not-divide", "block-d2s-block-does-not-divide",
            "block-s2d-fed-axis-placeholder",
            "block-s2d-fed-axis-unranked", "block-s2d-fed-axis-two-numbers",
            "block-s2d-fed-axis-float32", "block-s2d-fed-axis-two-fed-numbers",
            "block-d2s-fed-axis-placeholder", "block-s2d-fed-axis-outside-at-run",
            "block-s2d-fed-axis-int64-at-run", "block-s2d-fed-axis-degenerate-at-run",
            "block-s2d-fed-axis-block3-at-run",
            "nonzero-result-shape", "nonzero-destination-no-rows", "nonzero-destination-five-rows",
        };
        unsigned i;
        for (i = 0; i < sizeof(kQuestions) / sizeof(kQuestions[0]); i++)
            fprintf(stderr, "%s ", kQuestions[i]);
        fprintf(stderr, "\n");
        return 2;
    }
    const char *q = argv[1];
    @autoreleasepool {
        gDevice = MTLCreateSystemDefaultDevice();
        gGraphDevice = [MPSGraphDevice deviceWithMTLDevice:gDevice];
        NSArray<NSNumber *> *twoByFour = @[@2, @4];
        NSArray<NSNumber *> *twoByThreeByFourShape = @[@2, @3, @4];

        // The broadcast of an axis the shape makes WIDER than the operand's, over a destination filled with a
        // pattern: what the release writes where it has no element to write is the whole of the question.
        if (strcmp(q, "broadcast-wider") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g broadcastTensor:a toShape:@[@4, @4] name:@"b"]; }, twoByFour, rowFeed, "broadcast-wider");
            return 0;
        }
        if (strcmp(q, "broadcast-added") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g broadcastTensor:a toShape:@[@2, @2, @4] name:@"b"]; }, twoByFour, rowFeed, "broadcast-added");
            return 0;
        }
        // An aligned axis NARROWER than the operand's, which is the other way round and is not a broadcast
        // at all: what the release does with it is what the row has to say.
        if (strcmp(q, "broadcast-narrower") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g broadcastTensor:a toShape:@[@1, @4] name:@"b"]; }, twoByFour, rowFeed, "broadcast-narrower");
            return 0;
        }
        if (strcmp(q, "broadcast-zero-extent") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g broadcastTensor:a toShape:@[@2, @0] name:@"b"]; }, twoByFour, rowFeed, "broadcast-zero");
            return 0;
        }
        // The five FED forms. Each of these is a parameter that arrives at run time rather than written down,
        // and each is asked in a process of its own because the release takes the process down.
        if (strcmp(q, "slice-length-zero") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g sliceTensor:a dimension:1 start:0 length:0 name:@"s"]; }, twoByFour, rowFeed, "slice-length-zero");
            return 0;
        }
        if (strcmp(q, "slice-start-past-end") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g sliceTensor:a dimension:1 start:9 length:2 name:@"s"]; }, twoByFour, rowFeed, "slice-start-past-end");
            return 0;
        }
        if (strcmp(q, "slice-stride-zero") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g sliceTensor:a starts:@[@0, @0] ends:@[@2, @4] strides:@[@1, @0] name:@"s"]; }, twoByFour, rowFeed, "slice-stride-zero");
            return 0;
        }
        if (strcmp(q, "slice-length-past-end") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g sliceTensor:a dimension:1 start:2 length:9 name:@"s"]; }, twoByFour, rowFeed, "slice-length-past-end");
            return 0;
        }
        if (strcmp(q, "reshape-fed-shape") == 0) {
            fed(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g reshapeTensor:a withShapeTensor:p name:@"r"]; }, twoByFour, rowFeed, 4, MPSDataTypeInt32, @[@1], @[@4], "reshape-fed-shape");
            return 0;
        }
        if (strcmp(q, "reshape-volume-mismatch") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g reshapeTensor:a withShape:@[@1, @7] name:@"r"]; }, twoByFour, rowFeed, "reshape-volume-mismatch");
            return 0;
        }
        if (strcmp(q, "reshape-two-dynamic") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g reshapeTensor:a withShape:@[@-1, @-1] name:@"r"]; }, twoByFour, rowFeed, "reshape-two-dynamic");
            return 0;
        }
        if (strcmp(q, "reshape-dynamic-only") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g reshapeTensor:a withShape:@[@-1] name:@"r"]; }, twoByFour, rowFeed, "reshape-dynamic-only");
            return 0;
        }
            // THE 16.1 GENERAL FORM over its THREE FED LISTS, which is the arrangement the 15.0 fed pair
            // established: the result tensor carries no shape at build, the compile hands back an executable,
            // and the RUN reads the lists and answers. Six questions - both directions, each of the three
            // parameters fed in turn - over the [3, 4, 6] of 1 to 72 with the spatial axes @[@1, @2], the
            // batch axis @0 and the block @[@2, @2], the other two held as constants.
            else if (strstr(q, "block-s2b-fed-axes") || strstr(q, "block-s2b-fed-batch") ||
                     strstr(q, "block-s2b-fed-block") || strstr(q, "block-b2s-fed-axes") ||
                     strstr(q, "block-b2s-fed-batch") || strstr(q, "block-b2s-fed-block")) {
                int32_t axes[2] = { 1, 2 }, batch = 0, block[2] = { 2, 2 };
                MPSGraph *graph = [MPSGraph new];
                NSArray<NSNumber *> *threeByFourBySix = @[@3, @4, @6];
                NSArray<NSNumber *> *twelveByTwoByThree = @[@12, @2, @3];
                BOOL toBatch = strstr(q, "s2b") != NULL;
                int which = strstr(q, "axes") ? 1 : (strstr(q, "batch") ? 2 : 3);
                MPSGraphTensor *src = [graph placeholderWithShape:toBatch ? threeByFourBySix : twelveByTwoByThree
                                                            dataType:MPSDataTypeFloat32 name:@"a"];
                MPSGraphTensor *ax = which == 1
                    ? [graph placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"x"]
                    : [graph constantWithData:[NSData dataWithBytes:axes length:sizeof axes] shape:@[@2]
                                 dataType:MPSDataTypeInt32];
                MPSGraphTensor *wh = which == 2
                    ? [graph placeholderWithShape:@[@1] dataType:MPSDataTypeInt32 name:@"y"]
                    : [graph constantWithData:[NSData dataWithBytes:&batch length:sizeof batch] shape:@[@1]
                                 dataType:MPSDataTypeInt32];
                MPSGraphTensor *sz = which == 3
                    ? [graph placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"z"]
                    : [graph constantWithData:[NSData dataWithBytes:block length:sizeof block] shape:@[@2]
                                 dataType:MPSDataTypeInt32];
                MPSGraphTensor *fed = toBatch
                    ? [graph spaceToBatchTensor:src spatialAxesTensor:ax batchAxisTensor:wh
                            blockDimensionsTensor:sz usePixelShuffleOrder:NO name:@"s"]
                    : [graph batchToSpaceTensor:src spatialAxesTensor:ax batchAxisTensor:wh
                            blockDimensionsTensor:sz usePixelShuffleOrder:NO name:@"b"];
                // ONLY THE FED LIST goes into the feeds and the inputs: a constant is in the graph and not a
                // feed, and one there is the release's own "Input feed tensor not found in placeholders,
                // tensor corresponds to operation: mps_constant" (MPSGraphExecutable.mm:1990), which says
                // nothing about the fed list - measured, and it is what this question asked first.
                NSMutableDictionary *shaped = [NSMutableDictionary dictionary];
                NSMutableArray *inputs = [NSMutableArray array];
                NSArray<NSNumber *> *operandShape = toBatch ? threeByFourBySix : twelveByTwoByThree;
                shaped[src] = [[MPSGraphShapedType alloc] initWithShape:operandShape dataType:MPSDataTypeFloat32];
                [inputs addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:
                                      [gDevice newBufferWithBytes:wideFeed length:72 * sizeof(float)
                                                          options:MTLResourceStorageModeShared]
                                               shape:operandShape dataType:MPSDataTypeFloat32]];
                NSArray<NSNumber *> *fedShape = which == 2 ? @[@1] : @[@2];
                const void *fedBytes = which == 1 ? (const void *)axes
                    : (which == 2 ? (const void *)&batch : (const void *)block);
                shaped[which == 1 ? ax : (which == 2 ? wh : sz)] =
                    [[MPSGraphShapedType alloc] initWithShape:fedShape dataType:MPSDataTypeInt32];
                // The fed list's buffer is its own ELEMENT COUNT and not its rank: a list of two axes is
                // declared [2] - one axis of extent two - and fed eight bytes, and handing it the four a rank
                // would give is the release's own NDArray saying "buffer is not large enough. Must be 8
                // bytes", which says nothing about the operation - measured, and it is what this question
                // asked first.
                NSUInteger fedCount = 1;
                for (NSNumber *one in fedShape) fedCount *= (NSUInteger)one.integerValue;
                [inputs addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:
                                      [gDevice newBufferWithBytes:fedBytes
                                                          length:fedCount * sizeof(int32_t)
                                                        options:MTLResourceStorageModeShared]
                                               shape:fedShape dataType:MPSDataTypeInt32]];
                printf("%s result-shape %s\n", q,
                       fed.shape ? [[fed.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
                NSArray<NSNumber *> *destination = toBatch ? twelveByTwoByThree : threeByFourBySix;
                size_t outBytes = 72 * sizeof(float);
                id<MTLBuffer> out = [gDevice newBufferWithLength:outBytes options:MTLResourceStorageModeShared];
                memset([out contents], gPattern, outBytes);
                MPSGraphExecutable *e2 = [graph compileWithDevice:gGraphDevice feeds:shaped targetTensors:@[fed]
                                                  targetOperations:@[] compilationDescriptor:nil];
                printf("%s executable %s\n", q, e2 == nil ? "nil" : "built");
                if (e2 == nil) return 0;
                [e2 runWithMTLCommandQueue:[gDevice newCommandQueue] inputsArray:inputs
                              resultsArray:@[[[MPSGraphTensorData alloc] initWithMTLBuffer:out shape:destination
                                                                                       dataType:MPSDataTypeFloat32]]
                       executionDescriptor:nil];
                printf("%s run returned\n", q);
                const float *p2 = (const float *)[out contents];
                printf("%s bytes", q);
                for (size_t i = 0; i < 72; i++) printf(" %.0f", p2[i]);
                printf("\n");
                fflush(stdout);
                return 0;
            }
        // THE OTHER RUN PATH of the five fed forms and the reshape's own: the release allocates the result, so
        // what the caller gets is a shape rather than a buffer it chose, and the shape is what it resolved.
        if (strcmp(q, "fed-flatten-axis-own") == 0) {
            fedOwn(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g flatten2DTensor:a axisTensor:p name:@"f"]; }, twoByFour, rowFeed, 1, MPSDataTypeInt32, @[@1], "fed-flatten-axis-own");
            return 0;
        }
        if (strcmp(q, "fed-broadcast-shape-own") == 0) {
            fedOwn(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g broadcastTensor:a toShapeTensor:p name:@"b"]; }, twoByFour, rowFeed, 4, MPSDataTypeInt32, @[@1], "fed-broadcast-shape-own");
            return 0;
        }
        if (strcmp(q, "fed-squeeze-axes-own") == 0) {
            fedOwn(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g squeezeTensor:a axesTensor:p name:@"s"]; }, @[@1, @2, @4], twoByThreeByFour, 0, MPSDataTypeInt32, @[@1], "fed-squeeze-axes-own");
            return 0;
        }
        if (strcmp(q, "fed-expand-axes-own") == 0) {
            fedOwn(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g expandDimsOfTensor:a axesTensor:p name:@"e"]; }, twoByFour, rowFeed, 0, MPSDataTypeInt32, @[@1], "fed-expand-axes-own");
            return 0;
        }
        if (strcmp(q, "reshape-fed-shape-own") == 0) {
            fedOwn(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g reshapeTensor:a withShapeTensor:p name:@"r"]; }, twoByFour, rowFeed, 4, MPSDataTypeInt32, @[@1], "reshape-fed-shape-own");
            return 0;
        }
        if (strcmp(q, "fed-flatten-axis") == 0) {
            fed(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g flatten2DTensor:a axisTensor:p name:@"f"]; }, twoByFour, rowFeed, 1, MPSDataTypeInt32, @[@1], @[@2, @4], "fed-flatten-axis");
            return 0;
        }
        if (strcmp(q, "fed-broadcast-shape") == 0) {
            fed(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g broadcastTensor:a toShapeTensor:p name:@"b"]; }, twoByFour, rowFeed, 4, MPSDataTypeInt32, @[@1], @[@4], "fed-broadcast-shape");
            return 0;
        }
        if (strcmp(q, "fed-reverse-axes") == 0) {
            fed(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g reverseTensor:a axesTensor:p name:@"r"]; }, twoByFour, rowFeed, 0, MPSDataTypeInt32, @[@1], @[@2, @4], "fed-reverse-axes");
            return 0;
        }
        if (strcmp(q, "fed-squeeze-axes") == 0) {
            fed(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g squeezeTensor:a axesTensor:p name:@"s"]; }, @[@1, @2, @4], twoByThreeByFour, 0, MPSDataTypeInt32, @[@1], @[@2, @4], "fed-squeeze-axes");
            return 0;
        }
        if (strcmp(q, "fed-expand-axes") == 0) {
            fed(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *p) {
                return [g expandDimsOfTensor:a axesTensor:p name:@"e"]; }, twoByFour, rowFeed, 0, MPSDataTypeInt32, @[@1], @[@1, @2, @4], "fed-expand-axes");
            return 0;
        }
        // The forms the port refuses and what the release does with each of them.
        if (strcmp(q, "squeeze-not-unit") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g squeezeTensor:a axis:1 name:@"s"]; }, twoByFour, rowFeed, "squeeze-not-unit");
            return 0;
        }
        if (strcmp(q, "flatten-axis-outside") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g flatten2DTensor:a axis:5 name:@"f"]; }, twoByFour, rowFeed, "flatten-axis-outside");
            return 0;
        }
        if (strcmp(q, "expand-axis-outside") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g expandDimsOfTensor:a axis:5 name:@"e"]; }, twoByFour, rowFeed, "expand-axis-outside");
            return 0;
        }
        if (strcmp(q, "transpose-axis-outside") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g transposeTensor:a dimension:0 withDimension:5 name:@"t"]; }, twoByFour, rowFeed, "transpose-axis-outside");
            return 0;
        }
        if (strcmp(q, "reverse-axis-outside") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g reverseTensor:a axes:@[@5] name:@"r"]; }, twoByFour, rowFeed, "reverse-axis-outside");
            return 0;
        }
        // An empty array of axes where the family takes one, and a nil, for the two families that take one.
        if (strcmp(q, "reverse-axes-empty") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g reverseTensor:a axes:@[] name:@"r"]; }, twoByFour, rowFeed, "reverse-axes-empty");
            return 0;
        }
        if (strcmp(q, "squeeze-axes-empty") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g squeezeTensor:a axes:@[] name:@"s"]; }, @[@1, @2, @4], twoByThreeByFour, "squeeze-axes-empty");
            return 0;
        }
        if (strcmp(q, "expand-axes-empty") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g expandDimsOfTensor:a axes:@[] name:@"e"]; }, twoByFour, rowFeed, "expand-axes-empty");
            return 0;
        }
        // A transpose naming the same axis twice, and a permutation that is not one - both are shapes the
        // result's own rank does not decide, so what the release answers is the row's to carry.
        if (strcmp(q, "transpose-same-axis") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g transposeTensor:a dimension:0 withDimension:0 name:@"t"]; }, twoByThreeByFourShape, twoByThreeByFour, "transpose-same-axis");
            return 0;
        }
        if (strcmp(q, "transpose-short-permutation") == 0) {
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g transposeTensor:a permutation:@[@1] name:@"t"]; }, twoByThreeByFourShape, twoByThreeByFour, "transpose-short-permutation");
            return 0;
        }
        // THE SLICE FAMILY'S OWN QUESTIONS, which are the ones the eleven rows of the mask, gradient and
        // update forms carry. The data of the family is the data of the update cases above: the data tensor
        // is of (100, 200, 300, 400 | 500, 600, 700, 800) and the update of (-1, -2, -3, -4).
        if (strcmp(q, "slice-mask-start-empty") == 0) {
            // A masked start is zero, so a start of 9 with an end of 0 asks for a result of no elements -
            // which the release builds and then cannot make an NDArray for.
            one(^MPSGraphTensor *(MPSGraph *g, MPSGraphTensor *a) {
                return [g sliceTensor:a starts:@[@9, @0] ends:@[@0, @4] strides:@[@1, @1]
                          startMask:1 endMask:0 squeezeMask:0 name:@"s"]; }, twoByFour, rowFeed, "slice-mask-start-empty");
            return 0;
        }
        if (strcmp(q, "slice-fed-ends") == 0 || strcmp(q, "slice-fed-sizes") == 0
            || strcmp(q, "slice-fed-float32") == 0) {
            // The two FED slice forms of 18.2, and the floating point one besides them: the result's shape
            // comes out of the fed tensors, and a shape that is data is the one thing the release cannot
            // build a graph over.
            int32_t starts[2] = { 0, 0 };
            int32_t ends[2] = { 1, 4 };
            int32_t each[2] = { 1, 1 };
            float halves[2] = { 0.0f, 0.0f };
            MPSGraph *g = [MPSGraph new];
            MPSGraphTensor *a = [g placeholderWithShape:twoByFour dataType:MPSDataTypeFloat32 name:@"a"];
            MPSGraphTensor *t;
            NSArray<NSArray<NSNumber *> *> *shapes;
            NSArray<NSData *> *bytes;
            NSArray<NSNumber *> *types;
            if (strcmp(q, "slice-fed-ends") == 0) {
                MPSGraphTensor *s = [g placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"s"];
                MPSGraphTensor *e = [g placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"e"];
                MPSGraphTensor *t2 = [g placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"t"];
                t = [g sliceTensor:a startTensor:s endTensor:e strideTensor:t2
                      startMask:0 endMask:0 squeezeMask:0 name:@"s"];
                shapes = @[@[@2, @4], @[@2], @[@2], @[@2]];
                bytes = @[[NSData dataWithBytes:rowFeed length:32], [NSData dataWithBytes:starts length:sizeof starts],
                          [NSData dataWithBytes:ends length:sizeof ends], [NSData dataWithBytes:each length:sizeof each]];
                types = @[@(MPSDataTypeFloat32), @(MPSDataTypeInt32), @(MPSDataTypeInt32), @(MPSDataTypeInt32)];
            } else if (strcmp(q, "slice-fed-sizes") == 0) {
                MPSGraphTensor *s = [g placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"s"];
                MPSGraphTensor *z = [g placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"z"];
                t = [g sliceTensor:a startTensor:s sizeTensor:z squeezeMask:0 name:@"s"];
                shapes = @[@[@2, @4], @[@2], @[@2]];
                bytes = @[[NSData dataWithBytes:rowFeed length:32], [NSData dataWithBytes:starts length:sizeof starts],
                          [NSData dataWithBytes:ends length:sizeof ends]];
                types = @[@(MPSDataTypeFloat32), @(MPSDataTypeInt32), @(MPSDataTypeInt32)];
            } else {
                MPSGraphTensor *s = [g placeholderWithShape:@[@2] dataType:MPSDataTypeFloat32 name:@"s"];
                MPSGraphTensor *e = [g placeholderWithShape:@[@2] dataType:MPSDataTypeFloat32 name:@"e"];
                MPSGraphTensor *t2 = [g placeholderWithShape:@[@2] dataType:MPSDataTypeFloat32 name:@"t"];
                t = [g sliceTensor:a startTensor:s endTensor:e strideTensor:t2
                      startMask:0 endMask:0 squeezeMask:0 name:@"s"];
                shapes = @[@[@2, @4], @[@2], @[@2], @[@2]];
                bytes = @[[NSData dataWithBytes:rowFeed length:32], [NSData dataWithBytes:halves length:sizeof halves],
                          [NSData dataWithBytes:halves length:sizeof halves], [NSData dataWithBytes:halves length:sizeof halves]];
                types = @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32), @(MPSDataTypeFloat32), @(MPSDataTypeFloat32)];
            }
            multi(^MPSGraphTensor *(MPSGraph *graph, NSArray<MPSGraphTensor *> *in) { return t; },
                  shapes, bytes, types, twoByFour, q);
            return 0;
        }
        if (strcmp(q, "slice-gradient-fed-shape") == 0 || strcmp(q, "slice-gradient-fed") == 0) {
            // The gradient whose forward input's shape is FED rather than a constant: the release's own
            // result tensor carries no shape, before the run or after it, and the process writes the
            // gradient's element 0 into the destination's element 0 and nothing else.
            int32_t forward[2] = { 2, 4 };
            int32_t starts[2] = { 0, 1 };
            int32_t ends[2] = { 1, 3 };
            int32_t each[2] = { 1, 1 };
            float gradient[2] = { -1.0f, -2.0f };
            multi(^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      if (strcmp(q, "slice-gradient-fed") == 0)
                          return [g sliceGradientTensor:in[0] fwdInShapeTensor:in[1] startTensor:in[2]
                                              endTensor:in[3] strideTensor:in[4] startMask:0 endMask:0
                                              squeezeMask:0 name:@"grad"];
                      return [g sliceGradientTensor:in[0] fwdInShapeTensor:in[1] starts:@[@0, @1]
                                          ends:@[@1, @3] strides:@[@1, @1] name:@"grad"]; },
                  @[@[@1, @2], @[@2], @[@2], @[@2], @[@2]],
                  @[[NSData dataWithBytes:gradient length:sizeof gradient],
                    [NSData dataWithBytes:forward length:sizeof forward],
                    [NSData dataWithBytes:starts length:sizeof starts],
                    [NSData dataWithBytes:ends length:sizeof ends],
                    [NSData dataWithBytes:each length:sizeof each]],
                  @[@(MPSDataTypeFloat32), @(MPSDataTypeInt32), @(MPSDataTypeInt32), @(MPSDataTypeInt32),
                    @(MPSDataTypeInt32)], twoByFour, q);
            return 0;
        }
        if (strcmp(q, "slice-gradient-squeeze") == 0 || strcmp(q, "slice-gradient-stride2") == 0
            || strcmp(q, "slice-gradient-shape-mismatch") == 0) {
            // Three gradients the release's own compiler will not build: a squeezeMask (with and without the
            // mask it pairs with), a stride above one, and a gradient whose shape is not the region's - the
            // last with the release's own words for it, which are the check the port makes at build time.
            float gradient[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
            float four[4] = { -1, -2, -3, -4 };
            multi(^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      if (strcmp(q, "slice-gradient-squeeze") == 0)
                          return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShape(g, 2, 4)
                                              starts:@[@0, @0] ends:@[@1, @4] strides:@[@1, @1]
                                              startMask:0 endMask:0 squeezeMask:1 name:@"grad"];
                      if (strcmp(q, "slice-gradient-stride2") == 0)
                          return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShape(g, 2, 4)
                                              starts:@[@0, @0] ends:@[@1, @3] strides:@[@1, @2]
                                              startMask:0 endMask:0 squeezeMask:0 name:@"grad"];
                      // A gradient of one row where a startMask over axis 0 makes the region two rows, which
                      // is the release's own words for a gradient that is not the region's: "'mps.
                      // strided_slice_gradient' op `grad_input`[0] = 1 should match dimension size: 2
                      // deduced from `fwd_shape`".
                      return [g sliceGradientTensor:in[0] fwdInShapeTensor:forwardShape(g, 2, 4)
                                          starts:@[@1, @0] ends:@[@2, @4] strides:@[@1, @1]
                                          startMask:1 endMask:0 squeezeMask:0 name:@"grad"]; },
                  (strcmp(q, "slice-gradient-shape-mismatch") == 0) ? @[@[@1, @4]] : @[@[@2, @4]],
                  (strcmp(q, "slice-gradient-shape-mismatch") == 0)
                      ? @[[NSData dataWithBytes:four length:sizeof four]]
                      : @[[NSData dataWithBytes:gradient length:sizeof gradient]],
                  @[@(MPSDataTypeFloat32)], twoByFour, q);
            return 0;
        }
        if (strcmp(q, "slice-update-end-mask") == 0 || strcmp(q, "slice-update-squeeze-mask") == 0
            || strcmp(q, "slice-update-shape-wide") == 0 || strcmp(q, "slice-update-shape-narrow") == 0
            || strcmp(q, "slice-update-fed-answer") == 0) {
            // The update's own questions: the two masks the release refuses on it, the two shapes of update
            // that are not the region's, and the one fed form it DOES answer - which is the whole of what
            // separates 18.0's fed update from the five fed gather parameters the release cannot build over.
            float data[8] = { 100, 200, 300, 400, 500, 600, 700, 800 };
            float four[4] = { -1, -2, -3, -4 };
            float two[2] = { -1, -2 };
            int32_t starts[2] = { 0, 1 };
            int32_t ends[2] = { 1, 3 };
            int32_t each[2] = { 1, 1 };
            uint32_t masks[3] = { 0, 0, 0 };
            if (strcmp(q, "slice-update-end-mask") == 0) masks[1] = 2;
            if (strcmp(q, "slice-update-squeeze-mask") == 0) masks[2] = 2;
            NSArray<NSNumber *> *updateShape = (strcmp(q, "slice-update-shape-wide") == 0) ? @[@2, @4] : @[@1, @2];
            if (strcmp(q, "slice-update-shape-narrow") == 0) updateShape = @[@1, @1];
            // The one fed parameter of this family the release DOES answer, and it is asked here beside the
            // refusals because that is what makes it the interesting one: the result's shape is the data
            // tensor's own, which the graph knows when it is built, so the starts, the ends and the strides
            // can arrive as data.
            if (strcmp(q, "slice-update-fed-answer") == 0) {
                multi(^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                          return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] startsTensor:in[2]
                                                  endsTensor:in[3] stridesTensor:in[4] name:@"upd"]; },
                      @[@[@2, @4], @[@1, @2], @[@2], @[@2], @[@2]],
                      @[[NSData dataWithBytes:data length:sizeof data],
                        [NSData dataWithBytes:two length:sizeof two],
                        [NSData dataWithBytes:starts length:sizeof starts],
                        [NSData dataWithBytes:ends length:sizeof ends],
                        [NSData dataWithBytes:each length:sizeof each]],
                      @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32), @(MPSDataTypeInt32), @(MPSDataTypeInt32),
                        @(MPSDataTypeInt32)], twoByFour, q);
                return 0;
            }
            uint32_t startMask = masks[0], endMask = masks[1], squeezeMask = masks[2];
            multi(^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                      return [g sliceUpdateDataTensor:in[0] updateTensor:in[1] starts:@[@0, @1] ends:@[@1, @3]
                                              strides:@[@1, @1] startMask:startMask endMask:endMask
                                              squeezeMask:squeezeMask name:@"upd"]; },
                  @[@[@2, @4], updateShape],
                  @[[NSData dataWithBytes:data length:sizeof data], [NSData dataWithBytes:four length:sizeof four]],
                  @[@(MPSDataTypeFloat32), @(MPSDataTypeFloat32)], twoByFour, q);
            (void)starts; (void)ends; (void)each;
            return 0;
        }
        // THE TILE'S GRADIENT over a SENTINEL-PADDED gradient, which is the only way to ask it at all: where
        // a window runs off the end of an axis the release READS PAST THE END of the caller's gradient buffer,
        // so its answer there is whatever memory follows it and two harnesses that ask the identical question
        // get different bytes. Measured with the sentinel: a 4x4 of (1 ... 16) with a multiplier of (1, 2)
        // answers the first three rows 6, 8, 10, 12 | 14, 16, 18, 20 | 22, 24, 26, 28 and the last row
        // 1013, 1015, 1017, 1019 - which is the last row of the gradient (13, 14, 15, 16) plus the sentinel
        // read one element past the operand (1000, 1001, 1002, 1003). Without the sentinel the same question
        // answers 13, 14, 15, 16 on this host and 30, 32, 34, 36 inside the differential, which is the heap.
        // So these are asked of the release with the sentinel in place and their bytes recorded here: the
        // answer is then made of the caller's own buffer and is the one measurement of this method that does
        // not depend on memory this repository does not own.
        if (strncmp(q, "tilegrad-", 8) == 0) {
            NSArray<NSNumber *> *shape = nil;
            NSArray<NSNumber *> *multiplier = nil;
            if (strcmp(q, "tilegrad-1x1") == 0) { shape = @[@4, @4]; multiplier = @[@1, @1]; }
            else if (strncmp(q, "tilegrad-1x2", 12) == 0) { shape = @[@4, @4]; multiplier = @[@1, @2]; }
            else if (strcmp(q, "tilegrad-1x3") == 0) { shape = @[@4, @4]; multiplier = @[@1, @3]; }
            else if (strcmp(q, "tilegrad-1x5") == 0) { shape = @[@4, @4]; multiplier = @[@1, @5]; }
            else if (strcmp(q, "tilegrad-4x3") == 0) { shape = @[@4, @4]; multiplier = @[@4, @3]; }
            else if (strcmp(q, "tilegrad-1x3-short") == 0) { shape = @[@2, @4]; multiplier = @[@1, @3]; }
            else { shape = @[@4, @4, @2]; multiplier = @[@1, @3, @3]; }
            NSUInteger count = 1;
            for (NSNumber *dimension in shape) count *= (NSUInteger)dimension.integerValue;
            float *gradient = malloc(count * sizeof(float));
            for (NSUInteger i = 0; i < count; i++) gradient[i] = (float)(i + 1);
            float *source = malloc(count * sizeof(float));
            for (NSUInteger i = 0; i < count; i++) source[i] = 1.0f;
            MPSGraph *one = [MPSGraph new];
            MPSGraphTensor *g = [one placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:@"g"];
            MPSGraphTensor *s = [one placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:@"s"];
            MPSGraphTensor *t = [one tileGradientWithIncomingGradientTensor:g sourceTensor:s
                                                            withMultiplier:multiplier name:@"tg"];
            printf("%s result-shape %s\n", q,
                   t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
            size_t bytes = count * sizeof(float);
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
            memset([buffer contents], gPattern, bytes);
            MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:shape
                                                                                 dataType:MPSDataTypeFloat32];
            NSMutableDictionary *shaped = [NSMutableDictionary dictionary];
            shaped[g] = [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32];
            shaped[s] = [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32];
            MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:shaped targetTensors:@[t]
                                                   targetOperations:@[] compilationDescriptor:nil];
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:@[sentinelFeed(gradient, shape, strstr(q, "wide") != NULL, strstr(q, "zero") == NULL),
                               feed(source, shape, MPSDataTypeFloat32)]
                                   resultsArray:@[destination] executionDescriptor:nil];
            put(q, buffer, bytes);
            free(gradient);
            free(source);
            return 0;
        }
        // THE PAD AND THE TILE'S OWN REFUSALS, each measured on this host's own MPSGraph: two modes the
        // release refuses by name, a mirror that reaches past the axis it mirrors - and the same mirror over
        // an axis ONE element long, which reaches nothing at all - and a destination whose shape is the
        // OPERAND's where the result's is a different one.
        //
        // What this branch no longer holds is a refusal of a rank of THREE. It used to hold one, and the two
        // entries it recorded - "Invalid KernelDAG, equalShape for destination failed" - were this file's own
        // question asked into the wrong shape: the destination below is the OPERAND's, and a 2x3x4 padded by
        // one at each end of every axis is a 4x5x6. Asked into a destination of the RESULT's shape the same
        // pad answers in every mode, which is what graph-cases.m's pad-rank3-clamp and pad-rank3-symmetric
        // compare. So the entry is renamed to what it measures, and the rank-3 pad is a case and not a
        // refusal.
        if (strncmp(q, "pad-", 4) == 0 || strcmp(q, "tile-rank3") == 0) {
            int rank3 = strstr(q, "rank3") != NULL;
            int thin = strstr(q, "thin") != NULL;
            int tile = strstr(q, "tile") != NULL;
            MPSGraphPaddingMode mode = MPSGraphPaddingModeConstant;
            if (strstr(q, "periodic")) mode = MPSGraphPaddingModePeriodic;
            else if (strstr(q, "antiperiodic")) mode = MPSGraphPaddingModeAntiPeriodic;
            else if (strstr(q, "symmetric")) mode = MPSGraphPaddingModeSymmetric;
            else if (strstr(q, "clamp")) mode = MPSGraphPaddingModeClampToEdge;
            else if (strstr(q, "reflect")) mode = MPSGraphPaddingModeReflect;
            NSArray<NSNumber *> *shape = rank3 ? @[@2, @3, @4] : thin ? @[@1, @4] : twoByFour;
            NSArray<NSNumber *> *left = rank3 ? @[@1, @1, @1] : thin ? @[@1, @0] : @[@1, @2];
            NSArray<NSNumber *> *right = rank3 ? @[@1, @1, @1] : thin ? @[@1, @0] : @[@1, @0];
            if (strstr(q, "past-extent")) { left = @[@3, @2]; right = @[@2, @0]; }
            // A mirror over an axis of ONE element long reaches nothing into it, so the padding that is one
            // past its own limit is one for the reflect and two for the symmetric - the symmetric reaches
            // the axis itself, which is the whole of the difference between the two limits.
            if (thin && mode == 2) { left = @[@2, @0]; right = @[@2, @0]; }
            const void *values = rank3 ? (const void *)twoByThreeByFour : thin ? (const void *)thinRow
                                                                : (const void *)rowFeed;
            NSUInteger count = rank3 ? 24 : thin ? 4 : 8;
            float *bytes = malloc(count * sizeof(float));
            memcpy(bytes, values, count * sizeof(float));
            MPSGraph *one = [MPSGraph new];
            MPSGraphTensor *a = [one placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:@"a"];
            MPSGraphTensor *t = tile ? [one tileTensor:a withMultiplier:@[@2, @2, @2] name:@"t"]
                : [one padTensor:a withPaddingMode:mode leftPadding:left rightPadding:right
                     constantValue:99.0 name:@"p"];
            NSMutableDictionary *shaped = [NSMutableDictionary dictionary];
            shaped[a] = [[MPSGraphShapedType alloc] initWithShape:shape dataType:MPSDataTypeFloat32];
            MPSGraphExecutable *executable = [one compileWithDevice:gGraphDevice feeds:shaped targetTensors:@[t]
                                                   targetOperations:@[] compilationDescriptor:nil];
            // The result's own shape is printed whatever it is, and the destination is the OPERAND's shape,
            // because a process that is gone writes nothing this file can match and the shape line is what
            // the release did answer before it went.
            printf("%s result-shape %s\n", q, t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:count * sizeof(float)
                                                      options:MTLResourceStorageModeShared];
            memset([buffer contents], gPattern, count * sizeof(float));
            MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:shape
                                                                                 dataType:MPSDataTypeFloat32];
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:@[feed(bytes, shape, MPSDataTypeFloat32)]
                                   resultsArray:@[destination] executionDescriptor:nil];
            put(q, buffer, count * sizeof(float));
            free(bytes);
            return 0;
        }
        // MIXED DATA TYPES, the header's sentence about the operands' type, measured here because the port
        // does not refuse it: a float32 2x4 beside an int32 2x4 builds a result tensor whose data type is the
        // FIRST operand's (a float32 beside an int32 answers a float32 result, 0x10000020) and only the
        // release's own compiler refuses it - "'mps.concat' op element type of operand and result differ" -
        // with the process still alive and nothing written. So the port, which takes the result's data type
        // from the operands' own, agrees with the release about the tensor; what the release has and the port
        // has not is the refusal, and that refusal is a compiler's and not the graph's.
        //
        // The header's OTHER sentence, the array being the operands themselves, is NOT here because it is not
        // a refusal: measured over the whole path, an empty array builds a result tensor of nil shape and
        // float32, the compile returns an executable and the run leaves the destination as it was. It is two
        // cases of the differential instead - graph-cases.m's concat-empty and stack-empty - and the port
        // answers it the same way after the correction that removed the raise.
        if (strcmp(q, "concat-mixed-types") == 0) {
            MPSGraph *graph = [MPSGraph new];
            MPSGraphTensor *a = [graph placeholderWithShape:twoByFour dataType:MPSDataTypeFloat32 name:@"a"];
            MPSGraphTensor *b = [graph placeholderWithShape:twoByFour dataType:MPSDataTypeInt32 name:@"b"];
            MPSGraphTensor *t = [graph concatTensors:@[a, b] dimension:1 name:@"c"];
            printf("%s shape %s result-data-type 0x%x\n", q,
                   t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil", (unsigned)t.dataType);
            fflush(stdout);
            NSUInteger n = 16;
            id<MTLBuffer> out = [gDevice newBufferWithLength:n * sizeof(float)
                                                   options:MTLResourceStorageModeShared];
            memset([out contents], gPattern, n * sizeof(float));
            int32_t other[8] = { -1, -2, -3, -4, -5, -6, -7, -8 };
            MPSGraphExecutable *executable = [graph compileWithDevice:gGraphDevice
                    feeds:@{a: [[MPSGraphShapedType alloc] initWithShape:twoByFour dataType:MPSDataTypeFloat32],
                            b: [[MPSGraphShapedType alloc] initWithShape:twoByFour dataType:MPSDataTypeInt32]}
            targetTensors:@[t] targetOperations:@[] compilationDescriptor:nil];
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:@[feed(rowFeed, twoByFour, MPSDataTypeFloat32),
                                                feed(other, twoByFour, MPSDataTypeInt32)]
                                   resultsArray:@[[[MPSGraphTensorData alloc] initWithMTLBuffer:out
                                                                                          shape:@[@2, @8]
                                                                                       dataType:MPSDataTypeFloat32]]
                               executionDescriptor:nil];
            put(q, out, n * sizeof(float));
            return 0;
        }
        // THE CONCAT AND STACK FAMILY, the one walk whose result is several operands, and the two things the
        // release refuses about it. Both are refused where the graph is BUILT, by its own compiler, and the
        // compiler's own message is what is recorded - so this is a measurement of the release rather than a
        // question the port has to have an opinion about.
        //
        //   - an axis outside the rank. A concat takes `-rank <= axis < rank` and a stack takes
        //     `-rank + 1 <= axis < rank + 1` over the RESULT's rank, one more than the operands', and one
        //     past either end of that is refused. The two carry different messages, which is why they are two
        //     questions: the release builds a stack out of an expanded dimension per operand and then a
        //     concatenation, and the expanded dimension is what names the axis first (MPSGraphUtilities.mm
        //     3237) while the concatenation is what names it for a concat (MPSGraphUtilities.mm:748).
        //   - operands whose shapes differ anywhere but the axis they are laid along. The header says the
        //     inputs must be "broadcast compatible" and the release does not take it at all: a 1x4 beside a
        //     2x4 is refused with axis 1 the one laid along, and so is a stack of two 2x4s beside a 1x4.
        if (strncmp(q, "concat-", 7) == 0 || strncmp(q, "stack-", 6) == 0) {
            int stacked = strncmp(q, "stack-", 6) == 0;
            NSInteger axis = stacked ? 3 : 2;
            NSArray<NSArray<NSNumber *> *> *shapes = @[twoByFour, twoByFour];
            NSArray<NSData *> *values = @[[NSData dataWithBytes:rowFeed length:sizeof rowFeed],
                                          [NSData dataWithBytes:rowFeed length:sizeof rowFeed]];
            NSString *question = [NSString stringWithUTF8String:q];
            if (strstr(q, "interleave-unequal")) {
                // The operands are a 2x4 and a 2x1, so the axis they are laid along is the ONLY one whose
                // extent differs between them - which end to end answers a 2x5 and is the case
                // concat-unequal-axis1 in the differential. Interleaved it is refused, and that refusal is the
                // whole of the invariant the walk's division rests on.
                axis = 1;
                shapes = @[@[@2, @4], @[@2, @1]];
                values = @[[NSData dataWithBytes:rowFeed length:sizeof rowFeed],
                           [NSData dataWithBytes:rowFeed length:2 * sizeof(float)]];
            }
            if (strstr(q, "zero-extent")) {
                // The zero is the FIRST operand, which is the harder case for a walk that lays regions out
                // by offset: the two regions then START at the same place and nothing in the offsets says
                // which of them an element belongs to. The release builds the result tensor of the other
                // operand's length and then fails inside its own array; the port refuses where the graph is
                // built.
                axis = 1;
                shapes = @[@[@2, @0], twoByFour];
                values = @[[NSData dataWithBytes:thinRow length:0],
                           [NSData dataWithBytes:rowFeed length:sizeof rowFeed]];
            }
            if (strstr(q, "shapes-differ")) {
                axis = 1;
                // The extent that differs is on axis 0, and the axis the operands are laid along is axis 1,
                // so the difference is one the release's own words say it cannot take.
                shapes = stacked ? @[twoByFour, twoByFour, @[@1, @4]] : @[@[@1, @4], twoByFour];
                values = stacked ? @[[NSData dataWithBytes:rowFeed length:sizeof rowFeed],
                                      [NSData dataWithBytes:rowFeed length:sizeof rowFeed],
                                      [NSData dataWithBytes:thinRow length:sizeof thinRow]]
                                 : @[[NSData dataWithBytes:thinRow length:sizeof thinRow],
                                     [NSData dataWithBytes:rowFeed length:sizeof rowFeed]];
            }
            MPSGraph *graph = [MPSGraph new];
            NSMutableArray *operands = [NSMutableArray array];
            NSMutableDictionary *feeds = [NSMutableDictionary dictionary];
            NSMutableArray *inputs = [NSMutableArray array];
            for (NSUInteger i = 0; i < shapes.count; i++) {
                MPSGraphTensor *p = [graph placeholderWithShape:shapes[i] dataType:MPSDataTypeFloat32 name:@"i"];
                [operands addObject:p];
                feeds[p] = [[MPSGraphShapedType alloc] initWithShape:shapes[i] dataType:MPSDataTypeFloat32];
                [inputs addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:
                                   [gDevice newBufferWithBytes:values[i].bytes length:values[i].length
                                                        options:MTLResourceStorageModeShared]
                                                         shape:shapes[i] dataType:MPSDataTypeFloat32]];
            }
            // The interleave form of the same question, so that the flag is measured to change nothing about
            // what the release refuses: the axis is named by the same concatenation either way.
            int interleaved = strstr(q, "interleave") != NULL;
            MPSGraphTensor *t = stacked ? [graph stackTensors:operands axis:axis name:@"s"]
                                        : interleaved ? [graph concatTensors:operands dimension:axis
                                                             interleave:YES name:@"c"]
                                                      : [graph concatTensors:operands dimension:axis name:@"c"];
            // The result's own shape is printed whatever it is, because a process that is gone writes nothing
            // this file can match and the shape is what the release did answer before it went.
            printf("%s result-shape %s\n", question.UTF8String,
                   t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
            fflush(stdout);
            NSUInteger count = 1;
            for (NSNumber *dimension in t.shape) count *= (NSUInteger)dimension.integerValue;
            size_t bytes = count * sizeof(float);
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
            memset([buffer contents], gPattern, bytes);
            MPSGraphTensorData *destination = [[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:t.shape
                                                                                 dataType:MPSDataTypeFloat32];
            MPSGraphExecutable *executable = [graph compileWithDevice:gGraphDevice feeds:feeds targetTensors:@[t]
                                                   targetOperations:@[] compilationDescriptor:nil];
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:inputs resultsArray:@[destination] executionDescriptor:nil];
            put(q, buffer, bytes);
            return 0;
        }
        // THE BLOCK-MOVING FAMILY of 15.0 and 16.1 - the space-to-depth and depth-to-space of 15.0 and the
        // space-to-batch and batch-to-space of 16.1 - and every question of theirs a case cannot ask. They
        // are four methods and FOUR OPERATIONS to the release, and each operation refuses in its own words
        // and at its own moment: an axis outside the rank is refused where the GRAPH is built, with the
        // result's shape nil, while a degenerate pair of axes and a block that does not divide are refused
        // where the graph is COMPILED, after the release has built a result of a shape of its own. Both
        // moments are printed, so a refusal that moved is a refusal this file no longer describes.
        if (strncmp(q, "block-", 6) == 0) {
            NSString *question = [NSString stringWithUTF8String:q];
            MPSGraph *graph = [MPSGraph new];
            NSArray<NSNumber *> *threeByFourBySix = @[@3, @4, @6];
            NSArray<NSNumber *> *twelveByTwoByThree = @[@12, @2, @3];
            NSArray<NSNumber *> *eightByTwoByTwo = @[@8, @2, @2];
            // THE FED PAIR of 15.0 is four operands: the tensor and its three axes. Over a CONSTANT of one
            // number the release answers exactly what the written-down axes answer, so the questions here are
            // the fed forms' own - a placeholder, a constant of no rank, and a constant of two numbers.
            if (strstr(q, "fed-axis")) {
                int32_t axis[4] = { 2, 1, 0, 2 };
                // A constant of NO RANK is not constructible at all: the release's own +constantWithData:
                // shape:dataType: takes the process down, so the question is that call and nothing else.
                if (strstr(q, "unranked")) {
                    printf("%s about to make an unranked constant\n", question.UTF8String); fflush(stdout);
                    [graph constantWithData:[NSData dataWithBytes:axis length:sizeof axis]
                                     shape:@[] dataType:MPSDataTypeInt32];
                    return 0;
                }
                // A constant of MORE THAN ONE NUMBER builds the graph and leaves the result with no shape,
                // and a PLACEHOLDER does the same - which is what these two measure against each other,
                // because the shape the caller would run into is the shape of the written-down form.
                if (strstr(q, "two-numbers")) {
                    MPSGraphTensor *operand = [graph placeholderWithShape:threeByFourBySix
                                                                  dataType:MPSDataTypeFloat32 name:@"a"];
                    MPSGraphTensor *wide = [graph constantWithData:[NSData dataWithBytes:axis length:sizeof axis]
                                                           shape:@[@2] dataType:MPSDataTypeInt32];
                    MPSGraphTensor *t = [graph spaceToDepth2DTensor:operand widthAxisTensor:wide
                                                  heightAxisTensor:wide depthAxisTensor:wide blockSize:2
                                           usePixelShuffleOrder:NO name:@"s"];
                    printf("%s result-shape %s\n", question.UTF8String,
                           t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
                    return 0;
                }
                // WHAT THE RELEASE'S OWN VERIFIER WANTS OF A FED AXIS TENSOR, which is a rule about the
                // tensor and not about its value and which the port asks where the graph is built: one
                // number, of an index type. A fed float32 axis and a fed placeholder of two numbers are each
                // refused there, before anything is compiled.
                if (strstr(q, "float32") || strstr(q, "two-fed-numbers")) {
                    // Asked through multi() and not by building and printing, because these two are refused
                    // where the graph is COMPILED rather than built: measured, the result tensor comes back
                    // with no shape at all and it is -compileWithDevice: that takes the process down.
                    MPSDataType type = strstr(q, "float32") ? MPSDataTypeFloat32 : MPSDataTypeInt32;
                    NSArray<NSNumber *> *shape = strstr(q, "float32") ? @[@1] : @[@2];
                    // Each axis is fed its own number, in a buffer of the width the axis tensor declares: the
                    // release reads the axis out of the caller's own buffer and refuses a short one in its own
                    // NDArray ("buffer is not large enough. Must be 8 bytes"), which would be this question's
                    // harness and not the release's answer to the pair.
                    int32_t fed[3][2] = { { 2, 2 }, { 1, 1 }, { 0, 0 } };
                    NSMutableArray *values = [NSMutableArray array];
                    [values addObject:[NSData dataWithBytes:wideFeed length:72 * sizeof(float)]];
                    for (int i = 0; i < 3; i++)
                        [values addObject:[NSData dataWithBytes:fed[i] length:sizeof fed[i]]];
                    multi(^(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g spaceToDepth2DTensor:in[0] widthAxisTensor:in[1] heightAxisTensor:in[2]
                                        depthAxisTensor:in[3] blockSize:2 usePixelShuffleOrder:NO name:@"s"]; },
                          @[threeByFourBySix, shape, shape, shape], values,
                          @[@(MPSDataTypeFloat32), @(type), @(type), @(type)], twelveByTwoByThree, q);
                    return 0;
                }
                // THE DEPTH-TO-SPACE over three fed axes, which the previous pass recorded as measured not to
                // return within 300 s and which answers: the graph builds with the result carrying no shape,
                // the compile hands back an executable, the run writes the written-down form's values into the
                // destination the caller gave it, and the process exits 0. Measured under a timeout of 120 s in
                // a probe of its own (.agent-work/probe/fedrun.m of the band that measured it), five runs of
                // it byte for byte the same, so the hang was never this question's answer.
                if (strstr(q, "depth-to-space")) {
                    int32_t w = 2, h = 1, d = 0;
                    MPSGraphTensor *operand = [graph placeholderWithShape:twelveByTwoByThree
                                                                  dataType:MPSDataTypeFloat32 name:@"a"];
                    MPSGraphTensor *widthT = [graph placeholderWithShape:@[@1] dataType:MPSDataTypeInt32 name:@"x"];
                    MPSGraphTensor *heightT = [graph placeholderWithShape:@[@1] dataType:MPSDataTypeInt32 name:@"x"];
                    MPSGraphTensor *depthT = [graph placeholderWithShape:@[@1] dataType:MPSDataTypeInt32 name:@"x"];
                    MPSGraphTensor *t = [graph depthToSpace2DTensor:operand widthAxisTensor:widthT
                                                 heightAxisTensor:heightT depthAxisTensor:depthT blockSize:2
                                              usePixelShuffleOrder:NO name:@"n"];
                    printf("%s result-shape %s\n", question.UTF8String,
                           t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
                    fflush(stdout);
                    multi(^(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g depthToSpace2DTensor:in[0] widthAxisTensor:in[1] heightAxisTensor:in[2]
                                        depthAxisTensor:in[3] blockSize:2 usePixelShuffleOrder:NO name:@"n"]; },
                          @[twelveByTwoByThree, @[@1], @[@1], @[@1]],
                          @[[NSData dataWithBytes:wideFeed length:72 * sizeof(float)],
                            [NSData dataWithBytes:&w length:sizeof w],
                            [NSData dataWithBytes:&h length:sizeof h],
                            [NSData dataWithBytes:&d length:sizeof d]],
                          @[@(MPSDataTypeFloat32), @(MPSDataTypeInt32), @(MPSDataTypeInt32), @(MPSDataTypeInt32)],
                          threeByFourBySix, q);
                    return 0;
                }
                // THE AXES A RUN IS REFUSED OVER, or answered wrongly by: the graph builds and the compile hands
                // back an executable in every one of them, and it is the run that finds out.
                if (strstr(q, "outside-at-run") || strstr(q, "int64-at-run") || strstr(q, "degenerate-at-run")
                    || strstr(q, "block3-at-run")) {
                    // What each question asks, and each over the axes it names and no other: a width axis
                    // outside the rank, which takes the process down in the RUN; the same three axes as int64,
                    // which the release takes and answers exactly as it answers int32; the depth axis among
                    // the two spatial ones; and a block of 3 over a height of 4. The last two are the two the
                    // release answers with a buffer it flags as an error in the same breath, and they are here
                    // because the port refuses them where the graph runs and a reader has to see what it
                    // refuses.
                    BOOL wide = strstr(q, "int64-at-run") != NULL;
                    int64_t wide64[3] = { 2, 1, 0 };
                    int32_t narrow[3] = { 3, 1, 0 };
                    if (strstr(q, "degenerate-at-run")) { narrow[0] = 2; narrow[1] = 1; narrow[2] = 1; }
                    if (strstr(q, "block3-at-run")) { narrow[0] = 2; narrow[1] = 1; narrow[2] = 0; }
                    NSUInteger block = strstr(q, "block3-at-run") ? 3 : 2;
                    NSArray<NSNumber *> *axisShape = @[@1];
                    NSMutableArray *values = [NSMutableArray array];
                    [values addObject:[NSData dataWithBytes:wideFeed length:72 * sizeof(float)]];
                    for (int i = 0; i < 3; i++)
                        [values addObject:[NSData dataWithBytes:wide ? (const void *)&wide64[i]
                                                                 : (const void *)&narrow[i]
                                                         length:wide ? sizeof(int64_t) : sizeof(int32_t)]];
                    multi(^(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                              return [g spaceToDepth2DTensor:in[0] widthAxisTensor:in[1] heightAxisTensor:in[2]
                                        depthAxisTensor:in[3] blockSize:block usePixelShuffleOrder:NO name:@"s"]; },
                          @[threeByFourBySix, axisShape, axisShape, axisShape], values,
                          @[@(MPSDataTypeFloat32),
                            @(wide ? MPSDataTypeInt64 : MPSDataTypeInt32),
                            @(wide ? MPSDataTypeInt64 : MPSDataTypeInt32),
                            @(wide ? MPSDataTypeInt64 : MPSDataTypeInt32)],
                          twelveByTwoByThree, q);
                    return 0;
                }
                // The three axes of 2, 1 and 0, ONE EACH: the release reads all three where the graph runs, so
                // handing the same value to all three is not the same question as handing each its own.
                int32_t width2[1] = { 2 }, height1[1] = { 1 }, depth0[1] = { 0 };
                multi(^MPSGraphTensor *(MPSGraph *g, NSArray<MPSGraphTensor *> *in) {
                          return [g spaceToDepth2DTensor:in[0] widthAxisTensor:in[1] heightAxisTensor:in[2]
                                    depthAxisTensor:in[3] blockSize:2 usePixelShuffleOrder:NO name:@"s"]; },
                      @[threeByFourBySix, @[@1], @[@1], @[@1]],
                      @[[NSData dataWithBytes:wideFeed length:72 * sizeof(float)],
                        [NSData dataWithBytes:width2 length:sizeof width2],
                        [NSData dataWithBytes:height1 length:sizeof height1],
                        [NSData dataWithBytes:depth0 length:sizeof depth0]],
                      @[@(MPSDataTypeFloat32), @(MPSDataTypeInt32), @(MPSDataTypeInt32), @(MPSDataTypeInt32)],
                      twelveByTwoByThree, q);
                return 0;
            }
            // And the WRITTEN-DOWN forms, which is where the two operations' own sentences live.
            MPSGraphTensor *operand = [graph placeholderWithShape:threeByFourBySix dataType:MPSDataTypeFloat32
                                                             name:@"a"];
            MPSGraphTensor *shallow = [graph placeholderWithShape:twelveByTwoByThree
                                                         dataType:MPSDataTypeFloat32 name:@"b"];
            MPSGraphTensor *cube = [graph placeholderWithShape:eightByTwoByTwo dataType:MPSDataTypeFloat32
                                                         name:@"c"];
            MPSGraphTensor *t = nil;
            if (strstr(q, "s2b-axis-outside"))
                t = [graph spaceToBatchTensor:operand spatialAxes:@[@3] batchAxis:0
                              blockDimensions:@[@2] usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "s2b-axis-duplicate"))
                t = [graph spaceToBatchTensor:operand spatialAxes:@[@1, @1] batchAxis:0
                              blockDimensions:@[@2, @2] usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "s2b-batch-among-spatial"))
                t = [graph spaceToBatchTensor:operand spatialAxes:@[@0, @1] batchAxis:0
                              blockDimensions:@[@2, @2] usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "s2b-block-list-short"))
                t = [graph spaceToBatchTensor:operand spatialAxes:@[@1, @2] batchAxis:0
                              blockDimensions:@[@2] usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "s2b-block-does-not-divide"))
                t = [graph spaceToBatchTensor:operand spatialAxes:@[@1, @2] batchAxis:0
                              blockDimensions:@[@2, @5] usePixelShuffleOrder:NO name:@"s"];
            // THE BATCH AXIS OUTSIDE THE RANK, which the fed pair's own question covers for the 2D form
            // (block-s2d-fed-axis-outside-at-run, at the RUN) and which the GENERAL form had no question for
            // at all: the batch axis is a parameter of its own here, and one outside the rank is refused where
            // the graph is built, in the plan. Both directions, and a negative one outside the rank as well,
            // because the plan counts a negative axis from the end and the sentence says what the release says.
            else if (strstr(q, "s2b-batch-outside"))
                t = [graph spaceToBatchTensor:operand spatialAxes:@[@1, @2] batchAxis:3
                              blockDimensions:@[@2, @2] usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "s2b-batch-negoutside"))
                t = [graph spaceToBatchTensor:operand spatialAxes:@[@1, @2] batchAxis:(NSInteger)-4
                              blockDimensions:@[@2, @2] usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "b2s-batch-outside"))
                t = [graph batchToSpaceTensor:cube spatialAxes:@[@1, @2] batchAxis:3
                              blockDimensions:@[@2, @2] usePixelShuffleOrder:NO name:@"b"];
            else if (strstr(q, "b2s-batch-negoutside"))
                t = [graph batchToSpaceTensor:cube spatialAxes:@[@1, @2] batchAxis:(NSInteger)-4
                              blockDimensions:@[@2, @2] usePixelShuffleOrder:NO name:@"b"];
            else if (strstr(q, "b2s-batch-among-spatial"))
                t = [graph batchToSpaceTensor:cube spatialAxes:@[@0, @1] batchAxis:0
                              blockDimensions:@[@2, @2] usePixelShuffleOrder:NO name:@"b"];
            else if (strstr(q, "b2s-block-list-short"))
                t = [graph batchToSpaceTensor:cube spatialAxes:@[@1, @2] batchAxis:0
                              blockDimensions:@[@2] usePixelShuffleOrder:NO name:@"b"];
            else if (strstr(q, "s2d-axis-outside"))
                t = [graph spaceToDepth2DTensor:operand widthAxis:3 heightAxis:1 depthAxis:0 blockSize:2
                          usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "s2d-axis-negoutside"))
                t = [graph spaceToDepth2DTensor:operand widthAxis:(NSUInteger)-1 heightAxis:1 depthAxis:0
                                       blockSize:2 usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "s2d-degenerate-axes"))
                t = [graph spaceToDepth2DTensor:operand widthAxis:2 heightAxis:1 depthAxis:1 blockSize:2
                          usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "s2d-block-does-not-divide"))
                t = [graph spaceToDepth2DTensor:operand widthAxis:2 heightAxis:1 depthAxis:0 blockSize:3
                          usePixelShuffleOrder:NO name:@"s"];
            else if (strstr(q, "d2s-block-does-not-divide"))
                t = [graph depthToSpace2DTensor:shallow widthAxis:2 heightAxis:1 depthAxis:0 blockSize:3
                          usePixelShuffleOrder:NO name:@"d"];
            printf("%s result-shape %s\n", question.UTF8String,
                   t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
            fflush(stdout);
            NSUInteger count = 1;
            for (NSNumber *d in (t.shape.count ? t.shape : threeByFourBySix)) count *= (NSUInteger)d.integerValue;
            size_t bytes = count * sizeof(float);
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
            memset([buffer contents], gPattern, bytes);
            NSMutableDictionary *feeds = [NSMutableDictionary dictionary];
            NSMutableArray *inputs = [NSMutableArray array];
            for (MPSGraphTensor *one in @[operand, shallow, cube]) {
                if (one.shape == nil) continue;
                feeds[one] = [[MPSGraphShapedType alloc] initWithShape:one.shape dataType:MPSDataTypeFloat32];
                [inputs addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:
                                   [gDevice newBufferWithBytes:wideFeed length:72 * sizeof(float)
                                                        options:MTLResourceStorageModeShared]
                                    shape:one.shape dataType:MPSDataTypeFloat32]];
            }
            MPSGraphExecutable *executable = [graph compileWithDevice:gGraphDevice feeds:feeds
                                                       targetTensors:@[t] targetOperations:@[]
                                              compilationDescriptor:nil];
            if (executable == nil) { printf("  NO EXECUTABLE\n"); return 0; }
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:inputs
                                   resultsArray:@[[[MPSGraphTensorData alloc] initWithMTLBuffer:buffer
                                                                               shape:t.shape
                                                                             dataType:MPSDataTypeFloat32]]
                           executionDescriptor:nil];
            put(q, buffer, bytes);
            return 0;
        }
        // THE SPLIT AND THE COORDINATE ALONG AN AXIS, the two walks of 15.4 that are not gathers, and every
        // question of theirs a case cannot ask because the release takes the process down. A split whose
        // result is SEVERAL tensors is asked here with every result of its own buffer, and a coordinate has
        // no operand at all - which is why the two are one branch with a target count each.
        if (strncmp(q, "nonzero-", 8) == 0) {
            // THE ONE OPERATION OF THIS LIBRARY WHOSE RESULT IS A LIST, so the two things a case cannot ask
            // about it are the shape its result tensor carries and the one destination the release cannot be
            // given. Measured: the result is `-1` by the operand's rank whatever the operand is, and a
            // destination of NO ROWS takes the process down inside the release's own NDArray with "Error:
            // device may not be nil" (MPSNDArray.mm:759) - a zero-length buffer has no device, which is the
            // whole of that refusal. Every other destination is answered, and those answers are the
            // differential's (tests/backports/host/mpsgraph/graph-cases.m, the gather_nonzero family, which
            // asks each of its cases in a process of its own for the reason quoted there).
            NSString *question = [NSString stringWithUTF8String:q];
            MPSGraph *graph = [MPSGraph new];
            MPSGraphTensor *operand = [graph placeholderWithShape:@[@3, @4, @6] dataType:MPSDataTypeFloat32
                                                            name:@"a"];
            MPSGraphTensor *t = [graph nonZeroIndicesOfTensor:operand name:@"nz"];
            printf("%s result-shape %s datatype 0x%x\n", question.UTF8String,
                   t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil", (unsigned)t.dataType);
            fflush(stdout);
            NSArray<NSNumber *> *destination = strstr(q, "no-rows") ? @[@0, @3] : @[@5, @3];
            size_t rows = (size_t)destination.firstObject.unsignedIntegerValue;
            // A zero-length MTLBuffer is no buffer at all, so the case's own allocation keeps four bytes and
            // the DESTINATION's shape is what says the answer has no rows.
            size_t bytes = (rows ? rows * 3 * sizeof(int32_t) : 4);
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
            memset([buffer contents], gPattern, bytes);
            MPSGraphExecutable *executable = [graph compileWithDevice:gGraphDevice
                                                       feeds:@{operand: [[MPSGraphShapedType alloc]
                                                                          initWithShape:@[@3, @4, @6]
                                                                                   dataType:MPSDataTypeFloat32]}
                                                       targetTensors:@[t] targetOperations:@[]
                                              compilationDescriptor:nil];
            printf("%s executable %s\n", question.UTF8String, executable == nil ? "nil" : "built");
            fflush(stdout);
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:@[[[MPSGraphTensorData alloc]
                                                    initWithMTLBuffer:
                                                        [gDevice newBufferWithBytes:wideFeed
                                                                            length:sizeof wideFeed
                                                                           options:MTLResourceStorageModeShared]
                                                             shape:@[@3, @4, @6] dataType:MPSDataTypeFloat32]]
                                   resultsArray:@[[[MPSGraphTensorData alloc] initWithMTLBuffer:buffer
                                                                                       shape:destination
                                                                                    dataType:MPSDataTypeInt32]]
                           executionDescriptor:nil];
            char label[128];
            snprintf(label, sizeof label, "%s-result", q);
            put(label, buffer, bytes);
            return 0;
        }
        if (strncmp(q, "split-", 6) == 0 || strncmp(q, "coord-", 6) == 0) {
            NSArray<NSNumber *> *twoByFour = @[@2, @4];
            NSArray<NSNumber *> *twoByThreeByFour = @[@2, @3, @4];
            NSArray<NSNumber *> *twoByFive = @[@2, @5];
            NSString *question = [NSString stringWithUTF8String:q];
            MPSGraph *graph = [MPSGraph new];
            // A coordinate has NO OPERAND, so its graph carries no placeholder of its own: the only placeholder
            // in it is the fed parameter, and a graph with a second one changes what the release's run pairs
            // its inputs array against - which is measured, and is why this is one branch and not two.
            BOOL coordinate = strncmp(q, "coord-", 6) == 0;
            MPSGraphTensor *operand = coordinate ? nil
                : [graph placeholderWithShape:twoByFour dataType:MPSDataTypeFloat32 name:@"a"];
            NSArray<MPSGraphTensor *> *targets = nil;
            NSUInteger axis = 1;
            // The fed parameter of the two questions that have one, FED as a caller of the fed form would:
            // the value is in the graph's feeds and in the run's inputs array, which is the whole point of a
            // parameter that arrives as data. Left unfed the release refuses at the run with a different
            // sentence of its own ("Unsupported MPS operation mps.placeholder", MPSRuntime.mm:459), which is
            // a refusal of the CALLER's pairing rather than of the form.
            MPSGraphTensorData *fedValue = nil;
            MPSGraphTensor *fedTensor = nil;
            // THE SIZES, written down or fed. @[@1, @1] and @[@3, @3] of a 2x4 along axis 1 do not add up and
            // are refused by the release's own compiler after it has built both result tensors; @[@0, @4]
            // builds the result of no elements and is refused as the results are assembled; @[@1, @-1] takes
            // the process down with SIGSEGV and no word at all; and an axis outside the rank is refused with
            // the same sentence the concatenation's is.
            if (strstr(q, "sizes")) {
                if (strstr(q, "sum-short"))
                    targets = [graph splitTensor:operand splitSizes:@[@1, @1] axis:1 name:@"sp"];
                else if (strstr(q, "sum-long"))
                    targets = [graph splitTensor:operand splitSizes:@[@3, @3] axis:1 name:@"sp"];
                else if (strstr(q, "axis-outside")) {
                    targets = [graph splitTensor:operand splitSizes:@[@1, @1] axis:2 name:@"sp"];
                } else if (strstr(q, "axis-negoutside")) {
                    targets = [graph splitTensor:operand splitSizes:@[@1, @1] axis:-3 name:@"sp"];
                } else if (strstr(q, "zero"))
                    targets = [graph splitTensor:operand splitSizes:@[@0, @4] axis:1 name:@"sp"];
                else if (strstr(q, "negative"))
                    targets = [graph splitTensor:operand splitSizes:@[@1, @(-1)] axis:1 name:@"sp"];
                else if (strstr(q, "fed-placeholder")) {
                    // The sizes fed as a PLACEHOLDER, which is the form the header is written for and which
                    // takes the release down where the graph is BUILT: SIGSEGV, no word, nothing printed.
                    MPSGraphTensor *sizes = [graph placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"s"];
                    printf("%s about to build\n", question.UTF8String); fflush(stdout);
                    targets = [graph splitTensor:operand splitSizesTensor:sizes axis:1 name:@"sp"];
                } else
                    targets = [graph splitTensor:operand splitSizes:@[@1, @3] axis:1 name:@"sp"];
            }
            // THE COUNT, which the release turns into sizes by its own measured rule and refuses when that
            // rule has nothing left for the last one. 4 into 3 and 6 into 4 are the two that are refused
            // while 5 into 3 is not.
            if (strstr(q, "num")) {
                NSUInteger count = 2;
                if (strstr(q, "num3")) count = 3;
                if (strstr(q, "num4")) count = 4;
                if (strstr(q, "num0")) count = 0;
                if (strstr(q, "divisible")) {
                    // An axis of 4 into 3 and one of 6 into 4.
                    operand = [graph placeholderWithShape:twoByFour dataType:MPSDataTypeFloat32 name:@"a"];
                    targets = [graph splitTensor:operand numSplits:3 axis:1 name:@"sp"];
                } else if (strstr(q, "six-into-four")) {
                    // An axis of SIX into four, which the release's own rule refuses because the first three
                    // sizes of ceil(6/4) = 2 already take the whole axis and the last would be zero.
                    MPSGraphTensor *wide = [graph placeholderWithShape:@[@2, @6] dataType:MPSDataTypeFloat32
                                                                    name:@"w"];
                    targets = [graph splitTensor:wide numSplits:4 axis:1 name:@"sp"];
                } else
                    targets = [graph splitTensor:operand numSplits:count axis:1 name:@"sp"];
            }
            // A coordinate's AXIS outside the rank is refused by the release's own compiler with its own
            // operation's name in the sentence, which is neither a split nor a gather.
            if (strstr(q, "coord") || strncmp(q, "coord-", 6) == 0) {
                NSInteger where = 1;
                if (strstr(q, "axis-outside")) where = 3;
                // -4 of a rank of THREE, which is one below the rank: -3 would be axis 0 and answers.
                if (strstr(q, "axis-negoutside")) where = -4;
                if (strstr(q, "rank-one-axis1")) where = 1;
                if (strstr(q, "fed-axis-placeholder")) {
                    MPSGraphTensor *fed = [graph placeholderWithShape:@[@1] dataType:MPSDataTypeInt32 name:@"ax"];
                    printf("%s about to build\n", question.UTF8String); fflush(stdout);
                    targets = @[[graph coordinateAlongAxisTensor:fed withShape:twoByFour name:@"c"]];
                    fedTensor = fed;
                    int32_t one = 1;
                    fedValue = [[MPSGraphTensorData alloc] initWithMTLBuffer:
                                    [gDevice newBufferWithBytes:&one length:sizeof one
                                                     options:MTLResourceStorageModeShared]
                                    shape:@[@1] dataType:MPSDataTypeInt32];
                } else if (strstr(q, "fed-axis-float")) {
                    MPSGraphTensor *fed = [graph placeholderWithShape:@[@1] dataType:MPSDataTypeFloat32 name:@"ax"];
                    targets = @[[graph coordinateAlongAxisTensor:fed withShape:twoByFour name:@"c"]];
                    fedTensor = fed;
                    float one = 1.0f;
                    fedValue = [[MPSGraphTensorData alloc] initWithMTLBuffer:
                                    [gDevice newBufferWithBytes:&one length:sizeof one
                                                     options:MTLResourceStorageModeShared]
                                    shape:@[@1] dataType:MPSDataTypeFloat32];
                } else if (strstr(q, "fed-shape-placeholder")) {
                    MPSGraphTensor *fed = [graph placeholderWithShape:@[@2] dataType:MPSDataTypeInt32 name:@"sh"];
                    targets = @[[graph coordinateAlongAxis:1 withShapeTensor:fed name:@"c"]];
                    fedTensor = fed;
                    int32_t two[2] = { 2, 4 };
                    fedValue = [[MPSGraphTensorData alloc] initWithMTLBuffer:
                                    [gDevice newBufferWithBytes:two length:sizeof two
                                                     options:MTLResourceStorageModeShared]
                                    shape:@[@2] dataType:MPSDataTypeInt32];
                } else if (strstr(q, "zero-extent")) {
                    // A coordinate of a shape with a zero extent: the release BUILDS the result (the shape
                    // line prints 0, or 2x0 for the rank of two) and its own RUN refuses the destination,
                    // because a buffer of no bytes does not exist. So this question is the run.
                    targets = @[[graph coordinateAlongAxis:0 withShape:@[@0] name:@"c"]];
                } else if (strstr(q, "rank-one")) {
                    // An axis of 1 of a rank of one, which the shape line answers and the compiler refuses.
                    targets = @[[graph coordinateAlongAxis:where withShape:@[@5] name:@"c"]];
                } else {
                    targets = @[[graph coordinateAlongAxis:where withShape:twoByThreeByFour name:@"c"]];
                }
            }
            // Whatever the question built, the result's own shapes are printed first: a process that is gone
            // writes nothing this file can match, and the shapes are what the release did answer.
            printf("%s result-shape", question.UTF8String);
            for (MPSGraphTensor *t in targets)
                printf(" %s", t.shape ? [[t.shape componentsJoinedByString:@"x"] UTF8String] : "nil");
            printf("\n");
            fflush(stdout);
            NSMutableDictionary *feeds = [NSMutableDictionary dictionary];
            NSMutableArray *inputs = [NSMutableArray array];
            if (operand != nil) {
                feeds[operand] = [[MPSGraphShapedType alloc] initWithShape:operand.shape dataType:operand.dataType];
                [inputs addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:
                                   [gDevice newBufferWithBytes:rowFeed length:sizeof rowFeed
                                                    options:MTLResourceStorageModeShared]
                                   shape:operand.shape dataType:MPSDataTypeFloat32]];
            }
            // The feed is for the PLACEHOLDER the caller made, which is not the operation's first input: the
            // release holds the fed parameter as a constant of its own (the run's own complaint when it is
            // paired wrongly is "Input feed tensor not found in placeholders, tensor corresponds to
            // operation: mps_constant"), so pairing the value with the caller's own placeholder is the only
            // way a caller can ask this at all.
            if (fedValue != nil && fedTensor != nil) {
                feeds[fedTensor] = [[MPSGraphShapedType alloc] initWithShape:fedValue.shape
                                                                      dataType:fedValue.dataType];
                [inputs addObject:fedValue];
            }
            NSMutableArray *results = [NSMutableArray array];
            NSMutableArray *buffers = [NSMutableArray array];
            for (MPSGraphTensor *t in targets) {
                NSUInteger count = 1;
                for (NSNumber *d in t.shape) count *= (NSUInteger)d.integerValue;
                size_t bytes = count * MPSSizeofMPSDataType(t.dataType);
                id<MTLBuffer> buffer = [gDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
                memset([buffer contents], gPattern, bytes);
                [buffers addObject:buffer];
                [results addObject:[[MPSGraphTensorData alloc] initWithMTLBuffer:buffer shape:t.shape
                                                                        dataType:t.dataType]];
            }
            MPSGraphExecutable *executable = [graph compileWithDevice:gGraphDevice feeds:feeds
                                                       targetTensors:targets targetOperations:@[]
                                              compilationDescriptor:nil];
            if (executable == nil) { printf("  NO EXECUTABLE\n"); return 0; }
            [executable runWithMTLCommandQueue:[gDevice newCommandQueue]
                                  inputsArray:inputs resultsArray:results executionDescriptor:nil];
            for (NSUInteger i = 0; i < buffers.count; i++) {
                char label[128];
                snprintf(label, sizeof label, "%s-result%lu", q, (unsigned long)i);
                put(label, buffers[i], [buffers[i] length]);
            }
            return 0;
        }
        fprintf(stderr, "unknown question '%s'\n", q);
        return 2;
    }
}
