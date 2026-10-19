// MPSGraphTensorShapeOps154.m - the eight shape operations that arrived with MPSGraph in 15.4: the four
// squeezes, the three expanded dimensions and the stack. From the header MPSGraphTensorShapeOps.h in the SDK
// of iOS 16.4, which declares all eight, each with its own availability note (ios(15.4)).
//
// One object per release: this one names eight methods of 15.4 and nothing of any other release. The seven
// about axes are one walk in MPSGraphInterpreter14.m with the axes left alone - measured, every one of them
// answers the operand's own bytes in the operand's own order - so what is here is each method's own rule
// about which axes the result keeps, which is measured as well:
//
//   - a squeeze with no axes drops every axis of extent one and leaves the rest: a 1x2x4 is a 2x4 of the same
//     eight bytes, and a 2x4 with no unit axis is itself.
//   - a squeeze of one axis drops that axis and keeps the rest, in order.
//   - a squeeze of a set of axes drops those of them and keeps the rest, in order.
//   - an expanded dimension at an axis adds an axis of extent one there: axis 0 of a 2x4 is a 1x2x4 of the
//     same bytes, axis 2 and axis -1 are a 2x4x1, and a negative axis is counted from the end and may be the
//     rank itself, which is the trailing unit axis.
//   - an expanded dimension of a set of axes adds one there for each of them: axes @[@0, @2] of a 2x4 is a
//     1x2x1x4.
//
// The one the release refuses is a squeeze of an axis that is not of extent one: measured, it writes
// "squeezed axis must have length 1, input.shape[1] == 2" and then "LLVM ERROR: Failed to infer result
// type(s)" takes the process down, so the port raises NSInvalidArgumentException instead - the refusal the
// reduction family's axis is, and the one an axis outside the rank is. The stack's own two refusals - an axis
// outside the result's rank, and operands whose shapes differ at all - are above its own method.

#import "CharonMPSGraph.h"

@implementation MPSGraph (CharonMPSGraphTensorShape154)

// The STACK, which is the concatenation family of 14.0 with one axis ADDED rather than one axis filled: the
// result's axis of extent as many operands as the caller wrote down says which operand an element came from,
// and the axes around it are the operands' own. So it is that family's one walk, reached through its seam,
// with the axis the caller named counted from the end of the RESULT's rank - one more than the operands' -
// which is what the header's own range says (`-rank + 1 <= dimension < rank + 1`).
//
// Measured on this host's own MPSGraph, over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) beside one of
// (5, 6, 7, 8 | 50, 60, 70, 80) and one of (9, 10, 11, 12 | 90, 100, 110, 120):
//   - axis 1 of two is a 2x2x4 of (1, 2, 3, 4, 5, 6, 7, 8 | 10, 20, 30, 40, 50, 60, 70, 80) and axis 2 a
//     2x4x2 of (1, 5, 2, 6, 3, 7, 4, 8 | 10, 50, 20, 60, 30, 70, 40, 80), so the operands are laid along
//     that axis in the order the caller wrote them - which is the concatenation with no interleave and an
//     extent of one each.
//   - a NEGATIVE axis is counted from the end of the result's rank, so axes -3, -2 and -1 answer what axes
//     0, 1 and 2 answer, and an axis outside -3 to 2 is refused by the release's own compiler - "invalid
//     axis: 3, axis must be in range -|rank| <= axis < |rank|" (MPSGraphUtilities.mm:3237), over an operation
//     of its own: the release builds this as an expanded dimension per operand and then a concatenation.
//   - ONE operand answers the operand itself with the new axis of extent one: measured, a stack of one 2x4
//     is a 1x2x4 of its own eight values.
//   - every operand has to have the SAME shape, which the header calls "broadcast compatible" and the
//     release does not take: measured, a 2x4 and a 2x4 beside a 1x4 stacked at axis 1 are refused by its own
//     compiler with "'mps.concat' op invalid input tensor shapes, all input shapes must match except at axis"
//     (MPSGraphUtilities.mm:748), and so are a 1x4 and a 2x4 stacked at axis 0. The port raises there.
//   - an EMPTY ARRAY is not a refusal either: measured over the whole path, `stackTensors:@[]` builds a
//     result tensor of nil shape and float32, `compileWithDevice:` returns an executable and the run leaves
//     the caller's destination as it was. So the result tensor here carries no shape and no value, which is
//     what the concatenation family's seam gives this method for an empty array.
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

