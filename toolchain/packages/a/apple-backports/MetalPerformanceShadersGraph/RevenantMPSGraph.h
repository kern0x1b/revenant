#ifndef MPSGRAPH_REVENANT_H
#define MPSGRAPH_REVENANT_H

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>

#import "../MetalPerformanceShaders/RevenantMPS.h"

#define RevenantMPSGraphRefuse(...) NSLog(__VA_ARGS__)

static inline NSUInteger RevenantMPSGraphElementCount(NSArray<NSNumber *> *shape)
{
    NSUInteger count = 1;
    for (NSNumber *dimension in shape) {
        NSInteger extent = dimension.integerValue;
        count *= (NSUInteger)(extent > 1 ? extent : 1);
    }
    return count;
}

typedef NS_ENUM(NSInteger, RevenantMPSGraphOperationKind) {
    RevenantMPSGraphOperationKindNone = 0,
    RevenantMPSGraphOperationKindPlaceholder,
    RevenantMPSGraphOperationKindConstant,
    RevenantMPSGraphOperationKindAdd,
    RevenantMPSGraphOperationKindSubtract,
    RevenantMPSGraphOperationKindMultiply,
    RevenantMPSGraphOperationKindDivide,
    RevenantMPSGraphOperationKindNegate,
    RevenantMPSGraphOperationKindSquare,
    RevenantMPSGraphOperationKindReciprocal,
    RevenantMPSGraphOperationKindRsqrt,
    RevenantMPSGraphOperationKindSqrt,
    RevenantMPSGraphOperationKindExp,
    RevenantMPSGraphOperationKindLog,
    RevenantMPSGraphOperationKindAbs,
    RevenantMPSGraphOperationKindSign,
    RevenantMPSGraphOperationKindMinimum,
    RevenantMPSGraphOperationKindMaximum,
    RevenantMPSGraphOperationKindClamp,
    RevenantMPSGraphOperationKindIdentity,
    RevenantMPSGraphOperationKindExpBase2,
    RevenantMPSGraphOperationKindExpBase10,
    RevenantMPSGraphOperationKindLogBase2,
    RevenantMPSGraphOperationKindLogBase10,
    RevenantMPSGraphOperationKindSin,
    RevenantMPSGraphOperationKindCos,
    RevenantMPSGraphOperationKindTan,
    RevenantMPSGraphOperationKindSinh,
    RevenantMPSGraphOperationKindCosh,
    RevenantMPSGraphOperationKindTanh,
    RevenantMPSGraphOperationKindAsin,
    RevenantMPSGraphOperationKindAcos,
    RevenantMPSGraphOperationKindAtan,
    RevenantMPSGraphOperationKindAsinh,
    RevenantMPSGraphOperationKindAcosh,
    RevenantMPSGraphOperationKindAtanh,
    RevenantMPSGraphOperationKindErf,
    RevenantMPSGraphOperationKindSignBit,
    RevenantMPSGraphOperationKindFloor,
    RevenantMPSGraphOperationKindCeil,
    RevenantMPSGraphOperationKindRound,
    RevenantMPSGraphOperationKindRint,
    RevenantMPSGraphOperationKindIsNaN,
    RevenantMPSGraphOperationKindIsFinite,
    RevenantMPSGraphOperationKindIsInfinite,
    RevenantMPSGraphOperationKindLogicalNot,
    RevenantMPSGraphOperationKindEqual,
    RevenantMPSGraphOperationKindNotEqual,
    RevenantMPSGraphOperationKindLessThan,
    RevenantMPSGraphOperationKindLessThanOrEqualTo,
    RevenantMPSGraphOperationKindGreaterThan,
    RevenantMPSGraphOperationKindGreaterThanOrEqualTo,
    RevenantMPSGraphOperationKindLogicalAnd,
    RevenantMPSGraphOperationKindLogicalOr,
    RevenantMPSGraphOperationKindLogicalNand,
    RevenantMPSGraphOperationKindLogicalNor,
    RevenantMPSGraphOperationKindLogicalXor,
    RevenantMPSGraphOperationKindLogicalXnor,
    RevenantMPSGraphOperationKindModulo,
    RevenantMPSGraphOperationKindFloorModulo,
    RevenantMPSGraphOperationKindPower,
    RevenantMPSGraphOperationKindAtan2,
    RevenantMPSGraphOperationKindDivisionNoNaN,
    RevenantMPSGraphOperationKindSelect,
    RevenantMPSGraphOperationKindClamp3,
    RevenantMPSGraphOperationKindReLU,
    RevenantMPSGraphOperationKindReLUGradient,
    RevenantMPSGraphOperationKindSigmoid,
    RevenantMPSGraphOperationKindSigmoidGradient,
    RevenantMPSGraphOperationKindReductionSum,
    RevenantMPSGraphOperationKindReductionProduct,
    RevenantMPSGraphOperationKindReductionMaximum,
    RevenantMPSGraphOperationKindReductionMinimum,
    RevenantMPSGraphOperationKindReductionMaximumPropagateNaN,
    RevenantMPSGraphOperationKindReductionMinimumPropagateNaN,
    RevenantMPSGraphOperationKindReductionMean,
    RevenantMPSGraphOperationKindReductionVariance,
    RevenantMPSGraphOperationKindReductionArgMaximum,
    RevenantMPSGraphOperationKindReductionArgMinimum,
    RevenantMPSGraphOperationKindReductionAnd,
    RevenantMPSGraphOperationKindReductionOr,
RevenantMPSGraphOperationKindCumulativeSum,
    RevenantMPSGraphOperationKindCumulativeProduct,
    RevenantMPSGraphOperationKindCumulativeMaximum,
    RevenantMPSGraphOperationKindCumulativeMinimum,
    RevenantMPSGraphOperationKindSlice,
    RevenantMPSGraphOperationKindReshape,
    RevenantMPSGraphOperationKindTranspose,
    RevenantMPSGraphOperationKindSqueeze,
    RevenantMPSGraphOperationKindExpandDims,
    RevenantMPSGraphOperationKindFlatten2D,
    RevenantMPSGraphOperationKindBroadcast,
    RevenantMPSGraphOperationKindReverse,
    RevenantMPSGraphOperationKindConcat,
    RevenantMPSGraphOperationKindStack,
    RevenantMPSGraphOperationKindSplit,
    RevenantMPSGraphOperationKindCoordinates,
    RevenantMPSGraphOperationKindBlockShuffle,
    RevenantMPSGraphOperationKindNonZero
};

