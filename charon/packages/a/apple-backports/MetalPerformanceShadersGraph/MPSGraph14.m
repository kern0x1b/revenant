// MPSGraph, from the header of MPSGraph.h in the SDK of iOS 16.4: the graph the operations are added to,
// the placeholders that are fed at run time, and the two ways to run it.
//
// The graph is a description, so running it means walking the operations in the order they were added
// and asking each one to fill its outputs from its inputs and the feeds. A tensor's value is found by
// looking it up: a placeholder's comes from the feeds, any other one's from the operation that produced
// it, which is why the operations are walked in the order they were added - an operation can only read
// what an earlier one wrote.

#import "CharonMPSGraph.h"

// What an arithmetic family operation does to one pair of elements. A binary one takes the two and
// writes one; a unary one takes the first and writes one; a clamped one takes the two and a lower and an
// upper bound. The data type of the first operand decides the arithmetic, as it does everywhere else in
// this framework.
typedef enum {
    CharonMPSGraphArityUnary,
    CharonMPSGraphArityBinary,
    CharonMPSGraphArityClamp
} CharonMPSGraphArity;

@implementation MPSGraph {
    MPSGraphDevice *_device;
    MPSGraphOptions _options;
    NSMutableArray<MPSGraphTensor *> *_placeholders;
    NSMutableArray<MPSGraphOperation *> *_operations;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        // A graph's device is the one it was made against, or the port's own Metal device when the
        // caller named none: every device this port has is charon's, so there is nothing to choose.
        _device = [MPSGraphDevice deviceWithMTLDevice:MTLCreateSystemDefaultDevice()];
        _options = MPSGraphOptionsDefault;
        _placeholders = [NSMutableArray array];
        _operations = [NSMutableArray array];
    }
    return self;
}

- (MPSGraphDevice *)charon_mps_device
{
    return _device;
}

- (MPSGraphOptions)options
{
    return _options;
}

- (void)setOptions:(MPSGraphOptions)options
{
    _options = options;
}

- (NSArray<MPSGraphTensor *> *)placeholderTensors
{
    return [_placeholders copy];
}

#pragma mark - the operations a graph is built from

- (MPSGraphTensor *)placeholderWithShape:(NSArray<NSNumber *> *)shape dataType:(MPSDataType)dataType name:(NSString *)name
{
    MPSGraphOperation *operation = [self charon_mps_addOperationOfKind:CharonMPSGraphOperationKindPlaceholder
                                                                 name:name
                                                                inputs:@[]
                                                               outputs:@[]
                                                             parameters:nil];
    MPSGraphTensor *tensor = [[MPSGraphTensor alloc] initWithShape:shape dataType:dataType operation:operation index:0];
    [operation charon_mps_setOutputTensors:@[tensor]];
    [_placeholders addObject:tensor];
    return tensor;
}

- (MPSGraphTensor *)constantWithShape:(NSArray<NSNumber *> *)shape
                            dataType:(MPSDataType)dataType
                              values:(NSData *)values
                                name:(NSString *)name
{
    MPSGraphOperation *operation = [self charon_mps_addOperationOfKind:CharonMPSGraphOperationKindConstant
                                                                 name:name
                                                                inputs:@[]
                                                               outputs:@[]
                                                             parameters:@{@"values": values}];
    MPSGraphTensor *tensor = [[MPSGraphTensor alloc] initWithShape:shape dataType:dataType operation:operation index:0];
    [operation charon_mps_setOutputTensors:@[tensor]];
    return tensor;
}

// The same constant written the way MPSGraphMemoryOps.h spells it, with the data as an NSData rather than
// as bytes and a length. It is the same operation: the header's own note is that the number of bytes should
// be sizeof(dataType) times the number of elements and that the shape has to be statically shaped, which is
// what a constant is. It is here because a caller that has its data in an NSData has no other way to put it
// in a graph, and because the slice's gradient takes the shape of its forward input as a TENSOR, so a graph
// that is to answer one before it runs anything needs this factory to build it.
- (MPSGraphTensor *)constantWithData:(NSData *)data
                               shape:(NSArray<NSNumber *> *)shape
                            dataType:(MPSDataType)dataType
{
    return [self constantWithShape:shape dataType:dataType values:data name:nil];
}

- (MPSGraphTensor *)charon_mps_operation:(CharonMPSGraphOperationKind)kind
                                inputs:(NSArray<MPSGraphTensor *> *)inputs
                            parameters:(NSDictionary *)parameters
                                   name:(NSString *)name
{
    // The output takes the first input's shape and data type, which is what every elementwise operation
    // in this family produces; a family whose result has a shape of its own computes it here instead. A
    // result whose shape is decided by data that arrives when the graph RUNS takes neither: there is no shape
    // to put on it before then, and that is what the release's own tensor carries over one (measured: no
    // shape at all, before the run or after it), so the interpreter puts it on when it walks the operation.
    MPSGraphTensor *source = inputs.firstObject;
    NSArray<NSNumber *> *shape = [parameters[@"resultShapeIsFed"] boolValue] ? nil : source.shape;
    MPSDataType dataType = source.dataType;
    if ([parameters[@"shape"] isKindOfClass:[NSArray class]])
        shape = parameters[@"shape"];
    if ([parameters[@"dataType"] isKindOfClass:[NSNumber class]])
        dataType = (MPSDataType)[parameters[@"dataType"] unsignedIntValue];
    MPSGraphOperation *operation = [self charon_mps_addOperationOfKind:kind name:name inputs:inputs outputs:@[] parameters:parameters];
    MPSGraphTensor *tensor = [[MPSGraphTensor alloc] initWithShape:shape dataType:dataType operation:operation index:0];
    [operation charon_mps_setOutputTensors:@[tensor]];
    return tensor;
}

- (MPSGraphOperation *)charon_mps_addOperationOfKind:(CharonMPSGraphOperationKind)kind
                                                name:(NSString *)name
                                              inputs:(NSArray<MPSGraphTensor *> *)inputs
                                             outputs:(NSArray<MPSGraphTensor *> *)outputs
                                           parameters:(NSDictionary *)parameters
{
    MPSGraphOperation *operation = [[MPSGraphOperation alloc] initWithGraph:self kind:kind name:name inputs:inputs outputs:outputs];
    [operation charon_mps_setParameters:parameters];
    [_operations addObject:operation];
    return operation;
}

#pragma mark - the arithmetic family

- (MPSGraphTensor *)charon_mps_arithmetic:(CharonMPSGraphOperationKind)kind
                                 operands:(NSArray<MPSGraphTensor *> *)operands
                                      name:(NSString *)name
{
    return [self charon_mps_operation:kind inputs:operands parameters:nil name:name];
}

// The same for the operations whose answer is a truth rather than a number. Measured on this host's own
// MPSGraph, a comparison over a rank-3 float32 operand answers MPSDataTypeBool (0x80000008, one byte
// an element) and so do lessThan, greaterThan, notEqual, the two <= and >= forms and the three
// questions about a value; the logical family, not and signbit answer the operand's own type, which is
// why those three go through the arithmetic form above and not through this one.
- (MPSGraphTensor *)charon_mps_predicate:(CharonMPSGraphOperationKind)kind
                                operands:(NSArray<MPSGraphTensor *> *)operands
                                     name:(NSString *)name
{
    return [self charon_mps_operation:kind
                              inputs:operands
                          parameters:@{@"dataType": @(MPSDataTypeBool)}
                                 name:name];
}

- (MPSGraphTensor *)additionWithPrimaryTensor:(MPSGraphTensor *)primary
                             secondaryTensor:(MPSGraphTensor *)secondary
                                        name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAdd operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)subtractionWithPrimaryTensor:(MPSGraphTensor *)primary
                                secondaryTensor:(MPSGraphTensor *)secondary
                                           name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSubtract operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)multiplicationWithPrimaryTensor:(MPSGraphTensor *)primary
                                  secondaryTensor:(MPSGraphTensor *)secondary
                                             name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindMultiply operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)divisionWithPrimaryTensor:(MPSGraphTensor *)primary
                              secondaryTensor:(MPSGraphTensor *)secondary
                                         name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindDivide operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)negationWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindNegate operands:@[tensor] name:name];
}

- (MPSGraphTensor *)squareWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSquare operands:@[tensor] name:name];
}

- (MPSGraphTensor *)reciprocalWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindReciprocal operands:@[tensor] name:name];
}

- (MPSGraphTensor *)squareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSqrt operands:@[tensor] name:name];
}

- (MPSGraphTensor *)reverseSquareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindRsqrt operands:@[tensor] name:name];
}

- (MPSGraphTensor *)exponentialWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindExp operands:@[tensor] name:name];
}

- (MPSGraphTensor *)logarithmWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLog operands:@[tensor] name:name];
}

- (MPSGraphTensor *)absoluteWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAbs operands:@[tensor] name:name];
}

- (MPSGraphTensor *)signWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSign operands:@[tensor] name:name];
}

- (MPSGraphTensor *)identityWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindIdentity operands:@[tensor] name:name];
}

#pragma mark - the transcendentals and the rounding

- (MPSGraphTensor *)exponentBase2WithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindExpBase2 operands:@[tensor] name:name];
}

- (MPSGraphTensor *)exponentBase10WithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindExpBase10 operands:@[tensor] name:name];
}

- (MPSGraphTensor *)logarithmBase2WithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogBase2 operands:@[tensor] name:name];
}

- (MPSGraphTensor *)logarithmBase10WithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogBase10 operands:@[tensor] name:name];
}

- (MPSGraphTensor *)negativeWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindNegate operands:@[tensor] name:name];
}

- (MPSGraphTensor *)signbitWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSignBit operands:@[tensor] name:name];
}

- (MPSGraphTensor *)ceilWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindCeil operands:@[tensor] name:name];
}

- (MPSGraphTensor *)floorWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindFloor operands:@[tensor] name:name];
}

// The two roundings the header separates by name: round is the half away from zero and rint is the one
// the C library rounds to even with. A feed of (0.5, 1.5, 2.5, -0.5, -1.5, -2.5) is measured against
// both on this host's own MPSGraph and comes back 1, 2, 3, -1, -2, -3 for round and 0, 2, 2, -0, -2, -2
// for rint, which is what the two C functions answer.
- (MPSGraphTensor *)roundWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindRound operands:@[tensor] name:name];
}

- (MPSGraphTensor *)rintWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindRint operands:@[tensor] name:name];
}

- (MPSGraphTensor *)sinWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSin operands:@[tensor] name:name];
}

- (MPSGraphTensor *)cosWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindCos operands:@[tensor] name:name];
}

- (MPSGraphTensor *)tanWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindTan operands:@[tensor] name:name];
}

- (MPSGraphTensor *)sinhWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSinh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)coshWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindCosh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)tanhWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindTanh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)asinWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAsin operands:@[tensor] name:name];
}

- (MPSGraphTensor *)acosWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAcos operands:@[tensor] name:name];
}

- (MPSGraphTensor *)atanWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAtan operands:@[tensor] name:name];
}

- (MPSGraphTensor *)asinhWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAsinh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)acoshWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAcosh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)atanhWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAtanh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)erfWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindErf operands:@[tensor] name:name];
}

// The logical not of a value, which is the operand's own type and not a boolean: measured on this host's
// own MPSGraph, not of a rank-3 float32 operand is MPSDataTypeFloat32 where isNaN of the same operand is
// MPSDataTypeBool.
- (MPSGraphTensor *)notWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogicalNot operands:@[tensor] name:name];
}

- (MPSGraphTensor *)isInfiniteWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindIsInfinite operands:@[tensor] name:name];
}

- (MPSGraphTensor *)isFiniteWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindIsFinite operands:@[tensor] name:name];
}

- (MPSGraphTensor *)isNaNWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindIsNaN operands:@[tensor] name:name];
}

#pragma mark - the arithmetic that is not IEEE

- (MPSGraphTensor *)moduloWithPrimaryTensor:(MPSGraphTensor *)primary
                          secondaryTensor:(MPSGraphTensor *)secondary
                                     name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindModulo operands:@[primary, secondary] name:name];
}

// C's fmod truncates towards zero and the floor modulo answers the remainder of the divisor's own sign,
// which is the difference between -7 modulo 3 and -7 floor-modulo 3: -1 and 2.
- (MPSGraphTensor *)floorModuloWithPrimaryTensor:(MPSGraphTensor *)primary
                                 secondaryTensor:(MPSGraphTensor *)secondary
                                            name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindFloorModulo operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)powerWithPrimaryTensor:(MPSGraphTensor *)primary
                          secondaryTensor:(MPSGraphTensor *)secondary
                                     name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindPower operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)minimumWithPrimaryTensor:(MPSGraphTensor *)primary
                            secondaryTensor:(MPSGraphTensor *)secondary
                                       name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindMinimum operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)maximumWithPrimaryTensor:(MPSGraphTensor *)primary
                            secondaryTensor:(MPSGraphTensor *)secondary
                                       name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindMaximum operands:@[primary, secondary] name:name];
}

