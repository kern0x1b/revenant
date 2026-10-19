#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphTensorShape154)

- (MPSGraphTensor *)stackTensors:(NSArray<MPSGraphTensor *> *)inputTensors
                            axis:(NSInteger)axis
                            name:(NSString *)name
{
    return [self charon_mps_concat:CharonMPSGraphOperationKindStack
                            tensors:inputTensors ?: @[]
                               axis:axis
                         interleave:NO
                              name:name];
}

- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    NSMutableArray<NSNumber *> *unit = [NSMutableArray array];
    NSUInteger rank = tensor.shape.count;
    for (NSUInteger axis = 0; axis < rank; axis++)
        if (tensor.shape[axis].integerValue == 1)
            [unit addObject:@(axis)];
    return [self charon_mps_gather:CharonMPSGraphOperationKindSqueeze
                             tensor:tensor
                        parameters:@{@"gather": @"squeeze", @"gatherDrop": unit}
                               name:name];
}

- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor
                              axis:(NSInteger)axis
                              name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindSqueeze
                             tensor:tensor
                        parameters:@{@"gather": @"squeeze", @"gatherDrop": @[@(axis)]}
                               name:name];
}

- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor
                              axes:(NSArray<NSNumber *> *)axes
                              name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindSqueeze
                             tensor:tensor
                        parameters:@{@"gather": @"squeeze", @"gatherDrop": axes ?: @[]}
                               name:name];
}

- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor
                        axesTensor:(MPSGraphTensor *)axesTensor
                              name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindSqueeze
                             tensor:tensor
                      fedParameter:axesTensor
                        parameters:@{@"gather": @"squeeze", @"gatherOperand": @"axes"}
                               name:name];
}

- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)tensor
                                  axis:(NSInteger)axis
                                  name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindExpandDims
                             tensor:tensor
                        parameters:@{@"gather": @"expand", @"gatherAdd": @[@(axis)]}
                               name:name];
}

- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)tensor
                                  axes:(NSArray<NSNumber *> *)axes
                                  name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindExpandDims
                             tensor:tensor
                        parameters:@{@"gather": @"expand", @"gatherAdd": axes ?: @[]}
                               name:name];
}

- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)tensor
                            axesTensor:(MPSGraphTensor *)axesTensor
                                  name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindExpandDims
                             tensor:tensor
                      fedParameter:axesTensor
                        parameters:@{@"gather": @"expand", @"gatherOperand": @"axes"}
                               name:name];
}


#pragma mark - the split and the coordinate, the two walks of 15.4 that are not gathers

- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)inputTensor
                                 splitSizes:(NSArray<NSNumber *> *)splitSizes
                                       axis:(NSInteger)axis
                                       name:(NSString *)name
{
    return [self charon_mps_split:inputTensor axis:axis sizes:splitSizes numSplits:0 name:name];
}

- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)inputTensor
                                 numSplits:(NSUInteger)numSplits
                                       axis:(NSInteger)axis
                                       name:(NSString *)name
{
    return [self charon_mps_split:inputTensor axis:axis sizes:nil numSplits:numSplits name:name];
}

- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)inputTensor
                          splitSizesTensor:(MPSGraphTensor *)splitSizesTensor
                                       axis:(NSInteger)axis
                                       name:(NSString *)name
{
    return [self charon_mps_split:inputTensor axis:axis
                           sizes:[self charon_mps_constantShapeOfTensor:splitSizesTensor]
                      numSplits:0
                            name:name];
}

- (MPSGraphTensor *)coordinateAlongAxis:(NSInteger)axis
                              withShape:(NSArray<NSNumber *> *)withShape
                                   name:(NSString *)name
{
    return [self charon_mps_coordinates:axis fedAxis:nil shape:withShape fedShape:nil name:name];
}

- (MPSGraphTensor *)coordinateAlongAxis:(NSInteger)axis
                         withShapeTensor:(MPSGraphTensor *)withShapeTensor
                                   name:(NSString *)name
{
    return [self charon_mps_coordinates:axis fedAxis:nil shape:nil fedShape:withShapeTensor name:name];
}

- (MPSGraphTensor *)coordinateAlongAxisTensor:(MPSGraphTensor *)axisTensor
                                    withShape:(NSArray<NSNumber *> *)withShape
                                         name:(NSString *)name
{
    return [self charon_mps_coordinates:0 fedAxis:axisTensor shape:withShape fedShape:nil name:name];
}

- (MPSGraphTensor *)coordinateAlongAxisTensor:(MPSGraphTensor *)axisTensor
                             withShapeTensor:(MPSGraphTensor *)withShapeTensor
                                         name:(NSString *)name
{
    return [self charon_mps_coordinates:0 fedAxis:axisTensor shape:nil fedShape:withShapeTensor name:name];
}

@end