@class MPSGraph;
@class MPSGraphTensor;
@class MPSGraphOperation;
@class MPSGraphDevice;
@class MPSGraphExecutable;
@class MPSGraphExecutableExecutionDescriptor;

#import "../MetalPerformanceShaders/RevenantMPS26.h"

@interface MPSGraphObject (RevenantMPSGraph)
@end

@interface MPSGraphExecutable (RevenantMPSGraph)
- (instancetype)initWithGraph:(MPSGraph *)graph
                        device:(MPSGraphDevice *)device
                        feeds:(NSDictionary *)feeds
                 targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
              targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
           executableDescriptor:(MPSGraphExecutableExecutionDescriptor *)executableDescriptor;
- (MPSGraphDevice *)device;
@end

@interface MPSGraphShapedType (RevenantMPSGraph)
- (NSUInteger)rank;
- (NSUInteger)elementCount;
- (NSUInteger)offset;
- (BOOL)isEmpty;
@end

@interface MPSGraphTensorData (RevenantMPSGraph)
- (instancetype)initWithDevice:(MPSGraphDevice *)device
                   elementCount:(NSUInteger)elementCount
                          shape:(NSArray<NSNumber *> *)shape
                       dataType:(MPSDataType)dataType;
- (id<MTLBuffer>)revenant_mps_buffer;
- (void *)revenant_mps_bytes;
- (NSUInteger)revenant_mps_elementCount;
@end

@interface MPSGraphTensor (RevenantMPSGraph)
- (NSUInteger)revenant_mps_index;
- (void)revenant_mps_setShape:(NSArray<NSNumber *> *)shape;
- (NSUInteger)revenant_mps_elementCount;
- (BOOL)isEqualToTensor:(MPSGraphTensor *)tensor;
- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape
                    dataType:(MPSDataType)dataType
                   operation:(MPSGraphOperation *)operation
                       index:(NSUInteger)index;