// A division that answers a zero where IEEE answers a NaN, which is what the "NoNaN" in its own name
// says: a zero over a zero, and a NaN over anything at all, are both a zero. Measured over the sixteen
// classes of the arithmetic case file on this host's own MPSGraph, divisionNoNaN answers 0x00000000 for
// 1.0 over 0.0 and for 0x00000001 over 0x00000001, where division answers 0x7fc00000 for both.
- (MPSGraphTensor *)divisionNoNaNWithPrimaryTensor:(MPSGraphTensor *)primary
                                  secondaryTensor:(MPSGraphTensor *)secondary
                                             name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindDivisionNoNaN operands:@[primary, secondary] name:name];
}

// The two-argument arctangent, whose arguments are in the order the header writes them: the tangent of
// the angle is primary over secondary, which is atan2(y, x), not atan2(x, y).
- (MPSGraphTensor *)atan2WithPrimaryTensor:(MPSGraphTensor *)primary
                          secondaryTensor:(MPSGraphTensor *)secondary
                                     name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindAtan2 operands:@[primary, secondary] name:name];
}

#pragma mark - the predicates over two operands

- (MPSGraphTensor *)equalWithPrimaryTensor:(MPSGraphTensor *)primary
                          secondaryTensor:(MPSGraphTensor *)secondary
                                     name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindEqual operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)notEqualWithPrimaryTensor:(MPSGraphTensor *)primary
                             secondaryTensor:(MPSGraphTensor *)secondary
                                        name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindNotEqual operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)lessThanWithPrimaryTensor:(MPSGraphTensor *)primary
                            secondaryTensor:(MPSGraphTensor *)secondary
                                       name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindLessThan operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)lessThanOrEqualToWithPrimaryTensor:(MPSGraphTensor *)primary
                                     secondaryTensor:(MPSGraphTensor *)secondary
                                                name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindLessThanOrEqualTo operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)greaterThanWithPrimaryTensor:(MPSGraphTensor *)primary
                               secondaryTensor:(MPSGraphTensor *)secondary
                                          name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindGreaterThan operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)greaterThanOrEqualToWithPrimaryTensor:(MPSGraphTensor *)primary
                                        secondaryTensor:(MPSGraphTensor *)secondary
                                                   name:(NSString *)name
{
    return [self charon_mps_predicate:CharonMPSGraphOperationKindGreaterThanOrEqualTo operands:@[primary, secondary] name:name];
}

#pragma mark - the logical family, which answers the operand's own type

- (MPSGraphTensor *)logicalANDWithPrimaryTensor:(MPSGraphTensor *)primary
                               secondaryTensor:(MPSGraphTensor *)secondary
                                          name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogicalAnd operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalORWithPrimaryTensor:(MPSGraphTensor *)primary
                              secondaryTensor:(MPSGraphTensor *)secondary
                                         name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogicalOr operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalNANDWithPrimaryTensor:(MPSGraphTensor *)primary
                                secondaryTensor:(MPSGraphTensor *)secondary
                                           name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogicalNand operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalNORWithPrimaryTensor:(MPSGraphTensor *)primary
                               secondaryTensor:(MPSGraphTensor *)secondary
                                          name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogicalNor operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalXORWithPrimaryTensor:(MPSGraphTensor *)primary
                               secondaryTensor:(MPSGraphTensor *)secondary
                                          name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogicalXor operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalXNORWithPrimaryTensor:(MPSGraphTensor *)primary
                                secondaryTensor:(MPSGraphTensor *)secondary
                                           name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindLogicalXnor operands:@[primary, secondary] name:name];
}

#pragma mark - the operations with a third operand

// A select reads three operands: where the predicate is true the second, where it is false the third,
// and the answer is the predicate's own type. A clamp reads the value and its two bounds.
- (MPSGraphTensor *)selectWithPredicateTensor:(MPSGraphTensor *)predicate
                         truePredicateTensor:(MPSGraphTensor *)whenTrue
                          falsePredicateTensor:(MPSGraphTensor *)whenFalse
                                         name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSelect operands:@[predicate, whenTrue, whenFalse] name:name];
}

- (MPSGraphTensor *)clampWithTensor:(MPSGraphTensor *)tensor
                     minValueTensor:(MPSGraphTensor *)minimum
                     maxValueTensor:(MPSGraphTensor *)maximum
                               name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindClamp3 operands:@[tensor, minimum, maximum] name:name];
}

#pragma mark - the activations and their gradients

- (MPSGraphTensor *)reLUWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindReLU operands:@[tensor] name:name];
}

- (MPSGraphTensor *)reLUGradientWithIncomingGradient:(MPSGraphTensor *)gradient
                                         sourceTensor:(MPSGraphTensor *)source
                                                name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindReLUGradient operands:@[gradient, source] name:name];
}

- (MPSGraphTensor *)sigmoidWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSigmoid operands:@[tensor] name:name];
}

// A sigmoid's gradient is the incoming gradient times the source times one minus the source, where the
// source is the sigmoid's own answer rather than its input: measured on this host's own MPSGraph over a
// feed of (0, 1, -1, 2), a sigmoidGradient of an incoming gradient of all ones comes back as
// (0, 0.196612, 0.196612, 0.104994), which is what that product is and not what the gradient of the
// input would be.
- (MPSGraphTensor *)sigmoidGradientWithIncomingGradient:(MPSGraphTensor *)gradient
                                            sourceTensor:(MPSGraphTensor *)source
                                                   name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSigmoidGradient operands:@[gradient, source] name:name];
}

#pragma mark - the reduction family

// What all eight of these share: a set of axes of the operand's rank, and a result whose shape is the
// operand's with those axes taken out. Three questions about the set are answered by measurement rather
// than by the reading, and every one of them is a case in tests/backports/host/mpsgraph/graph-cases.m:
//
//   - an axis may be negative and is counted from the end of the rank, so -1 is the last axis and -2
//     the one before it. Measured: reductionSumWithTensor:axis:-1 over a 2x4 answers a 2x1 of the same
//     bytes as axis:1, and axis:-2 the same as axis:0.
//   - the order the axes are written in does not matter, and an axis written twice reduces once, so the
//     set is a set. Measured: axes:@[@1,@0] and axes:@[@0,@1] over the same 2x4 both answer a 1x1 of
//     110, and axes:@[@0,@0] answers the same bytes and the same 1x4 as axes:@[@0].
//   - nil reduces every axis and an empty array reduces none. Measured: axes:nil over the 2x4 answers a
//     1x1 of 110, and axes:@[] answers the 2x4 the operand already was, byte for byte.
//
// `parameters` is what tells the walk in MPSGraphInterpreter14.m which fold to run, so that this object
// and every later release's object share one walk and neither names the other's operations: what is
// added here on top of the axes and the result's shape is only what this release's own eight differ in,
// which is the two that latch a NaN.
// An axis outside the rank is a graph that cannot be built, and the framework refuses it in a way a
// caller cannot catch: measured on this host's own MPSGraph, reductionSumWithTensor:axis:5 over a 2x4
// writes "invalid axes: 5" and then dies with "LLVM ERROR: Failed to infer result type(s)", so the
// process is gone before any answer. There is no way to reproduce that from a port, and returning a
// tensor for it would be an answer the release does not give at all, so this raises instead - which is
// the one form of "this graph is not buildable" a caller can handle and is decided when the graph is
// built rather than left to be discovered as a wrong number later. Every later release's reduction goes
// through the same seam and is refused the same way: the argument reductions of 15.0 were measured
// refused the same way, and the truth folds of 15.3 with them.
- (MPSGraphTensor *)charon_mps_reduction:(CharonMPSGraphOperationKind)kind
                                    axes:(NSArray<NSNumber *> *)axes
                                  tensor:(MPSGraphTensor *)tensor
                             parameters:(NSDictionary *)parameters
                                    name:(NSString *)name
{
    NSArray<NSNumber *> *shape = tensor.shape;
    NSUInteger rank = shape.count;
    NSMutableIndexSet *dropped = [NSMutableIndexSet indexSet];
    if (axes != nil) {
        for (NSNumber *axis in axes) {
            NSInteger value = axis.integerValue;
            if (value < 0)
                value += (NSInteger)rank;
            if (value < 0 || value >= (NSInteger)rank) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was asked to reduce axis %ld of a rank-%lu tensor, and "
                                   @"axis 0 to %lu is all it has",
                                    name, (long)axis.integerValue, (unsigned long)rank,
                                    (unsigned long)rank];
            }
            [dropped addIndex:(NSUInteger)value];
        }
    } else {
        // nil is every axis, which is the same set written out.
        for (NSUInteger axis = 0; axis < rank; axis++)
            [dropped addIndex:axis];
    }
    NSMutableArray<NSNumber *> *kept = [NSMutableArray arrayWithCapacity:rank];
    NSMutableArray<NSNumber *> *reduced = [NSMutableArray arrayWithCapacity:dropped.count];
    for (NSUInteger axis = 0; axis < rank; axis++) {
        if ([dropped containsIndex:axis])
            [reduced addObject:@(axis)];
        else
            [kept addObject:shape[axis]];
    }
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    all[@"axes"] = reduced;
    all[@"shape"] = kept;
    if (parameters)
        [all addEntriesFromDictionary:parameters];
    return [self charon_mps_operation:kind inputs:@[tensor] parameters:all name:name];
}

// What the eight of 14.0 differ in is the combination they fold with, and the two that latch a NaN say
// so here. The walk reads both out of the parameters, so a later release's reduction needs no name here.
- (MPSGraphTensor *)charon_mps_reductionOf:(NSArray<NSNumber *> *)axes
                                    tensor:(MPSGraphTensor *)tensor
                             combination:(NSString *)combination
                                     kind:(CharonMPSGraphOperationKind)kind
                          propagatesNaN:(BOOL)propagatesNaN
                                     name:(NSString *)name
{
    return [self charon_mps_reduction:kind
                                axes:axes
                              tensor:tensor
                         parameters:@{@"combination": combination, @"propagateNaN": @(propagatesNaN)}
                                name:name];
}

- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)tensor
                           dimension:(NSUInteger)dimension
                        withDimension:(NSUInteger)withDimension
                                name:(NSString *)name
{
    // The one shape operation that arrived with the framework itself, and the row-major transpose it is:
    // measured over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) it answers (1, 10, 2, 20, 3, 30, 4, 40) into a
    // 4x2, and a negative dimension is counted from the end, so dimension:-1 withDimension:0 answers what
    // dimension:0 withDimension:1 answers. The walk refuses an axis outside the rank, which is the same
    // refusal the reduction family's axis is.
    // The two axes are exchanged and the result KEEPS THE OPERAND'S RANK, measured: dimension:0
    // withDimension:2 of a 2x3x4 answers a 4x3x2, and dimension:0 withDimension:0 answers the operand itself.
    // So the permutation handed to the walk is the identity with those two entries exchanged rather than a
    // two-entry ordering, which would answer a rank of two whatever the operand's rank was. Both axes are read
    // back as the signed numbers the header's own NSUInteger was written as, because the release counts a
    // negative one from the end (measured, dimension:-1 withDimension:0 answers what dimension:0
    // withDimension:1 answers).
    NSUInteger rank = tensor.shape.count;
    NSInteger first = (NSInteger)(int32_t)(uint32_t)dimension;
    NSInteger second = (NSInteger)(int32_t)(uint32_t)withDimension;
    if (first < 0) first += (NSInteger)rank;
    if (second < 0) second += (NSInteger)rank;
    if ((NSUInteger)first >= rank || (NSUInteger)second >= rank) {
        // An axis outside the rank is the walk's refusal, so the two are handed over as they were written and
        // the walk names them: the release builds a tensor whose shape is nil here and writes nothing, which
        // is the named divergence every axis outside the rank in this library carries.
        return [self charon_mps_gather:CharonMPSGraphOperationKindTranspose
                                 tensor:tensor
                            parameters:@{@"gather": @"transpose",
                                         @"gatherPermutation": @[@(first), @(second)]}
                                   name:name];
    }
    NSMutableArray<NSNumber *> *permutation = [NSMutableArray arrayWithCapacity:rank];
    for (NSUInteger axis = 0; axis < rank; axis++)
        [permutation addObject:@((NSInteger)axis)];
    [permutation exchangeObjectAtIndex:(NSUInteger)first withObjectAtIndex:(NSUInteger)second];
    return [self charon_mps_gather:CharonMPSGraphOperationKindTranspose
                             tensor:tensor
                        parameters:@{@"gather": @"transpose", @"gatherPermutation": permutation}
                               name:name];
}

