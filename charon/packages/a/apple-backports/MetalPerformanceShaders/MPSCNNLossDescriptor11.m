// MPSCNNLossDescriptor, from the header of MPSCNNLoss.h in the SDK of iOS 16.4: the type of a loss filter, its
// reduction, and the six numbers a loss reads. A plain shape object with no storage of its own: it names a loss and
// runs none. The defaults are the ones the release answers for the factory, measured on the host.

#import "CharonMPS.h"

@implementation MPSCNNLossDescriptor {
    MPSCNNLossType _lossType;
    MPSCNNReductionType _reductionType;
    BOOL _reduceAcrossBatch;
    float _weight;
    float _labelSmoothing;
    NSUInteger _numberOfClasses;
    float _epsilon;
    float _delta;
}

// -init is NS_UNAVAILABLE in the header and is not overridden here: a caller that reaches NSObject's -init gets the
// zeroed object the release answers too (measured on the host).
+ (MPSCNNLossDescriptor *)cnnLossDescriptorWithType:(MPSCNNLossType)lossType reductionType:(MPSCNNReductionType)reductionType
{
    // The release asserts on a loss type outside MPSCNNLossType, and on a reduction type at or past
    // MPSCNNReductionTypeCount (measured: loss type 10 and -1 abort; reduction 4 aborts, and -1 is accepted, because
    // the reduction is a signed enum and the test is the same one). An API in this port never crashes its caller:
    // it refuses by name and returns nil.
    if ((unsigned int)lossType >= MPSCNNLossTypeCount) {
        CharonMPSRefuse(@"MPSCNNLossDescriptor: loss type %u is not an MPSCNNLossType, so no descriptor is made",
                        (unsigned int)lossType);
        return nil;
    }
    if (reductionType >= MPSCNNReductionTypeCount) {
        CharonMPSRefuse(@"MPSCNNLossDescriptor: reduction type %d is not an MPSCNNReductionType, so no descriptor is made",
                        (int)reductionType);
        return nil;
    }
    MPSCNNLossDescriptor *descriptor = [[self alloc] init];
    descriptor->_lossType = lossType;
    descriptor->_reductionType = reductionType;
    descriptor->_reduceAcrossBatch = NO;
    descriptor->_weight = 1.0f;
    descriptor->_labelSmoothing = 0.0f;
    descriptor->_numberOfClasses = 1;
    descriptor->_epsilon = 1e-7f;
    descriptor->_delta = 1.0f;
    return descriptor;
}

- (MPSCNNLossType)lossType
{
    return _lossType;
}

- (void)setLossType:(MPSCNNLossType)lossType
{
    // The release does not check the loss type on the setter (measured: 10 is accepted here, and refused only by the
    // factory), so the port does not either.
    _lossType = lossType;
}

- (MPSCNNReductionType)reductionType
{
    return _reductionType;
}

- (void)setReductionType:(MPSCNNReductionType)reductionType
{
    _reductionType = reductionType;
}

// reduceAcrossBatch is declared at iOS 14.0 in the header, later than this class's 11.3, so its accessors are written
// out rather than synthesised: the port answers them on every release it targets, and the header's availability is
// recorded in facts/MetalPerformanceShaders/MPSCNNLossDescriptor.md.
- (BOOL)reduceAcrossBatch
{
    return _reduceAcrossBatch;
}

- (void)setReduceAcrossBatch:(BOOL)reduceAcrossBatch
{
    _reduceAcrossBatch = reduceAcrossBatch;
}

- (float)weight
{
    return _weight;
}

- (void)setWeight:(float)weight
{
    _weight = weight;
}

- (float)labelSmoothing
{
    return _labelSmoothing;
}

- (void)setLabelSmoothing:(float)labelSmoothing
{
    // Valid only for the softmax and the sigmoid cross entropies. The release asserts on the setter for any other loss
    // type, and it reads the loss type the descriptor holds at the moment of the set (measured).
    if (_lossType != MPSCNNLossTypeSoftMaxCrossEntropy && _lossType != MPSCNNLossTypeSigmoidCrossEntropy) {
        CharonMPSRefuse(@"MPSCNNLossDescriptor: labelSmoothing is valid only for softmax and sigmoid cross entropy, so it is not set");
        return;
    }
    _labelSmoothing = labelSmoothing;
}

- (NSUInteger)numberOfClasses
{
    return _numberOfClasses;
}

- (void)setNumberOfClasses:(NSUInteger)numberOfClasses
{
    // Valid only for the softmax cross entropy (measured: the setter asserts on any other loss type).
    if (_lossType != MPSCNNLossTypeSoftMaxCrossEntropy) {
        CharonMPSRefuse(@"MPSCNNLossDescriptor: numberOfClasses is valid only for softmax cross entropy, so it is not set");
        return;
    }
    _numberOfClasses = numberOfClasses;
}

- (float)epsilon
{
    return _epsilon;
}

- (void)setEpsilon:(float)epsilon
{
    // Valid only for the log loss (measured: the setter asserts on any other loss type).
    if (_lossType != MPSCNNLossTypeLog) {
        CharonMPSRefuse(@"MPSCNNLossDescriptor: epsilon is valid only for the log loss, so it is not set");
        return;
    }
    _epsilon = epsilon;
}

- (float)delta
{
    return _delta;
}

- (void)setDelta:(float)delta
{
    // Valid only for the Huber loss (measured: the setter asserts on any other loss type).
    if (_lossType != MPSCNNLossTypeHuber) {
        CharonMPSRefuse(@"MPSCNNLossDescriptor: delta is valid only for the Huber loss, so it is not set");
        return;
    }
    _delta = delta;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPSCNNLossDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy->_lossType = _lossType;
    copy->_reductionType = _reductionType;
    copy->_reduceAcrossBatch = _reduceAcrossBatch;
    copy->_weight = _weight;
    copy->_labelSmoothing = _labelSmoothing;
    copy->_numberOfClasses = _numberOfClasses;
    copy->_epsilon = _epsilon;
    copy->_delta = _delta;
    return copy;
}

@end
