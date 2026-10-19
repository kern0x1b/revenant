#import "CharonAUAudioUnit.h"

// The AVAudioUnit subclasses of iOS 8, over the release's own built-in audio units.
//
// Each of these is a *description* and a set of parameters. The descriptions are the release's own
// subtypes - kAudioUnitSubType_Delay, kAudioUnitSubType_Distortion, kAudioUnitSubType_AudioUnitReverb,
// kAudioUnitSubType_Varispeed, kAudioUnitSubType_TimePitch - and every parameter id below is the
// release's own, out of AudioUnitParameters.h: kDelayParam_DelayTime, kDistortionParam_PreGain,
// kVarispeedParam_PlaybackRate, kTimePitchParam_Rate and the rest. A value set here is an
// AudioUnitSetParameter on the real unit, so it changes what the release's unit renders.
//
// The classes themselves - AVAudioUnit, AVAudioUnitEffect, AVAudioNode, AVAudioEngine - are carried in
// libAVFoundationBackports.dylib, which this library links. Nothing of theirs is edited here; the two
// Charon hooks below are declared here rather than by importing their private header, because a
// private header of another folder is not this library's to depend on.

NS_ASSUME_NONNULL_BEGIN

// The two hooks libAVFoundationBackports' AVAudioUnit carries, declared with the signatures its own
// CharonAVAudioUnit.h gives them.
@interface AVAudioUnit (CharonAVFAudioImpl)
- (instancetype)initWithCharonComponentDescription:(AudioComponentDescription)description
                                              name:(NSString *_Nullable)name
                                  manufacturerName:(NSString *_Nullable)manufacturerName
                                           version:(NSUInteger)version;
- (void)charon_applyPendingParameters;
@end

// The generator family's own hook: the base class's hook with the description the caller gave. The
// MIDI instrument is not a generator: the SDK makes AVAudioUnitMIDIInstrument an AVAudioUnit subclass
// (AVAudioUnitMIDIInstrument.h:24), so it calls the AVAudioUnit hook above.
@interface AVAudioUnitGenerator (CharonAVFAudioImpl)
- (instancetype)initWithCharonComponentDescription:(AudioComponentDescription)description
                                              name:(NSString *_Nullable)name
                                  manufacturerName:(NSString *_Nullable)manufacturerName
                                           version:(NSUInteger)version;
@end

// The description of one of the release's built-in units: the release's own type and subtype with
// the Apple manufacturer code, which is the manufacturer the release's own units carry.
static inline AudioComponentDescription CharonUnitDescription(OSType unitType, OSType subType)
{
    AudioComponentDescription description = {0};
    description.componentType = unitType;
    description.componentSubType = subType;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    return description;
}

// The value of one of the release's own parameters, asked of the unit. A unit with no such
// parameter, and a unit this release does not carry at all (NULL), both answer zero - which is what
// AudioUnitGetParameter leaves the value at when it fails.
static inline float CharonUnitParameter(AudioUnit unit, AudioUnitParameterID identifier)
{
    if (unit == NULL) {
        return 0;
    }
    AudioUnitParameterValue value = 0;
    if (AudioUnitGetParameter(unit, identifier, kAudioUnitScope_Global, 0, &value) != noErr) {
        return 0;
    }
    return (float)value;
}

static inline void CharonSetUnitParameter(AudioUnit unit, AudioUnitParameterID identifier, float value)
{
    if (unit == NULL) {
        return;
    }
    AudioUnitSetParameter(unit, identifier, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)value, 0);
}

NS_ASSUME_NONNULL_END