@end

@interface MPSGraphOperation (RevenantMPSGraph)
- (instancetype)initWithGraph:(MPSGraph *)graph
                         kind:(RevenantMPSGraphOperationKind)kind
                         name:(NSString *)name
                        inputs:(NSArray<MPSGraphTensor *> *)inputs
                       outputs:(NSArray<MPSGraphTensor *> *)outputs;
- (RevenantMPSGraphOperationKind)revenant_mps_kind;
- (NSDictionary *)revenant_mps_parameters;
- (void)revenant_mps_setParameters:(NSDictionary *)parameters;
@end

static inline void RevenantMPSGraphWriteInto(MPSGraphTensor *target, MPSGraphTensorData *value,
                                           MPSGraphTensorData *destination)
{
    void *to = [destination revenant_mps_bytes];
    if (to == NULL) {
        RevenantMPSGraphRefuse(@"MPSGraph: the destination the caller gave the answer of the operation named %@ "
                             @"has no buffer, so that destination is left as it was",
                             [target operation].name);
        return;
    }
    NSUInteger width = MPSSizeofMPSDataType(value.dataType);
    NSUInteger stride = destination.shape.lastObject.unsignedIntegerValue
                      * MPSSizeofMPSDataType(destination.dataType);
    NSUInteger room = [destination revenant_mps_elementCount] * MPSSizeofMPSDataType(destination.dataType);
    if (![[[target operation] revenant_mps_parameters][@"answerFillsDestination"] boolValue]) {
        void *from = [value revenant_mps_bytes];
        if (from == NULL) {
            RevenantMPSGraphRefuse(@"MPSGraph: the answer of the operation named %@ could not be copied into "
                                 @"the destination the caller gave, so that destination is left as it was",
                                 [target operation].name);
            return;
        }
        memcpy(to, from, MIN([value revenant_mps_elementCount] * width, room));
        return;
    }
    NSUInteger rank = value.shape.lastObject.unsignedIntegerValue;
    NSUInteger count = value.shape.firstObject.unsignedIntegerValue;
    NSUInteger rows = stride ? room / stride : 0;
    NSUInteger written = count == 1 ? rows : MIN(count, rows);
    void *from = count ? [value revenant_mps_bytes] : NULL;
    if (count && from == NULL) {
        RevenantMPSGraphRefuse(@"MPSGraph: the answer of the operation named %@ could not be read back to be "
                             @"written into the destination the caller gave, so that destination is left as it "
                             @"was", [target operation].name);
        return;
    }
    for (NSUInteger row = 0; row < rows; row++) {
        char *into = (char *)to + row * stride;
        NSUInteger length = MIN(rank * width, room - row * stride);
        if (row < written)
            memcpy(into, (char *)from + (count == 1 ? 0 : row * rank) * width, length);
        else
            memset(into, 0, length);
    }
}

@interface MPSGraphExecutionDescriptor (RevenantMPSGraph)
- (void)revenant_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
@end

@interface MPSGraphExecutableExecutionDescriptor (RevenantMPSGraph)
- (void)revenant_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
@end

@interface MPSGraphExecutable (RevenantMPSGraphRun)
- (NSArray<MPSGraphTensorData *> *)revenant_mps_walkInputs:(NSArray<MPSGraphTensorData *> *)inputsArray
                                                   results:(NSArray<MPSGraphTensorData *> *)resultsArray
                                        executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)descriptor;
@end

@interface MPSGraphOperation (RevenantMPSGraphWiring)
- (void)revenant_mps_setOutputTensors:(NSArray<MPSGraphTensor *> *)outputs;
@end