// The squeeze and the expanded dimension are one walk in MPSGraphInterpreter14.m with the axes left alone -
// measured, every one of the seven methods here answers the operand's own bytes in the operand's own order -
// so what is left in this object is each method's own answer to one question: which axes are dropped, which
// are added, and whether the caller wrote them down or fed them. The walk turns that into the result's
// shape and into which axis of the operand each axis of the result reads, and it is the walk that refuses
// what the release cannot build.

// A squeeze with no axes drops every axis of extent one and leaves the rest: measured, a 1x2x4 is a 2x4 of
// the same eight bytes and a 2x4 with no unit axis is itself.
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
    // The axes are fed, so which of them they are is not known until the graph runs: the walk reads them out
    // of the operation's second input, which is why nothing but the transformation's own name is written
    // down here.
    return [self charon_mps_gather:CharonMPSGraphOperationKindSqueeze
                             tensor:tensor
                      fedParameter:axesTensor
                        parameters:@{@"gather": @"squeeze", @"gatherOperand": @"axes"}
                               name:name];
}

// An expanded dimension at an axis adds an axis of extent one there: measured, axis 0 of a 2x4 is a 1x2x4 of
// the same bytes, axis 2 and axis -1 are a 2x4x1 - and a negative axis is counted from the end and may be the
// rank itself, which is the trailing unit axis.
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

// The SPLIT, which is the first operation in this library whose result is SEVERAL TENSORS and the only one
// whose regions are cut OUT of the operand rather than laid into a result: result i is the operand's own
// elements from the running total of the sizes before it to that total plus its own size, along the axis
// named, in the ORDER the caller wrote them. So it is the SLICE walk asked once per region, with the offset
// of a region being the sum of the sizes before it - which is why the seam below hands the interpreter one
// set of sizes and lets it build a region of the operand per output.
//
// MEASURED on this host's own MPSGraph (macOS 27.0 build 26A428, M4 Pro, Metal 4), over a 2x4 of
// (1, 2, 3, 4 | 10, 20, 30, 40):
//   - the regions are cut in the order written: @[@1, @3] along axis 1 is a 2x1 of (1, 10) and a 2x3 of
//     (2, 3, 4 | 20, 30, 40), and @[@3, @1] is a 2x3 of (1, 2, 3 | 10, 20, 30) and a 2x1 of (4 | 40);
//   - the axis is the operand's own and a negative one is counted from the end: @[@1, @1] along axis 0 is
//     two 1x4s of (1, 2, 3, 4) and (10, 20, 30, 40), and -2 answers what 0 answers and -1 what 1 does;
//   - the result's data type is the operand's own (0x10000020, float32, for every case measured here);
//   - ONE size is the operand itself: @[@4] along axis 1 is a 2x4 of the same eight values, which is what
//     the one-operand concatenation of 14.0 answers;
//   - a rank of ONE splits as it should: @[@1, @2] along axis 0 of a [3] is a [1] of (71) and a [2] of
//     (72, 73), and -1 answers what 0 does;
//   - a rank of three answers on each of its axes: @[@1, @2] along axis 1 of a 2x3x4 is a 2x1x4 and a
//     2x2x4, @[@1, @1] along axis 0 two 1x3x4s and @[@2, @1, @1] along axis 2 a 2x3x2 and two 2x3x1s;
//   - THE SIZES MUST ADD UP TO THE AXIS'S EXTENT: @[@1, @1] and @[@3, @3] of a 2x4 along axis 1 both build
//     their result tensors (two 2x1s and two 2x3s) and are then refused by the release's own compiler,
//     "'mps.split' op sum of result dimension lengths along split axis must equal input dimension length
//     along split axis" (MPSGraphUtilities.mm:1543), after which "Pass failed: MPSCopyDataFiles" takes the
//     process down. So are @[@1, @2] along axis 2 of a 2x3x4, whose result tensors are a 2x3x1 and a 2x3x2.
//     The port raises where the graph is built, as it does for every shape the release refuses.
//   - a size of ZERO builds the result tensor of no elements - the shape line prints 2x0 - and is then
//     refused by the release as it assembles the results: NSInvalidArgumentException, "object cannot be
//     nil", from -[__NSArrayM insertObject:atIndex:]. A zero is refused where the graph is built here too.
//   - an axis outside the rank is refused by the same compiler, with the same sentence the concatenation's
//     is and a line of its own: "invalid axis tensor: [2], axis must be in range -rank <= axis < rank,
//     rank = 2" (MPSGraphUtilities.mm:1543), then "LLVM ERROR: Failed to infer result type(s):".
//   - a NEGATIVE size takes the process down where the graph is built, with SIGSEGV and no word at all
//     (measured, @[@1, @(-1)] of a 2x4 along axis 1), so it is refused here as well.

