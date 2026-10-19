// CharonMPSGraph.h - what this framework's own files share.
//
// The guard is not decoration: the host harness includes this header twice over, once through a
// source's own import and once through its prefixed declarations, and a header that declares classes
// has to survive that.
//
// A graph is a description of work and a tensor is a description of a result; the arithmetic happens
// when the graph runs, over the host memory behind an MTLBuffer, exactly as the matrix kernels in
// ../MetalPerformanceShaders do (facts/MetalPerformanceShaders/Matrix.md). Nothing here needs a
// texture, so none of it waits on the pixel formats.
//
// The interpreter is a table: an operation records what it is and what its operands are, and
// -[MPSGraph runWithFeeds:targetTensors:targetOperations:] walks the operations in the order they were
// added, asking each one to fill its outputs. A tensor's value is found by looking it up: a
// placeholder's comes from the feeds, any other one's from the operation that produced it.

#ifndef MPSGRAPH_CHARON_H
#define MPSGRAPH_CHARON_H

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>

// The matrix framework's own header already says what an MPSDataType means and how an element is read
// and written, so including it here means one definition rather than two.
#import "../MetalPerformanceShaders/CharonMPS.h"

// A graph that cannot run says so once, in the log, naming what it could not do, and writes nothing:
// an operation the release would have faulted on leaves its output alone here rather than filling it
// with something of another kind's meaning.
#define CharonMPSGraphRefuse(...) NSLog(__VA_ARGS__)

// The number of elements a tensor of a shape holds. A dimension below one is taken as one, which is
// what a scalar's empty shape and a degenerate extent both come to.
static inline NSUInteger CharonMPSGraphElementCount(NSArray<NSNumber *> *shape)
{
    NSUInteger count = 1;
    for (NSNumber *dimension in shape) {
        NSInteger extent = dimension.integerValue;
        count *= (NSUInteger)(extent > 1 ? extent : 1);
    }
    return count;
}