@interface MPSGraph (RevenantMPSGraph)
- (MPSGraphTensor *)revenant_mps_operation:(RevenantMPSGraphOperationKind)kind
                                inputs:(NSArray<MPSGraphTensor *> *)inputs
                            parameters:(NSDictionary *)parameters
                                   name:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_reduction:(RevenantMPSGraphOperationKind)kind
                                    axes:(NSArray<NSNumber *> *)axes
                                  tensor:(MPSGraphTensor *)tensor
                             parameters:(NSDictionary *)parameters
                                    name:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_gather:(RevenantMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_gather:(RevenantMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                         fedParameter:(MPSGraphTensor *)fedParameter
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
- (NSArray<NSNumber *> *)revenant_mps_gatherShapeOfTensor:(MPSGraphTensor *)tensor
                                             parameters:(NSDictionary *)parameters
                                                    named:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_concat:(RevenantMPSGraphOperationKind)kind
                               tensors:(NSArray<MPSGraphTensor *> *)tensors
                                  axis:(NSInteger)axis
                            interleave:(BOOL)interleave
                                 name:(NSString *)name;
- (NSArray<NSNumber *> *)revenant_mps_concatShapeOfTensors:(NSArray<MPSGraphTensor *> *)tensors
                                                    axis:(NSInteger)axis
                                              interleave:(BOOL)interleave
                                                stacked:(BOOL)stacked
                                                   named:(NSString *)name;
- (NSArray<MPSGraphTensor *> *)revenant_mps_split:(MPSGraphTensor *)tensor
                                            axis:(NSInteger)axis
                                           sizes:(NSArray<NSNumber *> *)sizes
                                      numSplits:(NSUInteger)numSplits
                                            name:(NSString *)name;
- (NSArray<NSNumber *> *)revenant_mps_splitSizes:(NSArray<NSNumber *> *)written
                                    numSplits:(NSUInteger)numSplits
                                         axis:(NSInteger)axis
                                  ofShape:(NSArray<NSNumber *> *)operandShape
                                       named:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_coordinates:(NSInteger)axis
                                    fedAxis:(MPSGraphTensor *)fedAxis
                                      shape:(NSArray<NSNumber *> *)shape
                                   fedShape:(MPSGraphTensor *)fedShape
                                       name:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_blockShuffle:(MPSGraphTensor *)tensor
                                     spatial:(NSArray<NSNumber *> *)spatial
                                       batch:(NSInteger)batch
                                       block:(NSArray<NSNumber *> *)block
                                     toBatch:(BOOL)toBatch
                                     shuffle:(BOOL)shuffle
                                         name:(NSString *)name;
- (NSDictionary *)revenant_mps_blockShufflePlan:(NSString *)name
                                       ofShape:(NSArray<NSNumber *> *)operandShape
                                       spatial:(NSArray<NSNumber *> *)spatial
                                         batch:(NSInteger)batch
                                         block:(NSArray<NSNumber *> *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle;
- (MPSGraphTensor *)revenant_mps_fedBlockShuffle:(MPSGraphTensor *)tensor
                                       spatial:(MPSGraphTensor *)spatial
                                         batch:(MPSGraphTensor *)batch
                                         block:(MPSGraphTensor *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle
                                           name:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_slice:(RevenantMPSGraphOperationKind)kind
                               inputs:(NSArray<MPSGraphTensor *> *)inputs
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
- (NSArray<NSNumber *> *)revenant_mps_constantShapeOfTensor:(MPSGraphTensor *)tensor;
- (void)revenant_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_scan:(RevenantMPSGraphOperationKind)kind
                               axis:(NSInteger)axis
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name;
- (MPSGraphTensor *)revenant_mps_scan:(RevenantMPSGraphOperationKind)kind
                         axisTensor:(MPSGraphTensor *)axisTensor
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name;
- (void)revenant_mps_runOperation:(MPSGraphOperation *)operation
                          values:(NSMutableDictionary *)values;
- (MPSGraphDevice *)revenant_mps_device;
- (MPSGraphOperation *)revenant_mps_addOperationOfKind:(RevenantMPSGraphOperationKind)kind
                                                name:(NSString *)name
                                              inputs:(NSArray<MPSGraphTensor *> *)inputs
                                             outputs:(NSArray<MPSGraphTensor *> *)outputs
                                           parameters:(NSDictionary *)parameters;
@end

#endif
