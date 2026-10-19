#import "CharonGC.h"

@implementation GCDualSenseAdaptiveTrigger (Charon154)

- (void)setModeSlopeFeedbackWithStartPosition:(float)startPosition
                                 endPosition:(float)endPosition
                                startStrength:(float)startStrength
                                  endStrength:(float)endStrength
{
    (void)startPosition;
    (void)endPosition;
    (void)startStrength;
    (void)endStrength;
    [self charon_setRequestedMode:GCDualSenseAdaptiveTriggerModeSlopeFeedback];
}

- (void)setModeFeedbackWithResistiveStrengths:(GCDualSenseAdaptiveTriggerPositionalResistiveStrengths)positionalResistiveStrengths
{
    (void)positionalResistiveStrengths;
    [self charon_setRequestedMode:GCDualSenseAdaptiveTriggerModeFeedback];
}

- (void)setModeVibrationWithAmplitudes:(GCDualSenseAdaptiveTriggerPositionalAmplitudes)positionalAmplitudes
                             frequency:(float)frequency
{
    (void)positionalAmplitudes;
    (void)frequency;
    [self charon_setRequestedMode:GCDualSenseAdaptiveTriggerModeVibration];
}

@end