// What an operation is, which is how the interpreter knows what to run. One case per family, so a
// family lands by adding a case and a function rather than by touching every other one.
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
    // The transcendentals and the rounding of the 14.0 arithmetic family. Each is the C function of
    // that name and nothing else: what the release answers for a zero, a negative and an infinity is
    // measured per case in tests/backports/host/mpsgraph, and what it answers that IEEE does not is in
    // facts/MetalPerformanceShadersGraph/Core.md.
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
    // The three questions about a value that are not arithmetic, and the three that are a predicate:
    // isNaN, isFinite and isInfinite are the three of them, and they are the three whose result is a
    // boolean rather than a number. Measured on this host's own MPSGraph over a rank-3 float32
    // operand: a comparison, a less-than and isNaN answer MPSDataTypeBool (0x80000008, one byte an
    // element), and logicalAND, not and signbit answer the operand's own type. Both are in
    // facts/MetalPerformanceShadersGraph/Core.md.
    CharonMPSGraphOperationKindIsNaN,
    CharonMPSGraphOperationKindIsFinite,
    CharonMPSGraphOperationKindIsInfinite,
    CharonMPSGraphOperationKindLogicalNot,
    // The predicates over two operands. The same measurement as the three above: all six are a
    // boolean.
    CharonMPSGraphOperationKindEqual,
    CharonMPSGraphOperationKindNotEqual,
    CharonMPSGraphOperationKindLessThan,
    CharonMPSGraphOperationKindLessThanOrEqualTo,
    CharonMPSGraphOperationKindGreaterThan,
    CharonMPSGraphOperationKindGreaterThanOrEqualTo,
    // The logical family over two operands, which answers the operand's own type and not a boolean -
    // the same measurement as logicalAND above.
    CharonMPSGraphOperationKindLogicalAnd,
    CharonMPSGraphOperationKindLogicalOr,
    CharonMPSGraphOperationKindLogicalNand,
    CharonMPSGraphOperationKindLogicalNor,
    CharonMPSGraphOperationKindLogicalXor,
    CharonMPSGraphOperationKindLogicalXnor,
    // The two arithmetic operations that are not IEEE, and the three that take a third operand.
    CharonMPSGraphOperationKindModulo,
    CharonMPSGraphOperationKindFloorModulo,
    CharonMPSGraphOperationKindPower,
    CharonMPSGraphOperationKindAtan2,
    CharonMPSGraphOperationKindDivisionNoNaN,
    CharonMPSGraphOperationKindSelect,
    CharonMPSGraphOperationKindClamp3,
    // The activations, and the two of the four that are their own gradient: a ReLU gradient reads the
    // source as well as the incoming gradient, and so does a sigmoid's.
    CharonMPSGraphOperationKindReLU,
    CharonMPSGraphOperationKindReLUGradient,
    CharonMPSGraphOperationKindSigmoid,
    CharonMPSGraphOperationKindSigmoidGradient,
    // The reduction family, which is walked by its own function rather than element by element: a
    // reduction writes one element from many, so the loop is over the operand and not over the result.
    // These eight arrived with the framework in 14.0; the two that arrived in 15.0 and the four that
    // arrived in 15.3 are in the objects of those releases.
    CharonMPSGraphOperationKindReductionSum,
    CharonMPSGraphOperationKindReductionProduct,
    CharonMPSGraphOperationKindReductionMaximum,
    CharonMPSGraphOperationKindReductionMinimum,
    CharonMPSGraphOperationKindReductionMaximumPropagateNaN,
    CharonMPSGraphOperationKindReductionMinimumPropagateNaN,
    CharonMPSGraphOperationKindReductionMean,
    CharonMPSGraphOperationKindReductionVariance,
    // The two argument reductions of 15.0 and the two truth folds of 15.3. An argument reduction is the
    // maximum or the minimum that answers its index rather than its value, and a truth fold answers
    // whether any element of the reduced set is nonzero, or whether every one of them is. The walk over
    // all four is the walk over the family above, and it is told which one it is by the operation's own
    // parameters rather than by which of these it is - see the seam on MPSGraph below.
    CharonMPSGraphOperationKindReductionArgMaximum,
    CharonMPSGraphOperationKindReductionArgMinimum,
    CharonMPSGraphOperationKindReductionAnd,
    CharonMPSGraphOperationKindReductionOr,
    // The cumulative family of 16.0, which is the fold above walked along an axis instead of across a set:
    // the result is the operand's own shape, and each element holds the fold of everything before it or
    // everything after it, in one direction or the other. Which of the four it is, which direction, and
    // whether the element at a position is in its own answer are all parameters of the operation, for the
    // same reason the reduction family's are.
