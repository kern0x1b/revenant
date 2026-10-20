#import "RevenantMPSGraph.h"

typedef enum {
    RevenantMPSGraphArityUnary,
    RevenantMPSGraphArityBinary,
    RevenantMPSGraphArityClamp
} RevenantMPSGraphArity;

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

- (MPSGraphDevice *)revenant_mps_device
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
    MPSGraphOperation *operation = [self revenant_mps_addOperationOfKind:RevenantMPSGraphOperationKindPlaceholder
                                                                 name:name
                                                                inputs:@[]
                                                               outputs:@[]
                                                             parameters:nil];
    MPSGraphTensor *tensor = [[MPSGraphTensor alloc] initWithShape:shape dataType:dataType operation:operation index:0];
    [operation revenant_mps_setOutputTensors:@[tensor]];
    [_placeholders addObject:tensor];
    return tensor;
}

- (MPSGraphTensor *)constantWithShape:(NSArray<NSNumber *> *)shape
                            dataType:(MPSDataType)dataType
                              values:(NSData *)values
                                name:(NSString *)name
{
    MPSGraphOperation *operation = [self revenant_mps_addOperationOfKind:RevenantMPSGraphOperationKindConstant
                                                                 name:name
                                                                inputs:@[]
                                                               outputs:@[]
                                                             parameters:@{@"values": values}];
    MPSGraphTensor *tensor = [[MPSGraphTensor alloc] initWithShape:shape dataType:dataType operation:operation index:0];
    [operation revenant_mps_setOutputTensors:@[tensor]];
    return tensor;
}

- (MPSGraphTensor *)constantWithData:(NSData *)data
                               shape:(NSArray<NSNumber *> *)shape
                            dataType:(MPSDataType)dataType
{
    return [self constantWithShape:shape dataType:dataType values:data name:nil];
}

- (MPSGraphTensor *)revenant_mps_operation:(RevenantMPSGraphOperationKind)kind
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
    MPSGraphOperation *operation = [self revenant_mps_addOperationOfKind:kind name:name inputs:inputs outputs:@[] parameters:parameters];
    MPSGraphTensor *tensor = [[MPSGraphTensor alloc] initWithShape:shape dataType:dataType operation:operation index:0];
    [operation revenant_mps_setOutputTensors:@[tensor]];
    return tensor;
}

- (MPSGraphOperation *)revenant_mps_addOperationOfKind:(RevenantMPSGraphOperationKind)kind
                                                name:(NSString *)name
                                              inputs:(NSArray<MPSGraphTensor *> *)inputs
                                             outputs:(NSArray<MPSGraphTensor *> *)outputs
                                           parameters:(NSDictionary *)parameters
{
    MPSGraphOperation *operation = [[MPSGraphOperation alloc] initWithGraph:self kind:kind name:name inputs:inputs outputs:outputs];
    [operation revenant_mps_setParameters:parameters];
    [_operations addObject:operation];
    return operation;
}

#pragma mark - the arithmetic family

- (MPSGraphTensor *)revenant_mps_arithmetic:(RevenantMPSGraphOperationKind)kind
                                 operands:(NSArray<MPSGraphTensor *> *)operands
                                      name:(NSString *)name
{
    return [self revenant_mps_operation:kind inputs:operands parameters:nil name:name];
}

- (MPSGraphTensor *)revenant_mps_predicate:(RevenantMPSGraphOperationKind)kind
                                operands:(NSArray<MPSGraphTensor *> *)operands
                                     name:(NSString *)name
{
    return [self revenant_mps_operation:kind
                              inputs:operands
                          parameters:@{@"dataType": @(MPSDataTypeBool)}
                                 name:name];
}

- (MPSGraphTensor *)additionWithPrimaryTensor:(MPSGraphTensor *)primary
                             secondaryTensor:(MPSGraphTensor *)secondary
                                        name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAdd operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)subtractionWithPrimaryTensor:(MPSGraphTensor *)primary
                                secondaryTensor:(MPSGraphTensor *)secondary
                                           name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSubtract operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)multiplicationWithPrimaryTensor:(MPSGraphTensor *)primary
                                  secondaryTensor:(MPSGraphTensor *)secondary
                                             name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindMultiply operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)divisionWithPrimaryTensor:(MPSGraphTensor *)primary
                              secondaryTensor:(MPSGraphTensor *)secondary
                                         name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindDivide operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)negationWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindNegate operands:@[tensor] name:name];
}