// The sizes as the caller wrote them down, over the axis named.
- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)inputTensor
                                 splitSizes:(NSArray<NSNumber *> *)splitSizes
                                       axis:(NSInteger)axis
                                       name:(NSString *)name
{
    return [self charon_mps_split:inputTensor axis:axis sizes:splitSizes numSplits:0 name:name];
}

// The sizes as a COUNT instead of as a list, which the release turns into a list of its own. The rule is
// measured, and it is NOT "divide evenly": over an extent E and a count N the first N-1 sizes are ceil(E/N)
// and the last is what is left. Measured over every pair of E in 1..8 and N in 1..4, and then over
// (9,3), (9,4), (10,3), (10,4), (11,4), (12,5), (13,5), (9,5), (16,5) and (17,6):
//
//     E=3 N=2 -> 2 1        E=5 N=2 -> 3 2        E=7 N=2 -> 4 3        E=8 N=2 -> 4 4
//     E=3 N=3 -> 1 1 1      E=5 N=3 -> 2 2 1      E=7 N=3 -> 3 3 1      E=8 N=3 -> 3 3 2
//     E=9 N=3 -> 3 3 3      E=4 N=4 -> 1 1 1 1    E=7 N=4 -> 2 2 2 1    E=17 N=6 -> 3 3 3 3 3 2
//
// and the count is REFUSED exactly when the last size would not be positive, which is when (N-1)*ceil(E/N)
// is not less than E: E=4 N=3, E=6 N=4, E=9 N=4, E=12 N=5, E=16 N=5, and every N above E. All of those the
// release's own compiler refuses with "infer split sizes from total size=E and num_splits=N failed."
// (MPSGraphUtilities.mm:1543) and then "LLVM ERROR: Failed to infer result type(s):". A count of ONE is the
// whole axis (E=5 N=1 is a [5]) and a count of ZERO is refused the same way.
- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)inputTensor
                                 numSplits:(NSUInteger)numSplits
                                       axis:(NSInteger)axis
                                       name:(NSString *)name
{
    return [self charon_mps_split:inputTensor axis:axis sizes:nil numSplits:numSplits name:name];
}

// The sizes as a TENSOR, which is the form the header is written for, and the release reads it only when the
// graph HOLDS the value. Measured, a CONSTANT of @[@1, @3] along axis 1 of a 2x4 answers exactly what the
// written-down @[@1, @3] answers - a 2x1 of (1, 10) and a 2x3 of (2, 3, 4 | 20, 30, 40) - and so do
// constants of @[@2, @2], @[@3, @1], @[@1, @1, @2] and @[@4], over int32 and with the axis at 0 as well.
// A PLACEHOLDER, which is what a caller who wants the sizes to arrive at run time makes, takes the release
// down where the graph is BUILT, with SIGSEGV and no word at all - measured over a sizes tensor of shape [2]
// and of shape [1], an int32 and an int64 alike - so the port refuses it where the graph is built, and that
// measurement is what this row carries.
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

