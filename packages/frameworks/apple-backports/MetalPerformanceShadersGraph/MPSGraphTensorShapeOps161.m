#import "RevenantMPSGraph.h"

@implementation MPSGraph (RevenantMPSGraphTensorShape161)

- (MPSGraphTensor *)spaceToBatchTensor:(MPSGraphTensor *)tensor
                          spatialAxes:(NSArray<NSNumber *> *)spatialAxes
                            batchAxis:(NSInteger)batchAxis
                      blockDimensions:(NSArray<NSNumber *> *)blockDimensions
                 usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                 name:(NSString *)name
{
    return [self revenant_mps_blockShuffle:tensor
                                  spatial:spatialAxes ?: @[]
                                    batch:batchAxis
                                    block:blockDimensions ?: @[]
                                  toBatch:YES
                                  shuffle:usePixelShuffleOrder
                                      name:name];
}

- (MPSGraphTensor *)batchToSpaceTensor:(MPSGraphTensor *)tensor
                          spatialAxes:(NSArray<NSNumber *> *)spatialAxes
                            batchAxis:(NSInteger)batchAxis
                      blockDimensions:(NSArray<NSNumber *> *)blockDimensions
                 usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                 name:(NSString *)name
{
    return [self revenant_mps_blockShuffle:tensor
                                  spatial:spatialAxes ?: @[]
                                    batch:batchAxis
                                    block:blockDimensions ?: @[]
                                  toBatch:NO
                                  shuffle:usePixelShuffleOrder
                                      name:name];
}

- (MPSGraphTensor *)spaceToBatchTensor:(MPSGraphTensor *)tensor
                    spatialAxesTensor:(MPSGraphTensor *)spatialAxesTensor
                      batchAxisTensor:(MPSGraphTensor *)batchAxisTensor
                blockDimensionsTensor:(MPSGraphTensor *)blockDimensionsTensor
                 usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                 name:(NSString *)name
{
    return [self revenant_mps_fedBlockShuffle:tensor
                                     spatial:spatialAxesTensor
                                       batch:batchAxisTensor
                                       block:blockDimensionsTensor
                                     toBatch:YES
                                     shuffle:usePixelShuffleOrder
                                         name:name];
}

- (MPSGraphTensor *)batchToSpaceTensor:(MPSGraphTensor *)tensor
                    spatialAxesTensor:(MPSGraphTensor *)spatialAxesTensor
                      batchAxisTensor:(MPSGraphTensor *)batchAxisTensor
                blockDimensionsTensor:(MPSGraphTensor *)blockDimensionsTensor
                 usePixelShuffleOrder:(BOOL)usePixelShuffleOrder
                                 name:(NSString *)name
{
    return [self revenant_mps_fedBlockShuffle:tensor
                                     spatial:spatialAxesTensor
                                       batch:batchAxisTensor
                                       block:blockDimensionsTensor
                                     toBatch:NO
                                     shuffle:usePixelShuffleOrder
                                         name:name];
}

@end