- (MPSGraphTensor *)squareWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSquare operands:@[tensor] name:name];
}

- (MPSGraphTensor *)reciprocalWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindReciprocal operands:@[tensor] name:name];
}

- (MPSGraphTensor *)squareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSqrt operands:@[tensor] name:name];
}

- (MPSGraphTensor *)reverseSquareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindRsqrt operands:@[tensor] name:name];
}

- (MPSGraphTensor *)exponentialWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindExp operands:@[tensor] name:name];
}

- (MPSGraphTensor *)logarithmWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLog operands:@[tensor] name:name];
}

- (MPSGraphTensor *)absoluteWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAbs operands:@[tensor] name:name];
}

- (MPSGraphTensor *)signWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSign operands:@[tensor] name:name];
}

- (MPSGraphTensor *)identityWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindIdentity operands:@[tensor] name:name];
}

#pragma mark - the transcendentals and the rounding

- (MPSGraphTensor *)exponentBase2WithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindExpBase2 operands:@[tensor] name:name];
}

- (MPSGraphTensor *)exponentBase10WithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindExpBase10 operands:@[tensor] name:name];
}

- (MPSGraphTensor *)logarithmBase2WithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogBase2 operands:@[tensor] name:name];
}

- (MPSGraphTensor *)logarithmBase10WithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogBase10 operands:@[tensor] name:name];
}

- (MPSGraphTensor *)negativeWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindNegate operands:@[tensor] name:name];
}

- (MPSGraphTensor *)signbitWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSignBit operands:@[tensor] name:name];
}

- (MPSGraphTensor *)ceilWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindCeil operands:@[tensor] name:name];
}

- (MPSGraphTensor *)floorWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindFloor operands:@[tensor] name:name];
}

- (MPSGraphTensor *)roundWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindRound operands:@[tensor] name:name];
}

- (MPSGraphTensor *)rintWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindRint operands:@[tensor] name:name];
}

- (MPSGraphTensor *)sinWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSin operands:@[tensor] name:name];
}

- (MPSGraphTensor *)cosWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindCos operands:@[tensor] name:name];
}

- (MPSGraphTensor *)tanWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindTan operands:@[tensor] name:name];
}

- (MPSGraphTensor *)sinhWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSinh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)coshWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindCosh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)tanhWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindTanh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)asinWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAsin operands:@[tensor] name:name];
}

- (MPSGraphTensor *)acosWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAcos operands:@[tensor] name:name];
}

- (MPSGraphTensor *)atanWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAtan operands:@[tensor] name:name];
}

- (MPSGraphTensor *)asinhWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAsinh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)acoshWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAcosh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)atanhWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAtanh operands:@[tensor] name:name];
}

- (MPSGraphTensor *)erfWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindErf operands:@[tensor] name:name];
}

- (MPSGraphTensor *)notWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogicalNot operands:@[tensor] name:name];
}

- (MPSGraphTensor *)isInfiniteWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindIsInfinite operands:@[tensor] name:name];
}

- (MPSGraphTensor *)isFiniteWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindIsFinite operands:@[tensor] name:name];
}

- (MPSGraphTensor *)isNaNWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindIsNaN operands:@[tensor] name:name];
}

#pragma mark - the arithmetic that is not IEEE

- (MPSGraphTensor *)moduloWithPrimaryTensor:(MPSGraphTensor *)primary
                          secondaryTensor:(MPSGraphTensor *)secondary
                                     name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindModulo operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)floorModuloWithPrimaryTensor:(MPSGraphTensor *)primary
                                 secondaryTensor:(MPSGraphTensor *)secondary
                                            name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindFloorModulo operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)powerWithPrimaryTensor:(MPSGraphTensor *)primary
                          secondaryTensor:(MPSGraphTensor *)secondary
                                     name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindPower operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)minimumWithPrimaryTensor:(MPSGraphTensor *)primary
                            secondaryTensor:(MPSGraphTensor *)secondary
                                       name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindMinimum operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)maximumWithPrimaryTensor:(MPSGraphTensor *)primary
                            secondaryTensor:(MPSGraphTensor *)secondary
                                       name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindMaximum operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)divisionNoNaNWithPrimaryTensor:(MPSGraphTensor *)primary
                                  secondaryTensor:(MPSGraphTensor *)secondary
                                             name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindDivisionNoNaN operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)atan2WithPrimaryTensor:(MPSGraphTensor *)primary
                          secondaryTensor:(MPSGraphTensor *)secondary
                                     name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindAtan2 operands:@[primary, secondary] name:name];
}

