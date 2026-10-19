#ifndef MPSGRAPH_CHARON_H
#define MPSGRAPH_CHARON_H

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>

#import "../MetalPerformanceShaders/CharonMPS.h"

#define CharonMPSGraphRefuse(...) NSLog(__VA_ARGS__)

static inline NSUInteger CharonMPSGraphElementCount(NSArray<NSNumber *> *shape)
{
    NSUInteger count = 1;
    for (NSNumber *dimension in shape) {
        NSInteger extent = dimension.integerValue;
        count *= (NSUInteger)(extent > 1 ? extent : 1);
    }
    return count;
}

typedef NS_ENUM(NSInteger, CharonMPSGraphOperationKind) {
    CharonMPSGraphOperationKindNone = 0,
    CharonMPSGraphOperationKindPlaceholder,
    CharonMPSGraphOperationKindConstant,
    CharonMPSGraphOperationKindAdd,
    CharonMPSGraphOperationKindSubtract,
    CharonMPSGraphOperationKindMultiply,
    CharonMPSGraphOperationKindDivide,
    CharonMPSGraphOperationKindNegate,
    CharonMPSGraphOperationKindSquare,
    CharonMPSGraphOperationKindReciprocal,
    CharonMPSGraphOperationKindRsqrt,
    CharonMPSGraphOperationKindSqrt,
    CharonMPSGraphOperationKindExp,
    CharonMPSGraphOperationKindLog,
    CharonMPSGraphOperationKindAbs,
    CharonMPSGraphOperationKindSign,
    CharonMPSGraphOperationKindMinimum,
    CharonMPSGraphOperationKindMaximum,
    CharonMPSGraphOperationKindClamp,
    CharonMPSGraphOperationKindIdentity,
    CharonMPSGraphOperationKindExpBase2,
    CharonMPSGraphOperationKindExpBase10,
    CharonMPSGraphOperationKindLogBase2,
    CharonMPSGraphOperationKindLogBase10,
    CharonMPSGraphOperationKindSin,
    CharonMPSGraphOperationKindCos,
    CharonMPSGraphOperationKindTan,
    CharonMPSGraphOperationKindSinh,
    CharonMPSGraphOperationKindCosh,
    CharonMPSGraphOperationKindTanh,
    CharonMPSGraphOperationKindAsin,
    CharonMPSGraphOperationKindAcos,
    CharonMPSGraphOperationKindAtan,
    CharonMPSGraphOperationKindAsinh,
    CharonMPSGraphOperationKindAcosh,
    CharonMPSGraphOperationKindAtanh,
    CharonMPSGraphOperationKindErf,
    CharonMPSGraphOperationKindSignBit,
    CharonMPSGraphOperationKindFloor,
    CharonMPSGraphOperationKindCeil,
    CharonMPSGraphOperationKindRound,
    CharonMPSGraphOperationKindRint,
    CharonMPSGraphOperationKindIsNaN,
    CharonMPSGraphOperationKindIsFinite,
    CharonMPSGraphOperationKindIsInfinite,
    CharonMPSGraphOperationKindLogicalNot,
    CharonMPSGraphOperationKindEqual,
    CharonMPSGraphOperationKindNotEqual,
    CharonMPSGraphOperationKindLessThan,
    CharonMPSGraphOperationKindLessThanOrEqualTo,
    CharonMPSGraphOperationKindGreaterThan,
    CharonMPSGraphOperationKindGreaterThanOrEqualTo,
    CharonMPSGraphOperationKindLogicalAnd,
    CharonMPSGraphOperationKindLogicalOr,
    CharonMPSGraphOperationKindLogicalNand,
    CharonMPSGraphOperationKindLogicalNor,
    CharonMPSGraphOperationKindLogicalXor,
    CharonMPSGraphOperationKindLogicalXnor,
    CharonMPSGraphOperationKindModulo,
    CharonMPSGraphOperationKindFloorModulo,
    CharonMPSGraphOperationKindPower,
    CharonMPSGraphOperationKindAtan2,
    CharonMPSGraphOperationKindDivisionNoNaN,
    CharonMPSGraphOperationKindSelect,
    CharonMPSGraphOperationKindClamp3,
    CharonMPSGraphOperationKindReLU,
    CharonMPSGraphOperationKindReLUGradient,
    CharonMPSGraphOperationKindSigmoid,
    CharonMPSGraphOperationKindSigmoidGradient,
    CharonMPSGraphOperationKindReductionSum,
    CharonMPSGraphOperationKindReductionProduct,
    CharonMPSGraphOperationKindReductionMaximum,
    CharonMPSGraphOperationKindReductionMinimum,
    CharonMPSGraphOperationKindReductionMaximumPropagateNaN,
    CharonMPSGraphOperationKindReductionMinimumPropagateNaN,
    CharonMPSGraphOperationKindReductionMean,
    CharonMPSGraphOperationKindReductionVariance,
    CharonMPSGraphOperationKindReductionArgMaximum,
    CharonMPSGraphOperationKindReductionArgMinimum,
    CharonMPSGraphOperationKindReductionAnd,
    CharonMPSGraphOperationKindReductionOr,
CharonMPSGraphOperationKindCumulativeSum,
    CharonMPSGraphOperationKindCumulativeProduct,
    CharonMPSGraphOperationKindCumulativeMaximum,
    CharonMPSGraphOperationKindCumulativeMinimum,
    CharonMPSGraphOperationKindSlice,
    CharonMPSGraphOperationKindReshape,
    CharonMPSGraphOperationKindTranspose,
    CharonMPSGraphOperationKindSqueeze,
    CharonMPSGraphOperationKindExpandDims,
    CharonMPSGraphOperationKindFlatten2D,
    CharonMPSGraphOperationKindBroadcast,
    CharonMPSGraphOperationKindReverse,
    CharonMPSGraphOperationKindConcat,
    CharonMPSGraphOperationKindStack,
    CharonMPSGraphOperationKindSplit,
    CharonMPSGraphOperationKindCoordinates,
    CharonMPSGraphOperationKindBlockShuffle,
    CharonMPSGraphOperationKindNonZero
};