// The reshape, which arrived with the framework itself: the operand's elements in the same order at another
// extent, which is one gather with the axes left alone and the result's shape the caller's. The header allows
// a dynamic extent (-1) where the result type can be inferred unambiguously, and the walk resolves it; the
// volumes have to match or the release cannot build the graph at all (measured: "LLVM ERROR: Failed to infer
// result type(s)" takes the process down), so the port refuses that where the graph is built.
- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor
                        withShape:(NSArray<NSNumber *> *)shape
                             name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindReshape
                             tensor:tensor
                        parameters:@{@"gather": @"reshape", @"gatherShape": shape ?: @[]}
                               name:name];
}

// The slice, which arrived with the framework itself: one axis of the operand from a start for a length, or
// every axis at once from starts, ends and strides. It is one gather with an OFFSET and a STRIDE, which is the
// only thing it adds to the walk, and the header's two forms are the same walk - the simple one is a single
// axis with a stride of one and an end of start + length, which is how the factory spells it here. A negative
// start counts from the end of that axis, as the header says and as the walk measures.
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor
                      dimension:(NSUInteger)dimensionIndex
                          start:(NSInteger)start
                         length:(NSInteger)length
                           name:(NSString *)name
{
    NSUInteger rank = tensor.shape.count;
    NSMutableArray<NSNumber *> *starts = [NSMutableArray arrayWithCapacity:rank];
    NSMutableArray<NSNumber *> *strides = [NSMutableArray arrayWithCapacity:rank];
    NSMutableArray<NSNumber *> *ends = [NSMutableArray arrayWithCapacity:rank];
    for (NSUInteger axis = 0; axis < rank; axis++) {
        // The axis named takes the caller's start and the axes this form does not name start at zero and keep
        // the operand's own extent, which is what a stride of one and an end of that extent say. A negative
        // start is counted from the end by the walk, as the header says.
        [starts addObject:@(axis == dimensionIndex ? start : 0)];
        [strides addObject:@1];
        // An axis this form does not name keeps the operand's own extent, which is what a start of zero, a
        // stride of one and an end of the extent say.
        [ends addObject:@(axis == dimensionIndex ? start + length : tensor.shape[axis].integerValue)];
    }
    return [self charon_mps_gather:CharonMPSGraphOperationKindSlice
                             tensor:tensor
                        parameters:@{@"gather": @"slice",
                                     @"sliceStarts": starts, @"sliceEnds": ends, @"sliceStrides": strides,
                                     @"sliceAxis": @(dimensionIndex), @"sliceLength": @(length)}
                               name:name];
}

- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor
                         starts:(NSArray<NSNumber *> *)starts
                           ends:(NSArray<NSNumber *> *)ends
                        strides:(NSArray<NSNumber *> *)strides
                           name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindSlice
                             tensor:tensor
                        parameters:@{@"gather": @"slice",
                                     @"sliceStarts": starts ?: @[], @"sliceEnds": ends ?: @[],
                                     @"sliceStrides": strides ?: @[]}
                               name:name];
}

// The strided slice with the three masks, which is 14.0's own form of the same walk: a bit of startMask
// says the start written down for that axis is not to be read - the axis starts at zero instead, which is
// measured: a start of 5 and a start of -3 over a 2x4 both answer what a start of 0 answers, and a start of
// 9 with an end of 0 answers a result of no elements, which the release builds and then cannot make an
// NDArray for - a bit of endMask says the end is not to be read either, and the axis runs to its own last
// element (measured: endMask over axis 1 of a 2x4 from a start of 1 answers three elements, 2, 3 and 4, and
// with a stride of -1 from 3 it answers four, 4, 3, 2 and 1), and a bit of squeezeMask says the axis is
// dropped from the RESULT's shape whatever its extent, the elements being the mapped walk's own in order
// (measured: axis 0 of a 2x4 with squeezeMask answers a rank of one holding the first row, and it answers
// the same rank of one over two selected rows, and both axes together answer a rank of zero holding the
// first element).
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor
                         starts:(NSArray<NSNumber *> *)starts
                           ends:(NSArray<NSNumber *> *)ends
                        strides:(NSArray<NSNumber *> *)strides
                      startMask:(uint32_t)startMask
                        endMask:(uint32_t)endMask
                    squeezeMask:(uint32_t)squeezeMask
                           name:(NSString *)name
{
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[tensor]
                      parameters:@{@"gather": @"slice",
                                   @"sliceStarts": starts ?: @[], @"sliceEnds": ends ?: @[],
                                   @"sliceStrides": strides ?: @[],
                                   @"sliceStartMask": @(startMask), @"sliceEndMask": @(endMask),
                                   @"sliceSqueezeMask": @(squeezeMask)}
                             name:name];
}

// The slice's GRADIENT, which goes the other way: the result is a tensor of the shape the FORWARD pass's
// input had - which is why that shape is a tensor here and not a shape, and why it is the second input of
// the operation - and the gradient's elements are written into the region the same starts, ends and strides
// select, every other element of the result a zero. Measured on the release with the shape a constant, which
// is the only way it can be asked at all: over a destination filled with the byte 0xbd the zeros are written
// and not left, so the gradient is a scatter over a zeroed result and not a copy of the region.
//
// The parameters of the slice's GRADIENT, for both of the forms whose starts, ends and strides the caller
// wrote down and only the forward input's shape can be fed. The forward shape is in the parameters only when
// the caller made it a CONSTANT, whose value the factory reads here; a fed one is not in the parameters at
// all, because a dictionary cannot hold a nil and because the walk reads it out of the operation's second
// input when the graph runs instead (measured: with the shape fed the release's own result tensor carries no
// shape at all, before the run and after it).
- (NSDictionary *)charon_mps_sliceGradientParameters:(MPSGraphTensor *)fwdInShapeTensor
                                             starts:(NSArray<NSNumber *> *)starts
                                               ends:(NSArray<NSNumber *> *)ends
                                            strides:(NSArray<NSNumber *> *)strides
                                            gradient:(MPSGraphTensor *)inputGradientTensor
                                          startMask:(uint32_t)startMask
                                            endMask:(uint32_t)endMask
                                         squeezeMask:(uint32_t)squeezeMask
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"gather"] = @"sliceGradient";
    parameters[@"sliceStarts"] = starts ?: @[];
    parameters[@"sliceEnds"] = ends ?: @[];
    parameters[@"sliceStrides"] = strides ?: @[];
    parameters[@"sliceScatteredShape"] = inputGradientTensor.shape;
    if (startMask != 0)
        parameters[@"sliceStartMask"] = @(startMask);
    if (endMask != 0)
        parameters[@"sliceEndMask"] = @(endMask);
    if (squeezeMask != 0)
        parameters[@"sliceSqueezeMask"] = @(squeezeMask);
    NSArray<NSNumber *> *forward = [self charon_mps_constantShapeOfTensor:fwdInShapeTensor];
    if (forward != nil)
        parameters[@"sliceForwardShape"] = forward;
    return parameters;
}

// The shape arrives as data, and a shape that arrives as data is the one thing the release cannot build a
// graph over - measured: the result tensor's shape is nil at build and after the run, and the process writes
// the gradient's element 0 into the destination's element 0 and nothing else, whatever the destination's
// shape. The port reads that shape when the graph runs and answers this gradient, as the header describes the
// gradient output's shape as the forward pass input's shape; the divergence is
// named in the row of each of the three methods with the release's measurement.
- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor
                       fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor
                                 starts:(NSArray<NSNumber *> *)starts
                                   ends:(NSArray<NSNumber *> *)ends
                                strides:(NSArray<NSNumber *> *)strides
                                   name:(NSString *)name
{
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[inputGradientTensor, fwdInShapeTensor]
                      parameters:[self charon_mps_sliceGradientParameters:fwdInShapeTensor
                                                                      starts:starts ends:ends strides:strides
                                                                      gradient:inputGradientTensor
                                                                    startMask:0 endMask:0 squeezeMask:0]
                             name:name];
}

- (MPSGraphTensor *)sliceGradientTensor:(MPSGraphTensor *)inputGradientTensor
                       fwdInShapeTensor:(MPSGraphTensor *)fwdInShapeTensor
                                 starts:(NSArray<NSNumber *> *)starts
                                   ends:(NSArray<NSNumber *> *)ends
                                strides:(NSArray<NSNumber *> *)strides
                              startMask:(uint32_t)startMask
                                endMask:(uint32_t)endMask
                            squeezeMask:(uint32_t)squeezeMask
                                   name:(NSString *)name
{
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[inputGradientTensor, fwdInShapeTensor]
                      parameters:[self charon_mps_sliceGradientParameters:fwdInShapeTensor
                                                                      starts:starts ends:ends strides:strides
                                                                      gradient:inputGradientTensor
                                                                    startMask:startMask endMask:endMask
                                                                   squeezeMask:squeezeMask]
                             name:name];
}

#pragma mark - the concat family of 14.0: the one walk whose result is SEVERAL operands
// The three concatenations MPSGraph itself arrived with, over the header's own three forms: two tensors, any
// number of them, and any number of them interleaved. They are one walk in MPSGraphInterpreter14.m, which
// derives the result's shape from the operands' own shapes and lays a region of the axis per operand, so
// what is here is each method's own rule about which axis and whether the regions interleave.
//
// Measured on this host's own MPSGraph, over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) beside one of
// (5, 6, 7, 8 | 50, 60, 70, 80) and one of (9, 10, 11, 12 | 90, 100, 110, 120):
//   - END TO END along the axis, in the order the caller wrote them: axis 0 of the three is a 6x4 holding
//     the three 2x4s in that order, and axis 1 a 2x12 holding their rows side by side. The two-tensor form
//     answers the same thing as the many over two operands, and a negative axis is counted from the end.
//   - INTERLEAVED along the axis, which puts operand i's coordinate c at the result's coordinate
//     i + c * (the number of operands): axis 1 of two is a 2x8 of (1, 5, 2, 6, 3, 7, 4, 8 | 10, 50, 20, 60,
//     30, 70, 40, 80) and axis 1 of three a 2x12 of (1, 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12 | 10, 50, 90,
//     20, 60, 100, 30, 70, 110, 40, 80, 120). The result's extent on that axis is the SUM either way, and
//     the interleave form with NO answers exactly what the many-operand form answers.
//   - one operand is the identity: a 2x4 on its own is a 2x4 of its own eight values.
//   - every axis but the one named must hold the SAME extent in every operand, which the header calls
//     "broadcast compatible" and the release does not take: measured, a 1x4 beside a 2x4 with the concat on
//     axis 1 is refused by its own compiler with "'mps.concat' op invalid input tensor shapes, all input
//     shapes must match except at axis" (MPSGraphUtilities.mm:748), and the port raises there instead.
//   - an axis outside the rank is refused by the release's own compiler - "invalid axis tensor: [2], axis
//     must be in range -rank <= axis < rank, rank = 2" - and then "LLVM ERROR: Failed to infer result
//     type(s)" takes the process down with it, so the port raises where the graph is built.
//   - an EMPTY ARRAY is NOT a refusal, and the port answers it the way the release does rather than the way
//     this row first claimed. Measured on this host's own MPSGraph over the whole path, `concatTensors:@[]`
//     builds the result tensor with its shape NIL and its data type FLOAT32, `compileWithDevice:` returns an
//     executable and the run leaves the caller's destination as it was. So the result tensor here carries no
//     shape and no value; see the seam below for where that comes from.

- (MPSGraphTensor *)concatTensor:(MPSGraphTensor *)tensor
                      withTensor:(MPSGraphTensor *)tensor2
                       dimension:(NSInteger)dimensionIndex
                            name:(NSString *)name
{
    return [self charon_mps_concat:CharonMPSGraphOperationKindConcat
                            tensors:@[tensor, tensor2]
                               axis:dimensionIndex
                         interleave:NO
                              name:name];
}

- (MPSGraphTensor *)concatTensors:(NSArray<MPSGraphTensor *> *)tensors
                        dimension:(NSInteger)dimensionIndex
                             name:(NSString *)name
{
    return [self charon_mps_concat:CharonMPSGraphOperationKindConcat
                            tensors:tensors ?: @[]
                               axis:dimensionIndex
                         interleave:NO
                              name:name];
}

- (MPSGraphTensor *)concatTensors:(NSArray<MPSGraphTensor *> *)tensors
                        dimension:(NSInteger)dimensionIndex
                       interleave:(BOOL)interleave
                             name:(NSString *)name
{
    return [self charon_mps_concat:CharonMPSGraphOperationKindConcat
                            tensors:tensors ?: @[]
                               axis:dimensionIndex
                         interleave:interleave
                              name:name];
}

