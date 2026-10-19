// The thirteen functions of MLCTypes.h that name an enumeration's cases in words, and the seed every
// MLCompute program reads out of MLCPlatform.
//
// The strings are Apple's own, read by asking the host for each case in turn (facts/MLCompute/Values.md
// holds the whole table, and tests/backports/host/mlcompute holds this file to it case by case). Nothing
// here is spelled from the header's comments: "ElementwiseMin" for MLCArithmeticOperationMin and "Use
// Padding Size" for MLCPaddingPolicyUsePaddingSize are what the framework answers, and they are not what
// the case is called.

#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

NSString *MLCActivationTypeDebugDescription(MLCActivationType activationType)
{
    switch (activationType) {
        case MLCActivationTypeNone:
            return @"None";
        case MLCActivationTypeReLU:
            return @"ReLU";
        case MLCActivationTypeLinear:
            return @"Linear";
        case MLCActivationTypeSigmoid:
            return @"Sigmoid";
        case MLCActivationTypeHardSigmoid:
            return @"Hard Sigmoid";
        case MLCActivationTypeTanh:
            return @"Tanh";
        case MLCActivationTypeAbsolute:
            return @"Absolute";
        case MLCActivationTypeSoftPlus:
            return @"Soft Plus";
        case MLCActivationTypeSoftSign:
            return @"Soft Sign";
        case MLCActivationTypeELU:
            return @"ELU";
        case MLCActivationTypeReLUN:
            return @"ReLUN";
        case MLCActivationTypeLogSigmoid:
            return @"Log Sigmoid";
        case MLCActivationTypeSELU:
            return @"SELU";
        case MLCActivationTypeCELU:
            return @"CELU";
        case MLCActivationTypeHardShrink:
            return @"Hard Shrink";
        case MLCActivationTypeSoftShrink:
            return @"Soft Shrink";
        case MLCActivationTypeTanhShrink:
            return @"Tanh Shrink";
        case MLCActivationTypeThreshold:
            return @"Threshold";
        case MLCActivationTypeGELU:
            return @"GELU";
        case MLCActivationTypeHardSwish:
            return @"HardSwish";
        case MLCActivationTypeClamp:
            return @"Clamp";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"None";
    }
}

NSString *MLCArithmeticOperationDebugDescription(MLCArithmeticOperation operation)
{
    switch (operation) {
        case MLCArithmeticOperationAdd:
            return @"Add";
        case MLCArithmeticOperationSubtract:
            return @"Subtract";
        case MLCArithmeticOperationMultiply:
            return @"Multiply";
        case MLCArithmeticOperationDivide:
            return @"Divide";
        case MLCArithmeticOperationFloor:
            return @"Floor";
        case MLCArithmeticOperationRound:
            return @"Round";
        case MLCArithmeticOperationCeil:
            return @"Ceil";
        case MLCArithmeticOperationSqrt:
            return @"Sqrt";
        case MLCArithmeticOperationRsqrt:
            return @"Rsqrt";
        case MLCArithmeticOperationSin:
            return @"Sin";
        case MLCArithmeticOperationCos:
            return @"Cos";
        case MLCArithmeticOperationTan:
            return @"Tan";
        case MLCArithmeticOperationAsin:
            return @"Asin";
        case MLCArithmeticOperationAcos:
            return @"Acos";
        case MLCArithmeticOperationAtan:
            return @"Atan";
        case MLCArithmeticOperationSinh:
            return @"Sinh";
        case MLCArithmeticOperationCosh:
            return @"Cosh";
        case MLCArithmeticOperationTanh:
            return @"Tanh";
        case MLCArithmeticOperationAsinh:
            return @"Asinh";
        case MLCArithmeticOperationAcosh:
            return @"Acosh";
        case MLCArithmeticOperationAtanh:
            return @"Atanh";
        case MLCArithmeticOperationPow:
            return @"Pow";
        case MLCArithmeticOperationExp:
            return @"Exp";
        case MLCArithmeticOperationExp2:
            return @"Exp2";
        case MLCArithmeticOperationLog:
            return @"Log";
        case MLCArithmeticOperationLog2:
            return @"Log2";
        case MLCArithmeticOperationMultiplyNoNaN:
            return @"MultiplyNoNaN";
        case MLCArithmeticOperationDivideNoNaN:
            return @"DivideNoNaN";
        case MLCArithmeticOperationMin:
            return @"ElementwiseMin";
        case MLCArithmeticOperationMax:
            return @"ElementwiseMax";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Add";
    }
}

NSString *MLCReductionTypeDebugDescription(MLCReductionType reductionType)
{
    switch (reductionType) {
        case MLCReductionTypeNone:
            return @"None";
        case MLCReductionTypeSum:
            return @"Sum";
        case MLCReductionTypeMean:
            return @"Mean";
        case MLCReductionTypeMax:
            return @"Max";
        case MLCReductionTypeMin:
            return @"Min";
        case MLCReductionTypeArgMax:
            return @"Arg Max";
        case MLCReductionTypeArgMin:
            return @"Arg Min";
        case MLCReductionTypeL1Norm:
            return @"L1Norm";
        case MLCReductionTypeAny:
            return @"Any";
        case MLCReductionTypeAll:
            return @"All";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"None";
    }
}

NSString *MLCLossTypeDebugDescription(MLCLossType lossType)
{
    switch (lossType) {
        case MLCLossTypeMeanAbsoluteError:
            return @"Absolute Error";
        case MLCLossTypeMeanSquaredError:
            return @"Mean Squared Error";
        case MLCLossTypeSoftmaxCrossEntropy:
            return @"Softmax Cross Entropy";
        case MLCLossTypeSigmoidCrossEntropy:
            return @"Sigmoid Cross Entropy";
        case MLCLossTypeCategoricalCrossEntropy:
            return @"Categorical Cross Entropy";
        case MLCLossTypeHinge:
            return @"Hinge";
        case MLCLossTypeHuber:
            return @"Huber";
        case MLCLossTypeCosineDistance:
            return @"Cosine Distance";
        case MLCLossTypeLog:
            return @"Log";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Absolute Error";
    }
}