@class MPSGraph;
@class MPSGraphTensor;
@class MPSGraphOperation;
@class MPSGraphDevice;
@class MPSGraphExecutable;
@class MPSGraphExecutableExecutionDescriptor;

#import "../MetalPerformanceShaders/CharonMPS26.h"

@interface MPSGraphObject (CharonMPSGraph)
@end

@interface MPSGraphExecutable (CharonMPSGraph)
- (instancetype)initWithGraph:(MPSGraph *)graph
                        device:(MPSGraphDevice *)device
                        feeds:(NSDictionary *)feeds
                 targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
              targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
           executableDescriptor:(MPSGraphExecutableExecutionDescriptor *)executableDescriptor;
- (MPSGraphDevice *)device;
@end

@interface MPSGraphShapedType (CharonMPSGraph)
- (NSUInteger)rank;
- (NSUInteger)elementCount;
- (NSUInteger)offset;
- (BOOL)isEmpty;
@end

@interface MPSGraphTensorData (CharonMPSGraph)
- (instancetype)initWithDevice:(MPSGraphDevice *)device
                   elementCount:(NSUInteger)elementCount
                          shape:(NSArray<NSNumber *> *)shape
                       dataType:(MPSDataType)dataType;
- (id<MTLBuffer>)charon_mps_buffer;
- (void *)charon_mps_bytes;
- (NSUInteger)charon_mps_elementCount;
@end

@interface MPSGraphTensor (CharonMPSGraph)
- (NSUInteger)charon_mps_index;
- (void)charon_mps_setShape:(NSArray<NSNumber *> *)shape;
- (NSUInteger)charon_mps_elementCount;
- (BOOL)isEqualToTensor:(MPSGraphTensor *)tensor;
- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape
                    dataType:(MPSDataType)dataType
                   operation:(MPSGraphOperation *)operation
                       index:(NSUInteger)index;