// The seam the concat and the stack both go through, which is the one walk of this library that has no
// single operand: the operation takes every tensor as an input, the parameters say which axis the result's
// elements are laid along and whether they interleave there and whether that axis is one the operands
// already have or one the result adds, and the interpreter's plan derives the result's shape from the
// operands' own - here at build time so that a caller can read the shape off the tensor, and again when the
// graph runs, where it is the offsets the walk needs.
//
// The result's DATA TYPE is the first operand's, which is what every operation of this family does and what
// the release answers for an operation whose operands are of more than one type (measured: a float32 2x4
// beside an int32 2x4 gives a float32 result and only the release's own compiler objects). With NO operands
// there is no first one, and the release's answer there is float32 - measured, 0x10000020 - so that is the
// value written down, and the measurement is named here rather than the number standing in for behaviour.
- (MPSGraphTensor *)charon_mps_concat:(CharonMPSGraphOperationKind)kind
                               tensors:(NSArray<MPSGraphTensor *> *)tensors
                                  axis:(NSInteger)axis
                            interleave:(BOOL)interleave
                                 name:(NSString *)name
{
    BOOL stacked = kind == CharonMPSGraphOperationKindStack;
    NSArray<NSNumber *> *shape = [self charon_mps_concatShapeOfTensors:tensors axis:axis interleave:interleave
                                                                stacked:stacked named:name];
    MPSGraphTensor *result = [self charon_mps_operation:kind inputs:tensors ?: @[]
                                            parameters:@{@"concatAxis": @(axis), @"concatInterleave": @(interleave),
                                                         @"concatStacked": @(stacked),
                                                         @"dataType": @(tensors.firstObject.dataType
                                                                        ?: MPSDataTypeFloat32)}
                                                   name:name];
    // No shape is put on the tensor when the plan has none, which is the empty array of operands: the
    // release's result tensor there has a nil shape too, and a caller that reads the shape off the tensor
    // gets nil on both sides.
    if (shape != nil)
        [result charon_mps_setShape:shape];
    return result;
}

#pragma mark - the split and the coordinate: the two seams of 15.4 whose result is not one operand's walk
// The SPLIT's seam, which is the first seam in this library that answers with SEVERAL tensors: the operation
// takes the operand as its only input, the parameters say which axis the regions are cut from and either the
// sizes as they were written or the count the caller named instead, and each OUTPUT is built here from the
// operand's own shape with that one axis replaced by that region's own size. So a caller reads every
// result's shape off its tensor before it runs anything, which is what the release answers - it infers the
// result's types when the graph is built - and the interpreter below builds the same regions when it runs.
//
// The sizes themselves, and every refusal about them, are in CharonMPSGraphSplitSizes in
// MPSGraphInterpreter14.m: asked here with the operand's own shape and asked there again with the shape the
// operand's value has, so a graph whose operand is fed is cut the way the value says and not the way the
// tensor did.
- (NSArray<MPSGraphTensor *> *)charon_mps_split:(MPSGraphTensor *)tensor
                                            axis:(NSInteger)axis
                                           sizes:(NSArray<NSNumber *> *)sizes
                                      numSplits:(NSUInteger)numSplits
                                            name:(NSString *)name
{
    NSArray<NSNumber *> *operandShape = tensor.shape;
    NSInteger where = axis;
    if (where < 0)
        where += (NSInteger)operandShape.count;
    NSArray<NSNumber *> *own = [self charon_mps_splitSizes:sizes numSplits:numSplits axis:where
                                            ofShape:operandShape named:name];
    MPSGraphOperation *operation = [self charon_mps_addOperationOfKind:CharonMPSGraphOperationKindSplit
                                                                 name:name
                                                                inputs:@[tensor]
                                                               outputs:@[]
                                                             parameters:@{@"splitAxis": @(where),
                                                                          @"splitSizes": sizes ?: @[],
                                                                          @"splitNumSplits": @(numSplits)}];
    NSMutableArray<MPSGraphTensor *> *results = [NSMutableArray arrayWithCapacity:own.count];
    for (NSUInteger i = 0; i < own.count; i++) {
        NSMutableArray<NSNumber *> *shape = [operandShape mutableCopy];
        shape[(NSUInteger)where] = own[i];
        MPSGraphTensor *result = [[MPSGraphTensor alloc] initWithShape:shape dataType:tensor.dataType
                                                              operation:operation index:i];
        [results addObject:result];
    }
    [operation charon_mps_setOutputTensors:results];
    return results;
}

// The COORDINATE ALONG AN AXIS's seam, which is the one walk with NO OPERAND: the operation's inputs are the
// fed parameters the caller gave and nothing else, its result is MPSDataTypeInt32 whatever the shape is, and
// the shape is the one the caller wrote down or the one the graph HOLDS in a constant - a fed parameter is
// read here, when the graph is built, exactly as the slice's gradient reads the shape of its forward input.
//
// A fed parameter that is a PLACEHOLDER is refused here, and the reason is measured rather than chosen: the
// release builds a graph over one and then takes the process down. An axis fed as a placeholder does it with
// SIGSEGV where the graph is built, for an axis of 1, 0, -1 and 5 alike; a shape fed as one builds a result
// whose shape is -1x-1 and goes down with it (exit 134), for an int32 and an int64 alike. A FLOATING POINT
// fed parameter is refused with the release's own sentence, which is the one the fed gather parameters of this
// library already raise.
- (MPSGraphTensor *)charon_mps_coordinates:(NSInteger)axis
                                    fedAxis:(MPSGraphTensor *)fedAxis
                                      shape:(NSArray<NSNumber *> *)shape
                                   fedShape:(MPSGraphTensor *)fedShape
                                       name:(NSString *)name
{
    NSArray<NSNumber *> *own = shape;
    if (fedShape != nil) {
        own = [self charon_mps_constantShapeOfTensor:fedShape];
        if (own == nil) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given the shape of its result as a tensor the caller feeds, "
                               @"and a shape that arrives as data is not a shape the release can build a graph "
                               @"over: measured, its own result then carries the shape -1x-1 and the process "
                               @"goes down with it (exit 134), for an int32 and an int64 alike", name];
        }
    }
    NSInteger where = axis;
    if (fedAxis != nil) {
        NSArray<NSNumber *> *one = [self charon_mps_constantShapeOfTensor:fedAxis];
        if (one == nil) {
            MPSDataType type = fedAxis.dataType;
            if (type == MPSDataTypeFloat32 || type == MPSDataTypeFloat16 || type == MPSDataTypeBool) {
                [NSException raise:NSInvalidArgumentException
                            format:@"MPSGraph: %@ was given its axis as a tensor of data type 0x%x, and an axis "
                                   @"is an index: measured, the release's own compiler refuses a floating "
                                   @"point operand with \"'mps.get_coordinates' op operand #1 must be 0D "
                                   @"tensor of mps index type values or static-shape defined tensor with shape "
                                   @"equal to [1] or unranked tensor of mps index type values\"", name,
                                    (unsigned)type];
            }
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given its axis as a tensor the caller feeds, and an axis that "
                               @"arrives as data is not an axis the release can build a graph over: measured, it "
                               @"takes the process down with SIGSEGV where the graph is built, for an axis of "
                               @"1, of 0, of -1 and of 5 alike", name];
        }
        if (one.count != 1) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given %lu numbers as its axis, and an axis is one of them: "
                               @"measured, the release takes an axis as a 0D tensor or one of shape [1]", name,
                        (unsigned long)one.count];
        }
        where = one.firstObject.integerValue;
    }
    // A SHAPE WITH NO ELEMENTS IN IT is refused where the graph is built, which is what this library does for
    // every extent the release will not run and what the split's own zero size is two files away. Measured:
    // the release BUILDS the result - a coordinate of a [0] is a [0] and of a 2x0 a 2x0, both int32 - and
    // then its own run refuses the destination with "object cannot be nil" from -[__NSArrayM
    // insertObject:atIndex:], because a tensor of no elements has no buffer to be given (measured on this
    // host: newBufferWithLength:0 and newBufferWithBytes:length:0 both answer nil). So there is no run to
    // answer here and the shape is refused instead of building a tensor nothing can be written into.
    for (NSUInteger k = 0; k < own.count; k++) {
        if (own[k].integerValue != 0)
            continue;
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for the coordinate of a shape whose axis %lu holds no "
                           @"elements at all, and a result of no elements is a shape the release cannot run: "
                           @"measured, it BUILDS the result (the shape line prints the shape) and its own run "
                           @"then refuses the destination with \"object cannot be nil\" from "
                           @"-[__NSArrayM insertObject:atIndex:], because a buffer of no bytes does not exist",
                          name, (unsigned long)k];
    }
    // The axis is counted from the end of the rank, and an axis outside it is refused where the graph is
    // built rather than left to be discovered as a wrong number: measured, the release's own compiler refuses
    // it with "'mps.get_coordinates' op invalid axis: N." (MPSGraphUtilities.mm:1678) and takes the process
    // down, and the refusal is the one an axis outside the rank is in every other family of this library.
    NSInteger rank = (NSInteger)own.count;
    if (where < 0)
        where += rank;
    if (where < 0 || where >= rank) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for the coordinate of axis %ld of a rank-%ld shape, and axis "
                           @"0 to %ld is all it has: measured, the release's own compiler refuses it with "
                           "\"'mps.get_coordinates' op invalid axis: %ld.\" (MPSGraphUtilities.mm:1678) and "
                           @"the process goes down",
                          name, (long)axis, (long)rank, (long)rank - 1, (long)axis];
    }
    MPSGraphOperation *operation = [self charon_mps_addOperationOfKind:CharonMPSGraphOperationKindCoordinates
                                                                 name:name
                                                                inputs:@[]
                                                               outputs:@[]
                                                             parameters:@{@"coordinateAxis": @(where),
                                                                          @"coordinateShape": own,
                                                                          @"dataType": @(MPSDataTypeInt32)}];
    MPSGraphTensor *result = [[MPSGraphTensor alloc] initWithShape:own dataType:MPSDataTypeInt32
                                                          operation:operation index:0];
    [operation charon_mps_setOutputTensors:@[result]];
    return result;
}

#pragma mark - the space-to-depth family: four operations of 15.0 and 16.1 that are ONE chain of walks
// What every operation of this family does, measured: it moves a BLOCK of the operand's spatial axes into
// the batch axis, or out of it, and the result's batch axis holds the operand's batch coordinate woven with
// the block's own coordinates. Two shapes of answer, and which one is which is what the header's
// usePixelShuffleOrder says - with YES the block's own coordinates are CONTIGUOUS in the result's batch axis
// and without it they are INTERLEAVED with the batch coordinate - and neither needs a walk of its own:
//
//   1. a RESHAPE that splits each spatial axis into its block rows and its block columns (for the two
//      operations that move the blocks TO the batch axis), or that merges them back (for the two that move
//      them FROM it), and splits or merges the batch axis the other way round;
//   2. a TRANSPOSE that puts the batch axis and the block's coordinates into the order the flag names;
//   3. the other half of the reshape.
//
// Every one of those three is a walk this library already has and the harness already compares - the reshape
// of 15.0 and the permutation transpose of 16.0 - so what is here is the chain, the order the axis is held
// in, and the rules the release refuses the family by.
//
// MEASURED on this host's own MPSGraph (macOS 27.0 build 26A428, M4 Pro, Metal 4) over a [3, 4, 6] of 1 to 72
// with a 2x2 block, the spatial axes @[@1, @2] and the batch axis @0, whose result is a [12, 2, 3]:
//
//   - THE BLOCK'S OWN COORDINATES ARE ORDERED WITH THE LAST SPATIAL AXIS FASTEST, which is what makes the 2D
//     form's two axis arguments read (widthAxis, heightAxis) with the width the fastest: measured, the 2D
//     form over the same operand answers byte for byte what the general form answers with
//     spatialAxes=@[@1, @2] and blockDimensions=@[@2, @2], and with THREE spatial axes the last of them
//     varies fastest of all.
//   - BLOCK DIMENSION i BELONGS TO SPATIAL AXIS i, and THE RESULT'S AXES ARE THE OPERAND'S OWN in the
//     operand's own order - the two together are what a list written the other way round is, and each is
//     measured over a [2, 4, 8] whose batch axis is 0: spatialAxes @[@1, @2] with block @[@4, @2] answers a
//     [16, 1, 4] - axis 1 over ITS OWN block of 4 is 1 and axis 2 over its own block of 2 is 4, so the result
//     holds the operand's axes and not the list's - and spatialAxes @[@2, @1] with the same @[@4, @2]
//     answers a [16, 2, 2], which is the same two numbers read positionally against the other list.
//     A list written the other way round with the blocks swapped to match pairs each axis with its own block
//     again and answers the SAME shape and DIFFERENT bytes: spatialAxes @[@1, @2] with block @[@2, @4] and
//     spatialAxes @[@2, @1] with block @[@4, @2] are both a [16, 2, 2] and not the same bytes, and with an
//     EQUAL block the two are both a [8, 1, 2] over a [2, 2, 4] and still not the same bytes - because the
//     block's own coordinate runs in the LIST's order, with the last of them fastest, whichever order that
//     is.
//   - WITH usePixelShuffleOrder=NO the batch coordinate is the FASTEST of the two in the result's batch axis:
//     the result's batch coordinate d' is d + D*k, where D is the operand's own batch extent and k is the
//     block's own coordinate in its row-major order - measured over the [3, 4, 6]: the elements at
//     (0, 0, w even) are at the result's d' = 0, those at (1, 0, w even) at d' = 1 and those at (0, 1, w even)
//     at d' = 6, and the odd half of each of those at d' = 3, 4 and 9.
//   - WITH usePixelShuffleOrder=YES the block's own coordinate is the fastest: d' is d*(the product of the
//     block) + k - measured, the same operand's (0, 0, w even) at d' = 0, (0, 0, w odd) at d' = 1,
//     (0, 1, w even) at d' = 2 and (1, 0, w even) at d' = 4.
//   - THE RESULT'S SHAPE is the operand's own with the batch axis made D*times the product of the block and
//     every spatial axis made extent/block - measured [3, 4, 6] -> [12, 2, 3] - and for the other direction the
//     same statement the other way round, the batch axis made D over the product of the block and every
//     spatial axis extent times its own.
//   - EACH OPERATION IS THE INVERSE OF ITS PARTNER WITH THE SAME FLAG, and the round trip is the IDENTITY:
//     measured, a space-to-depth over the [3, 4, 6] and then the depth-to-space of what it built answers
//     1 to 72 in the operand's own order, and a space-to-batch and then a batch-to-space does the same, for
//     BOTH flags. That is the header's own "This operation is the inverse of" sentence measured rather than
//     assumed, and it is why the two directions are one chain run forwards and one run backwards here.

