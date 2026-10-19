#import "CharonAVAudioUnit.h"
#import "CharonDistortionPresets.h"
#import <AudioToolbox/AudioUnitParameters.h>

// The AVAudioUnit subclasses that are a *description of one of the release's own built-in units* plus
// a set of the release's own parameters. Each description is a release subtype out of
// AudioUnitParameters.h - kAudioUnitSubType_Delay, kAudioUnitSubType_Varispeed,
// kAudioUnitSubType_TimePitch, kAudioUnitSubType_Distortion, kAudioUnitSubType_AudioUnitReverb - and
// every parameter id is the release's own out of the same header, so a value set here is an
// AudioUnitSetParameter on a real unit of the release and changes what it renders.
//
// The base classes - AVAudioUnit, AVAudioUnitEffect, AVAudioNode - are carried in
// libAVFoundationBackports.dylib, which this library links; nothing of theirs is edited here.
//
// AVAudioUnitMIDIInstrument and AVAudioUnitSampler are deliberately NOT here: iOS 6.1.3 exports no
// function that sends a MIDI event to an audio unit (its AudioToolbox AudioUnit family is the
// twenty-seven functions enumerated in facts/AVFAudio/AUAudioUnit.md, and none of them is a MIDI
// send), and it carries no sampler component. The path a MIDI instrument has on this release is
// MusicSequence and MusicPlayer, which it exports in full, and that is the sequencer family's to
// build. Writing the note methods as a queue nothing drains would be exactly the silent fake
// COORDINATION section 2 forbids, so they wait for that family - see facts/AVFAudio/AVAudioUnitMIDI.md.

@implementation AVAudioUnitTimeEffect

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    return [self initWithCharonComponentDescription:audioComponentDescription name:nil manufacturerName:nil version:0];
}

@end

// AVAudioUnitEffect is NOT defined here. It is carried in libAVFoundationBackports.dylib by
// AVFoundation/AVAudioUnit.m, whose registry entry is registry/AVFoundation/ios8avaudiouniteq.json.
// A second definition of one class is a duplicate-class hazard at load rather than a link error,
// which is how it survived into this series and was only found by the port-versus-host harness,
// where it was a duplicate symbol. The subclasses below call its -initWithAudioComponentDescription:,
// which is that one.

@implementation AVAudioUnitGenerator

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    return [self initWithCharonComponentDescription:audioComponentDescription name:nil manufacturerName:nil version:0];
}

@end

// A parameter's value, and where it comes from. A parameter the application has chosen is kept in an
// ivar and told to the unit; one it has not is read from the unit, which is asked rather than a table
// consulted. Whether it has been chosen is a BOOL, never a magic value: kDelayParam_Feedback and
// kTimePitchParam_Pitch both take -1 inside their documented range, so "-1 means unset" would swallow
// a value the host is entitled to set. (That is not a hypothesis - the host differential in
// tests/backports/host/avfaudio sets both to -1 before attach and reads them back.)
#define CharonParameterOf(unit, identifier) CharonUnitParameter((unit).audioUnit, (identifier))
#define CharonSetParameterOf(unit, identifier, value) CharonSetUnitParameter((unit).audioUnit, (identifier), (value))

@implementation AVAudioUnitDelay {
    float _charon_delayTime;
    BOOL _charon_havedelayTime;
    float _charon_feedback;
    BOOL _charon_havefeedback;
    float _charon_lowPassCutoff;
    BOOL _charon_havelowPassCutoff;
    float _charon_wetDryMix;
    BOOL _charon_havewetDryMix;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _charon_delayTime = 0;
        _charon_havedelayTime = NO;
        _charon_feedback = 0;
        _charon_havefeedback = NO;
        _charon_lowPassCutoff = 0;
        _charon_havelowPassCutoff = NO;
        _charon_wetDryMix = 0;
        _charon_havewetDryMix = NO;
    }
    return self;
}

- (NSTimeInterval)delayTime
{
    if (_charon_havedelayTime) {
        return _charon_delayTime;
    }
    return CharonParameterOf(self, kDelayParam_DelayTime);
}

