#import "CharonMPSGraph.h"

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

- (MPSGraphTensor *)divisionNoNaNWithPrimaryTensor:(MPSGraphTensor *)primary
                                  secondaryTensor:(MPSGraphTensor *)secondary
                                             name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindDivisionNoNaN operands:@[primary, secondary] name:name];
}

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

- (MPSGraphTensor *)sigmoidGradientWithIncomingGradient:(MPSGraphTensor *)gradient
                                            sourceTensor:(MPSGraphTensor *)source
                                                   name:(NSString *)name
{
    return [self charon_mps_arithmetic:CharonMPSGraphOperationKindSigmoidGradient operands:@[gradient, source] name:name];
}

#pragma mark - the reduction family

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
    NSUInteger rank = tensor.shape.count;
    NSInteger first = (NSInteger)(int32_t)(uint32_t)dimension;
    NSInteger second = (NSInteger)(int32_t)(uint32_t)withDimension;
    if (first < 0) first += (NSInteger)rank;
    if (second < 0) second += (NSInteger)rank;
    if ((NSUInteger)first >= rank || (NSUInteger)second >= rank) {
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

- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor
                        withShape:(NSArray<NSNumber *> *)shape
                             name:(NSString *)name
{
    return [self charon_mps_gather:CharonMPSGraphOperationKindReshape
                             tensor:tensor
                        parameters:@{@"gather": @"reshape", @"gatherShape": shape ?: @[]}
                               name:name];
}

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
        [starts addObject:@(axis == dimensionIndex ? start : 0)];
        [strides addObject:@1];
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
    if (shape != nil)
        [result charon_mps_setShape:shape];
    return result;
}

#pragma mark - the split and the coordinate: the two seams of 15.4 whose result is not one operand's walk
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

- (MPSGraphTensor *)charon_mps_blockShuffle:(MPSGraphTensor *)tensor
                                     spatial:(NSArray<NSNumber *> *)spatial
                                       batch:(NSInteger)batch
                                       block:(NSArray<NSNumber *> *)block
                                     toBatch:(BOOL)toBatch
                                     shuffle:(BOOL)shuffle
                                         name:(NSString *)name
{
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
- (MPSGraphTensor *)charon_mps_gather:(CharonMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name
{
    MPSGraphTensor *result = [self charon_mps_operation:kind inputs:@[tensor] parameters:parameters name:name];
    NSArray<NSNumber *> *shape = [self charon_mps_gatherShapeOfTensor:tensor
                                                          parameters:parameters
                                                                 named:name];
    if (shape != nil)
        [result charon_mps_setShape:shape];
    return result;
}

static NSUInteger CharonMPSGraphFedAxisCount(NSArray<NSNumber *> *fedShape)
{
    if (fedShape.count != 1)
        return 0;
    NSInteger named = fedShape.firstObject.integerValue;
    return named > 0 ? (NSUInteger)named : 0;
}

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
    MPSGraphTensor *result = [self charon_mps_operation:kind inputs:@[tensor, fedParameter]
                                             parameters:parameters name:name];
    [result charon_mps_setShape:CharonMPSGraphFedGatherResultShape(parameters[@"gather"], tensor.shape,
                                                                   fedParameter.shape)];
    return result;
}

#pragma mark - pad and tile, which arrived with the framework itself

- (MPSGraphTensor *)tileTensor:(MPSGraphTensor *)tensor
                withMultiplier:(NSArray<NSNumber *> *)multiplier
                          name:(NSString *)name
{
    return [self charon_mps_slice:CharonMPSGraphOperationKindSlice
                          inputs:@[tensor]
                      parameters:@{@"gather": @"tile", @"tileMultiplier": multiplier ?: @[]}
                             name:name];
}

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
    if (incomingGradientTensor.shape != nil && ![incomingGradientTensor.shape isEqualToArray:sourceShape]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for the tile gradient of a tensor of %@ with an incoming "
                           @"gradient of %@, and a gradient is of the tensor it is the gradient of: the "
                           @"release answers 'Incompatible shape for parameter at index 0' where the graph "
                           @"runs", name, [sourceShape componentsJoinedByString:@"x"],
                     [incomingGradientTensor.shape componentsJoinedByString:@"x"]];
    }
    MPSDataType type = incomingGradientTensor.dataType;
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
    NSUInteger leading = sourceShape.firstObject.unsignedIntegerValue;
    if (multiplier.firstObject.integerValue > (NSInteger)leading) {
        [NSException raise:NSInvalidArgumentException
                    format:@"MPSGraph: %@ was asked for %ld copies of the leading axis, which is %lu long, "
                           @"and above its own extent the release's answer is not a gradient of the incoming "
                           @"gradient at all: measured, it reads the SOURCE tensor instead, which is not a rule "
                           @"this port can reproduce",
                         name, (long)multiplier.firstObject.integerValue, (unsigned long)leading];
    }
    NSMutableArray<MPSGraphTensor *> *terms = [NSMutableArray arrayWithObject:incomingGradientTensor];
    for (NSUInteger axis = 0; axis + 1 < rank; axis++) {
        NSInteger window = multiplier[axis + 1].integerValue;
        NSUInteger stride = 1;
        for (NSUInteger after = axis + 1; after < rank; after++)
            stride *= (NSUInteger)sourceShape[after].integerValue;
        NSUInteger extent = (NSUInteger)sourceShape[axis].integerValue;
        for (NSInteger shift = 1; shift < window; shift++) {
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
        [result charon_mps_setShape:nil];
    }
    return result;
}

- (NSArray<NSNumber *> *)charon_mps_constantShapeOfTensor:(MPSGraphTensor *)tensor
{
    MPSGraphOperation *operation = tensor.operation;
    if (operation == nil || [operation charon_mps_kind] != CharonMPSGraphOperationKindConstant)
        return nil;
    NSData *bytes = [operation charon_mps_parameters][@"values"];
    if (bytes == nil)
        return nil;
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

- (MPSGraphTensor *)meanOfTensor:(MPSGraphTensor *)tensor
                            axes:(NSArray<NSNumber *> *)axes
                            name:(NSString *)name
{
    return [self charon_mps_reductionOf:axes tensor:tensor combination:@"mean"
                                    kind:CharonMPSGraphOperationKindReductionMean propagatesNaN:NO name:name];
}

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

static NSDictionary *CharonMPSGraphRunForm(MPSGraph *graph, NSDictionary *feeds,
                                           NSArray<MPSGraphTensor *> *targets,
                                           NSArray<MPSGraphOperation *> *operations, NSDictionary *results,
                                           MPSGraphExecutionDescriptor *descriptor)
{
    [descriptor charon_mps_applyEventsAtStage:MPSGraphExecutionStageCompleted named:@"a graph run"];
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
    return [[MPSGraphExecutable alloc] initWithGraph:self
                                               device:device
                                               feeds:feeds
                                        targetTensors:targetTensors
                                     targetOperations:targetOperations
                                  executableDescriptor:nil];
}

@end