- (MPSGraphTensor *)charon_mps_blockShuffle:(MPSGraphTensor *)tensor
                                     spatial:(NSArray<NSNumber *> *)spatial
                                       batch:(NSInteger)batch
                                       block:(NSArray<NSNumber *> *)block
                                     toBatch:(BOOL)toBatch
                                     shuffle:(BOOL)shuffle
                                         name:(NSString *)name
{
    // THE CHAIN, which is three operations this library already has and the harness already compares - the
    // reshape of 15.0 and the permutation transpose of 16.0 - so what the plan hands over is exactly what
    // each of the three carries: the shape the first splits the operand into, the permutation the second
    // reads, and the shape the third merges it back into. The plan itself, with every refusal of the family,
    // is in the interpreter (CharonMPSGraphBlockShufflePlan) and is asked twice over: here, when the graph
    // is built, by the four written-down forms whose axes are numbers the caller wrote down, and when the
    // graph RUNS, by the fed pair of 15.0, whose three axes arrive as data and so cannot be asked before
    // then - measured: the release builds a graph whose result carries no shape over three fed axes, hands
    // back an executable, and its run answers exactly what the written-down axes answer over the same operand.
    NSDictionary *plan = [self charon_mps_blockShufflePlan:name
                                                   ofShape:tensor.shape
                                                   spatial:spatial
                                                     batch:batch
                                                     block:block
                                                   toBatch:toBatch
                                                   shuffle:shuffle];
    MPSGraphTensor *split = [self reshapeTensor:tensor withShape:plan[@"splitShape"] name:name];
    MPSGraphTensor *moved = [self transposeTensor:split permutation:plan[@"permutation"] name:name];
    return [self reshapeTensor:moved withShape:plan[@"resultShape"] name:name];
}

// The FED forms of the block-moving family, where the spatial axes, the batch axis and the block dimensions
// each arrive as a tensor. A parameter the graph HOLDS - a CONSTANT - is read here, when the graph is built,
// and one the caller FEEDS is read when the graph RUNS instead, by the same plan the 2D form's fed pair is:
// measured on this host's own MPSGraph over the [3, 4, 6] of 1 to 72, both directions and each of the three
// parameters fed in turn, the release builds a graph whose result carries no shape, the compile hands back an
// executable, and the run writes exactly what the written-down axes write over the same operand. What the
// release refuses over a fed parameter is a FLOATING POINT one, at the graph's own building, with the sentence
// below - which is the same rule the 2D form's fed pair carries and not the rule this comment used to state.
- (MPSGraphTensor *)charon_mps_fedBlockShuffle:(MPSGraphTensor *)tensor
                                       spatial:(MPSGraphTensor *)spatial
                                         batch:(MPSGraphTensor *)batch
                                         block:(MPSGraphTensor *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle
                                           name:(NSString *)name
{
    NSArray<NSNumber *> *axes = [self charon_mps_constantShapeOfTensor:spatial];
    NSArray<NSNumber *> *where = [self charon_mps_constantShapeOfTensor:batch];
    NSArray<NSNumber *> *sizes = [self charon_mps_constantShapeOfTensor:block];
    if (axes == nil || where == nil || sizes == nil) {
        MPSGraphTensor *fed = axes == nil ? spatial : (where == nil ? batch : block);
        MPSDataType type = fed.dataType;
        if (type == MPSDataTypeFloat32 || type == MPSDataTypeFloat16 || type == MPSDataTypeBool) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was given a parameter of this family as a tensor of data type "
                               @"0x%x, and an axis, a block and a list of extents are all indices: measured, the "
                               @"release's own compiler refuses a floating point operand with \"'mps."
                               @"space_to_batch' op operand #%lu must be 0D tensor of mps index type values\"",
                              name, (unsigned)type, (unsigned long)(fed == spatial ? 1 : (fed == batch ? 2 : 3))];
        }
        // A PARAMETER THE CALLER FEEDS IS ANSWERED, at run time, by the same plan the 2D form's fed pair is:
        // measured on this host's own MPSGraph over the [3, 4, 6] of 1 to 72, both directions and each of the
        // three parameters fed in turn, the release builds a graph whose result carries NO shape,
        // -compileWithDevice: hands back an executable, and the run writes exactly what the written-down axes
        // write over the same operand - so the previous claim here, that a fed parameter is one the release
        // cannot build a graph over, was true of the 2D form's verifier and NOT of these. A floating point one
        // is still refused above, with the release's own compiler sentence, because that one it refuses at the
        // graph's own building.
        return [self charon_mps_operation:CharonMPSGraphOperationKindBlockShuffle
                                      inputs:@[tensor, spatial, batch, block]
                                  parameters:@{@"blockShuffle": @YES,
                                               @"blockShuffleGeneral": @YES,
                                               @"blockShuffleToBatch": @(toBatch),
                                               @"blockShuffleShuffle": @(shuffle),
                                               @"resultShapeIsFed": @YES}
                                         name:name];
    }
    if (where.count != 1) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was given %lu numbers as its batch axis, and the batch axis is one of "
                           @"them: measured, the release takes it as a 0D tensor or one of shape [1]", name,
                  (unsigned long)where.count];
    }
    return [self charon_mps_blockShuffle:tensor
                                  spatial:axes
                                    batch:where.firstObject.integerValue
                                    block:sizes
                                  toBatch:toBatch
                                  shuffle:shuffle
                                      name:name];
}

#pragma mark - the gather family: the one seam every release's shape factory goes through
// What a gather is: the result's shape, and the parameters that say which transformation produces it. The
// walk in MPSGraphInterpreter14.m is one function for the whole family - the squeeze and the expanded
// dimension and the flatten are the same gather with the axes left alone, and the transpose, the broadcast
// and the reverse are the same gather with them not - so this only has to hand the parameters over and to
// put the result's own shape where the factory computed it, which is the @shape every operation in this
// framework already carries.
- (MPSGraphTensor *)charon_mps_gather:(CharonMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name
{
    MPSGraphTensor *result = [self charon_mps_operation:kind inputs:@[tensor] parameters:parameters name:name];
    // The result's shape goes on the output tensor here, when the parameter is written down and the operand's
    // own shape is known - which is what a caller reads off the tensor before it runs anything, and what the
    // release can always answer because it infers the result's type when the graph is built. A fed parameter
    // is data and arrives when the graph runs, so the interpreter puts the shape on then.
    NSArray<NSNumber *> *shape = [self charon_mps_gatherShapeOfTensor:tensor
                                                          parameters:parameters
                                                                 named:name];
    if (shape != nil)
        [result charon_mps_setShape:shape];
    return result;
}

// HOW MANY AXES A FED PARAMETER NAMES, which is the one number the release reads out of it when the graph is
// built, and it reads it out of a fed tensor of rank ONE: a fed shape of [2] over a 2x4 gives a result of rank
// two and one of [4] a result of rank four, and the same fed tensor of [1] a result of rank one. A fed tensor
// of no rank, or of two axes or more, gives a result with NO shape at all - measured, a fed 0D reshape prints
// `result-shape nil` and so does a fed [2, 2], and the release's own compiler then refuses the second of those
// two with its own rule about the operand: "'mps.reshape' op operand #1 must be 0D tensor of mps index type
// values or 1D tensor of mps index type values or unranked tensor of mps index type values, but got
// 'tensor<2x2xsi32>'" (MPSGraphUtilities.mm:310). The fed [1] the port answers is that rule's own case.
static NSUInteger CharonMPSGraphFedAxisCount(NSArray<NSNumber *> *fedShape)
{
    if (fedShape.count != 1)
        return 0;
    NSInteger named = fedShape.firstObject.integerValue;
    return named > 0 ? (NSUInteger)named : 0;
}

// WHAT THE RELEASE'S OWN TENSOR CARRIES OVER A FED PARAMETER, which is neither the operand's shape nor
// nothing: the release infers the result's type when the graph is built, and over a fed parameter it infers
// as far as the graph already knows and writes -1 for every extent the fed value decides. The -1 is its own
// marker for an extent it could not resolve (the same one the two dynamic extents of a written-down reshape
// print), and it is on the tensor before the run and after it.
//
// Measured on this host's own MPSGraph over thirty-seven configurations - .agent-work/probe/fedshape.m, one
// case per process under a timeout, the raw run beside it - the rank of that vector is:
//
//   reshape   the axes the fed tensor names, so a fed shape of [2] of a 2x4 gives -1x-1 and one of [4] gives
//             -1x-1x-1x-1, and a fed shape of no rank or of two axes gives no shape at all.
//   expand    the axes the fed tensor names, at every rank of operand from two to four: a fed axis count of
//             one gives -1 and of two -1x-1.
//   flatten   TWO, whatever the axis is, because a flatten2D's result is of rank two whatever it collapses -
//             measured over a fed tensor of rank one, of two and of none.
//   squeeze   the operand's rank LESS the axes the fed tensor names, because that is how many axes it takes
//             off - one axis of a 1x2x4 gives -1x-1, two axes of the same give -1, one axis of a 1x1x2x4 gives
//             -1x-1x-1 and two axes of that give -1x-1 - and as many axes as the operand has is a result of
//             rank ZERO, which the release answers with an EMPTY shape rather than with none.
//   broadcast and reverse  the OPERAND'S OWN SHAPE, and that is what this function hands back for them.
//
// The broadcast is the one whose extents the measurements do not reduce: its RANK is the axes the fed tensor
// names in every one of the seven configurations measured, but the extents are the operand's own shape at a
// rank of operand two whatever the fed numbers are (a 2x4 to a fed [2] answers 2x4, whatever its two numbers
// are), a 2x2x4 to a fed [3] answers 2x2x4, and a 1x2x4 answers -1x2x4, -1x-1x2x4 and -1x-1 where its own
// extents and its own rank say 1x2x4 and 2x4. No rule over the operand's rank, the fed tensor's own shape and
// the two ranks reproduces those extents - the release's own answer describes neither the operand nor the
// broadcast - so the port carries the operand's own shape there, which is the release's answer in two of the
// seven, and the row of the broadcast names the five it does not, with this measurement.
static NSArray<NSNumber *> *CharonMPSGraphFedGatherResultShape(NSString *gather, NSArray<NSNumber *> *operandShape,
                                                               NSArray<NSNumber *> *fedShape)
{
    if ([gather isEqualToString:@"flatten"])
        return @[@(-1), @(-1)];
    NSUInteger named = CharonMPSGraphFedAxisCount(fedShape);
    if ([gather isEqualToString:@"squeeze"]) {
        if (named == 0)
            return nil;
        NSUInteger left = operandShape.count - named;
        NSMutableArray<NSNumber *> *unresolved = [NSMutableArray arrayWithCapacity:left];
        for (NSUInteger k = 0; k < left; k++)
            [unresolved addObject:@(-1)];
        return unresolved;
    }
    if ([gather isEqualToString:@"reshape"] || [gather isEqualToString:@"expand"]) {
        if (named == 0)
            return nil;
        NSMutableArray<NSNumber *> *unresolved = [NSMutableArray arrayWithCapacity:named];
        for (NSUInteger k = 0; k < named; k++)
            [unresolved addObject:@(-1)];
        return unresolved;
    }
    return operandShape;
}

// The gather whose parameter is fed rather than written down: the axis, the axes or the shape arrives as the
// operation's second input, and the walk reads it when the graph runs. Measured, an int32 and an int64 of
// shape [1] both answer for an axis, and a floating point one is refused by the factory because the release
// cannot build the graph over it at all.
- (MPSGraphTensor *)charon_mps_gather:(CharonMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                         fedParameter:(MPSGraphTensor *)fedParameter
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name
{
    MPSDataType type = fedParameter.dataType;
    if (type == MPSDataTypeFloat32 || type == MPSDataTypeFloat16 || type == MPSDataTypeBool) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for a parameter fed as a tensor of data type 0x%x, and "
                           @"an axis, a set of axes and a shape are all indices: measured, the release's own "
                           @"compiler refuses a floating point operand and the process goes down with it",
                            name, (unsigned)type];
    }
    // Nothing is added to the parameters here: the shape of a fed parameter is not known until the graph runs,
    // so the count of its elements is read out of the fed tensor data itself then, and the parameters say
    // only which of the operation's inputs carries it.
    MPSGraphTensor *result = [self charon_mps_operation:kind inputs:@[tensor, fedParameter]
                                             parameters:parameters name:name];
    // And the result does NOT carry the operand's shape, which is what every other operation of this framework
    // does fall back to: over a fed parameter that shape is a shape nobody asked for, and the release's own
    // tensor carries the measured vector of CharonMPSGraphFedGatherResultShape instead. The walk puts the real
    // shape on when the graph runs, which is the only moment a fed value is there to read it from.
    [result charon_mps_setShape:CharonMPSGraphFedGatherResultShape(parameters[@"gather"], tensor.shape,
                                                                   fedParameter.shape)];
    return result;
}