@end

@interface MPSGraphOperation (CharonMPSGraph)
- (instancetype)initWithGraph:(MPSGraph *)graph
                         kind:(CharonMPSGraphOperationKind)kind
                         name:(NSString *)name
                        inputs:(NSArray<MPSGraphTensor *> *)inputs
                       outputs:(NSArray<MPSGraphTensor *> *)outputs;
- (CharonMPSGraphOperationKind)charon_mps_kind;
- (NSDictionary *)charon_mps_parameters;
- (void)charon_mps_setParameters:(NSDictionary *)parameters;
@end

static inline void CharonMPSGraphWriteInto(MPSGraphTensor *target, MPSGraphTensorData *value,
                                           MPSGraphTensorData *destination)
{
    void *to = [destination charon_mps_bytes];
    if (to == NULL) {
        CharonMPSGraphRefuse(@"MPSGraph: the destination the caller gave the answer of the operation named %@ "
                             @"has no buffer, so that destination is left as it was",
                             [target operation].name);
        return;
    }
    NSUInteger width = MPSSizeofMPSDataType(value.dataType);
    NSUInteger stride = destination.shape.lastObject.unsignedIntegerValue
                      * MPSSizeofMPSDataType(destination.dataType);
    NSUInteger room = [destination charon_mps_elementCount] * MPSSizeofMPSDataType(destination.dataType);
    if (![[[target operation] charon_mps_parameters][@"answerFillsDestination"] boolValue]) {
        void *from = [value charon_mps_bytes];
        if (from == NULL) {
            CharonMPSGraphRefuse(@"MPSGraph: the answer of the operation named %@ could not be copied into "
                                 @"the destination the caller gave, so that destination is left as it was",
                                 [target operation].name);
            return;
        }
        memcpy(to, from, MIN([value charon_mps_elementCount] * width, room));
        return;
    }
    NSUInteger rank = value.shape.lastObject.unsignedIntegerValue;
    NSUInteger count = value.shape.firstObject.unsignedIntegerValue;
    NSUInteger rows = stride ? room / stride : 0;
    NSUInteger written = count == 1 ? rows : MIN(count, rows);
    void *from = count ? [value charon_mps_bytes] : NULL;
    if (count && from == NULL) {
        CharonMPSGraphRefuse(@"MPSGraph: the answer of the operation named %@ could not be read back to be "
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

@interface MPSGraphExecutionDescriptor (CharonMPSGraph)
- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
@end

@interface MPSGraphExecutableExecutionDescriptor (CharonMPSGraph)
- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
@end

@interface MPSGraphExecutable (CharonMPSGraphRun)
- (NSArray<MPSGraphTensorData *> *)charon_mps_walkInputs:(NSArray<MPSGraphTensorData *> *)inputsArray
                                                   results:(NSArray<MPSGraphTensorData *> *)resultsArray
                                        executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)descriptor;
@end

@interface MPSGraphOperation (CharonMPSGraphWiring)
- (void)charon_mps_setOutputTensors:(NSArray<MPSGraphTensor *> *)outputs;
@end

@interface MPSGraph (CharonMPSGraph)
- (MPSGraphTensor *)charon_mps_operation:(CharonMPSGraphOperationKind)kind
                                inputs:(NSArray<MPSGraphTensor *> *)inputs
                            parameters:(NSDictionary *)parameters
                                   name:(NSString *)name;
- (MPSGraphTensor *)charon_mps_reduction:(CharonMPSGraphOperationKind)kind
                                    axes:(NSArray<NSNumber *> *)axes
                                  tensor:(MPSGraphTensor *)tensor
                             parameters:(NSDictionary *)parameters
                                    name:(NSString *)name;
- (MPSGraphTensor *)charon_mps_gather:(CharonMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
- (MPSGraphTensor *)charon_mps_gather:(CharonMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                         fedParameter:(MPSGraphTensor *)fedParameter
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
- (NSArray<NSNumber *> *)charon_mps_gatherShapeOfTensor:(MPSGraphTensor *)tensor
                                             parameters:(NSDictionary *)parameters
                                                    named:(NSString *)name;
- (MPSGraphTensor *)charon_mps_concat:(CharonMPSGraphOperationKind)kind
                               tensors:(NSArray<MPSGraphTensor *> *)tensors
                                  axis:(NSInteger)axis
                            interleave:(BOOL)interleave
                                 name:(NSString *)name;
- (NSArray<NSNumber *> *)charon_mps_concatShapeOfTensors:(NSArray<MPSGraphTensor *> *)tensors
                                                    axis:(NSInteger)axis
                                              interleave:(BOOL)interleave
                                                stacked:(BOOL)stacked
                                                   named:(NSString *)name;
- (NSArray<MPSGraphTensor *> *)charon_mps_split:(MPSGraphTensor *)tensor
                                            axis:(NSInteger)axis
                                           sizes:(NSArray<NSNumber *> *)sizes
                                      numSplits:(NSUInteger)numSplits
                                            name:(NSString *)name;
- (NSArray<NSNumber *> *)charon_mps_splitSizes:(NSArray<NSNumber *> *)written
                                    numSplits:(NSUInteger)numSplits
                                         axis:(NSInteger)axis
                                  ofShape:(NSArray<NSNumber *> *)operandShape
                                       named:(NSString *)name;
- (MPSGraphTensor *)charon_mps_coordinates:(NSInteger)axis
                                    fedAxis:(MPSGraphTensor *)fedAxis
                                      shape:(NSArray<NSNumber *> *)shape
                                   fedShape:(MPSGraphTensor *)fedShape
                                       name:(NSString *)name;
- (MPSGraphTensor *)charon_mps_blockShuffle:(MPSGraphTensor *)tensor
                                     spatial:(NSArray<NSNumber *> *)spatial
                                       batch:(NSInteger)batch
                                       block:(NSArray<NSNumber *> *)block
                                     toBatch:(BOOL)toBatch
                                     shuffle:(BOOL)shuffle
                                         name:(NSString *)name;
- (NSDictionary *)charon_mps_blockShufflePlan:(NSString *)name
                                       ofShape:(NSArray<NSNumber *> *)operandShape
                                       spatial:(NSArray<NSNumber *> *)spatial
                                         batch:(NSInteger)batch
                                         block:(NSArray<NSNumber *> *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle;
- (MPSGraphTensor *)charon_mps_fedBlockShuffle:(MPSGraphTensor *)tensor
                                       spatial:(MPSGraphTensor *)spatial
                                         batch:(MPSGraphTensor *)batch
                                         block:(MPSGraphTensor *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle
                                           name:(NSString *)name;
- (MPSGraphTensor *)charon_mps_slice:(CharonMPSGraphOperationKind)kind
                               inputs:(NSArray<MPSGraphTensor *> *)inputs
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
- (NSArray<NSNumber *> *)charon_mps_constantShapeOfTensor:(MPSGraphTensor *)tensor;
- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
- (MPSGraphTensor *)charon_mps_scan:(CharonMPSGraphOperationKind)kind
                               axis:(NSInteger)axis
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name;
- (MPSGraphTensor *)charon_mps_scan:(CharonMPSGraphOperationKind)kind
                         axisTensor:(MPSGraphTensor *)axisTensor
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name;
- (void)charon_mps_runOperation:(MPSGraphOperation *)operation
                          values:(NSMutableDictionary *)values;
- (MPSGraphDevice *)charon_mps_device;
- (MPSGraphOperation *)charon_mps_addOperationOfKind:(CharonMPSGraphOperationKind)kind
                                                name:(NSString *)name
                                              inputs:(NSArray<MPSGraphTensor *> *)inputs
                                             outputs:(NSArray<MPSGraphTensor *> *)outputs
                                           parameters:(NSDictionary *)parameters;
@end

#endif