- (void)setDelayTime:(NSTimeInterval)delayTime
{
    _charon_delayTime = (float)delayTime;
    _charon_havedelayTime = YES;
    CharonSetParameterOf(self, kDelayParam_DelayTime, _charon_delayTime);
}

- (float)feedback
{
    if (_charon_havefeedback) {
        return _charon_feedback;
    }
    return CharonParameterOf(self, kDelayParam_Feedback);
}

- (void)setFeedback:(float)feedback
{
    _charon_feedback = feedback;
    CharonSetParameterOf(self, kDelayParam_Feedback, feedback);
}

- (float)lowPassCutoff
{
    if (_charon_havelowPassCutoff) {
        return _charon_lowPassCutoff;
    }
    return CharonParameterOf(self, kDelayParam_LopassCutoff);
}

- (void)setLowPassCutoff:(float)lowPassCutoff
{
    _charon_lowPassCutoff = lowPassCutoff;
    CharonSetParameterOf(self, kDelayParam_LopassCutoff, lowPassCutoff);
}

- (float)wetDryMix
{
    if (_charon_havewetDryMix) {
        return _charon_wetDryMix;
    }
    return CharonParameterOf(self, kDelayParam_WetDryMix);
}

- (void)setWetDryMix:(float)wetDryMix
{
    _charon_wetDryMix = wetDryMix;
    CharonSetParameterOf(self, kDelayParam_WetDryMix, wetDryMix);
}

// A value chosen before the node was ever attached reaches the unit when the real one arrives.
- (void)charon_applyPendingParameters
{
    if (_charon_havedelayTime) CharonSetParameterOf(self, kDelayParam_DelayTime, _charon_delayTime);
    if (_charon_havefeedback) CharonSetParameterOf(self, kDelayParam_Feedback, _charon_feedback);
    if (_charon_havelowPassCutoff) CharonSetParameterOf(self, kDelayParam_LopassCutoff, _charon_lowPassCutoff);
    if (_charon_havewetDryMix) CharonSetParameterOf(self, kDelayParam_WetDryMix, _charon_wetDryMix);
    [super charon_applyPendingParameters];
}

@end

@implementation AVAudioUnitVarispeed {
    float _charon_rate;
    BOOL _charon_haverate;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _charon_rate = 0;
        _charon_haverate = NO;
    }
    return self;
}

- (float)rate
{
    if (_charon_haverate) {
        return _charon_rate;
    }
    return CharonParameterOf(self, kVarispeedParam_PlaybackRate);
}

- (void)setRate:(float)rate
{
    _charon_rate = rate;
    CharonSetParameterOf(self, kVarispeedParam_PlaybackRate, rate);
}

- (void)charon_applyPendingParameters
{
    if (_charon_haverate) CharonSetParameterOf(self, kVarispeedParam_PlaybackRate, _charon_rate);
    [super charon_applyPendingParameters];
}

@end

@implementation AVAudioUnitTimePitch {
    float _charon_rate;
    BOOL _charon_haverate;
    float _charon_pitch;
    BOOL _charon_havepitch;
    float _charon_overlap;
    BOOL _charon_haveoverlap;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _charon_rate = 0;
        _charon_haverate = NO;
        _charon_pitch = 0;
        _charon_havepitch = NO;
        _charon_overlap = 0;
        _charon_haveoverlap = NO;
    }
    return self;
}

- (float)rate
{
    if (_charon_haverate) {
        return _charon_rate;
    }
    return CharonParameterOf(self, kTimePitchParam_Rate);
}

- (void)setRate:(float)rate
{
    _charon_rate = rate;
    CharonSetParameterOf(self, kTimePitchParam_Rate, rate);
}

- (float)pitch
{
    if (_charon_havepitch) {
        return _charon_pitch;
    }
    return CharonParameterOf(self, kTimePitchParam_Pitch);
}

- (void)setPitch:(float)pitch
{
    _charon_pitch = pitch;
    CharonSetParameterOf(self, kTimePitchParam_Pitch, pitch);
}

- (float)overlap
{
    if (_charon_haveoverlap) {
        return _charon_overlap;
    }
    return CharonParameterOf(self, kTimePitchParam_EffectBlend);
}