NSString *MLCPaddingTypeDebugDescription(MLCPaddingType paddingType)
{
    switch (paddingType) {
        case MLCPaddingTypeZero:
            return @"Zero";
        case MLCPaddingTypeReflect:
            return @"Reflect";
        case MLCPaddingTypeSymmetric:
            return @"Symmetric";
        case MLCPaddingTypeConstant:
            return @"Constant";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Zero";
    }
}

NSString *MLCConvolutionTypeDebugDescription(MLCConvolutionType convolutionType)
{
    switch (convolutionType) {
        case MLCConvolutionTypeStandard:
            return @"Standard";
        case MLCConvolutionTypeTransposed:
            return @"Transposed";
        case MLCConvolutionTypeDepthwise:
            return @"Depthwise";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Standard";
    }
}

NSString *MLCPoolingTypeDebugDescription(MLCPoolingType poolingType)
{
    switch (poolingType) {
        case MLCPoolingTypeMax:
            return @"Max";
        case MLCPoolingTypeAverage:
            return @"Average";
        case MLCPoolingTypeL2Norm:
            return @"L2 Norm";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Max";
    }
}

NSString *MLCSoftmaxOperationDebugDescription(MLCSoftmaxOperation operation)
{
    switch (operation) {
        case MLCSoftmaxOperationSoftmax:
            return @"Softmax";
        case MLCSoftmaxOperationLogSoftmax:
            return @"Log Softmax";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Log Softmax";
    }
}

NSString *MLCSampleModeDebugDescription(MLCSampleMode mode)
{
    switch (mode) {
        case MLCSampleModeNearest:
            return @"Nearest";
        case MLCSampleModeLinear:
            return @"Linear";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Linear";
    }
}

NSString *MLCLSTMResultModeDebugDescription(MLCLSTMResultMode mode)
{
    switch (mode) {
        case MLCLSTMResultModeOutput:
            return @"Output";
        case MLCLSTMResultModeOutputAndStates:
            return @"Output and States";
        // A value that is not one of the cases is answered with a name, which is what the framework
        // does for all thirteen of these (measured for -1 and 999 on every one). It is not nil: an
        // earlier version of this file answered nil there, and no case asked, so the default arms were
        // unreachable and the divergence was invisible. This one answers "Output and States", which is
        // the last case rather than the first - measured, not guessed.
        default:
            return @"Output and States";
    }
}

NSString *MLCPaddingPolicyDebugDescription(MLCPaddingPolicy paddingPolicy)
{
    switch (paddingPolicy) {
        case MLCPaddingPolicySame:
            return @"Same";
        case MLCPaddingPolicyValid:
            return @"Valid";
        case MLCPaddingPolicyUsePaddingSize:
            return @"Use Padding Size";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Same";
    }
}

NSString *MLCComparisonOperationDebugDescription(MLCComparisonOperation operation)
{
    switch (operation) {
        case MLCComparisonOperationEqual:
            return @"Equal";
        case MLCComparisonOperationNotEqual:
            return @"Not Equal";
        case MLCComparisonOperationLess:
            return @"Less";
        case MLCComparisonOperationGreater:
            return @"Greater";
        case MLCComparisonOperationLessOrEqual:
            return @"Less or Equal";
        case MLCComparisonOperationGreaterOrEqual:
            return @"Greater or Equal";
        case MLCComparisonOperationLogicalAND:
            return @"Logical AND";
        case MLCComparisonOperationLogicalOR:
            return @"Logical OR";
        case MLCComparisonOperationLogicalNOT:
            return @"Logical NOT";
        case MLCComparisonOperationLogicalNAND:
            return @"Logical NAND";
        case MLCComparisonOperationLogicalNOR:
            return @"Logical NOR";
        case MLCComparisonOperationLogicalXOR:
            return @"Logical XOR";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"Equal";
    }
}

NSString *MLCGradientClippingTypeDebugDescription(MLCGradientClippingType gradientClippingType)
{
    switch (gradientClippingType) {
        case MLCGradientClippingTypeByValue:
            return @"By Value";
        case MLCGradientClippingTypeByNorm:
            return @"By Norm";
        case MLCGradientClippingTypeByGlobalNorm:
            return @"By Global Norm";
        // A value that is not one of the cases is answered with the first case's name, which is what
        // the framework does for all thirteen of these (measured for -1 and 999 on every one). It is
        // not nil: an earlier version of this file answered nil there, and no case asked, so the
        // default arms were unreachable and the divergence was invisible.
        default:
            return @"By Value";
    }
}

// The seed the random initializers of this port draw from, and the one +[MLCPlatform getRNGseed] answers.
// The host answers nil until an application sets one, and then the number it was given, 0 included
// (measured), and a seed of zero is a seed like any other: the port keeps it as a flag, not as a test for
// zero, so that setting it to zero really does reseed.
static BOOL CharonMLCHasRNGSeed = NO;
static NSInteger CharonMLCRNGSeed = 0;

@implementation MLCPlatform

+ (void)setRNGSeedTo:(NSNumber *)seed
{
    CharonMLCHasRNGSeed = YES;
    CharonMLCRNGSeed = seed.longLongValue;
}

+ (NSNumber *)getRNGseed
{
    return CharonMLCHasRNGSeed ? @(CharonMLCRNGSeed) : nil;
}

@end