#pragma mark - pad and tile, which arrived with the framework itself

// The TILE, which is the gather walk with every axis REPEATED: the result's axis k is the operand's axis k at
// `multiplier[k]` times its extent. Measured on this host's own MPSGraph over a 2x4 of
// (1, 2, 3, 4 | 10, 20, 30, 40): a multiplier of (2, 3) answers a 4x12 holding the operand three times over
// twice down, and a multiplier of (1, 3) a 2x12 holding it three times across - so the copies run along the
// LAST axis first, which is the row-major order every other operation of this family answers in too.
- (MPSGraphTensor *)tileTensor:(MPSGraphTensor *)tensor
                withMultiplier:(NSArray<NSNumber *> *)multiplier
                          name:(NSString *)name
{
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[tensor]
                      parameters:@{@"gather": @"tile", @"tileMultiplier": multiplier ?: @[]}
                             name:name];
}

// The TILE'S GRADIENT, and the whole of what the release's is, measured on this host's own MPSGraph over a
// gradient of (1 ... N) at four shapes and about thirty multipliers:
//
//   - the incoming gradient must be of the SOURCE'S OWN SHAPE and the result is that shape. A gradient of
//     the tiled shape, or of the same element count in another arrangement, is refused by the release where
//     the graph runs ("Incompatible shape for parameter at index 0", MPSGraphExecutable.mm:4500), and a
//     multiplier that is not one entry per axis is refused by its compiler ("'mps.tile_gradient' op `input`
//     rank: 2 should match `multiplier` length: 3", MPSGraphUtilities.mm:1258). Both are raised here.
//   - FOR EACH AXIS j from 0 to rank-2 the multiplier m[j+1] is a WINDOW of m[j+1] terms along axis j, at
//     axis j's OWN STRIDE, weighted one each, and a term that leaves the axis is DROPPED and not clamped:
//     over a 4x4 of (1 ... 16), m[1] of 2 answers 6, 8, 10, 12 | 14, 16, 18, 20 | 22, 24, 26, 28 | 13, 14,
//     15, 16, of 3 answers 15, 18, 21, 24 | 27, 30, 33, 36 | 22, 24, 26, 28 | 13, 14, 15, 16, and of 4 or of
//     5 or of 9 all answer 28, 32, 36, 40 | 27, 30, 33, 36 | 22, 24, 26, 28 | 13, 14, 15, 16 - the last
//     three rows of each are the window cut short by the end of the axis, which is what "dropped" means.
//   - the windows COMPOSE ACROSS AXES, and each axis's window is taken of the INCOMING GRADIENT and not of
//     the sum so far, so a rank of three with (3, 3, 3) is the 3x3 box around each element of the leading
//     block and a rank of two with (3, 3) is three terms and not six: measured, a 4x4 with (2, 2) answers
//     byte for byte what a 4x4 with (1, 2) answers, and a 4x4 with (3, 3) what a 4x4 with (1, 3) answers.
//   - m[0] IS NOT READ while it is at most the leading extent: measured, the gradient is answered unchanged
//     for m[0] of 1 and 2 on an 8x4, of 1 to 4 on a 4x4, of 1 to 5 on a 3x4, of 1 to 8 on a 2x4, of 1 to 3
//     on a 5x4 and of 1 and 2 on a 6x4. Above the leading extent the release's answer STOPS BEING THE
//     GRADIENT OF THE INCOMING GRADIENT and starts reading the SOURCE instead - measured, a gradient of
//     (1, 2, 4, 8, ...) with a source of ones and m[0] of 3 answers twice the gradient, while the same
//     source of (1, 2, 4, 8, ...) with a gradient of ONES answers 2, 4, 7, 12, 21, 38, 71, 136 - which is
//     the source's own elements and not the gradient's. An operation whose answer depends on the forward
//     operand is not a gradient, and there is no rule here to reproduce, so a leading multiplier above the
//     leading extent is refused and the row says so.
//   - AN ENTRY OF ZERO answers ZEROS, wherever it is: measured over a 4x4, (1, 0), (0, 1), (2, 0), (0, 2)
//     and (0, 0) all answer sixteen zeros.
//
// So the answer is the sum of the incoming gradient and one term per shift of every axis, every term sliced
// out of the INCOMING GRADIENT with that axis's own stride as the shift - which drops what runs off the end
// of the axis, because a slice's result coordinate with no element of the operand behind it is a zero, and
// that is the whole of "dropped and not clamped".
- (MPSGraphTensor *)tileGradientWithIncomingGradientTensor:(MPSGraphTensor *)incomingGradientTensor
                                             sourceTensor:(MPSGraphTensor *)sourceTensor
                                            withMultiplier:(NSArray<NSNumber *> *)multiplier
                                                      name:(NSString *)name
{
    NSArray<NSNumber *> *sourceShape = sourceTensor.shape;
    NSUInteger rank = sourceShape.count;
    if (multiplier.count != rank) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for a tile gradient of a rank-%lu tensor with a multiplier "
                           @"of %lu entries, and the release's own compiler refuses it: 'mps.tile_gradient' op "
                           @"`input` rank: %lu should match `multiplier` length: %lu",
                         name, (unsigned long)rank, (unsigned long)multiplier.count, (unsigned long)rank,
                         (unsigned long)multiplier.count];
    }
    for (NSUInteger axis = 0; axis < rank; axis++) {
        if (multiplier[axis].integerValue < 0) {
            [NSException raise:NSInvalidArgumentException
                        format:@"MPSGraph: %@ was asked for %ld copies of axis %lu, and a tile makes one or "
                               @"more of every axis", name, (long)multiplier[axis].integerValue,
                        (unsigned long)axis];
        }
    }
    // The gradient must be of the source's own shape, and the result is that shape whatever the multiplier
    // says. The release refuses the two that are not where the graph RUNS rather than where it is built -
    // "Incompatible shape for parameter at index 0" (MPSGraphExecutable.mm:4500) - and the refusal here is at
    // the build, which is earlier and is what the row records.
    if (incomingGradientTensor.shape != nil && ![incomingGradientTensor.shape isEqualToArray:sourceShape]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for the tile gradient of a tensor of %@ with an incoming "
                           @"gradient of %@, and a gradient is of the tensor it is the gradient of: the "
                           @"release answers 'Incompatible shape for parameter at index 0' where the graph "
                           @"runs", name, [sourceShape componentsJoinedByString:@"x"],
                     [incomingGradientTensor.shape componentsJoinedByString:@"x"]];
    }
    MPSDataType type = incomingGradientTensor.dataType;
    // An entry of zero is an empty window and an empty sum, which is a tensor of zeros of the source's own
    // shape in the gradient's own type - measured, every position of the multiplier that holds a zero answers
    // zeros and not the gradient.
    for (NSUInteger axis = 0; axis < rank; axis++) {
        if (multiplier[axis].integerValue != 0)
            continue;
        NSUInteger count = 1;
        for (NSNumber *extent in sourceShape) count *= (NSUInteger)extent.integerValue;
        size_t width = MPSSizeofMPSDataType(type);
        void *zeros = calloc(count, width);
        MPSGraphTensor *answer = [self constantWithShape:sourceShape dataType:type
                                                 values:[NSData dataWithBytes:zeros length:count * width]
                                                   name:name];
        free(zeros);
        return answer;
    }
    // The leading multiplier, read only while it is at most the leading extent - see the comment above.
    NSUInteger leading = sourceShape.firstObject.unsignedIntegerValue;
    if (multiplier.firstObject.integerValue > (NSInteger)leading) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for %ld copies of the leading axis, which is %lu long, "
                           @"and above its own extent the release's answer is not a gradient of the incoming "
                           @"gradient at all: measured, it reads the SOURCE tensor instead, which is not a rule "
                           @"this port can reproduce",
                         name, (long)multiplier.firstObject.integerValue, (unsigned long)leading];
    }
    // One term per shift of every axis below the last, and the sum of all of them with the incoming gradient.
    // The stride of an axis is the product of the extents after it, which is what one step of that axis moves
    // an element by - the last axis's stride is one and no window is taken along the last axis, because the
    // multiplier that would give it is the leading one and that is not read.
    NSMutableArray<MPSGraphTensor *> *terms = [NSMutableArray arrayWithObject:incomingGradientTensor];
    for (NSUInteger axis = 0; axis + 1 < rank; axis++) {
        NSInteger window = multiplier[axis + 1].integerValue;
        NSUInteger stride = 1;
        for (NSUInteger after = axis + 1; after < rank; after++)
            stride *= (NSUInteger)sourceShape[after].integerValue;
        NSUInteger extent = (NSUInteger)sourceShape[axis].integerValue;
        for (NSInteger shift = 1; shift < window; shift++) {
            // A shift past the axis is no term at all: the window is a count of terms ALONG the axis, so
            // the fourth shift of an axis of four reaches no coordinate and the fifth never happens. This is
            // why a window of five over a leading block of four answers what a window of four answers.
            if ((NSUInteger)shift >= extent)
                break;
            NSMutableArray<NSNumber *> *starts = [NSMutableArray arrayWithCapacity:rank];
            NSMutableArray<NSNumber *> *ends = [NSMutableArray arrayWithCapacity:rank];
            NSMutableArray<NSNumber *> *strides = [NSMutableArray arrayWithCapacity:rank];
            NSMutableArray<NSNumber *> *padLeft = [NSMutableArray arrayWithCapacity:rank];
            NSMutableArray<NSNumber *> *padRight = [NSMutableArray arrayWithCapacity:rank];
            for (NSUInteger k = 0; k < rank; k++) {
                BOOL onAxis = k == axis;
                [starts addObject:onAxis ? @(shift) : @0];
                [ends addObject:sourceShape[k]];
                [strides addObject:onAxis ? @(stride) : @1];
                [padLeft addObject:onAxis ? @(shift) : @0];
                [padRight addObject:@0];
            }
            // The region is the axis from `shift` to its end at the axis's own stride, which is the window's
            // shift of the gradient with what ran off the end of the axis left out - and it is put back at
            // the front with a ZERO pad rather than left short, because a gather's result coordinate with no
            // element of the operand behind it is not written at all and the result's bytes are a fresh
            // buffer's. The pad writes every element of the result, which is what makes the dropped terms
            // zeros and not whatever the allocator left.
            MPSGraphTensor *term = [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                                                   inputs:@[incomingGradientTensor]
                                               parameters:@{@"gather": @"slice", @"sliceStarts": starts,
                                                            @"sliceEnds": ends, @"sliceStrides": strides}
                                                      name:name];
            term = [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                                  inputs:@[term]
                              parameters:@{@"gather": @"pad", @"padMode": @(MPSGraphPaddingModeZero),
                                           @"padLeft": padLeft, @"padRight": padRight, @"padConstant": @0}
                                     name:name];
            [terms addObject:term];
        }
    }
    MPSGraphTensor *sum = terms.firstObject;
    for (NSUInteger i = 1; i < terms.count; i++)
        sum = [self additionWithPrimaryTensor:sum secondaryTensor:terms[i] name:name];
    return sum;
}