// The COORDINATE ALONG AN AXIS, which has no operand at all - its value IS the coordinate - so it is neither
// a gather nor a constant: the result's shape is the shape the caller gives it and every element of it holds
// the coordinate of the axis named.
//
// MEASURED on this host's own MPSGraph, and the three things a reader has to know:
//   - the result is MPSDataTypeInt32 (0x20000020) whatever the shape is, and not int64: measured over shapes
//     of rank one ([1], [3], [5]), of rank two (2x3, 1x1) and of rank three (2x3x4, 1x1x1);
//   - the axis is counted from the END of the rank, so -1 answers what 1 answers and -2 what 0 does, and -3 of
//     a 2x3 and -4 of a 2x3x4 are refused by the release's own compiler with "'mps.get_coordinates' op
//     invalid axis: -3." (MPSGraphUtilities.mm:1678) - the operation's own name, which is neither a split
//     nor a gather, and an axis of 1 of a rank of one and 3 of a 2x3x4 are refused with the same sentence;
//   - the value is the coordinate along that axis: axis 0 of a 2x3 is (0, 0, 0 | 1, 1, 1), axis 1 of a 2x3 is
//     (0, 1, 2 | 0, 1, 2), axis 1 of a 2x3x4 is (0, 1, 2 | 0, 1, 2) four times over, axis 2 of a 2x3x4 is
//     (0, 1, 2, 3) repeated six times, axis 0 of a [5] is (0, 1, 2, 3, 4) and an extent of one answers a
//     single zero whatever the axis or the rank.
- (MPSGraphTensor *)coordinateAlongAxis:(NSInteger)axis
                              withShape:(NSArray<NSNumber *> *)withShape
                                   name:(NSString *)name
{
    return [self charon_mps_coordinates:axis fedAxis:nil shape:withShape fedShape:nil name:name];
}

// The shape as a tensor: the same walk with the result's own shape arriving as data, and the release's
// answer depends on whether the graph holds the value. A CONSTANT is read when the graph is built and the
// release answers it - measured, an int32 constant of @[@2, @4] at axis 1 answers the 2x4 of the coordinate
// values, byte for byte what -coordinateAlongAxis:withShape:name: answers over the same 2x4. A PLACEHOLDER
// is refused by the release before a graph exists: the result's shape comes out as -1x-1 and the process
// goes down with it (exit 134), for an int32 and an int64 alike, and for both of this file's two fed shapes.
- (MPSGraphTensor *)coordinateAlongAxis:(NSInteger)axis
                         withShapeTensor:(MPSGraphTensor *)withShapeTensor
                                   name:(NSString *)name
{
    return [self charon_mps_coordinates:axis fedAxis:nil shape:nil fedShape:withShapeTensor name:name];
}

// The axis as a tensor, with the shape written down. A CONSTANT axis answers - measured, an int32 constant of
// 1 at a 2x4 answers the same 2x4 of coordinates as the written-down 1, a constant of 0 answers the 2x4 of
// row coordinates, and a constant of -1 answers what 1 answers. A PLACEHOLDER axis takes the release down
// where the graph is BUILT, with SIGSEGV and no word at all, for an axis of 1, of 0, of -1 and of 5 alike;
// and a FLOATING POINT one is refused by the release's own compiler with "'mps.get_coordinates' op operand #1
// must be 0D tensor of mps index type values or static-shape defined tensor with shape equal to [1] or
// unranked tensor of mps index type values" (MPSGraphUtilities.mm:1678), which is the same refusal the fed
// gather parameters of this library raise. All three are refused where the graph is built here.
- (MPSGraphTensor *)coordinateAlongAxisTensor:(MPSGraphTensor *)axisTensor
                                    withShape:(NSArray<NSNumber *> *)withShape
                                         name:(NSString *)name
{
    return [self charon_mps_coordinates:0 fedAxis:axisTensor shape:withShape fedShape:nil name:name];
}

// Both of them fed. The release takes the process down over it (measured, exit 134, the fed shape's -1x-1
// shape being what it prints first), and the port refuses it where the graph is built for the same reason
// the shape-fed form above is.
- (MPSGraphTensor *)coordinateAlongAxisTensor:(MPSGraphTensor *)axisTensor
                             withShapeTensor:(MPSGraphTensor *)withShapeTensor
                                         name:(NSString *)name
{
    return [self charon_mps_coordinates:0 fedAxis:axisTensor shape:nil fedShape:withShapeTensor name:name];
}

@end
