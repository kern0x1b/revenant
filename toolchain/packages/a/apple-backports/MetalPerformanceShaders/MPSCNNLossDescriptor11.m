#import "RevenantMPS.h"

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

+ (MPSCNNLossDescriptor *)cnnLossDescriptorWithType:(MPSCNNLossType)lossType reductionType:(MPSCNNReductionType)reductionType
{
    if ((unsigned int)lossType >= MPSCNNLossTypeCount) {
        RevenantMPSRefuse(@"MPSCNNLossDescriptor: loss type %u is not an MPSCNNLossType, so no descriptor is made",
                        (unsigned int)lossType);
        return nil;
    }
    if (reductionType >= MPSCNNReductionTypeCount) {
        RevenantMPSRefuse(@"MPSCNNLossDescriptor: reduction type %d is not an MPSCNNReductionType, so no descriptor is made",
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
    if (_lossType != MPSCNNLossTypeSoftMaxCrossEntropy && _lossType != MPSCNNLossTypeSigmoidCrossEntropy) {
        RevenantMPSRefuse(@"MPSCNNLossDescriptor: labelSmoothing is valid only for softmax and sigmoid cross entropy, so it is not set");
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
    if (_lossType != MPSCNNLossTypeSoftMaxCrossEntropy) {
        RevenantMPSRefuse(@"MPSCNNLossDescriptor: numberOfClasses is valid only for softmax cross entropy, so it is not set");
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
    if (_lossType != MPSCNNLossTypeLog) {
        RevenantMPSRefuse(@"MPSCNNLossDescriptor: epsilon is valid only for the log loss, so it is not set");
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
    if (_lossType != MPSCNNLossTypeHuber) {
        RevenantMPSRefuse(@"MPSCNNLossDescriptor: delta is valid only for the Huber loss, so it is not set");
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
