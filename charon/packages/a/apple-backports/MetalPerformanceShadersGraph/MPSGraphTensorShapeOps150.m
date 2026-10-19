// MPSGraphTensorShapeOps150.m - the six shape and axis operations that arrived with MPSGraph in 15.0: the
// two flattens, the two broadcasts and the three reverses. From the headers MPSGraphTensorShapeOps.h and
// MPSGraphTensorShapeOps.h's reshape header in the SDK of iOS 16.4, which declare all six, each with its own
// availability note (ios(15.0)).
//
// One object per release: this one names six methods of 15.0 and nothing of any other release. All six are
// one walk in MPSGraphInterpreter14.m - the result is the operand's elements in some other order or extent,
// and which axis of the result each axis of the operand feeds is the whole of the difference - so what is
// here is each method's own rule, and each of those is measured (facts/MetalPerformanceShadersGraph/Core.md):
//
//   - a flatten collapses every axis from the one named on into a single axis: axis 0 of a 2x4 is a 1x8 of the
//     operand's own bytes, axis 1 of a 2x4 is the 2x4 itself, and axis 0 of a 2x3x4 is a 1x24.
//   - a broadcast aligns the operand to the RIGHT of the shape given and wraps each axis that the shape makes
//     wider: a 2x4 into a 4x4 answers each of its rows twice, and into a 2x2x4 answers the 2x4 twice.
//   - a reverse flips the axes it is given and nothing else: axis 1 of a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40)
//     answers (4, 3, 2, 1 | 40, 30, 20, 10), axis 0 answers the two rows the other way round, and no axes at
//     all reverses every axis.

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphTensorShape150)

// The fed form of the reshape, which arrived with 15.0: the shape is a 1D tensor of int32 or int64, so the
// result's own shape is not known until the graph runs and the walk reads it out of the operation's second
// input. Measured, an int32 and an int64 of shape [1] both answer.
- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor
                  withShapeTensor:(MPSGraphTensor *)shapeTensor
                             name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindReshape
                             tensor:tensor
                      fedParameter:shapeTensor
                        parameters:@{@"gather": @"reshape", @"gatherOperand": @"shape"}
                               name:name];
}

// The axis is the caller's and is normalised by the walk: negative counted from the end of the rank, and an
// axis outside it refused there, because the release destroys the process over one.
- (MPSGraphTensor *)flatten2DTensor:(MPSGraphTensor *)tensor
                                axis:(NSInteger)axis
                                name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindFlatten2D
                             tensor:tensor
                        parameters:@{@"gather": @"flatten", @"gatherAxis": @(axis)}
                               name:name];
}

- (MPSGraphTensor *)flatten2DTensor:(MPSGraphTensor *)tensor
                          axisTensor:(MPSGraphTensor *)axisTensor
                                name:(NSString *)name
{
    // The axis is the caller's and it is read when the graph runs, because a fed axis is data: a flatten2D's
    // result is of rank two whatever axis it collapses - the product of the extents before the axis and the
    // product of the rest - so there is nothing to write down here. Measured, an int32 and an int64 axis of
    // shape [1] both answer. The result's own shape is not the operand's either: over a fed axis the
    // release's own tensor carries -1x-1, and that is what the seam below puts on it.
    return [self charon_mps_gather:CharonMPSGraphOperationKindFlatten2D
                             tensor:tensor
                      fedParameter:axisTensor
                        parameters:@{@"gather": @"flatten", @"gatherOperand": @"axis"}
                               name:name];
}

- (MPSGraphTensor *)broadcastTensor:(MPSGraphTensor *)tensor
                            toShape:(NSArray<NSNumber *> *)toShape
                               name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindBroadcast
                             tensor:tensor
                        parameters:@{@"gather": @"broadcast", @"gatherShape": toShape}
                               name:name];
}

- (MPSGraphTensor *)broadcastTensor:(MPSGraphTensor *)tensor
                      toShapeTensor:(MPSGraphTensor *)toShapeTensor
                               name:(NSString *)name
{
    // The shape is fed, so the result's own shape is not known until the graph runs: the walk reads it out of
    // the operand it was given, which is why nothing but the transformation's own name is written down here.
    return [self charon_mps_gather:CharonMPSGraphOperationKindBroadcast
                             tensor:tensor
                      fedParameter:toShapeTensor
                        parameters:@{@"gather": @"broadcast", @"gatherOperand": @"shape"}
                               name:name];
}

- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindReverse
                             tensor:tensor
                        parameters:@{@"gather": @"reverse"}
                               name:name];
}

- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor
                              axes:(NSArray<NSNumber *> *)axes
                              name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindReverse
                             tensor:tensor
                        parameters:@{@"gather": @"reverse", @"gatherAxes": axes ?: @[]}
                               name:name];
}

- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor
                       axesTensor:(MPSGraphTensor *)axesTensor
                              name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindReverse
                             tensor:tensor
                      fedParameter:axesTensor
                        parameters:@{@"gather": @"reverse", @"gatherOperand": @"axes"}
                               name:name];
}

#pragma mark - the space-to-depth family of 15.0: two axes of a block and the axis the blocks go to

// The SPACE-TO-DEPTH of 15.0, which is the general form of 16.1 with two spatial axes and one block size
// for both of them, and every measurement of this family is in
// -charon_mps_blockShuffle:spatial:batch:block:toBatch:shuffle:name: and in
// facts/MetalPerformanceShadersGraph/Core.md. What is here is the 2D form's own rule about ITS two axes:
// widthAxis is the fastest-running dimension WITHIN the block and heightAxis the second, so the general form's
// spatialAxes list is (heightAxis, widthAxis) - measured, the two forms over the same operand and the same
// block answer byte for byte the same values - and the depth axis is where the blocks go.
//
// Measured over a [2, 2, 4] of (1, 2, 3, 4 | 5, 6, 7, 8 | 9, 10, 11, 12 | 13, 14, 15, 16) with widthAxis 2,
// heightAxis 1, depthAxis 0 and a block of 2: the result is an 8x1x2, and with usePixelShuffleOrder=NO it is
// (1, 3 | 9, 11 | 2, 4 | 10, 12 | 5, 7 | 13, 15 | 6, 8 | 14, 16) - the operand's batch coordinate varying
// fastest inside the result's depth axis - and with YES (1, 3 | 2, 4 | 5, 7 | 6, 8 | 9, 11 | 10, 12 | 13, 15 |
// 14, 16), the block's own two values contiguous in it. A block of ONE is the identity (a 2x2x4 of the same
// sixteen values), and the 2D form's refusals are the release's own: an axis outside the rank with the axis's
// name in the sentence ("invalid width_axis (3) for shape of rank 3"), the depth axis among the two spatial
// ones, and a block that does not divide the extent it is a block of ("block_size (4) must be multiple of
// height 2").
- (MPSGraphTensor *)spaceToDepth2DTensor:(MPSGraphTensor *)tensor
                              widthAxis:(NSUInteger)widthAxis
                             heightAxis:(NSUInteger)heightAxis
                              depthAxis:(NSUInteger)depthAxis
                              blockSize:(NSUInteger)blockSize
                   usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                   name:(NSString *)name
{
    return [self charon_mps_blockShuffle:tensor
                                  spatial:@[@(heightAxis), @(widthAxis)]
                                    batch:(NSInteger)depthAxis
                                    block:@[@(blockSize), @(blockSize)]
                                  toBatch:YES
                                  shuffle:usePixelShuffleOrder
                                      name:name];
}

// The DEPTH-TO-SPACE of 15.0, which is the inverse of the space-to-depth above with the same flag: measured,
// a space-to-depth over a [3, 4, 6] and then the depth-to-space of what it built answers 1 to 72 in the
// operand's own order, for both flags.
- (MPSGraphTensor *)depthToSpace2DTensor:(MPSGraphTensor *)tensor
                              widthAxis:(NSUInteger)widthAxis
                             heightAxis:(NSUInteger)heightAxis
                              depthAxis:(NSUInteger)depthAxis
                              blockSize:(NSUInteger)blockSize
                   usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                   name:(NSString *)name
{
    // THE BLOCK RULE IN THE WORDS OF THIS OPERATION, which is not the general form's words for the same
    // rule. Moving the blocks OUT of the batch axis makes the block SQUARED divide the depth axis, and the
    // release says so where it says "Invalid prod(`block_dimensions`)" for the general form: measured over a
    // [12, 2, 3] with a block of 3, it builds the result as a 1x6x9 and refuses when the graph is COMPILED
    // with "'mps.depth_to_space_2d' op block_size (3) squared (9) must be multiple of depth 12". The
    // general form's own sentence is in the seam; this one is the 2D form's, and it lives here with the
    // method of 15.0 that answers with it.
    NSArray<NSNumber *> *operandShape = tensor.shape;
    long long depth = operandShape.count > 0 ? operandShape[(NSUInteger)depthAxis].longLongValue : 0;
    long long square = (long long)blockSize * (long long)blockSize;
    if (blockSize == 0 || (depth % square) != 0) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was given a block of %lu, whose square is %lld, for a depth axis of "
                           @"%lld elements, and this direction makes the block squared divide the depth axis: "
                           @"measured, the release's own compiler refuses it with \"'mps.depth_to_space_2d' op "
                           @"block_size (%lu) squared (%lld) must be multiple of depth %lld\"",
                      name, (unsigned long)blockSize, square, depth, (unsigned long)blockSize, square, depth];
    }
    return [self charon_mps_blockShuffle:tensor
                                  spatial:@[@(heightAxis), @(widthAxis)]
                                    batch:(NSInteger)depthAxis
                                    block:@[@(blockSize), @(blockSize)]
                                  toBatch:NO
                                  shuffle:usePixelShuffleOrder
                                      name:name];
}