CharonMPSGraphOperationKindCumulativeSum,
    CharonMPSGraphOperationKindCumulativeProduct,
    CharonMPSGraphOperationKindCumulativeMaximum,
    CharonMPSGraphOperationKindCumulativeMinimum,
    // The gather family, which is one walk: the result's shape and, for each of its axes, which axis of the
    // operand feeds it and whether that one is reversed. Which transformation it is (@"gather") is what the
    // walk reads, not which of these it is, for the reason the reduction family's are read the same way.
    CharonMPSGraphOperationKindSlice,
    CharonMPSGraphOperationKindReshape,
    CharonMPSGraphOperationKindTranspose,
    CharonMPSGraphOperationKindSqueeze,
    CharonMPSGraphOperationKindExpandDims,
    CharonMPSGraphOperationKindFlatten2D,
    CharonMPSGraphOperationKindBroadcast,
    CharonMPSGraphOperationKindReverse,
    // The CONCAT family, which is not one walk over ONE operand: its result is several of them laid end to
    // end along one axis, or one new axis that says which of them an element came from. So it is a walk of
    // its own, over every input of the operation, and the operation's own parameters say which of the two it
    // is: the axis of the result the operands are laid along, and whether they interleave along it.
    CharonMPSGraphOperationKindConcat,
    CharonMPSGraphOperationKindStack,
    // The SPLIT, which is the one walk of this library whose result is SEVERAL TENSORS and the only one whose
    // regions are cut OUT of one operand instead of being laid into a result: result i is the operand's own
    // elements from the running total of the sizes before it along one axis. And the COORDINATE ALONG AN AXIS,
    // which is the one walk with no operand at all - its value IS the coordinate, so the only thing the caller
    // gives it is a shape and an axis.
    CharonMPSGraphOperationKindSplit,
    CharonMPSGraphOperationKindCoordinates,
    // The BLOCK-MOVING family over FED axes, which is the one walk of this library whose three shapes are
    // not known when the graph is built: the axes arrive as data, so the split shape, the permutation and
    // the result's own shape are all asked of the same plan when the graph runs - see
    // -charon_mps_blockShufflePlan:ofShape:spatial:batch:block:toBatch:shuffle:.
    CharonMPSGraphOperationKindBlockShuffle,
    // The NON-ZERO INDICES of 17.0, whose result is a LIST: the coordinates of the elements of the operand
    // that are not a zero, one row of the operand's rank per element, in the operand's own row-major order.
    // It is a walk of its own because its result is not the operand's shape and its own LENGTH is not known
    // until the graph runs, which is why the release's own result tensor carries -1 for it (measured over a
    // [3, 4, 6] of 1 to 72: the result is -1x3, of MPSDataTypeInt32, whatever the operand's own type was).
    CharonMPSGraphOperationKindNonZero
};

@class MPSGraph;
@class MPSGraphTensor;
@class MPSGraphOperation;
@class MPSGraphDevice;
@class MPSGraphExecutable;
@class MPSGraphExecutableExecutionDescriptor;

// Four names of the 26.2 surface are in no 16.4 header - MPSGraphObject among them - and they are
// transcribed in ../MetalPerformanceShaders/CharonMPS26.h, which is where the whole set lives now, so
// they are not declared a second time here. That header leaves them out on a host whose own SDK
// already declares them, and keeps them where the SDK the port builds against does not.

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

// HOW AN ANSWER LANDS IN THE TENSOR DATA THE CALLER ALLOCATED, which is the one place in this library that
// knows the DESTINATION's own shape: the interpreter fills a result of its own, and this is where the answer
// is copied into the buffer a caller holds, so both run paths - the executable's and the graph's - end here.
//
// Every family of this library writes every element of its result, so for them this is a copy of the answer
// over the destination, bounded by what the destination holds. ONE family says so in its operation's own
// parameters, @"answerFillsDestination", and is written differently, because what the release's own kernel
// writes there is the whole destination and not the answer's own rows:
//
//   - the answer is `count` rows of the operand's RANK coordinates, and every row of the destination the
//     answer does not reach is a WRITTEN ZERO (measured over a destination filled with the byte 0xbd: a
//     [3, 4, 6] with three non-zero elements leaves none of the seventy-two rows' cells at 0xbd);
//   - an answer of exactly ONE row is written into EVERY row of the destination (measured: a [3, 4, 6] whose
//     only non-zero element is the seventy-second answers (2, 3, 5) in each of a twelve-row and a
//     seventy-two-row destination, and identically on three runs of one executable);
//   - the rows are written `rank` cells apart in the destination's OWN last extent, so a destination whose
//     second axis is four keeps its fifth cell and a destination of rank one has its three cells written
//     into the front of it (measured, both with 0xbd left in every cell the answer did not reach).
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
        // Bounded by what the destination holds: every family here writes a result of the shape its own
        // tensor carries, so this is a copy of the whole of it unless the caller gave a smaller buffer than
        // the answer, and then the answer is cut short rather than the caller's memory overrun.
        memcpy(to, from, MIN([value charon_mps_elementCount] * width, room));
        return;
    }
    // The answer's rows are its own shape's FIRST extent - the count the walk resolved - and not the
    // element count divided by the rank: an answer of NO rows has a shape of [0, rank], and this library
    // takes an extent below one as an extent of one, so the division would read that as one row.
    NSUInteger rank = value.shape.lastObject.unsignedIntegerValue;
    NSUInteger count = value.shape.firstObject.unsignedIntegerValue;
    NSUInteger rows = stride ? room / stride : 0;
    NSUInteger written = count == 1 ? rows : MIN(count, rows);
    // An answer of NO rows has no buffer to read from at all - a tensor data of no elements holds a buffer
    // whose contents is null - and needs none: every row of the destination is a zero.
    void *from = count ? [value charon_mps_bytes] : NULL;
    if (count && from == NULL) {
        CharonMPSGraphRefuse(@"MPSGraph: the answer of the operation named %@ could not be read back to be "
                             @"written into the destination the caller gave, so that destination is left as it "
                             @"was", [target operation].name);
        return;
    }
    // A row is `rank` cells, and the rows start `stride` bytes apart: where the destination's last extent is
    // shorter than the rank, the last row would run past the end of the caller's buffer, so every row is cut
    // at what the destination holds from where it starts.
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
// What a run does with the shared events this descriptor named: at the stage the caller named, every signal
// of that stage writes its value into its event, and every wait must be satisfied or the run is refused.
- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
@end