- (void)setOverlap:(float)overlap
{
    _charon_overlap = overlap;
    CharonSetParameterOf(self, kTimePitchParam_EffectBlend, overlap);
}

- (void)charon_applyPendingParameters
{
    if (_charon_haverate) CharonSetParameterOf(self, kTimePitchParam_Rate, _charon_rate);
    if (_charon_havepitch) CharonSetParameterOf(self, kTimePitchParam_Pitch, _charon_pitch);
    if (_charon_haveoverlap) CharonSetParameterOf(self, kTimePitchParam_EffectBlend, _charon_overlap);
    [super charon_applyPendingParameters];
}

@end

// The object's own preGain and wetDryMix, as the host keeps them: a value the application sets is held here and
// sent to the unit, and a preset does not change them, because the host's properties do not follow a preset (the
// unit's parameters do; tests/backports/host/avfaudio/distortion.m checks both). A fresh object holds row 0.
@implementation AVAudioUnitDistortion {
    NSInteger _charon_preset;
    float _charon_preGain;
    BOOL _charon_havepreGain;
    float _charon_wetDryMix;
    BOOL _charon_havewetDryMix;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _charon_preset = 0;
        _charon_preGain = CharonDistortionPresets[0][14];
        _charon_wetDryMix = CharonDistortionPresets[0][15];
    }
    return self;
}

- (float)preGain
{
    return _charon_preGain;
}

- (void)setPreGain:(float)preGain
{
    _charon_preGain = preGain;
    _charon_havepreGain = YES;
    CharonSetParameterOf(self, kDistortionParam_SoftClipGain, preGain);
}

- (float)wetDryMix
{
    return _charon_wetDryMix;
}

- (void)setWetDryMix:(float)wetDryMix
{
    _charon_wetDryMix = wetDryMix;
    _charon_havewetDryMix = YES;
    CharonSetParameterOf(self, kDistortionParam_FinalMix, wetDryMix);
}

// The host's answer: the preset's sixteen values go to the unit. Out of range, the call changes nothing, as the host's does.
- (void)loadFactoryPreset:(AVAudioUnitDistortionPreset)preset
{
    if (preset < 0 || preset >= CharonDistortionPresetCount) {
        return;
    }
    _charon_preset = (NSInteger)preset;
    CharonApplyDistortionPreset(self.audioUnit, _charon_preset);
}

// What was chosen before the unit existed reaches it when it arrives: the preset first, then the two values the
// application set itself, which are the ones the unit then holds.
- (void)charon_applyPendingParameters
{
    CharonApplyDistortionPreset(self.audioUnit, _charon_preset);
    if (_charon_havepreGain) CharonSetParameterOf(self, kDistortionParam_SoftClipGain, _charon_preGain);
    if (_charon_havewetDryMix) CharonSetParameterOf(self, kDistortionParam_FinalMix, _charon_wetDryMix);
    [super charon_applyPendingParameters];
}

@end

// The reverb's own parameter here is DryWetMix (kReverb2Param_DryWetMix, 0). Its factory presets are not
// in this release: loadFactoryPreset: is declared by the SDK and is owed, registry/AVFAudio/iosaudiounitsubclasses8.json.
@implementation AVAudioUnitReverb {
    float _charon_wetDryMix;
    BOOL _charon_havewetDryMix;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _charon_wetDryMix = 0;
        _charon_havewetDryMix = NO;
    }
    return self;
}

- (float)wetDryMix
{
    if (_charon_havewetDryMix) {
        return _charon_wetDryMix;
    }
    return CharonParameterOf(self, kReverb2Param_DryWetMix);
}

- (void)setWetDryMix:(float)wetDryMix
{
    _charon_wetDryMix = wetDryMix;
    CharonSetParameterOf(self, kReverb2Param_DryWetMix, wetDryMix);
}

- (void)charon_applyPendingParameters
{
    if (_charon_havewetDryMix) CharonSetParameterOf(self, kReverb2Param_DryWetMix, _charon_wetDryMix);
    [super charon_applyPendingParameters];
}

@end