// How a tensor is named in the release's own refusal, which prints the MLIR type it lowered to: measured, an
// int32 axis of shape [1] is 'tensor<1xsi32>', a float32 one 'tensor<1xf32>' and a placeholder of two numbers
// 'tensor<2xsi32>'. A data type the release spells another way is named as this port names a data type
// everywhere else, in hex, rather than spelled from a guess.
static NSString *CharonMPSGraphTensorTypeName(MPSGraphTensor *tensor)
{
    NSString *element = nil;
    switch (tensor.dataType) {
        case MPSDataTypeFloat32: element = @"f32"; break;
        case MPSDataTypeFloat16: element = @"f16"; break;
        case MPSDataTypeInt32: element = @"si32"; break;
        case MPSDataTypeInt64: element = @"si64"; break;
        case MPSDataTypeBool: element = @"i1"; break;
        default: break;
    }
    if (element == nil)
        return [NSString stringWithFormat:@"a tensor of data type 0x%x", (unsigned)tensor.dataType];
    return [NSString stringWithFormat:@"tensor<%@x%@>", [tensor.shape componentsJoinedByString:@"x"], element];
}

// WHAT THE RELEASE'S OWN VERIFIER WANTS OF AN AXIS TENSOR THE CALLER FEEDS, which is a rule about the tensor
// and not about its value: one number, of an index type - and both refusals of it are where the release
// refuses them, which is the COMPILE rather than the build (measured: the result tensor comes back with no
// shape at all and it is -compileWithDevice: that takes the process down). This port asks them where the graph
// is built, which is the moment every other extent of this library is asked at and the only moment a graph
// can be refused in:
//   - a fed float32 axis: "'mps.space_to_depth_2d' op operand #1 must be 0D tensor of mps index type values or
//     static-shape defined tensor with shape equal to [1] or unranked tensor of mps index type values, but got
//     'tensor<1xf32>'", exit 134, and nothing is compiled;
//   - a fed placeholder of two numbers: the same sentence with 'tensor<2xsi32>', exit 134;
//   - an int64 axis, fed: taken, like an int32 one, and answered the same - measured over the same [3, 4, 6]
//     and the same three axes, where the fed int64 answers byte for byte what the fed int32 answers.
static void CharonMPSGraphBlockAxisTensor(MPSGraphTensor *tensor, NSString *axisName, NSUInteger operand,
                                          NSString *operation, NSString *name)
{
    MPSDataType type = tensor.dataType;
    NSUInteger rank = tensor.shape.count;
    if (type != MPSDataTypeInt32 && type != MPSDataTypeInt64) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was given its %@ as %@, and an axis is an index rather than a value: "
                           @"measured, the release's own verifier refuses the tensor where the graph is COMPILED "
                           @"with \"'mps.%@' op operand #%lu must be 0D tensor of mps index type values or "
                           @"static-shape defined tensor with shape equal to [1] or unranked tensor of mps index "
                           @"type values, but got '%@'\" (exit 134)", name, axisName,
                       CharonMPSGraphTensorTypeName(tensor), operation, (unsigned long)operand,
                       CharonMPSGraphTensorTypeName(tensor)];
    }
    if (rank != 0 && rank != 1) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was given its %@ as a tensor of %lu axes, and the release's own "
                           @"verifier refuses that where the graph is COMPILED with \"'mps.%@' op operand #%lu "
                           @"must be 0D tensor of mps index type values or static-shape defined tensor with "
                           @"shape equal to [1] or unranked tensor of mps index type values, but got '%@'\" "
                           @"(exit 134)", name, axisName, (unsigned long)rank, operation, (unsigned long)operand,
                       CharonMPSGraphTensorTypeName(tensor)];
    }
}