@interface MPSGraphExecutableExecutionDescriptor (CharonMPSGraph)
// What a run does with the shared events this descriptor named: at the stage the caller named, every signal
// of that stage writes its value into its event, and every wait must be satisfied or the run is refused.
- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
@end

@interface MPSGraphExecutable (CharonMPSGraphRun)
// The walk every run of an executable is, whether the caller came through a Metal command queue or through
// MPSGraph's own command buffer: the executable's own feeds overlaid with the inputs, the graph's walk over
// its operations, the answer written into the tensor data the caller allocated, and the descriptor's shared
// events honoured at the end of it.
- (NSArray<MPSGraphTensorData *> *)charon_mps_walkInputs:(NSArray<MPSGraphTensorData *> *)inputsArray
                                                   results:(NSArray<MPSGraphTensorData *> *)resultsArray
                                        executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)descriptor;
@end

@interface MPSGraphOperation (CharonMPSGraphWiring)
// The output tensors and the parameters are set by the graph as it builds an operation, because they are
// its business rather than a caller's: an operation is made with its inputs and grows its outputs.
- (void)charon_mps_setOutputTensors:(NSArray<MPSGraphTensor *> *)outputs;
@end

@interface MPSGraph (CharonMPSGraph)
// The operation of a kind over the given operands, which is what every factory method in the family
// headers ends up calling. Its result takes the first input's shape and data type unless the parameters
// carry @shape or @dataType of their own, and carries NO shape at all when they carry
// @"resultShapeIsFed": a result whose shape is decided by data that arrives when the graph runs is a
// result the release's own tensor cannot carry a shape for either (measured: over a fed axis the release's
// result tensor has no shape, before the run and after it), and the interpreter puts the shape on when it
// walks the operation.
- (MPSGraphTensor *)charon_mps_operation:(CharonMPSGraphOperationKind)kind
                                inputs:(NSArray<MPSGraphTensor *> *)inputs
                            parameters:(NSDictionary *)parameters
                                   name:(NSString *)name;
// A reduction over a set of axes of one operand: the result's shape is the operand's with those axes
// taken out, which is what every member of the family produces. This is the seam every release's
// reduction factory goes through, and it is deliberately the only one: the 14.0 object that defines it
// names no operation of any later release, because everything the walk needs to know comes in
// `parameters` - the combination to fold with, whether a NaN latches, whether the answer is an index
// rather than a value, and the data type the result is stored as. A release's own factory fills those
// in and names only its own methods.
- (MPSGraphTensor *)charon_mps_reduction:(CharonMPSGraphOperationKind)kind
                                    axes:(NSArray<NSNumber *> *)axes
                                  tensor:(MPSGraphTensor *)tensor
                             parameters:(NSDictionary *)parameters
                                    name:(NSString *)name;
