#import "RevenantAVAudioUnit.h"
#import "RevenantDistortionPresets.h"
#import <AudioToolbox/AudioUnitParameters.h>

@implementation AVAudioUnitTimeEffect

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    return [self initWithRevenantComponentDescription:audioComponentDescription name:nil manufacturerName:nil version:0];
}

@end

@implementation AVAudioUnitGenerator

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    return [self initWithRevenantComponentDescription:audioComponentDescription name:nil manufacturerName:nil version:0];
}

@end

#define RevenantParameterOf(unit, identifier) RevenantUnitParameter((unit).audioUnit, (identifier))
#define RevenantSetParameterOf(unit, identifier, value) RevenantSetUnitParameter((unit).audioUnit, (identifier), (value))

@implementation AVAudioUnitDelay {
    float _revenant_delayTime;
    BOOL _revenant_havedelayTime;
    float _revenant_feedback;
    BOOL _revenant_havefeedback;
    float _revenant_lowPassCutoff;
    BOOL _revenant_havelowPassCutoff;
    float _revenant_wetDryMix;
    BOOL _revenant_havewetDryMix;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _revenant_delayTime = 0;
        _revenant_havedelayTime = NO;
        _revenant_feedback = 0;
        _revenant_havefeedback = NO;
        _revenant_lowPassCutoff = 0;
        _revenant_havelowPassCutoff = NO;
        _revenant_wetDryMix = 0;
        _revenant_havewetDryMix = NO;
    }
    return self;
}

- (NSTimeInterval)delayTime
{
    if (_revenant_havedelayTime) {
        return _revenant_delayTime;
    }
    return RevenantParameterOf(self, kDelayParam_DelayTime);
}

- (void)setDelayTime:(NSTimeInterval)delayTime
{
    _revenant_delayTime = (float)delayTime;
    _revenant_havedelayTime = YES;
    RevenantSetParameterOf(self, kDelayParam_DelayTime, _revenant_delayTime);
}

- (float)feedback
{
    if (_revenant_havefeedback) {
        return _revenant_feedback;
    }
    return RevenantParameterOf(self, kDelayParam_Feedback);
}

- (void)setFeedback:(float)feedback
{
    _revenant_feedback = feedback;
    RevenantSetParameterOf(self, kDelayParam_Feedback, feedback);
}

- (float)lowPassCutoff
{
    if (_revenant_havelowPassCutoff) {
        return _revenant_lowPassCutoff;
    }
    return RevenantParameterOf(self, kDelayParam_LopassCutoff);
}

- (void)setLowPassCutoff:(float)lowPassCutoff
{
    _revenant_lowPassCutoff = lowPassCutoff;
    RevenantSetParameterOf(self, kDelayParam_LopassCutoff, lowPassCutoff);
}

- (float)wetDryMix
{
    if (_revenant_havewetDryMix) {
        return _revenant_wetDryMix;
    }
    return RevenantParameterOf(self, kDelayParam_WetDryMix);
}

- (void)setWetDryMix:(float)wetDryMix
{
    _revenant_wetDryMix = wetDryMix;
    RevenantSetParameterOf(self, kDelayParam_WetDryMix, wetDryMix);
}

- (void)revenant_applyPendingParameters
{
    if (_revenant_havedelayTime) RevenantSetParameterOf(self, kDelayParam_DelayTime, _revenant_delayTime);
    if (_revenant_havefeedback) RevenantSetParameterOf(self, kDelayParam_Feedback, _revenant_feedback);
    if (_revenant_havelowPassCutoff) RevenantSetParameterOf(self, kDelayParam_LopassCutoff, _revenant_lowPassCutoff);
    if (_revenant_havewetDryMix) RevenantSetParameterOf(self, kDelayParam_WetDryMix, _revenant_wetDryMix);
    [super revenant_applyPendingParameters];
}

@end

@implementation AVAudioUnitVarispeed {
    float _revenant_rate;
    BOOL _revenant_haverate;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _revenant_rate = 0;
        _revenant_haverate = NO;
    }
    return self;
}

- (float)rate
{
    if (_revenant_haverate) {
        return _revenant_rate;
    }
    return RevenantParameterOf(self, kVarispeedParam_PlaybackRate);
}

- (void)setRate:(float)rate
{
    _revenant_rate = rate;
    RevenantSetParameterOf(self, kVarispeedParam_PlaybackRate, rate);
}

- (void)revenant_applyPendingParameters
{
    if (_revenant_haverate) RevenantSetParameterOf(self, kVarispeedParam_PlaybackRate, _revenant_rate);
    [super revenant_applyPendingParameters];
}

@end

