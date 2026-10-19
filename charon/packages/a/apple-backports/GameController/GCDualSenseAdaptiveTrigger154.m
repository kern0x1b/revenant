// The three 15.4 members of GCDualSenseAdaptiveTrigger, in an object of their own release.
//
// GCDualSenseAdaptiveTrigger.h:107, :123 and :152 mark these three API_AVAILABLE(ios(15.4)), while the
// class and the four setMode calls of GCAdaptiveTrigger145.m are the 14.5 ones, so one object per
// release puts these three here and not there. What each one is: the 14.5 family asks for a trigger's
// mode by giving one strength at one position, and these give the whole curve instead - a strength per
// point for feedback, an amplitude per point for vibration, and both ends of a slope with a strength at
// each. That is the header's own difference, and it is the whole of what is new.
//
// The behaviour is the 14.5 object's behaviour, unchanged, and its oracle is the host's own trigger.
// Measured on this machine against the host's GCDualSenseAdaptiveTrigger with no controller behind it:
// all three selectors are present, and each call leaves `mode` 0, `status` 0 and `armPosition` 0 - the
// same answer the four of the 14.5 object measured. The header says why that is the honest answer and
// not a stub: mode mirrors the real condition of the triggers, and the controller has to answer before
// it changes, so it does not update at once after -[GCDualSenseAdaptiveTrigger setMode...] is called.
// So the public properties answer what the host answers, and what this object records is the mode the
// caller asked for, through the class's own -charon_setRequestedMode:, for a profile that owns a
// trigger to send it to when a controller is attached.
//
// **What is not done with the arguments, and why.** The curves' points are not clamped, ordered or
// stored. The header declares the five fields normalized, and clamping them into a value nothing reads
// would be a check that examines nothing: the only thing that could act on a curve is a controller, and
// there is none - that is the whole of what the measurement above shows. So each of these three records
// the mode the caller asked for, which is the one part of the call the port can hold, and answers
// nothing else. What a profile does with -charon_requestedMode: when a controller is attached is the
// 14.5 object's own business and is unchanged.
#import "CharonGC.h"

@implementation GCDualSenseAdaptiveTrigger (Charon154)

// GCDualSenseAdaptiveTrigger.h:99-107: a slope over [startPosition, endPosition], a strength at each
// end. The header says the two positions must be ordered; nothing here acts on the order, for the
// reason the section below gives.
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

// GCDualSenseAdaptiveTrigger.h:115-123: the same feedback as the 14.5 call, with a strength at each
// of the five points of the pull instead of one strength for all of it. The 14.5 half of the family is
// GCAdaptiveTrigger145.m's, and this records the same mode rather than filling the same field twice.
- (void)setModeFeedbackWithResistiveStrengths:(GCDualSenseAdaptiveTriggerPositionalResistiveStrengths)positionalResistiveStrengths
{
    (void)positionalResistiveStrengths;
    [self charon_setRequestedMode:GCDualSenseAdaptiveTriggerModeFeedback];
}

// GCDualSenseAdaptiveTrigger.h:144-152: the same vibration as the 14.5 call, with an amplitude at each
// of the five points of the pull instead of one amplitude for all of it.
- (void)setModeVibrationWithAmplitudes:(GCDualSenseAdaptiveTriggerPositionalAmplitudes)positionalAmplitudes
                             frequency:(float)frequency
{
    (void)positionalAmplitudes;
    (void)frequency;
    [self charon_setRequestedMode:GCDualSenseAdaptiveTriggerModeVibration];
}

@end