// The ONE question both the pair's methods ask of their three axis tensors, and the two answers it has. A
// tensor the graph HOLDS - a constant - is read here, when the graph is built, and the written-down forms
// above do the work: measured, a constant of shape [1] answers exactly what the written-down axes answer,
// byte for byte, in both directions and under both flags. A tensor the caller FEEDS is read when the graph
// RUNS, because nothing about the result's type can be known before then: the release builds a graph whose
// result carries no shape, hands back an executable, and its run answers the written-down form's values into
// the destination the caller gave it. Both answers are the same chain of three walks over the same plan,
// which is why there is one plan and both paths go through it.
static MPSGraphTensor *CharonMPSGraphFed2DBlockShuffle(MPSGraph *graph, MPSGraphTensor *tensor,
                                                       MPSGraphTensor *widthTensor, MPSGraphTensor *heightTensor,
                                                       MPSGraphTensor *depthTensor, NSUInteger blockSize,
                                                       BOOL toBatch, BOOL shuffle, NSString *name)
{
    NSArray<NSNumber *> *width = [graph charon_mps_constantShapeOfTensor:widthTensor];
    NSArray<NSNumber *> *height = [graph charon_mps_constantShapeOfTensor:heightTensor];
    NSArray<NSNumber *> *depth = [graph charon_mps_constantShapeOfTensor:depthTensor];
    if (width != nil && height != nil && depth != nil) {
        NSUInteger w = (NSUInteger)width.firstObject.integerValue;
        NSUInteger h = (NSUInteger)height.firstObject.integerValue;
        NSUInteger d = (NSUInteger)depth.firstObject.integerValue;
        return toBatch ? [graph spaceToDepth2DTensor:tensor
                                           widthAxis:w heightAxis:h depthAxis:d blockSize:blockSize
                                usePixelShuffleOrder:shuffle name:name]
                       : [graph depthToSpace2DTensor:tensor
                                           widthAxis:w heightAxis:h depthAxis:d blockSize:blockSize
                                usePixelShuffleOrder:shuffle name:name];
    }
    // ONE FED AXIS IS ENOUGH for the whole chain to be unreadable, so every tensor is asked what the release
    // asks of it: a constant among them is read here, as above, and anything the caller feeds is checked
    // here, where the graph is built, which is where the release refuses it.
    MPSGraphTensor *tensors[3] = { widthTensor, heightTensor, depthTensor };
    for (NSUInteger i = 0; i < 3; i++) {
        NSArray<NSNumber *> *held = [graph charon_mps_constantShapeOfTensor:tensors[i]];
        NSString *axisName = i == 0 ? @"width axis" : (i == 1 ? @"height axis" : @"depth axis");
        if (held != nil && held.count != 1) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given %lu numbers as its %@, and an axis is one of them: "
                               @"measured, the release takes an axis as a 0D tensor or one of shape [1], and "
                               @"over a constant of anything else it builds a result that carries no shape", name,
                       (unsigned long)held.count, axisName];
        }
        if (held == nil)
            CharonMPSGraphBlockAxisTensor(tensors[i], axisName, i + 1,
                                          toBatch ? @"space_to_depth_2d" : @"depth_to_space_2d", name);
    }
    return [graph charon_mps_operation:CharonMPSGraphOperationKindBlockShuffle
                                inputs:@[tensor, widthTensor, heightTensor, depthTensor]
                            parameters:@{@"blockShuffle": @YES,
                                         @"blockShuffleBlock": @(blockSize),
                                         @"blockShuffleToBatch": @(toBatch),
                                         @"blockShuffleShuffle": @(shuffle),
                                         @"resultShapeIsFed": @YES}
                                   name:name];
}

- (MPSGraphTensor *)spaceToDepth2DTensor:(MPSGraphTensor *)tensor
                        widthAxisTensor:(MPSGraphTensor *)widthAxisTensor
                       heightAxisTensor:(MPSGraphTensor *)heightAxisTensor
                        depthAxisTensor:(MPSGraphTensor *)depthAxisTensor
                              blockSize:(NSUInteger)blockSize
                   usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                   name:(NSString *)name
{
    return CharonMPSGraphFed2DBlockShuffle(self, tensor, widthAxisTensor, heightAxisTensor, depthAxisTensor,
                                            blockSize, YES, usePixelShuffleOrder, name);
}

- (MPSGraphTensor *)depthToSpace2DTensor:(MPSGraphTensor *)tensor
                        widthAxisTensor:(MPSGraphTensor *)widthAxisTensor
                       heightAxisTensor:(MPSGraphTensor *)heightAxisTensor
                        depthAxisTensor:(MPSGraphTensor *)depthAxisTensor
                              blockSize:(NSUInteger)blockSize
                   usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                   name:(NSString *)name
{
    return CharonMPSGraphFed2DBlockShuffle(self, tensor, widthAxisTensor, heightAxisTensor, depthAxisTensor,
                                            blockSize, NO, usePixelShuffleOrder, name);
}

@end