#pragma mark - the predicates over two operands

- (MPSGraphTensor *)equalWithPrimaryTensor:(MPSGraphTensor *)primary
                          secondaryTensor:(MPSGraphTensor *)secondary
                                     name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindEqual operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)notEqualWithPrimaryTensor:(MPSGraphTensor *)primary
                             secondaryTensor:(MPSGraphTensor *)secondary
                                        name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindNotEqual operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)lessThanWithPrimaryTensor:(MPSGraphTensor *)primary
                            secondaryTensor:(MPSGraphTensor *)secondary
                                       name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindLessThan operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)lessThanOrEqualToWithPrimaryTensor:(MPSGraphTensor *)primary
                                     secondaryTensor:(MPSGraphTensor *)secondary
                                                name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindLessThanOrEqualTo operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)greaterThanWithPrimaryTensor:(MPSGraphTensor *)primary
                               secondaryTensor:(MPSGraphTensor *)secondary
                                          name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindGreaterThan operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)greaterThanOrEqualToWithPrimaryTensor:(MPSGraphTensor *)primary
                                        secondaryTensor:(MPSGraphTensor *)secondary
                                                   name:(NSString *)name
{
    return [self revenant_mps_predicate:RevenantMPSGraphOperationKindGreaterThanOrEqualTo operands:@[primary, secondary] name:name];
}

#pragma mark - the logical family, which answers the operand's own type

- (MPSGraphTensor *)logicalANDWithPrimaryTensor:(MPSGraphTensor *)primary
                               secondaryTensor:(MPSGraphTensor *)secondary
                                          name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogicalAnd operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalORWithPrimaryTensor:(MPSGraphTensor *)primary
                              secondaryTensor:(MPSGraphTensor *)secondary
                                         name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogicalOr operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalNANDWithPrimaryTensor:(MPSGraphTensor *)primary
                                secondaryTensor:(MPSGraphTensor *)secondary
                                           name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogicalNand operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalNORWithPrimaryTensor:(MPSGraphTensor *)primary
                               secondaryTensor:(MPSGraphTensor *)secondary
                                          name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogicalNor operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalXORWithPrimaryTensor:(MPSGraphTensor *)primary
                               secondaryTensor:(MPSGraphTensor *)secondary
                                          name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogicalXor operands:@[primary, secondary] name:name];
}

- (MPSGraphTensor *)logicalXNORWithPrimaryTensor:(MPSGraphTensor *)primary
                                secondaryTensor:(MPSGraphTensor *)secondary
                                           name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindLogicalXnor operands:@[primary, secondary] name:name];
}

#pragma mark - the operations with a third operand

- (MPSGraphTensor *)selectWithPredicateTensor:(MPSGraphTensor *)predicate
                         truePredicateTensor:(MPSGraphTensor *)whenTrue
                          falsePredicateTensor:(MPSGraphTensor *)whenFalse
                                         name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSelect operands:@[predicate, whenTrue, whenFalse] name:name];
}

- (MPSGraphTensor *)clampWithTensor:(MPSGraphTensor *)tensor
                     minValueTensor:(MPSGraphTensor *)minimum
                     maxValueTensor:(MPSGraphTensor *)maximum
                               name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindClamp3 operands:@[tensor, minimum, maximum] name:name];
}

#pragma mark - the activations and their gradients

- (MPSGraphTensor *)reLUWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindReLU operands:@[tensor] name:name];
}

- (MPSGraphTensor *)reLUGradientWithIncomingGradient:(MPSGraphTensor *)gradient
                                         sourceTensor:(MPSGraphTensor *)source
                                                name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindReLUGradient operands:@[gradient, source] name:name];
}

- (MPSGraphTensor *)sigmoidWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSigmoid operands:@[tensor] name:name];
}

- (MPSGraphTensor *)sigmoidGradientWithIncomingGradient:(MPSGraphTensor *)gradient
                                            sourceTensor:(MPSGraphTensor *)source
                                                   name:(NSString *)name
{
    return [self revenant_mps_arithmetic:RevenantMPSGraphOperationKindSigmoidGradient operands:@[gradient, source] name:name];
}

#pragma mark - the reduction family

- (MPSGraphTensor *)revenant_mps_reduction:(RevenantMPSGraphOperationKind)kind
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
    return [self revenant_mps_operation:kind inputs:@[tensor] parameters:all name:name];
}