// A GATHER: an operation whose result is the operand's elements in some other order or extent, and whose
// whole behaviour is which source axis each result axis comes from, whether that axis is reversed, and whether
// the coordinate has an element of the operand behind it at all. That is the walk over a reshape, a squeeze,
// an expanded dimension, a flatten, a broadcast, a reverse and a transpose, and it is asked of the
// operation's own parameters - which transformation (@"gather"), the parameter of it the caller wrote down
// (@"gatherAxis", @"gatherDrop", @"gatherAdd", @"gatherShape", @"gatherAxes", @"gatherPermutation") or which of
// the operation's inputs carries it instead (@"gatherOperand") - so every release's factory of the family
// fills those in and names only its own methods, and the result's shape is derived by the walk and put on the
// output tensor: at build time where the plan can be derived then, and when the graph runs otherwise, which
// is what lets a shape the caller FEEDS be one of them.
// A squeeze and an expanded dimension and a flatten are the same gather with the axes left alone:
// measured on this host's own MPSGraph, all three answer the operand's own bytes in the operand's own order.
- (MPSGraphTensor *)charon_mps_gather:(CharonMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
// The same over a parameter the caller feeds at run time rather than writing down - an axis, a set of axes
// or a shape - which becomes the operation's second input and is read by the walk when the graph runs.
- (MPSGraphTensor *)charon_mps_gather:(CharonMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                         fedParameter:(MPSGraphTensor *)fedParameter
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
// The result's shape of such a gather, asked when the graph is BUILT so that the output tensor carries it
// before anything runs: the release infers the result's type at build time - which is why an axis it cannot
// use aborts there - so a caller can read the shape off the tensor it was handed, and this is where the port
// answers that. It is the walk's own plan with the operand's shape and no fed parameter, so a parameter the
// caller fed gives nil and the interpreter puts the shape on when it runs.
- (NSArray<NSNumber *> *)charon_mps_gatherShapeOfTensor:(MPSGraphTensor *)tensor
                                             parameters:(NSDictionary *)parameters
                                                    named:(NSString *)name;
// The CONCAT and STACK family, the one walk of this library whose result is SEVERAL operands: the result is
// every input laid end to end along one axis of it, or one new axis of extent as many as there are inputs.
// A release's factory fills in the axis and whether the operands interleave along it and names only its own
// methods - concat is 14.0's three forms and stack is 15.4's one - and the walk derives the result's shape
// from the inputs' own shapes, so this is where that shape comes from.
// Measured on this host's own MPSGraph, over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) beside one of
// (5, 6, 7, 8 | 50, 60, 70, 80) and one of (9, 10, 11, 12 | 90, 100, 110, 120):
//   - laid END TO END along the axis, in the order the caller wrote them: axis 0 of the three is a 6x4
//     holding the three 2x4s in that order, axis 1 a 2x12 holding their rows side by side.
//   - INTERLEAVING along the axis, which puts operand i's coordinate c at the result's coordinate
//     i + c * (the number of operands): axis 1 of two is a 2x8 of (1, 5, 2, 6, 3, 7, 4, 8 | 10, 50, 20, 60,
//     30, 70, 40, 80), and axis 1 of three a 2x12 of (1, 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12 | 10, 50, 90,
//     20, 60, 100, 30, 70, 110, 40, 80, 120). The result's extent on that axis is the SUM either way.
//   - a NEGATIVE axis is counted from the end of the RESULT's rank, which for a stack is one more than the
//     operands': axis -3, -2 and -1 of two 2x4s are what axes 0, 1 and 2 answer.
//   - every axis but that one must hold the SAME extent in every input. The header says "broadcast
//     compatible" and the release does not take it: a 1x4 beside a 2x4 with the concat on axis 1 is refused
//     by its own compiler with "'mps.concat' op invalid input tensor shapes, all input shapes must match
//     except at axis" (MPSGraphUtilities.mm:748), and the refusal is the same for a stack, which has no
//     extent to differ on. An extent of one on the concat axis itself is not a broadcast either: it is one
//     element of the result.
//   - a STACK is the same walk with one axis ADDED: the result's axis of extent as many operands says which
//     operand an element came from, and the axes around it are the operands' own - axis 1 of two 2x4s is a
//     2x2x4 of (1, 2, 3, 4, 5, 6, 7, 8 | 10, 20, 30, 40, 50, 60, 70, 80) and axis -1 a 2x4x2 of (1, 5, 2, 6,
//     3, 7, 4, 8 | 10, 50, 20, 60, 30, 70, 40, 80).
- (MPSGraphTensor *)charon_mps_concat:(CharonMPSGraphOperationKind)kind
                               tensors:(NSArray<MPSGraphTensor *> *)tensors
                                  axis:(NSInteger)axis
                            interleave:(BOOL)interleave
                                 name:(NSString *)name;
// The result's shape of such a walk, asked when the graph is BUILT so that the output tensor carries it
// before anything runs - the same reason, and the same arrangement, as the gather's shape above: it is the
// walk's own plan over the inputs' shapes, and `stacked` says whether the axis named is one the operands
// already have or one the result adds.
- (NSArray<NSNumber *> *)charon_mps_concatShapeOfTensors:(NSArray<MPSGraphTensor *> *)tensors
                                                    axis:(NSInteger)axis
                                              interleave:(BOOL)interleave
                                                stacked:(BOOL)stacked
                                                   named:(NSString *)name;
// The SPLIT, the one walk whose result is SEVERAL TENSORS, and the one whose regions are cut OUT of one
// operand rather than laid into a result: result i is the operand's own elements from the running total of
// the sizes before it to that total plus its own size, along the axis named, in the ORDER the caller wrote
// them. So the operation takes the operand as its input, the parameters carry which axis the regions are cut
// from (@"splitAxis") and either the sizes as they were written (@"splitSizes") or the count the caller named
// instead (@"splitNumSplits"), and each output's shape is the operand's own with that one axis replaced -
// which is why a release's factory fills in those three and names only its own methods, and why the shapes
// are put on the output tensors here, at build time, which is what a caller reads off them before it runs
// anything.
//
// The sizes come out of one function, CharonMPSGraphSplitSizes in MPSGraphInterpreter14.m, asked both here
// and when the graph runs: the written ones as they are, and a count's by the release's own measured rule -
// the first n-1 sizes are ceil(extent/n) and the last is what is left, and a count whose last size would not
// be positive is refused there with the release's own words.
- (NSArray<MPSGraphTensor *> *)charon_mps_split:(MPSGraphTensor *)tensor
                                            axis:(NSInteger)axis
                                           sizes:(NSArray<NSNumber *> *)sizes
                                      numSplits:(NSUInteger)numSplits
                                            name:(NSString *)name;
// The sizes such a split cuts its regions by, asked of the interpreter - where the rule and the three
// refusals live - both when the graph is built and when the operation runs, so a graph whose operand is fed
// is cut the way its value says. `written` is the caller's own list or nil, `numSplits` the count they named
// instead or zero, `axis` the axis the regions are cut from already counted from the end, and `operandShape`
// the shape the sizes are measured against.
- (NSArray<NSNumber *> *)charon_mps_splitSizes:(NSArray<NSNumber *> *)written
                                    numSplits:(NSUInteger)numSplits
                                         axis:(NSInteger)axis
                                  ofShape:(NSArray<NSNumber *> *)operandShape
                                       named:(NSString *)name;
// The COORDINATE ALONG AN AXIS, which has NO OPERAND at all: its value IS the coordinate of the axis named,
// so what the caller gives it is a shape and an axis, and the result is MPSDataTypeInt32 whatever the shape
// is (measured, over ranks of one to three and extents of one to five). Each of the two may be written down
// (`axis`, `shape`) or fed as a tensor (`fedAxis`, `fedShape`), and what decides what happens is whether the
// graph HOLDS the fed tensor's value or the caller feeds it: a CONSTANT is read here, when the graph is
// built, and a placeholder is refused here, because the release takes the process down over one (measured,
// and named with the release's own words in the row of each method).
- (MPSGraphTensor *)charon_mps_coordinates:(NSInteger)axis
                                    fedAxis:(MPSGraphTensor *)fedAxis
                                      shape:(NSArray<NSNumber *> *)shape
                                   fedShape:(MPSGraphTensor *)fedShape
                                       name:(NSString *)name;
// The SPACE-TO-DEPTH family of 15.0 and 16.1 - spaceToDepth2D and depthToSpace2D, spaceToBatch and
// batchToSpace - which is ONE chain of walks: a reshape that splits or merges each spatial axis into its block
// rows and columns (and the batch axis the other way round), a transpose that puts the batch axis and the
// block's coordinates into the order usePixelShuffleOrder names, and the other half of the reshape. `spatial`
// is the list of axes the blocks are cut from, in the order the block's coordinates are stored in - the LAST
// of them is the fastest, which is what makes the 2D form's (widthAxis, heightAxis) the general form's
// (heightAxis, widthAxis) - `batch` is the axis the blocks go to or come from, `block` one extent per
// spatial axis, `toBatch` which of the two directions this is and `shuffle` the header's flag. Every
// measurement and every refusal of the family is in the implementation and in
// facts/MetalPerformanceShadersGraph/Core.md.
- (MPSGraphTensor *)charon_mps_blockShuffle:(MPSGraphTensor *)tensor
                                     spatial:(NSArray<NSNumber *> *)spatial
                                       batch:(NSInteger)batch
                                       block:(NSArray<NSNumber *> *)block
                                     toBatch:(BOOL)toBatch
                                     shuffle:(BOOL)shuffle
                                         name:(NSString *)name;
// The PLAN of that family - the three shapes its chain of three walks carries - asked of the interpreter,
// where the rule and every refusal of the family live, both when the graph is built (the four written-down
// forms, whose axes are numbers the caller wrote down) and when it runs (the fed pair of 15.0, whose three
// axes arrive as data). `operandShape` is the shape the extents are measured against: the tensor's own when
// the graph is built, the value's own when it runs.
- (NSDictionary *)charon_mps_blockShufflePlan:(NSString *)name
                                       ofShape:(NSArray<NSNumber *> *)operandShape
                                       spatial:(NSArray<NSNumber *> *)spatial
                                         batch:(NSInteger)batch
                                         block:(NSArray<NSNumber *> *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle;
// The FED forms of the same family, where the spatial axes, the batch axis and the block dimensions each
// arrive as a tensor. A parameter the graph HOLDS - a constant - is read when the graph is built and the
// written-down seam above does the work; one the caller feeds is refused there, with the measurement of how
// the release goes down over it.
- (MPSGraphTensor *)charon_mps_fedBlockShuffle:(MPSGraphTensor *)tensor
                                       spatial:(MPSGraphTensor *)spatial
                                         batch:(MPSGraphTensor *)batch
                                         block:(MPSGraphTensor *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle
                                           name:(NSString *)name;
// The SLICE family in its three directions, which are one plan over the same arithmetic - a start, an end
// and a stride per axis with the three masks applied - and three walks, because they go three ways:
//   - the slice itself (@"slice") is a gather: the result's axis k reads the operand's axis k from the start,
//     stepping by the stride, so it is the walk above with an offset and a stride in it;
//   - the slice's GRADIENT (@"sliceGradient") is a scatter: the result is a tensor of the FORWARD INPUT's
//     shape - which is why the shape arrives as a tensor, either a constant the graph knows at build time or
//     a feed it reads when the graph runs - and the gradient's elements are written into the region the slice
//     selects, every other element a zero (measured: the release writes those zeros over a destination that
//     was filled with a pattern);
//   - the slice's UPDATE (@"sliceUpdate") is a copy and a scatter: the result is the DATA tensor's own
//     elements with the update written over the region the slice selects, which replaces and does not add.
// Everything the plan needs is in `parameters` - which direction (@"gather"), the starts, the ends, the
// strides and the three masks (@"sliceStarts", @"sliceEnds", @"sliceStrides", @"sliceStartMask",
// @"sliceEndMask", @"sliceSqueezeMask"), whether an end is really a SIZE (@"sliceSizes"), the forward
// input's shape where the graph already knows it (@"sliceForwardShape") and the index in `inputs` where the
// slice's fed parameters start (@"sliceFedFrom"), so a release's factory fills those in and names only its
// own methods. The fed form of a parameter the result's SHAPE depends on is one the release cannot build a
// graph over at all (measured: every fed gather parameter, and the fed slice of 18.2, die in its own
// NDArray), which is why the port refuses a floating point one and reads the rest when the graph runs.
- (MPSGraphTensor *)charon_mps_slice:(CharonMPSGraphOperationKind)kind
                               inputs:(NSArray<MPSGraphTensor *> *)inputs
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name;
// The shape a constant tensor holds, and nil for any other tensor: how a slice's gradient is given the
// shape of its forward input before the graph runs. See the implementation for why that is the only way.
- (NSArray<NSNumber *> *)charon_mps_constantShapeOfTensor:(MPSGraphTensor *)tensor;
// What a run does with the shared events an execution descriptor named: at the stage the caller named, every
// signal of that stage writes its value into its event, and every wait must be satisfied or the run is
// refused. It is a method and not code in the runs because the events are the DESCRIPTOR's own state, and both
// of this library's descriptor classes declare the two methods that put them there.
- (void)charon_mps_applyEventsAtStage:(MPSGraphExecutionStage)stage named:(NSString *)name;
// A cumulative operation along one axis of one operand: the result is the operand's own shape, and each
// element holds a fold of the elements on one side of it. The axis is the caller's, so it is normalised
// here - negative counted from the end of the rank, and an axis outside it refused the way the reduction
// family's is - and everything else the walk needs comes in `parameters`: which fold (@"scanCombination",
// one of the four the reduction table already holds), whether an element is in its own answer
// (@"scanExclusive") and which way the walk goes (@"scanReverse"). A 16.0 factory fills those in and names
// only its own methods.
- (MPSGraphTensor *)charon_mps_scan:(CharonMPSGraphOperationKind)kind
                               axis:(NSInteger)axis
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name;
// The same over an axis the caller feeds at run time rather than writing down, which is the other half of
// every one of the four operations of 16.0. The axis tensor is the operation's second input, and the walk
// reads its one element; a floating point axis is refused here, because the release cannot build the graph
// at all over one (measured: its own compiler refuses the operand and the process goes down with
// "failed assertion", MPSGraphExecutable.mm:4419) and there is no answer to reproduce.
- (MPSGraphTensor *)charon_mps_scan:(CharonMPSGraphOperationKind)kind
                         axisTensor:(MPSGraphTensor *)axisTensor
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name;
// The operation that fills a tensor's value, called by the interpreter for each in turn.
- (void)charon_mps_runOperation:(MPSGraphOperation *)operation
                          values:(NSMutableDictionary *)values;
- (MPSGraphDevice *)charon_mps_device;
- (MPSGraphOperation *)charon_mps_addOperationOfKind:(CharonMPSGraphOperationKind)kind
                                                name:(NSString *)name
                                              inputs:(NSArray<MPSGraphTensor *> *)inputs
                                             outputs:(NSArray<MPSGraphTensor *> *)outputs
                                           parameters:(NSDictionary *)parameters;
@end

#endif /* MPSGRAPH_CHARON_H */
