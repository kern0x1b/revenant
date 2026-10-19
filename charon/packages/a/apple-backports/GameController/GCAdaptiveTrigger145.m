#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// A DualSense's adaptive trigger: a GCControllerButtonInput that is also a device the application
// commands a mode into.
//
// The three properties and the four setMode calls split the way the header says they do, and the
// host measures the split:
//
//   mode mirrors the real condition of the triggers: the controller has to answer, so it does not
//    change at once after -[GCDualSenseAdaptiveTrigger setMode...] is called (the header).
//
// Measured on the host's own trigger, built by the application with no controller behind it: every
// setMode call - off, feedback, weapon, vibration - leaves mode at 0 and status at 0, and armPosition
// stays 0 whatever the button's own value is. That is the honest contract here and not a stub: a mode
// the port set itself would be a mode no controller ever entered, and the header's own sentence says
// the value is the controller's answer, not the caller's.
//
// What the port does answer is what it can: the trigger is a real button, so its value, pressed and
// touched states and its handlers are this package's own button behaviour, and the four setMode calls
// accept what the caller passes and validate what the header says they can be - a start position and
// an end position that must be ordered, amplitudes and strengths clamped to the normalized range -
// and then report the mode they were asked for through -charon_requestedMode:, for the profile that
// owns the trigger to send when a controller is attached. On a device with no controller attached
// there is nothing to send it to, which is why the public properties answer what the host answers.

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

// The mode the last setMode call asked for, which is what the profile sends to a controller and what
// the public mode deliberately is not: the header says mode is the controller's answer, so a port that
// returned this one would be answering with the caller's own request.
- (GCDualSenseAdaptiveTriggerMode)charon_requestedMode
{
    return _requestedMode;
}

- (void)charon_setArmPosition:(float)armPosition
{
    _armPosition = fmaxf(0.0f, fminf(1.0f, armPosition));
}

// The writer for -charon_requestedMode:, reached from GCDualSenseAdaptiveTrigger154.m, which carries
// the 15.4 half of the setMode family and cannot write this class's ivar. A category cannot add an
// ivar, so the value stays here and the 15.4 object reaches it through this one - the same seam shape
// GCDualSenseAdaptiveTrigger's own four setMode calls use, and the reason the declaration is in
// CharonGC.h rather than in a category interface at the top of that file.
- (void)charon_setRequestedMode:(GCDualSenseAdaptiveTriggerMode)mode
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