- (MPSGraphTensor *)revenant_mps_reductionOf:(NSArray<NSNumber *> *)axes
                                    tensor:(MPSGraphTensor *)tensor
                             combination:(NSString *)combination
                                     kind:(RevenantMPSGraphOperationKind)kind
                          propagatesNaN:(BOOL)propagatesNaN
                                     name:(NSString *)name
{
    return [self revenant_mps_reduction:kind
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
        return [self revenant_mps_gather:RevenantMPSGraphOperationKindTranspose
                                 tensor:tensor
                            parameters:@{@"gather": @"transpose",
                                         @"gatherPermutation": @[@(first), @(second)]}
                                   name:name];
    }
    NSMutableArray<NSNumber *> *permutation = [NSMutableArray arrayWithCapacity:rank];
    for (NSUInteger axis = 0; axis < rank; axis++)
        [permutation addObject:@((NSInteger)axis)];
    [permutation exchangeObjectAtIndex:(NSUInteger)first withObjectAtIndex:(NSUInteger)second];
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindTranspose
                             tensor:tensor
                        parameters:@{@"gather": @"transpose", @"gatherPermutation": permutation}
                               name:name];
}

- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor
                        withShape:(NSArray<NSNumber *> *)shape
                             name:(NSString *)name
{
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindReshape
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
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindSlice
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
    return [self revenant_mps_gather:RevenantMPSGraphOperationKindSlice
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
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[tensor]
                      parameters:@{@"gather": @"slice",
                                   @"sliceStarts": starts ?: @[], @"sliceEnds": ends ?: @[],
                                   @"sliceStrides": strides ?: @[],
                                   @"sliceStartMask": @(startMask), @"sliceEndMask": @(endMask),
                                   @"sliceSqueezeMask": @(squeezeMask)}
                             name:name];
}

