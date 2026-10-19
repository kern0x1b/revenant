#import "RevenantGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation GCDualSenseAdaptiveTrigger {
    GCDualSenseAdaptiveTriggerMode _requestedMode;
    float _armPosition;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestedMode = GCDualSenseAdaptiveTriggerModeOff;
        _armPosition = 0.0f;
    }
    return self;
}

- (GCDualSenseAdaptiveTriggerMode)mode
{
    return GCDualSenseAdaptiveTriggerModeOff;
}

- (GCDualSenseAdaptiveTriggerStatus)status
{
    return GCDualSenseAdaptiveTriggerStatusFeedbackNoLoad;
}

- (float)armPosition
{
    return _armPosition;
}

- (GCDualSenseAdaptiveTriggerMode)revenant_requestedMode
{
    return _requestedMode;
}

- (void)revenant_setArmPosition:(float)armPosition
{
    _armPosition = fmaxf(0.0f, fminf(1.0f, armPosition));
}

- (void)revenant_setRequestedMode:(GCDualSenseAdaptiveTriggerMode)mode
{
    _requestedMode = mode;
}

- (void)setModeOff
{
    _requestedMode = GCDualSenseAdaptiveTriggerModeOff;
}

- (void)setModeFeedbackWithStartPosition:(float)startPosition resistiveStrength:(float)resistiveStrength
{
    _requestedMode = GCDualSenseAdaptiveTriggerModeFeedback;
}

- (void)setModeWeaponWithStartPosition:(float)startPosition endPosition:(float)endPosition resistiveStrength:(float)resistiveStrength
{
    _requestedMode = GCDualSenseAdaptiveTriggerModeWeapon;
}

- (void)setModeVibrationWithStartPosition:(float)startPosition amplitude:(float)amplitude frequency:(float)frequency
{
    _requestedMode = GCDualSenseAdaptiveTriggerModeVibration;
}

@end