@implementation AVAudioUnitTimePitch {
    float _revenant_rate;
    BOOL _revenant_haverate;
    float _revenant_pitch;
    BOOL _revenant_havepitch;
    float _revenant_overlap;
    BOOL _revenant_haveoverlap;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _revenant_rate = 0;
        _revenant_haverate = NO;
        _revenant_pitch = 0;
        _revenant_havepitch = NO;
        _revenant_overlap = 0;
        _revenant_haveoverlap = NO;
    }
    return self;
}

- (float)rate
{
    if (_revenant_haverate) {
        return _revenant_rate;
    }
    return RevenantParameterOf(self, kTimePitchParam_Rate);
}

- (void)setRate:(float)rate
{
    _revenant_rate = rate;
    RevenantSetParameterOf(self, kTimePitchParam_Rate, rate);
}

- (float)pitch
{
    if (_revenant_havepitch) {
        return _revenant_pitch;
    }
    return RevenantParameterOf(self, kTimePitchParam_Pitch);
}

- (void)setPitch:(float)pitch
{
    _revenant_pitch = pitch;
    RevenantSetParameterOf(self, kTimePitchParam_Pitch, pitch);
}

- (float)overlap
{
    if (_revenant_haveoverlap) {
        return _revenant_overlap;
    }
    return RevenantParameterOf(self, kTimePitchParam_EffectBlend);
}

- (void)setOverlap:(float)overlap
{
    _revenant_overlap = overlap;
    RevenantSetParameterOf(self, kTimePitchParam_EffectBlend, overlap);
}

- (void)revenant_applyPendingParameters
{
    if (_revenant_haverate) RevenantSetParameterOf(self, kTimePitchParam_Rate, _revenant_rate);
    if (_revenant_havepitch) RevenantSetParameterOf(self, kTimePitchParam_Pitch, _revenant_pitch);
    if (_revenant_haveoverlap) RevenantSetParameterOf(self, kTimePitchParam_EffectBlend, _revenant_overlap);
    [super revenant_applyPendingParameters];
}

@end

@implementation AVAudioUnitDistortion {
    NSInteger _revenant_preset;
    float _revenant_preGain;
    BOOL _revenant_havepreGain;
    float _revenant_wetDryMix;
    BOOL _revenant_havewetDryMix;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _revenant_preset = 0;
        _revenant_preGain = RevenantDistortionPresets[0][14];
        _revenant_wetDryMix = RevenantDistortionPresets[0][15];
    }
    return self;
}

- (float)preGain
{
    return _revenant_preGain;
}

- (void)setPreGain:(float)preGain
{
    _revenant_preGain = preGain;
    _revenant_havepreGain = YES;
    RevenantSetParameterOf(self, kDistortionParam_SoftClipGain, preGain);
}

- (float)wetDryMix
{
    return _revenant_wetDryMix;
}

- (void)setWetDryMix:(float)wetDryMix
{
    _revenant_wetDryMix = wetDryMix;
    _revenant_havewetDryMix = YES;
    RevenantSetParameterOf(self, kDistortionParam_FinalMix, wetDryMix);
}

- (void)loadFactoryPreset:(AVAudioUnitDistortionPreset)preset
{
    if (preset < 0 || preset >= RevenantDistortionPresetCount) {
        return;
    }
    _revenant_preset = (NSInteger)preset;
    RevenantApplyDistortionPreset(self.audioUnit, _revenant_preset);
}

- (void)revenant_applyPendingParameters
{
    RevenantApplyDistortionPreset(self.audioUnit, _revenant_preset);
    if (_revenant_havepreGain) RevenantSetParameterOf(self, kDistortionParam_SoftClipGain, _revenant_preGain);
    if (_revenant_havewetDryMix) RevenantSetParameterOf(self, kDistortionParam_FinalMix, _revenant_wetDryMix);
    [super revenant_applyPendingParameters];
}

@end

@implementation AVAudioUnitReverb {
    float _revenant_wetDryMix;
    BOOL _revenant_havewetDryMix;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    self = [super initWithAudioComponentDescription:audioComponentDescription];
    if (self) {
        _revenant_wetDryMix = 0;
        _revenant_havewetDryMix = NO;
    }
    return self;
}

- (float)wetDryMix
{
    if (_revenant_havewetDryMix) {
        return _revenant_wetDryMix;
    }
    return RevenantParameterOf(self, kReverb2Param_DryWetMix);
}

- (void)setWetDryMix:(float)wetDryMix
{
    _revenant_wetDryMix = wetDryMix;
    RevenantSetParameterOf(self, kReverb2Param_DryWetMix, wetDryMix);
}

- (void)revenant_applyPendingParameters
{
    if (_revenant_havewetDryMix) RevenantSetParameterOf(self, kReverb2Param_DryWetMix, _revenant_wetDryMix);
    [super revenant_applyPendingParameters];
}

@end
