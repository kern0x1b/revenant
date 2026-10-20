#import "RevenantMPSGraph.h"

@implementation MPSGraph (RevenantMPSGraphTensorShape150)

- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor
                  withShapeTensor:(MPSGraphTensor *)shapeTensor
                             name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindReshape
                             tensor:tensor
                      fedParameter:shapeTensor
                        parameters:@{@"gather": @"reshape", @"gatherOperand": @"shape"}
                               name:name];
}

- (MPSGraphTensor *)flatten2DTensor:(MPSGraphTensor *)tensor
                                axis:(NSInteger)axis
                                name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindFlatten2D
                             tensor:tensor
                        parameters:@{@"gather": @"flatten", @"gatherAxis": @(axis)}
                               name:name];
}

- (MPSGraphTensor *)flatten2DTensor:(MPSGraphTensor *)tensor
                          axisTensor:(MPSGraphTensor *)axisTensor
                                name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindFlatten2D
                             tensor:tensor
                      fedParameter:axisTensor
                        parameters:@{@"gather": @"flatten", @"gatherOperand": @"axis"}
                               name:name];
}

- (MPSGraphTensor *)broadcastTensor:(MPSGraphTensor *)tensor
                            toShape:(NSArray<NSNumber *> *)toShape
                               name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindBroadcast
                             tensor:tensor
                        parameters:@{@"gather": @"broadcast", @"gatherShape": toShape}
                               name:name];
}

- (MPSGraphTensor *)broadcastTensor:(MPSGraphTensor *)tensor
                      toShapeTensor:(MPSGraphTensor *)toShapeTensor
                               name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindBroadcast
                             tensor:tensor
                      fedParameter:toShapeTensor
                        parameters:@{@"gather": @"broadcast", @"gatherOperand": @"shape"}
                               name:name];
}

- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindReverse
                             tensor:tensor
                        parameters:@{@"gather": @"reverse"}
                               name:name];
}

- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor
                              axes:(NSArray<NSNumber *> *)axes
                              name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindReverse
                             tensor:tensor
                        parameters:@{@"gather": @"reverse", @"gatherAxes": axes ?: @[]}
                               name:name];
}

- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor
                       axesTensor:(MPSGraphTensor *)axesTensor
                              name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindReverse
                             tensor:tensor
                      fedParameter:axesTensor
                        parameters:@{@"gather": @"reverse", @"gatherOperand": @"axes"}
                               name:name];
}

#pragma mark - the space-to-depth family of 15.0: two axes of a block and the axis the blocks go to

- (MPSGraphTensor *)spaceToDepth2DTensor:(MPSGraphTensor *)tensor
                              widthAxis:(NSUInteger)widthAxis
                             heightAxis:(NSUInteger)heightAxis
                              depthAxis:(NSUInteger)depthAxis
                              blockSize:(NSUInteger)blockSize
                   usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                   name:(NSString *)name
{
    return [self revenant_mps_blockShuffle:tensor
                                  spatial:@[@(heightAxis), @(widthAxis)]
                                    batch:(NSInteger)depthAxis
                                    block:@[@(blockSize), @(blockSize)]
                                  toBatch:YES
                                  shuffle:usePixelShuffleOrder
                                      name:name];
}

- (MPSGraphTensor *)depthToSpace2DTensor:(MPSGraphTensor *)tensor
                              widthAxis:(NSUInteger)widthAxis
                             heightAxis:(NSUInteger)heightAxis
                              depthAxis:(NSUInteger)depthAxis
                              blockSize:(NSUInteger)blockSize
                   usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                   name:(NSString *)name
{
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
    return [self revenant_mps_blockShuffle:tensor
                                  spatial:@[@(heightAxis), @(widthAxis)]
                                    batch:(NSInteger)depthAxis
                                    block:@[@(blockSize), @(blockSize)]
                                  toBatch:NO
                                  shuffle:usePixelShuffleOrder
                                      name:name];
}

static NSString *RevenantMPSGraphTensorTypeName(MPSGraphTensor *tensor)
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

static void RevenantMPSGraphBlockAxisTensor(MPSGraphTensor *tensor, NSString *axisName, NSUInteger operand,
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
                       RevenantMPSGraphTensorTypeName(tensor), operation, (unsigned long)operand,
                       RevenantMPSGraphTensorTypeName(tensor)];
    }
    if (rank != 0 && rank != 1) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was given its %@ as a tensor of %lu axes, and the release's own "
                           @"verifier refuses that where the graph is COMPILED with \"'mps.%@' op operand #%lu "
                           @"must be 0D tensor of mps index type values or static-shape defined tensor with "
                           @"shape equal to [1] or unranked tensor of mps index type values, but got '%@'\" "
                           @"(exit 134)", name, axisName, (unsigned long)rank, operation, (unsigned long)operand,
                       RevenantMPSGraphTensorTypeName(tensor)];
    }
}

static MPSGraphTensor *RevenantMPSGraphFed2DBlockShuffle(MPSGraph *graph, MPSGraphTensor *tensor,
                                                       MPSGraphTensor *widthTensor, MPSGraphTensor *heightTensor,
                                                       MPSGraphTensor *depthTensor, NSUInteger blockSize,
                                                       BOOL toBatch, BOOL shuffle, NSString *name)
{
    NSArray<NSNumber *> *width = [graph revenant_mps_constantShapeOfTensor:widthTensor];
    NSArray<NSNumber *> *height = [graph revenant_mps_constantShapeOfTensor:heightTensor];
    NSArray<NSNumber *> *depth = [graph revenant_mps_constantShapeOfTensor:depthTensor];
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
    MPSGraphTensor *tensors[3] = { widthTensor, heightTensor, depthTensor };
    for (NSUInteger i = 0; i < 3; i++) {
        NSArray<NSNumber *> *held = [graph revenant_mps_constantShapeOfTensor:tensors[i]];
        NSString *axisName = i == 0 ? @"width axis" : (i == 1 ? @"height axis" : @"depth axis");
        if (held != nil && held.count != 1) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given %lu numbers as its %@, and an axis is one of them: "
                               @"measured, the release takes an axis as a 0D tensor or one of shape [1], and "
                               @"over a constant of anything else it builds a result that carries no shape", name,
                       (unsigned long)held.count, axisName];
        }
        if (held == nil)
            RevenantMPSGraphBlockAxisTensor(tensors[i], axisName, i + 1,
                                          toBatch ? @"space_to_depth_2d" : @"depth_to_space_2d", name);
    }
    return [graph revenant_mps_operation:RevenantMPSGraphOperationKindBlockShuffle
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
    return RevenantMPSGraphFed2DBlockShuffle(self, tensor, widthAxisTensor, heightAxisTensor, depthAxisTensor,
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
    return RevenantMPSGraphFed2DBlockShuffle(self, tensor, widthAxisTensor, heightAxisTensor, depthAxisTensor,
                                            blockSize, NO, usePixelShuffleOrder, name);
}

@end