// The PAD, and the whole of what its five answered modes are, each measured on this host's own MPSGraph:
//
//   MPSGraphPaddingModeConstant  the caller's constantValue, written in the result's own type (measured, a
//                                constant of 99 over a float32 2x4 answers 99 and not 99.0);
//   MPSGraphPaddingModeZero      zero, which is the same constant with a different name and is a mode of its
//                                own in the header;
//   MPSGraphPaddingModeClampToEdge  the nearest element of the axis - measured (1, 1, 1, 2, 3, 4) for one at
//                                each end of axis 1 of a 2x4;
//   MPSGraphPaddingModeReflect   the mirror ACROSS THE EDGE, so index -1 is the element at index +1 - measured
//                                (2, 1, 2, 3, 4, 3) for one at each end, which is neither the mirror about the
//                                last element (3, 1, 2, 3, 4, 3) nor one that repeats the edge;
//   MPSGraphPaddingModeSymmetric the mirror that DOES repeat the edge - measured (1, 1, 2, 3, 4, 4).
//
// The two mirror modes cannot reach past the axis they mirror, and each reaches a different way: measured
// over extents one, two and three and both sides of the axis, a REFLECT answers up to the axis LESS ONE and
// a SYMMETRIC up to the axis ITSELF, and one element more of either is refused by the release's own
// compiler ("Optimize Original Module MLIR pass manager failed"). PERIODIC and ANTI-PERIODIC are refused
// outright, with the release's own words "Unsupported paddingMode", after it has built the result tensor. So
// the two modes the release does not answer are refused where the graph is built, and the other five are the
// walk's own.
- (MPSGraphTensor *)padTensor:(MPSGraphTensor *)tensor
             withPaddingMode:(MPSGraphPaddingMode)paddingMode
                 leftPadding:(NSArray<NSNumber *> *)leftPadding
                rightPadding:(NSArray<NSNumber *> *)rightPadding
               constantValue:(double)constantValue
                        name:(NSString *)name
{
    if (paddingMode == MPSGraphPaddingModePeriodic || paddingMode == MPSGraphPaddingModeAntiPeriodic) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked to pad with mode %ld, and the release refuses both of the "
                           @"periodic modes with its own words, \"Unsupported paddingMode\", after it has "
                           @"built the result tensor", name, (long)paddingMode];
    }
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[tensor]
                      parameters:@{@"gather": @"pad", @"padMode": @(paddingMode),
                                   @"padLeft": leftPadding ?: @[], @"padRight": rightPadding ?: @[],
                                   @"padConstant": @(constantValue)}
                             name:name];
}

// The pad's GRADIENT, which is the forward pass's output copied back into a tensor of the input's own shape:
// the incoming gradient is of the PADDED shape, and every element of it outside the region the padding
// covered is dropped, which is the same scatter the slice's gradient is with the left padding as its offset.
// Measured: over an incoming gradient of (1 ... 24) as a 4x6 and a padding of (1, 2) at the left and (1, 0) at
// the right of a 2x4, the release answers 9, 10, 11, 12 | 15, 16, 17, 18 - which is the incoming gradient's own
// rows 1 and 2, columns 2 to 5, and is the sum over the copies that land on each element, which for a pad is
// the one copy and so is that element's value. (The numbers this comment carried before, 102 and 174 down the
// two rows, were not the release's and are taken back; the row of the registry had the right ones already.)
- (MPSGraphTensor *)padGradientWithIncomingGradientTensor:(MPSGraphTensor *)incomingGradientTensor
                                            sourceTensor:(MPSGraphTensor *)sourceTensor
                                             paddingMode:(MPSGraphPaddingMode)paddingMode
                                             leftPadding:(NSArray<NSNumber *> *)leftPadding
                                            rightPadding:(NSArray<NSNumber *> *)rightPadding
                                                    name:(NSString *)name
{
    (void)paddingMode;
    NSUInteger rank = sourceTensor.shape.count;
    NSMutableArray<NSNumber *> *oneEach = [NSMutableArray arrayWithCapacity:rank];
    for (NSUInteger k = 0; k < rank; k++)
        [oneEach addObject:@1];
    // The offset is the NEGATED left padding, and that is the whole of what a gradient of a pad is: the
    // region sits `leftPadding` elements into the incoming gradient, which is of the PADDED shape, so the
    // destination's coordinate is the incoming gradient's less that - measured, a gradient of (1 ... 24) as a
    // 4x6 over a padding of (1, 2) at the left and (1, 0) at the right answers 9, 10, 11, 12 | 15, 16, 17, 18,
    // which is the incoming gradient's own rows 1 and 2, columns 2 to 5.
    NSMutableArray<NSNumber *> *behind = [NSMutableArray arrayWithCapacity:leftPadding.count];
    for (NSNumber *before in leftPadding)
        [behind addObject:@(-before.integerValue)];
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[incomingGradientTensor, sourceTensor]
                      parameters:@{@"gather": @"scatter", @"shape": sourceTensor.shape,
                                   @"offsets": behind, @"strides": oneEach}
                             name:name];
}

#pragma mark - the slice family: the one seam its three directions go through

// The slice family's operation, of whichever direction the factory names in `parameters`, over the inputs
// it hands over. This is the gather seam with the inputs named rather than the one operand they are all
// built from: a gradient carries the gradient and the forward input's shape, an update carries the data and
// the update, and a fed form carries its starts, ends and strides as the operation's own later inputs.
//
// The result's shape goes on the output tensor where the plan can be derived now, which is what a caller
// reads off the tensor before it runs anything - and what the release can answer, because it infers the
// result's type when the graph is built (measured: with the shape of a gradient fed rather than written down,
// the release's own result tensor carries no shape at all, before the run or after it). A parameter the
// caller fed is data and arrives when the graph runs, so the interpreter puts the shape on then.
- (MPSGraphTensor *)charon_mps_slice:(CharonMPSGraphOperationKind)kind
                               inputs:(NSArray<MPSGraphTensor *> *)inputs
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name
{
    MPSGraphTensor *result = [self charon_mps_operation:kind inputs:inputs parameters:parameters name:name];
    NSArray<NSNumber *> *shape = [self charon_mps_gatherShapeOfTensor:inputs.firstObject
                                                          parameters:parameters
                                                                 named:name];
    if (shape != nil) {
        [result charon_mps_setShape:shape];
    } else if ([parameters[@"gather"] isEqualToString:@"sliceGradient"] && parameters[@"sliceForwardShape"] == nil) {
        // The GRADIENT's result is a tensor of the shape the forward pass's INPUT had, and that shape arrives
        // as the operation's second input: a constant's value is read here, when the graph is built, and a
        // feed's value only there when the graph runs. Over a feed the release's own result tensor carries NO
        // shape at all, before the run and after it - measured, refusals.m's slice-gradient-fed-shape and
        // slice-gradient-fed both print `result-shape nil`, and the harness asks the same of both forms of the
        // row in gather_slice_rest - so what charon_mps_operation: left on the tensor, which is the shape of
        // the INCOMING GRADIENT and so of the region rather than of the result, is taken off rather than left
        // to a caller that would read it as the answer.
        [result charon_mps_setShape:nil];
    }
    return result;
}

// The shape a CONSTANT tensor holds, and nil for anything else. A slice's gradient takes the shape of its
// forward input as a tensor, so the shape is a shape the graph has to be told - and the only place the graph
// can be told is a value that is in the graph, which is what a constant is. This is the release's own
// arrangement and not this port's convenience: with the shape a constant the release's result tensor carries
// its shape at build time and answers the gradient, and with the shape fed it carries none and writes one
// element (measured, both, in the row of each of the gradient methods).
- (NSArray<NSNumber *> *)charon_mps_constantShapeOfTensor:(MPSGraphTensor *)tensor
{
    MPSGraphOperation *operation = tensor.operation;
    if (operation == nil || [operation charon_mps_kind] != CharonMPSGraphOperationKindConstant)
        return nil;
    NSData *bytes = [operation charon_mps_parameters][@"values"];
    if (bytes == nil)
        return nil;
    // An int32 or an int64 is what a shape is fed as, and the release takes both: measured, an int32 and an
    // int64 of shape [1] each answer for an axis, and a shape is the same kind of number one axis longer.
    NSUInteger width = MPSSizeofMPSDataType(tensor.dataType);
    if (width != 4 && width != 8)
        return nil;
    NSUInteger count = bytes.length / width;
    NSMutableArray<NSNumber *> *shape = [NSMutableArray arrayWithCapacity:count];
    const uint8_t *raw = bytes.bytes;
    for (NSUInteger i = 0; i < count; i++) {
        int64_t extent = width == 4 ? (int64_t)((const int32_t *)raw)[i] : ((const int64_t *)raw)[i];
        [shape addObject:@(extent)];
    }
    return shape;
}

#pragma mark - the cumulative family, whose seam every release's scan factory goes through

// The axis of a scan is the caller's and is normalised the way the reduction family's is: a negative axis
// is counted from the end of the rank, and an axis outside it is refused when the graph is built rather
// than left to be discovered as a wrong number. Measured on this host's own MPSGraph, an axis outside the
// rank is refused by the release too and by a form no caller can catch: MPSGraphNDArrayScan.mm:253 writes
// "Axis = ... This class only supports axis = 0, 1, 2, 3" and takes the process down with it, so there is
// no answer to record and a tensor for it would be an answer the release never gives.
- (NSInteger)charon_mps_scanAxis:(NSInteger)axis ofRank:(NSUInteger)rank named:(NSString *)name
{
    NSInteger normalised = axis;
    if (normalised < 0)
        normalised += (NSInteger)rank;
    if (normalised < 0 || normalised >= (NSInteger)rank) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked to scan axis %ld of a rank-%lu tensor, and axis 0 to "
                           @"%lu is all it has",
                            name, (long)axis, (unsigned long)rank, (unsigned long)rank];
    }
    return normalised;
}

- (MPSGraphTensor *)charon_mps_scan:(CharonMPSGraphOperationKind)kind
                               axis:(NSInteger)axis
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name
{
    NSUInteger rank = tensor.shape.count;
    NSInteger normalised = [self charon_mps_scanAxis:axis ofRank:rank named:name];
    return [self charon_mps_operation:kind
                               inputs:@[tensor]
                           parameters:@{@"scanCombination": combination, @"scanAxis": @(normalised),
                                        @"scanExclusive": @(exclusive), @"scanReverse": @(reverse)}
                                  name:name];
}

- (MPSGraphTensor *)charon_mps_scan:(CharonMPSGraphOperationKind)kind
                         axisTensor:(MPSGraphTensor *)axisTensor
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name
{
    // The axis is data here, so there is no axis to normalise at build time: the walk reads it when the
    // graph runs and refuses it there, the way the reduction family refuses an axis outside the rank.
    // What can be asked now is the axis tensor's own type, and a floating point one is refused now for
    // the reason in the header: the release cannot build the graph over one at all.
    MPSDataType axisType = axisTensor.dataType;
    if (axisType != MPSDataTypeInt32 && axisType != MPSDataTypeInt64 && axisType != MPSDataTypeUInt32 &&
        axisType != MPSDataTypeUInt64 && axisType != MPSDataTypeInt16 && axisType != MPSDataTypeUInt16 &&
        axisType != MPSDataTypeInt8 && axisType != MPSDataTypeUInt8) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked to scan along an axis tensor of data type 0x%x, and an "
                           @"axis is an index: measured, the release's own compiler refuses the operand "
                           @"('mps.cumulative_sum' op operand #1 must be 0D tensor of mps index type values "
                           @"or ... shape equal to [1]) and the process goes down with it",
                            name, (unsigned)axisType];
    }
    return [self charon_mps_operation:kind
                               inputs:@[tensor, axisTensor]
                           parameters:@{@"scanCombination": combination, @"scanAxisTensor": @YES,
                                        @"scanExclusive": @(exclusive), @"scanReverse": @(reverse)}
                                  name:name];
}

