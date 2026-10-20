#import "RevenantMPS.h"

@implementation MPSCNNYOLOLossDescriptor {
    MPSCNNLossDescriptor *_XYLossDescriptor;
    MPSCNNLossDescriptor *_WHLossDescriptor;
    MPSCNNLossDescriptor *_confidenceLossDescriptor;
    MPSCNNLossDescriptor *_classesLossDescriptor;
    MPSCNNReductionType _reductionType;
    BOOL _rescore;
    float _scaleXY;
    float _scaleWH;
    float _scaleNoObject;
    float _scaleObject;
    float _scaleClass;
    float _minIOUForObjectPresence;
    float _maxIOUForObjectAbsence;
    NSUInteger _numberOfAnchorBoxes;
    NSData *_anchorBoxes;
}

+ (MPSCNNYOLOLossDescriptor *)cnnLossDescriptorWithXYLossType:(MPSCNNLossType)XYLossType
                                                   WHLossType:(MPSCNNLossType)WHLossType
                                           confidenceLossType:(MPSCNNLossType)confidenceLossType
                                              classesLossType:(MPSCNNLossType)classesLossType
                                                reductionType:(MPSCNNReductionType)reductionType
                                                  anchorBoxes:(NSData *)anchorBoxes
                                          numberOfAnchorBoxes:(NSUInteger)numberOfAnchorBoxes
{
    if (reductionType >= MPSCNNReductionTypeCount) {
        RevenantMPSRefuse(@"MPSCNNYOLOLossDescriptor: reduction type %d is not an MPSCNNReductionType, so no descriptor is made",
                        (int)reductionType);
        return nil;
    }
    MPSCNNLossDescriptor *XY = [MPSCNNLossDescriptor cnnLossDescriptorWithType:XYLossType reductionType:reductionType];
    MPSCNNLossDescriptor *WH = [MPSCNNLossDescriptor cnnLossDescriptorWithType:WHLossType reductionType:reductionType];
    MPSCNNLossDescriptor *confidence = [MPSCNNLossDescriptor cnnLossDescriptorWithType:confidenceLossType reductionType:reductionType];
    MPSCNNLossDescriptor *classes = [MPSCNNLossDescriptor cnnLossDescriptorWithType:classesLossType reductionType:reductionType];
    if (!XY || !WH || !confidence || !classes) {
        return nil;
    }
    MPSCNNYOLOLossDescriptor *descriptor = [[self alloc] init];
    descriptor->_XYLossDescriptor = XY;
    descriptor->_WHLossDescriptor = WH;
    descriptor->_confidenceLossDescriptor = confidence;
    descriptor->_classesLossDescriptor = classes;
    descriptor->_reductionType = reductionType;
    descriptor->_rescore = YES;
    descriptor->_scaleXY = 10.0f;
    descriptor->_scaleWH = 10.0f;
    descriptor->_scaleNoObject = 5.0f;
    descriptor->_scaleObject = 100.0f;
    descriptor->_scaleClass = 2.0f;
    descriptor->_minIOUForObjectPresence = 0.7f;
    descriptor->_maxIOUForObjectAbsence = 0.3f;
    descriptor->_numberOfAnchorBoxes = numberOfAnchorBoxes;
    descriptor->_anchorBoxes = anchorBoxes;
    return descriptor;
}

- (MPSCNNLossDescriptor *)XYLossDescriptor
{
    return _XYLossDescriptor;
}

- (void)setXYLossDescriptor:(MPSCNNLossDescriptor *)XYLossDescriptor
{
    _XYLossDescriptor = XYLossDescriptor;
}

- (MPSCNNLossDescriptor *)WHLossDescriptor
{
    return _WHLossDescriptor;
}

- (void)setWHLossDescriptor:(MPSCNNLossDescriptor *)WHLossDescriptor
{
    _WHLossDescriptor = WHLossDescriptor;
}

- (MPSCNNLossDescriptor *)confidenceLossDescriptor
{
    return _confidenceLossDescriptor;
}

- (void)setConfidenceLossDescriptor:(MPSCNNLossDescriptor *)confidenceLossDescriptor
{
    _confidenceLossDescriptor = confidenceLossDescriptor;
}

- (MPSCNNLossDescriptor *)classesLossDescriptor
{
    return _classesLossDescriptor;
}

- (void)setClassesLossDescriptor:(MPSCNNLossDescriptor *)classesLossDescriptor
{
    _classesLossDescriptor = classesLossDescriptor;
}

- (MPSCNNReductionType)reductionType
{
    return _reductionType;
}

- (void)setReductionType:(MPSCNNReductionType)reductionType
{
    _reductionType = reductionType;
}

- (BOOL)rescore
{
    return _rescore;
}

- (void)setRescore:(BOOL)rescore
{
    _rescore = rescore;
}

- (float)scaleXY
{
    return _scaleXY;
}

- (void)setScaleXY:(float)scaleXY
{
    _scaleXY = scaleXY;
}

- (float)scaleWH
{
    return _scaleWH;
}

- (void)setScaleWH:(float)scaleWH
{
    _scaleWH = scaleWH;
}

- (float)scaleNoObject
{
    return _scaleNoObject;
}

- (void)setScaleNoObject:(float)scaleNoObject
{
    _scaleNoObject = scaleNoObject;
}

- (float)scaleObject
{
    return _scaleObject;
}

- (void)setScaleObject:(float)scaleObject
{
    _scaleObject = scaleObject;
}

- (float)scaleClass
{
    return _scaleClass;
}

- (void)setScaleClass:(float)scaleClass
{
    _scaleClass = scaleClass;
}

- (float)minIOUForObjectPresence
{
    return _minIOUForObjectPresence;
}

- (void)setMinIOUForObjectPresence:(float)minIOUForObjectPresence
{
    _minIOUForObjectPresence = minIOUForObjectPresence;
}

- (float)maxIOUForObjectAbsence
{
    return _maxIOUForObjectAbsence;
}

- (void)setMaxIOUForObjectAbsence:(float)maxIOUForObjectAbsence
{
    _maxIOUForObjectAbsence = maxIOUForObjectAbsence;
}

- (NSUInteger)numberOfAnchorBoxes
{
    return _numberOfAnchorBoxes;
}

- (void)setNumberOfAnchorBoxes:(NSUInteger)numberOfAnchorBoxes
{
    _numberOfAnchorBoxes = numberOfAnchorBoxes;
}

- (NSData *)anchorBoxes
{
    return _anchorBoxes;
}

- (void)setAnchorBoxes:(NSData *)anchorBoxes
{
    _anchorBoxes = anchorBoxes;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPSCNNYOLOLossDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy->_XYLossDescriptor = [_XYLossDescriptor copy];
    copy->_WHLossDescriptor = [_WHLossDescriptor copy];
    copy->_confidenceLossDescriptor = [_confidenceLossDescriptor copy];
    copy->_classesLossDescriptor = [_classesLossDescriptor copy];
    copy->_reductionType = _reductionType;
    copy->_rescore = _rescore;
    copy->_scaleXY = _scaleXY;
    copy->_scaleWH = _scaleWH;
    copy->_scaleNoObject = _scaleNoObject;
    copy->_scaleObject = _scaleObject;
    copy->_scaleClass = _scaleClass;
    copy->_minIOUForObjectPresence = _minIOUForObjectPresence;
    copy->_maxIOUForObjectAbsence = _maxIOUForObjectAbsence;
    copy->_numberOfAnchorBoxes = _numberOfAnchorBoxes;
    copy->_anchorBoxes = _anchorBoxes;
    return copy;
}

@end