- (NSDictionary *)revenant_mps_sliceGradientParameters:(MPSGraphTensor *)fwdInShapeTensor
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
    NSArray<NSNumber *> *forward = [self revenant_mps_constantShapeOfTensor:fwdInShapeTensor];
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
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[inputGradientTensor, fwdInShapeTensor]
                      parameters:[self revenant_mps_sliceGradientParameters:fwdInShapeTensor
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
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[inputGradientTensor, fwdInShapeTensor]
                      parameters:[self revenant_mps_sliceGradientParameters:fwdInShapeTensor
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
    return [self revenant_mps_concat:RevenantMPSGraphOperationKindConcat
                            tensors:@[tensor, tensor2]
                               axis:dimensionIndex
                         interleave:NO
                              name:name];
}

- (MPSGraphTensor *)concatTensors:(NSArray<MPSGraphTensor *> *)tensors
                        dimension:(NSInteger)dimensionIndex
                             name:(NSString *)name
{
    return [self revenant_mps_concat:RevenantMPSGraphOperationKindConcat
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
    return [self revenant_mps_concat:RevenantMPSGraphOperationKindConcat
                            tensors:tensors ?: @[]
                               axis:dimensionIndex
                         interleave:interleave
                              name:name];
}

- (MPSGraphTensor *)revenant_mps_concat:(RevenantMPSGraphOperationKind)kind
                               tensors:(NSArray<MPSGraphTensor *> *)tensors
                                  axis:(NSInteger)axis
                            interleave:(BOOL)interleave
                                 name:(NSString *)name
{
    BOOL stacked = kind == RevenantMPSGraphOperationKindStack;
    NSArray<NSNumber *> *shape = [self revenant_mps_concatShapeOfTensors:tensors axis:axis interleave:interleave
                                                                stacked:stacked named:name];
    MPSGraphTensor *result = [self revenant_mps_operation:kind inputs:tensors ?: @[]
                                            parameters:@{@"concatAxis": @(axis), @"concatInterleave": @(interleave),
                                                         @"concatStacked": @(stacked),
                                                         @"dataType": @(tensors.firstObject.dataType
                                                                        ?: MPSDataTypeFloat32)}
                                                   name:name];
    if (shape != nil)
        [result revenant_mps_setShape:shape];
    return result;
}

#pragma mark - the split and the coordinate: the two seams of 15.4 whose result is not one operand's walk
- (NSArray<MPSGraphTensor *> *)revenant_mps_split:(MPSGraphTensor *)tensor
                                            axis:(NSInteger)axis
                                           sizes:(NSArray<NSNumber *> *)sizes
                                      numSplits:(NSUInteger)numSplits
                                            name:(NSString *)name
{
    NSArray<NSNumber *> *operandShape = tensor.shape;
    NSInteger where = axis;
    if (where < 0)
        where += (NSInteger)operandShape.count;
    NSArray<NSNumber *> *own = [self revenant_mps_splitSizes:sizes numSplits:numSplits axis:where
                                            ofShape:operandShape named:name];
    MPSGraphOperation *operation = [self revenant_mps_addOperationOfKind:RevenantMPSGraphOperationKindSplit
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
    [operation revenant_mps_setOutputTensors:results];
    return results;
}

- (MPSGraphTensor *)revenant_mps_coordinates:(NSInteger)axis
                                    fedAxis:(MPSGraphTensor *)fedAxis
                                      shape:(NSArray<NSNumber *> *)shape
                                   fedShape:(MPSGraphTensor *)fedShape
                                       name:(NSString *)name
{
    NSArray<NSNumber *> *own = shape;
    if (fedShape != nil) {
        own = [self revenant_mps_constantShapeOfTensor:fedShape];
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
        NSArray<NSNumber *> *one = [self revenant_mps_constantShapeOfTensor:fedAxis];
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
    MPSGraphOperation *operation = [self revenant_mps_addOperationOfKind:RevenantMPSGraphOperationKindCoordinates
                                                                 name:name
                                                                inputs:@[]
                                                               outputs:@[]
                                                             parameters:@{@"coordinateAxis": @(where),
                                                                          @"coordinateShape": own,
                                                                          @"dataType": @(MPSDataTypeInt32)}];
    MPSGraphTensor *result = [[MPSGraphTensor alloc] initWithShape:own dataType:MPSDataTypeInt32
                                                          operation:operation index:0];
    [operation revenant_mps_setOutputTensors:@[result]];
    return result;
}

#pragma mark - the space-to-depth family: four operations of 15.0 and 16.1 that are ONE chain of walks

- (MPSGraphTensor *)revenant_mps_blockShuffle:(MPSGraphTensor *)tensor
                                     spatial:(NSArray<NSNumber *> *)spatial
                                       batch:(NSInteger)batch
                                       block:(NSArray<NSNumber *> *)block
                                     toBatch:(BOOL)toBatch
                                     shuffle:(BOOL)shuffle
                                         name:(NSString *)name
{
    NSDictionary *plan = [self revenant_mps_blockShufflePlan:name
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

- (MPSGraphTensor *)revenant_mps_fedBlockShuffle:(MPSGraphTensor *)tensor
                                       spatial:(MPSGraphTensor *)spatial
                                         batch:(MPSGraphTensor *)batch
                                         block:(MPSGraphTensor *)block
                                       toBatch:(BOOL)toBatch
                                       shuffle:(BOOL)shuffle
                                           name:(NSString *)name
{
    NSArray<NSNumber *> *axes = [self revenant_mps_constantShapeOfTensor:spatial];
    NSArray<NSNumber *> *where = [self revenant_mps_constantShapeOfTensor:batch];
    NSArray<NSNumber *> *sizes = [self revenant_mps_constantShapeOfTensor:block];
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
        return [self revenant_mps_operation:RevenantMPSGraphOperationKindBlockShuffle
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
    return [self revenant_mps_blockShuffle:tensor
                                  spatial:axes
                                    batch:where.firstObject.integerValue
                                    block:sizes
                                  toBatch:toBatch
                                  shuffle:shuffle
                                      name:name];
}

#pragma mark - the gather family: the one seam every release's shape factory goes through
- (MPSGraphTensor *)revenant_mps_gather:(RevenantMPSGraphOperationKind)kind
                                tensor:(MPSGraphTensor *)tensor
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name
{
    MPSGraphTensor *result = [self revenant_mps_operation:kind inputs:@[tensor] parameters:parameters name:name];
    NSArray<NSNumber *> *shape = [self revenant_mps_gatherShapeOfTensor:tensor
                                                          parameters:parameters
                                                                 named:name];
    if (shape != nil)
        [result revenant_mps_setShape:shape];
    return result;
}

static NSUInteger RevenantMPSGraphFedAxisCount(NSArray<NSNumber *> *fedShape)
{
    if (fedShape.count != 1)
        return 0;
    NSInteger named = fedShape.firstObject.integerValue;
    return named > 0 ? (NSUInteger)named : 0;
}

static NSArray<NSNumber *> *RevenantMPSGraphFedGatherResultShape(NSString *gather, NSArray<NSNumber *> *operandShape,
                                                               NSArray<NSNumber *> *fedShape)
{
    if ([gather isEqualToString:@"flatten"])
        return @[@(-1), @(-1)];
    NSUInteger named = RevenantMPSGraphFedAxisCount(fedShape);
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

- (MPSGraphTensor *)revenant_mps_gather:(RevenantMPSGraphOperationKind)kind
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
    MPSGraphTensor *result = [self revenant_mps_operation:kind inputs:@[tensor, fedParameter]
                                             parameters:parameters name:name];
    [result revenant_mps_setShape:RevenantMPSGraphFedGatherResultShape(parameters[@"gather"], tensor.shape,
                                                                   fedParameter.shape)];
    return result;
}

#pragma mark - pad and tile, which arrived with the framework itself

- (MPSGraphTensor *)tileTensor:(MPSGraphTensor *)tensor
                withMultiplier:(NSArray<NSNumber *> *)multiplier
                          name:(NSString *)name
{
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
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
            MPSGraphTensor *term = [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                                                   inputs:@[incomingGradientTensor]
                                               parameters:@{@"gather": @"slice", @"sliceStarts": starts,
                                                            @"sliceEnds": ends, @"sliceStrides": strides}
                                                      name:name];
            term = [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
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
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
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
    return [self revenant_mps_slice:RevenantMPSGraphOperationKindSlice
                          inputs:@[incomingGradientTensor, sourceTensor]
                      parameters:@{@"gather": @"scatter", @"shape": sourceTensor.shape,
                                   @"offsets": behind, @"strides": oneEach}
                             name:name];
}

#pragma mark - the slice family: the one seam its three directions go through

- (MPSGraphTensor *)revenant_mps_slice:(RevenantMPSGraphOperationKind)kind
                               inputs:(NSArray<MPSGraphTensor *> *)inputs
                           parameters:(NSDictionary *)parameters
                                  name:(NSString *)name
{
    MPSGraphTensor *result = [self revenant_mps_operation:kind inputs:inputs parameters:parameters name:name];
    NSArray<NSNumber *> *shape = [self revenant_mps_gatherShapeOfTensor:inputs.firstObject
                                                          parameters:parameters
                                                                 named:name];
    if (shape != nil) {
        [result revenant_mps_setShape:shape];
    } else if ([parameters[@"gather"] isEqualToString:@"sliceGradient"] && parameters[@"sliceForwardShape"] == nil) {
        [result revenant_mps_setShape:nil];
    }
    return result;
}

- (NSArray<NSNumber *> *)revenant_mps_constantShapeOfTensor:(MPSGraphTensor *)tensor
{
    MPSGraphOperation *operation = tensor.operation;
    if (operation == nil || [operation revenant_mps_kind] != RevenantMPSGraphOperationKindConstant)
        return nil;
    NSData *bytes = [operation revenant_mps_parameters][@"values"];
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

- (NSInteger)revenant_mps_scanAxis:(NSInteger)axis ofRank:(NSUInteger)rank named:(NSString *)name
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

- (MPSGraphTensor *)revenant_mps_scan:(RevenantMPSGraphOperationKind)kind
                               axis:(NSInteger)axis
                             tensor:(MPSGraphTensor *)tensor
                        combination:(NSString *)combination
                           exclusive:(BOOL)exclusive
                             reverse:(BOOL)reverse
                                name:(NSString *)name
{
    NSUInteger rank = tensor.shape.count;
    NSInteger normalised = [self revenant_mps_scanAxis:axis ofRank:rank named:name];
    return [self revenant_mps_operation:kind
                               inputs:@[tensor]
                           parameters:@{@"scanCombination": combination, @"scanAxis": @(normalised),
                                        @"scanExclusive": @(exclusive), @"scanReverse": @(reverse)}
                                  name:name];
}

- (MPSGraphTensor *)revenant_mps_scan:(RevenantMPSGraphOperationKind)kind
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
    return [self revenant_mps_operation:kind
                               inputs:@[tensor, axisTensor]
                           parameters:@{@"scanCombination": combination, @"scanAxisTensor": @YES,
                                        @"scanExclusive": @(exclusive), @"scanReverse": @(reverse)}
                                  name:name];
}

- (MPSGraphTensor *)reductionSumWithTensor:(MPSGraphTensor *)tensor
                                       axis:(NSInteger)axis
                                       name:(NSString *)name
{
    return [self revenant_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"sum"
                                    kind:RevenantMPSGraphOperationKindReductionSum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionSumWithTensor:(MPSGraphTensor *)tensor
                                       axes:(NSArray<NSNumber *> *)axes
                                       name:(NSString *)name
{
    return [self revenant_mps_reductionOf:axes tensor:tensor combination:@"sum"
                                    kind:RevenantMPSGraphOperationKindReductionSum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionProductWithTensor:(MPSGraphTensor *)tensor
                                          axis:(NSInteger)axis
                                          name:(NSString *)name
{
    return [self revenant_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"product"
                                    kind:RevenantMPSGraphOperationKindReductionProduct propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionProductWithTensor:(MPSGraphTensor *)tensor
                                          axes:(NSArray<NSNumber *> *)axes
                                          name:(NSString *)name
{
    return [self revenant_mps_reductionOf:axes tensor:tensor combination:@"product"
                                    kind:RevenantMPSGraphOperationKindReductionProduct propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMaximumWithTensor:(MPSGraphTensor *)tensor
                                          axis:(NSInteger)axis
                                          name:(NSString *)name
{
    return [self revenant_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"maximum"
                                    kind:RevenantMPSGraphOperationKindReductionMaximum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMaximumWithTensor:(MPSGraphTensor *)tensor
                                          axes:(NSArray<NSNumber *> *)axes
                                          name:(NSString *)name
{
    return [self revenant_mps_reductionOf:axes tensor:tensor combination:@"maximum"
                                    kind:RevenantMPSGraphOperationKindReductionMaximum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMinimumWithTensor:(MPSGraphTensor *)tensor
                                          axis:(NSInteger)axis
                                          name:(NSString *)name
{
    return [self revenant_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"minimum"
                                    kind:RevenantMPSGraphOperationKindReductionMinimum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMinimumWithTensor:(MPSGraphTensor *)tensor
                                          axes:(NSArray<NSNumber *> *)axes
                                          name:(NSString *)name
{
    return [self revenant_mps_reductionOf:axes tensor:tensor combination:@"minimum"
                                    kind:RevenantMPSGraphOperationKindReductionMinimum propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)reductionMaximumPropagateNaNWithTensor:(MPSGraphTensor *)tensor
                                                     axis:(NSInteger)axis
                                                     name:(NSString *)name
{
    return [self revenant_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"maximum"
                                    kind:RevenantMPSGraphOperationKindReductionMaximumPropagateNaN propagatesNaN:YES name:name];
}

- (MPSGraphTensor *)reductionMaximumPropagateNaNWithTensor:(MPSGraphTensor *)tensor
                                                     axes:(NSArray<NSNumber *> *)axes
                                                     name:(NSString *)name
{
    return [self revenant_mps_reductionOf:axes tensor:tensor combination:@"maximum"
                                    kind:RevenantMPSGraphOperationKindReductionMaximumPropagateNaN propagatesNaN:YES name:name];
}

- (MPSGraphTensor *)reductionMinimumPropagateNaNWithTensor:(MPSGraphTensor *)tensor
                                                     axis:(NSInteger)axis
                                                     name:(NSString *)name
{
    return [self revenant_mps_reductionOf:@[@(axis)] tensor:tensor combination:@"minimum"
                                    kind:RevenantMPSGraphOperationKindReductionMinimumPropagateNaN propagatesNaN:YES name:name];
}

- (MPSGraphTensor *)reductionMinimumPropagateNaNWithTensor:(MPSGraphTensor *)tensor
                                                     axes:(NSArray<NSNumber *> *)axes
                                                     name:(NSString *)name
{
    return [self revenant_mps_reductionOf:axes tensor:tensor combination:@"minimum"
                                    kind:RevenantMPSGraphOperationKindReductionMinimumPropagateNaN propagatesNaN:YES name:name];
}

- (MPSGraphTensor *)meanOfTensor:(MPSGraphTensor *)tensor
                            axes:(NSArray<NSNumber *> *)axes
                            name:(NSString *)name
{
    return [self revenant_mps_reductionOf:axes tensor:tensor combination:@"mean"
                                    kind:RevenantMPSGraphOperationKindReductionMean propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)varianceOfTensor:(MPSGraphTensor *)tensor
                                axes:(NSArray<NSNumber *> *)axes
                                name:(NSString *)name
{
    return [self revenant_mps_reductionOf:axes tensor:tensor combination:@"variance"
                                    kind:RevenantMPSGraphOperationKindReductionVariance propagatesNaN:NO name:name];
}

- (MPSGraphTensor *)varianceOfTensor:(MPSGraphTensor *)tensor
                          meanTensor:(MPSGraphTensor *)meanTensor
                                axes:(NSArray<NSNumber *> *)axes
                                name:(NSString *)name
{
    return [self revenant_mps_reduction:RevenantMPSGraphOperationKindReductionVariance
                                 axes:axes
                               tensor:tensor
                          parameters:@{@"combination": @"variance", @"propagateNaN": @NO,
                                       @"mean": meanTensor}
                                 name:name];
}

#pragma mark - the run, async and encode forms, which are all one walk

static NSDictionary *RevenantMPSGraphRunForm(MPSGraph *graph, NSDictionary *feeds,
                                           NSArray<MPSGraphTensor *> *targets,
                                           NSArray<MPSGraphOperation *> *operations, NSDictionary *results,
                                           MPSGraphExecutionDescriptor *descriptor)
{
    [descriptor revenant_mps_applyEventsAtStage:MPSGraphExecutionStageCompleted named:@"a graph run"];
    NSArray<MPSGraphTensor *> *wanted = targets.count ? targets : (results != nil ? results.allKeys : nil);
    NSDictionary *computed = [graph runWithFeeds:feeds targetTensors:wanted targetOperations:operations];
    for (MPSGraphTensor *tensor in results.allKeys) {
        MPSGraphTensorData *destination = results[tensor];
        MPSGraphTensorData *value = computed[tensor];
        if (value == nil) {
            RevenantMPSGraphRefuse(@"MPSGraph: the result named %@ was not computed, so the entry the caller gave "
                                 @"it in is left as it was", tensor.operation.name);
            continue;
        }
        RevenantMPSGraphWriteInto(tensor, value, destination);
    }
    [descriptor revenant_mps_applyEventsAtStage:MPSGraphExecutionStageCompleted named:@"a graph run"];
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
    return RevenantMPSGraphRunForm(self, feeds, targetTensors, targetOperations, nil, nil);
}

- (void)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                        feeds:(MPSGraphTensorDataDictionary *)feeds
               targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
              resultsDictionary:(MPSGraphTensorDataDictionary *)resultsDictionary
{
    (void)commandQueue;
    RevenantMPSGraphRunForm(self, feeds, nil, targetOperations, resultsDictionary, nil);
}

- (MPSGraphTensorDataDictionary *)runAsyncWithFeeds:(MPSGraphTensorDataDictionary *)feeds
                                     targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                  targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                                 executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    return RevenantMPSGraphRunForm(self, feeds, targetTensors, targetOperations, nil, executionDescriptor);
}

- (MPSGraphTensorDataDictionary *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                                                       feeds:(MPSGraphTensorDataDictionary *)feeds
                                               targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                            targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                                          executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    (void)commandQueue;
    return RevenantMPSGraphRunForm(self, feeds, targetTensors, targetOperations, nil, executionDescriptor);
}

- (void)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
                              feeds:(MPSGraphTensorDataDictionary *)feeds
                     targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                    resultsDictionary:(MPSGraphTensorDataDictionary *)resultsDictionary
                  executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    (void)commandQueue;
    RevenantMPSGraphRunForm(self, feeds, nil, targetOperations, resultsDictionary, executionDescriptor);
}

- (MPSGraphTensorDataDictionary *)encodeToCommandBuffer:(MPSCommandBuffer *)commandBuffer
                                                 feeds:(MPSGraphTensorDataDictionary *)feeds
                                         targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                      targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
                                    executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    (void)commandBuffer;
    return RevenantMPSGraphRunForm(self, feeds, targetTensors, targetOperations, nil, executionDescriptor);
}

- (void)encodeToCommandBuffer:(MPSCommandBuffer *)commandBuffer
                        feeds:(MPSGraphTensorDataDictionary *)feeds
               targetOperations:(NSArray<MPSGraphOperation *> *)targetOperations
              resultsDictionary:(MPSGraphTensorDataDictionary *)resultsDictionary
            executionDescriptor:(MPSGraphExecutionDescriptor *)executionDescriptor
{
    (void)commandBuffer;
    RevenantMPSGraphRunForm(self, feeds, nil, targetOperations, resultsDictionary, executionDescriptor);
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
        [self revenant_mps_runOperation:operation values:values];
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