- (MPSGraphTensor *)reductionSumWithTensor:(MPSGraphTensor *)tensor
                                       axis:(NSInteger)axis
                                       name:(NSString *)name
{
    return [self charon_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"sum"
                                    kind:CharonMPSGraphOperationKindReductionSum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionSumWithTensor:(MPSGraphTensor *)tensor
                                       axes:(NSArray<NSNumber *> *)axes
                                       name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"sum"
                                    kind:CharonMPSGraphOperationKindReductionSum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionProductWithTensor:(MPSGraphTensor *)tensor
                                          axis:(NSInteger)axis
                                          name:(NSString *)name
{
    return [self charon_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"product"
                                    kind:CharonMPSGraphOperationKindReductionProduct propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionProductWithTensor:(MPSGraphTensor *)tensor
                                          axes:(NSArray<NSNumber *> *)axes
                                          name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"product"
                                    kind:CharonMPSGraphOperationKindReductionProduct propagatesNaN:NO name:name];
}

// The two maxima and the two minima differ in one thing only, and it is the one a reduction of floating
// point values is asked about: a NaN in the reduced set. A maximum that does not propagate answers the
// largest value that is not a NaN, so a NaN is skipped and the rest decide; a maximum that does
// propagate answers a NaN if there was one. Measured on this host's own MPSGraph over a 2x4 of
// (1, NaN, 3, 4 | NaN, 6, 7, 8): reductionMaximumWithTensor:axis:1 answers (4, 8) and
// reductionMaximumPropagateNaNWithTensor:axis:1 answers (NaN, NaN); the two minima answer (1, 6) and
// (NaN, NaN) over the same feed. The skipping maximum is C99's fmax, which is what it agrees with: a
// NaN operand is ignored, and a set of nothing but NaNs answers a NaN.
- (MPSGraphTensor *)reductionMaximumWithTensor:(MPSGraphTensor *)tensor
                                          axis:(NSInteger)axis
                                          name:(NSString *)name
{
    return [self charon_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"maximum"
                                    kind:CharonMPSGraphOperationKindReductionMaximum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMaximumWithTensor:(MPSGraphTensor *)tensor
                                          axes:(NSArray<NSNumber *> *)axes
                                          name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"maximum"
                                    kind:CharonMPSGraphOperationKindReductionMaximum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMinimumWithTensor:(MPSGraphTensor *)tensor
                                          axis:(NSInteger)axis
                                          name:(NSString *)name
{
    return [self charon_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"minimum"
                                    kind:CharonMPSGraphOperationKindReductionMinimum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMinimumWithTensor:(MPSGraphTensor *)tensor
                                          axes:(NSArray<NSNumber *> *)axes
                                          name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"minimum"
                                    kind:CharonMPSGraphOperationKindReductionMinimum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMaximumPropagateNaNWithTensor:(MPSGraphTensor *)tensor
                                                     axis:(NSInteger)axis
                                                     name:(NSString *)name
{
    return [self charon_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"maximum"
                                    kind:CharonMPSGraphOperationKindReductionMaximumPropagateNaN propagatesNaN:YES name:name];
}

- (MPSGraphTensor *)reductionMaximumPropagateNaNWithTensor:(MPSGraphTensor *)tensor
                                                     axes:(NSArray<NSNumber *> *)axes
                                                     name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"maximum"
                                    kind:CharonMPSGraphOperationKindReductionMaximumPropagateNaN propagatesNaN:YES name:name];
}

- (MPSGraphTensor *)reductionMinimumPropagateNaNWithTensor:(MPSGraphTensor *)tensor
                                                     axis:(NSInteger)axis
                                                     name:(NSString *)name
{
    return [self charon_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"minimum"
                                    kind:CharonMPSGraphOperationKindReductionMinimumPropagateNaN propagatesNaN:YES name:name];
}

- (MPSGraphTensor *)reductionMinimumPropagateNaNWithTensor:(MPSGraphTensor *)tensor
                                                     axes:(NSArray<NSNumber *> *)axes
                                                     name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"minimum"
                                    kind:CharonMPSGraphOperationKindReductionMinimumPropagateNaN propagatesNaN:YES name:name];
}

// The mean and the variance are the reduction family in the two forms every framework of arithmetic has
// them: the first is the sum over the axis divided by how many values were summed, and the second is the
// mean of the squared deviations. Both are written back through the type they are stored as, so a mean
// of integers is the truncated quotient and not a rounded one. Measured on this host's own MPSGraph:
// over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40), meanOfTensor:axes:@[@1] answers (2.5, 25) and
// varianceOfTensor:axes:@[@1] answers (1.25, 625); over the same feed as int32, where the sums are -6 and
// 10 and the counts are both 4, the mean answers (-1, 2) and the variance (1, 1) - the quotients
// 1.25 and 1.25 and 1.25 truncated twice, and 625 fits in neither a half nor an int32.
- (MPSGraphTensor *)meanOfTensor:(MPSGraphTensor *)tensor
                            axes:(NSArray<NSNumber *> *)axes
                            name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"mean"
                                    kind:CharonMPSGraphOperationKindReductionMean propagatesNaN:NO name:name];
}

// The variance is the only member of the family that can be given the mean it is to be taken about,
// which is the form a normalising network uses when it has already computed the mean for another reason.
// The two forms are the same arithmetic with the mean handed over instead of computed again, and the
// port holds them to each other rather than to two different answers: -varianceOfTensor:axes: is
// -varianceOfTensor:meanTensor: with a mean computed by the graph itself.
- (MPSGraphTensor *)varianceOfTensor:(MPSGraphTensor *)tensor
                                axes:(NSArray<NSNumber *> *)axes
                                name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"variance"
                                    kind:CharonMPSGraphOperationKindReductionVariance propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)varianceOfTensor:(MPSGraphTensor *)tensor
                          meanTensor:(MPSGraphTensor *)meanTensor
                                axes:(NSArray<NSNumber *> *)axes
                                name:(NSString *)name
{
    return [self charon_mps_reduction:CharonMPSGraphOperationKindReductionVariance
                                 axes:axes
                               tensor:tensor
                          parameters:@{@"combination": @"variance", @"propagateNaN": @NO,
                                       @"mean": meanTensor}
                                 name:name];
}

#pragma mark - the run, async and encode forms, which are all one walk

// What every one of the seven forms below does, and there are two shapes of answer between them, both
// measured on this host's own MPSGraph over a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) added to itself:
//
//   - the form that RETURNS a dictionary returns the release's OWN tensor data and leaves the caller's buffer
//     untouched: the caller passed a result tensor data of its own, and after the run its buffer still holds
//     zeros and the returned object is not the one the caller passed;
//   - the form that takes a RESULTS DICTIONARY writes into the data the caller put in it: the same graph
//     answers 2, 4, 6, 8 | 20, 40, 60, 80 into the caller's own buffer.
//
// The async and the encode forms are the same walk: the release's own difference between them is what it does
// with the GPU afterwards, and this port's walk is over the host's memory on the CPU with nothing to
// schedule, so the command queue and the command buffer are read for nothing - which each form says rather
// than leaving to look like an oversight.
//
// The descriptor's shared events are honoured at both ends of the walk: the WAITS are checked before it and
// the SIGNALS are written after it, and the one stage the header names is MPSGraphExecutionStageCompleted.
// Measured on this host: a fresh id<MTLSharedEvent>'s own signaledValue is 0 and naming it in a descriptor
// does not change it, so writing it is the only thing a run can do with one.
static NSDictionary *CharonMPSGraphRunForm(MPSGraph *graph, NSDictionary *feeds,
                                           NSArray<MPSGraphTensor *> *targets,
                                           NSArray<MPSGraphOperation *> *operations, NSDictionary *results,
                                           MPSGraphExecutionDescriptor *descriptor)
{
    [descriptor charon_mps_applyEventsAtStage:MPSGraphExecutionStageCompleted named:@"a graph run"];
    // The forms that take a RESULTS DICTIONARY name no target tensors of their own - the dictionary is what
    // says which results are wanted, and the walk only computes what it is asked for, so its keys are the
    // targets here. The forms that return a dictionary were given the tensors instead.
    NSArray<MPSGraphTensor *> *wanted = targets.count ? targets : (results != nil ? results.allKeys : nil);
    NSDictionary *computed = [graph runWithFeeds:feeds targetTensors:wanted targetOperations:operations];
    for (MPSGraphTensor *tensor in results.allKeys) {
        MPSGraphTensorData *destination = results[tensor];
        MPSGraphTensorData *value = computed[tensor];
        if (value == nil) {
            CharonMPSGraphRefuse(@"MPSGraph: the result named %@ was not computed, so the entry the caller gave "
                                 @"it in is left as it was", tensor.operation.name);
            continue;
        }
        CharonMPSGraphWriteInto(tensor, value, destination);
    }
    [descriptor charon_mps_applyEventsAtStage:MPSGraphExecutionStageCompleted named:@"a graph run"];
    // The descriptor's two handlers, which are the header's own notification points: the scheduled one is
    // called when the work is about to run and the completion one when it has finished, each with the results
    // and the error. On this port the walk is over the host's memory on the CPU and both are called around it
    // rather than around a GPU submission, and -waitUntilCompleted needs nothing: the answer is already in
    // the caller's buffer when the call returns, which is what that property asks for.
    if (descriptor.scheduledHandler)
        descriptor.scheduledHandler(computed, nil);
    if (descriptor.completionHandler)
        descriptor.completionHandler(computed, nil);
    return computed;
}

- (MPSGraphTensorDataDictionary *)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                                                  feeds:(MPSGraphTensorDataDictionary *)feeds
                                          targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                       targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
{
    (void)commandQueue;
    return CharonMPSGraphRunForm(self, feeds, targetTensors, targetOperations, nil, nil);
}

- (void)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                        feeds:(MPSGraphTensorDataDictionary *)feeds
               targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
              resultsDictionary:(MPSGraphTensorDataDictionary *)resultsDictionary
{
    (void)commandQueue;
    CharonMPSGraphRunForm(self, feeds, nil, targetOperations, resultsDictionary, nil);
}

- (MPSGraphTensorDataDictionary *)runAsyncWithFeeds:(MPSGraphTensorDataDictionary *)feeds
                                     targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                  targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                                 executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    return CharonMPSGraphRunForm(self, feeds, targetTensors, targetOperations, nil, executionDescriptor);
}

- (MPSGraphTensorDataDictionary *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                                                       feeds:(MPSGraphTensorDataDictionary *)feeds
                                               targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                            targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                                          executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    (void)commandQueue;
    return CharonMPSGraphRunForm(self, feeds, targetTensors, targetOperations, nil, executionDescriptor);
}

- (void)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                              feeds:(MPSGraphTensorDataDictionary *)feeds
                     targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                    resultsDictionary:(MPSGraphTensorDataDictionary *)resultsDictionary
                  executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    (void)commandQueue;
    CharonMPSGraphRunForm(self, feeds, nil, targetOperations, resultsDictionary, executionDescriptor);
}

- (MPSGraphTensorDataDictionary *)encodeToCommandBuffer:(MPSCommandBuffer *)commandBuffer
                                                 feeds:(MPSGraphTensorDataDictionary *)feeds
                                         targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                      targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                                    executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    (void)commandBuffer;
    return CharonMPSGraphRunForm(self, feeds, targetTensors, targetOperations, nil, executionDescriptor);
}

- (void)encodeToCommandBuffer:(MPSCommandBuffer *)commandBuffer
                        feeds:(MPSGraphTensorDataDictionary *)feeds
               targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
              resultsDictionary:(MPSGraphTensorDataDictionary *)resultsDictionary
            executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    (void)commandBuffer;
    CharonMPSGraphRunForm(self, feeds, nil, targetOperations, resultsDictionary, executionDescriptor);
}

#pragma mark - running it

- (NSDictionary *)runWithFeeds:(NSDictionary<MPSGraphTensor *, MPSGraphTensorData *> *)feeds
                  targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
               targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
{
    // The values every tensor written so far, keyed by the tensor itself: a placeholder's comes from
    // the feeds, and each operation's from the operation that produced it. Walking the operations in the
    // order they were added is what lets one read what another wrote.
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (MPSGraphTensor *tensor in feeds)
        values[tensor] = feeds[tensor];
    for (MPSGraphOperation *operation in _operations) {
        [self charon_mps_runOperation:operation values:values];
    }
    (void)targetOperations;
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    for (MPSGraphTensor *tensor in targetTensors) {
        MPSGraphTensorData *data = values[tensor];
        if (data)
            results[tensor] = data;
    }
    return results;
}

- (MPSGraphExecutable *)compileWithDevice:(MPSGraphDevice *)device
                                   feeds:(NSDictionary *)feeds
                           targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                        targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                  compilationDescriptor:(MPSGraphCompilationDescriptor *)compilationDescriptor
{
    // An executable of this port is the graph itself: the work is a walk over the operations, so there is
    // nothing to compile ahead of time and the executable holds the targets the compile named.
    return [[MPSGraphExecutable alloc] initWithGraph:self
                                               device:device
                                               feeds:feeds
                                        targetTensors:targetTensors
                                     targetOperations:targetOperations
                                  executableDescriptor:nil];
}

@end
