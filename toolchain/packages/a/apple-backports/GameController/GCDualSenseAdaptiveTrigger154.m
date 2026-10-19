#import "RevenantGC.h"

@implementation GCDualSenseAdaptiveTrigger (Revenant154)

- (void)setModeSlopeFeedbackWithStartPosition:(float)startPosition
                                 endPosition:(float)endPosition
                                startStrength:(float)startStrength
                                  endStrength:(float)endStrength
{
    (void)startPosition;
    (void)endPosition;
    (void)startStrength;
    (void)endStrength;
    [self revenant_setRequestedMode:GCDualSenseAdaptiveTriggerModeSlopeFeedback];
}

- (void)setModeFeedbackWithResistiveStrengths:(GCDualSenseAdaptiveTriggerPositionalResistiveStrengths)positionalResistiveStrengths
{
    (void)positionalResistiveStrengths;
    [self revenant_setRequestedMode:GCDualSenseAdaptiveTriggerModeFeedback];
}

- (void)setModeVibrationWithAmplitudes:(GCDualSenseAdaptiveTriggerPositionalAmplitudes)positionalAmplitudes
                             frequency:(float)frequency
{
    (void)positionalAmplitudes;
    (void)frequency;
    [self revenant_setRequestedMode:GCDualSenseAdaptiveTriggerModeVibration];
}

@end
