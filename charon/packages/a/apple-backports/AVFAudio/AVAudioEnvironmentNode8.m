#import "CharonAVFAudio.h"
#import "CharonAVFAudioNew.h"
#import <AVFAudio/AVAudioEnvironmentNode.h>
#import <AudioToolbox/AUComponent.h>
#import <AudioToolbox/AudioUnitParameters.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioToolbox/AudioSession.h>
#import "CharonEnvironmentOutput.h"
#import "CharonEnvironmentFilter.h"

// AVAudioEnvironmentNode on the release's own kAudioUnitSubType_SpatialMixer, and the two
// parameter classes that go with it.
//
// The unit is real and the release's own: AudioComponentFindNext for {kAudioUnitType_Mixer,
// kAudioUnitSubType_SpatialMixer, 'appl'}, and a parameter set of thirty-odd k3DMixerParam_
// entries in the release's own AudioUnitParameters.h marked iOS 2.0 - azimuth, elevation, distance,
// gain, playback rate, bus enable, min and max gain, dry/wet reverb blend, global reverb gain,
// occlusion and obstruction attenuation, and the InDecibels replacements for the deprecated ones.
// Nothing here translates that unit.
//
// The node carries a graph of its own - the mixer terminated into a generic output - so it can be
// rendered offline without an engine, which is what makes its own output measurable.
//
// The coordinate model is the mixer's: each input bus's parameters are that source's position
// *relative to the listener*, and the listener is at the mixer's origin. AVAudioEnvironmentNode
// exposes the listener as a position, which is the same statement the other way round - moving the
// listener is the inverse transform applied to every source. That is exact, not an approximation: a
// rigid transform and its inverse compose to the identity on the positions the mixer is given.
//
// The algorithms are mapped to what this unit offers. It has no head-related transfer function -
// nothing in its parameter set says where a listener's ears are - so the two it can be are the sound
// field and the stereo pass-through, and HRTF and equal-power panning are reported as not applicable
// rather than offered and quietly equal to the sound field.

// The mixer, asked for once per process: the component is a registration and the release answers it
// the same way every time.
static AudioComponent CharonEnvironmentComponent(void)
{
    static AudioComponent component;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        AudioComponentDescription description = {0};
        description.componentType = kAudioUnitType_Mixer;
        description.componentSubType = kAudioUnitSubType_SpatialMixer;
        description.componentManufacturer = kAudioUnitManufacturer_Apple;
        component = AudioComponentFindNext(NULL, &description);
    });
    return component;
}

@implementation AVAudioEnvironmentDistanceAttenuationParameters {
    __weak AVAudioEnvironmentNode *_charon_owner;
    AVAudioEnvironmentDistanceAttenuationModel _charon_model;
    float _charon_referenceDistance;
    float _charon_maximumDistance;
    float _charon_rolloffFactor;
}

// The header's own documented defaults: the inverse model, one metre of reference distance, one
// hundred thousand metres of maximum distance, and a rolloff factor of one.
- (instancetype)initWithCharonOwner:(AVAudioEnvironmentNode *)owner
{
    if ((self = [super init])) {
        _charon_owner = owner;
        _charon_model = AVAudioEnvironmentDistanceAttenuationModelInverse;
        _charon_referenceDistance = 1.0f;
        _charon_maximumDistance = 100000.0f;
        _charon_rolloffFactor = 1.0f;
    }
    return self;
}

- (AVAudioEnvironmentDistanceAttenuationModel)distanceAttenuationModel
{
    return _charon_model;
}

- (void)setDistanceAttenuationModel:(AVAudioEnvironmentDistanceAttenuationModel)distanceAttenuationModel
{
    _charon_model = distanceAttenuationModel;
    [_charon_owner charon_applyEnvironmentParameters];
}

- (float)referenceDistance
{
    return _charon_referenceDistance;
}

- (void)setReferenceDistance:(float)referenceDistance
{
    _charon_referenceDistance = referenceDistance;
    [_charon_owner charon_applyEnvironmentParameters];
}

- (float)maximumDistance
{
    return _charon_maximumDistance;
}

- (void)setMaximumDistance:(float)maximumDistance
{
    _charon_maximumDistance = maximumDistance;
    [_charon_owner charon_applyEnvironmentParameters];
}

- (float)rolloffFactor
{
    return _charon_rolloffFactor;
}

- (void)setRolloffFactor:(float)rolloffFactor
{
    _charon_rolloffFactor = rolloffFactor;
    [_charon_owner charon_applyEnvironmentParameters];
}

// The attenuation each of the header's three models describes, evaluated where the port can: a
// source's gain as a function of its distance. The unit still renders - this only decides the gain
// the unit is given, which is exactly the parameter it has. Written from the three definitions in the
// header's own documentation: the linear model stops attenuating at maximumDistance, the exponential
// one falls off by the rolloff factor, the inverse one is the reciprocal of the distance in units of
// the reference distance.
- (float)charon_gainForDistance:(float)distance
{
    float reference = _charon_referenceDistance > 0 ? _charon_referenceDistance : 1.0f;
    float rolloff = _charon_rolloffFactor > 0 ? _charon_rolloffFactor : 1.0f;
    switch (_charon_model) {
        case AVAudioEnvironmentDistanceAttenuationModelInverse:
            return reference / (reference + rolloff * (distance - reference));
        case AVAudioEnvironmentDistanceAttenuationModelExponential:
            return (float)exp(-rolloff * (distance - reference));
        case AVAudioEnvironmentDistanceAttenuationModelLinear: {
            if (distance <= reference) {
                return 1.0f;
            }
            if (distance >= _charon_maximumDistance) {
                return 0.0f;
            }
            float span = _charon_maximumDistance - reference;
            return span > 0 ? (float)(1.0 - rolloff * (distance - reference) / span) : 0.0f;
        }
    }
    return 1.0f;
}

@end

// The reverb's filter band. The header types it as an AVAudioUnitEQFilterParameters, and that class's setters store the value
// and hand it to an AVAudioUnitEQ owner, which the environment is not. So this subclass takes the environment as its owner,
// stores each value as the band does, and tells the environment to write the band to the mixer's reverb filter (SpatialMixer
// parameters 14 to 18). The defaults and the enable mapping are the host's (CharonEnvironmentFilter.h).
// The band's own initializer, which the AVFoundation backport defines; the EQ it names is not this class's owner, so nil.
@class AVAudioUnitEQ;
@interface AVAudioUnitEQFilterParameters (CharonEnvironment)
- (instancetype)initForCharonEQ:(AVAudioUnitEQ *)eq bandIndex:(NSUInteger)bandIndex;
@end

@interface CharonEnvironmentFilterParameters : AVAudioUnitEQFilterParameters
- (instancetype)initWithCharonOwner:(AVAudioEnvironmentNode *)owner;
@end

@implementation CharonEnvironmentFilterParameters {
    __weak AVAudioEnvironmentNode *_charon_owner;
}

// The host's defaults: 800 Hz, bandwidth 3, gain 0, the parametric type, and not bypassed (enable 1 on the mixer).
// The setters below run here before the environment has a mixer, and the environment ignores them until it does.
- (instancetype)initWithCharonOwner:(AVAudioEnvironmentNode *)owner
{
    if ((self = [super initForCharonEQ:nil bandIndex:0])) {
        _charon_owner = owner;
        self.frequency = CharonEnvironmentFilterDefaultFrequency;
        self.bandwidth = CharonEnvironmentFilterDefaultBandwidth;
        self.gain = CharonEnvironmentFilterDefaultGain;
        self.filterType = AVAudioUnitEQFilterTypeParametric;
        self.bypass = NO;
    }
    return self;
}

// The band stores the value raw, as the host does, so the value read back is the one written; the mixer clamps it.
- (void)setFilterType:(AVAudioUnitEQFilterType)filterType
{
    [super setFilterType:filterType];
    [_charon_owner charon_applyEnvironmentParameters];
}

- (void)setFrequency:(float)frequency
{
    [super setFrequency:frequency];
    [_charon_owner charon_applyEnvironmentParameters];
}

- (void)setBandwidth:(float)bandwidth
{
    [super setBandwidth:bandwidth];
    [_charon_owner charon_applyEnvironmentParameters];
}

- (void)setGain:(float)gain
{
    [super setGain:gain];
    [_charon_owner charon_applyEnvironmentParameters];
}

- (void)setBypass:(BOOL)bypass
{
    [super setBypass:bypass];
    [_charon_owner charon_applyEnvironmentParameters];
}

@end

@implementation AVAudioEnvironmentReverbParameters {
    __weak AVAudioEnvironmentNode *_charon_owner;
    float _charon_level;
    BOOL _charon_enable;
    CharonEnvironmentFilterParameters *_charon_filter;
}

- (instancetype)initWithCharonOwner:(AVAudioEnvironmentNode *)owner
{
    if ((self = [super init])) {
        _charon_owner = owner;
        _charon_filter = [[CharonEnvironmentFilterParameters alloc] initWithCharonOwner:owner];
    }
    return self;
}

- (AVAudioUnitEQFilterParameters *)filterParameters
{
    return _charon_filter;
}

// loadFactoryReverbPreset: is not implemented, and is owed. The host's preset changes none of the mixer's parameters, and its
// full state (the environment's and the reverb's) carries the preset's index and name but not the values it sets, so there is
// no table to map (facts/AVFAudio/AVAudioEnvironmentNode.md). Both rows are in registry/AVFAudio/iosaudioenvironment8.json.

- (BOOL)enable
{
    return _charon_enable;
}

- (void)setEnable:(BOOL)enable
{
    _charon_enable = enable;
    [_charon_owner charon_applyEnvironmentParameters];
}

- (float)level
{
    return _charon_level;
}

// The header's range is -40 to 40 dB and its default 0.0; the level is the mixer's own global reverb
// gain, which is in decibels, so the value goes there unchanged.
- (void)setLevel:(float)level
{
    _charon_level = level;
    [_charon_owner charon_applyEnvironmentParameters];
}

@end

@implementation AVAudioEnvironmentNode {
    AUGraph _charon_graph;
    AUNode _charon_mixer;
    AudioUnit _charon_mixerUnit;
    AUNode _charon_output;
    AudioUnit _charon_outputUnit;
    BOOL _charon_initialized;
    AVAudio3DPoint _charon_listenerPosition;
    AVAudio3DVectorOrientation _charon_listenerVectorOrientation;
    AVAudio3DAngularOrientation _charon_listenerAngularOrientation;
    float _charon_outputVolume;
    AVAudioEnvironmentDistanceAttenuationParameters *_charon_attenuation;
    AVAudioEnvironmentReverbParameters *_charon_reverb;
    AVAudioEnvironmentOutputType _charon_outputType;
}

// One graph, built in -init exactly as the release's own AUGraph calls say: NewAUGraph, AUGraphOpen,
// AUGraphAddNode for the mixer and for a generic output, AUGraphConnectNodeInput from the mixer to the
// output, and AUGraphNodeInfo to get each real AudioUnit.
- (instancetype)init
{
    if ((self = [super init])) {
        _charon_listenerPosition = AVAudioMake3DPoint(0, 0, 0);
        _charon_listenerVectorOrientation = AVAudioMake3DVectorOrientation(AVAudioMake3DVector(1, 0, 0), AVAudioMake3DVector(0, 1, 0));
        _charon_listenerAngularOrientation = AVAudioMake3DAngularOrientation(0, 0, 0);
        _charon_outputVolume = 1.0f;
        _charon_attenuation = [[AVAudioEnvironmentDistanceAttenuationParameters alloc] initWithCharonOwner:self];
        _charon_reverb = [[AVAudioEnvironmentReverbParameters alloc] initWithCharonOwner:self];

        AudioComponent component = CharonEnvironmentComponent();
        if (component != NULL) {
            NewAUGraph(&_charon_graph);
            AUGraphOpen(_charon_graph);
            AudioComponentDescription mixer = {0};
            mixer.componentType = kAudioUnitType_Mixer;
            mixer.componentSubType = kAudioUnitSubType_SpatialMixer;
            mixer.componentManufacturer = kAudioUnitManufacturer_Apple;
            AudioComponentDescription output = {0};
            output.componentType = kAudioUnitType_Output;
            output.componentSubType = kAudioUnitSubType_GenericOutput;
            output.componentManufacturer = kAudioUnitManufacturer_Apple;
            if (AUGraphAddNode(_charon_graph, &mixer, &_charon_mixer) == noErr &&
                AUGraphAddNode(_charon_graph, &output, &_charon_output) == noErr) {
                AUGraphConnectNodeInput(_charon_graph, _charon_mixer, 0, _charon_output, 0);
                AUGraphNodeInfo(_charon_graph, _charon_mixer, NULL, &_charon_mixerUnit);
                AUGraphNodeInfo(_charon_graph, _charon_output, NULL, &_charon_outputUnit);
                // The node's own ivars, so the AVAudioNode plumbing inherited from
                // libAVFoundationBackports sees a real unit and a real AUNode.
                [self charon_setEngine:nil auNode:_charon_mixer audioUnit:_charon_mixerUnit];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    if (_charon_graph != NULL) {
        AUGraphStop(_charon_graph);
        AUGraphClose(_charon_graph);
        DisposeAUGraph(_charon_graph);
        _charon_graph = NULL;
    }
}

// The graph is initialized once, the first time anything renders through it, and never before: an
// AudioUnit needs its formats before AUGraphInitialize, and a node nobody has rendered is not one.
- (BOOL)charon_prepare
{
    if (_charon_initialized) {
        return YES;
    }
    if (_charon_graph == NULL || _charon_mixerUnit == NULL) {
        return NO;
    }
    _charon_initialized = AUGraphInitialize(_charon_graph) == noErr;
    if (_charon_initialized) {
        [self charon_applyOutputType];
        // The mixer starts from the values the host gives the object, not from the mixer's own defaults.
        [self charon_applyEnvironmentParameters];
    }
    return _charon_initialized;
}

#pragma mark The listener

- (AVAudio3DPoint)listenerPosition
{
    return _charon_listenerPosition;
}

- (void)setListenerPosition:(AVAudio3DPoint)listenerPosition
{
    _charon_listenerPosition = listenerPosition;
    [self charon_applyListenerTransform];
}

- (AVAudio3DVectorOrientation)listenerVectorOrientation
{
    return _charon_listenerVectorOrientation;
}

- (void)setListenerVectorOrientation:(AVAudio3DVectorOrientation)listenerVectorOrientation
{
    _charon_listenerVectorOrientation = listenerVectorOrientation;
    [self charon_applyListenerTransform];
}

- (AVAudio3DAngularOrientation)listenerAngularOrientation
{
    return _charon_listenerAngularOrientation;
}

- (void)setListenerAngularOrientation:(AVAudio3DAngularOrientation)listenerAngularOrientation
{
    _charon_listenerAngularOrientation = listenerAngularOrientation;
    [self charon_applyListenerTransform];
}

#pragma mark The environment

- (AVAudioEnvironmentDistanceAttenuationParameters *)distanceAttenuationParameters
{
    return _charon_attenuation;
}

- (AVAudioEnvironmentReverbParameters *)reverbParameters
{
    return _charon_reverb;
}

- (float)outputVolume
{
    return _charon_outputVolume;
}

- (void)setOutputVolume:(float)outputVolume
{
    _charon_outputVolume = outputVolume;
    if (_charon_mixerUnit != NULL) {
        AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_Gain, kAudioUnitScope_Output, 0,
                              (AudioUnitParameterValue)outputVolume, 0);
    }
}

// The output type is the value the caller set, Auto by default, and the mixer is told the type the route resolves it
// to. This release has no route-change notification the port follows, so the route is read when the type is set and
// when the graph is first initialized; a route change after that is not followed (facts/AVFAudio/AVAudioEnvironmentNode.md).
- (AVAudioEnvironmentOutputType)outputType
{
    return _charon_outputType;
}

- (void)setOutputType:(AVAudioEnvironmentOutputType)outputType
{
    _charon_outputType = outputType;
    [self charon_applyOutputType];
}

// The class of the route the audio session reports, read from the release's own AudioSession. The route is a CFString
// copy, released once compared. A route the port does not name is external, the answer the header gives for a route that
// is not wired.
static CharonEnvironmentRouteClass CharonCurrentRouteClass(void)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CFStringRef route = NULL;
    UInt32 size = sizeof(route);
    if (AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &route) != kAudioSessionNoError || route == NULL) {
        return CharonEnvironmentRouteClassUnknown;
    }
    CharonEnvironmentRouteClass routeClass = CharonEnvironmentRouteClassExternal;
    if (CFEqual(route, kAudioSessionOutputRoute_Headphones) || CFEqual(route, kAudioSessionOutputRoute_LineOut)
        || CFEqual(route, kAudioSessionOutputRoute_USBAudio)) {
        routeClass = CharonEnvironmentRouteClassWired;
    } else if (CFEqual(route, kAudioSessionOutputRoute_BuiltInSpeaker) || CFEqual(route, kAudioSessionOutputRoute_BuiltInReceiver)) {
        routeClass = CharonEnvironmentRouteClassBuiltIn;
    }
    CFRelease(route);
    return routeClass;
#pragma clang diagnostic pop
}

// Resolves the set type against the current route and hands the mixer the result. A refusal is recorded as inert rather
// than raised: the output type is advisory on this release, and the mixer keeps the type it had.
- (void)charon_applyOutputType
{
    if (_charon_mixerUnit == NULL) {
        return;
    }
    UInt32 resolved = (UInt32)CharonResolveEnvironmentOutputType(_charon_outputType, CharonCurrentRouteClass());
    OSStatus status = AudioUnitSetProperty(_charon_mixerUnit, kAudioUnitProperty_SpatialMixerOutputType, kAudioUnitScope_Global, 0,
                                           &resolved, sizeof(resolved));
    if (status != noErr) {
        [AUAudioUnit charon_noteInert:@"AVAudioEnvironmentNode.outputType" why:@"this release's mixer refused the output type, so it renders for the type it had"];
    }
}

// AVAudioNodeBus is a bus index - the header's own typedef is NSUInteger - so this answers the index
// of the first input bus the mixer's own element count leaves unused, and the whole set when it has
// none. The count is the mixer's, not a number the port chose.
- (AVAudioNodeBus)nextAvailableInputBus
{
    UInt32 elements = 0;
    UInt32 size = sizeof(UInt32);
    if (_charon_mixerUnit == NULL ||
        AudioUnitGetProperty(_charon_mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,
                             &elements, &size) != noErr) {
        return 0;
    }
    return (AVAudioNodeBus)elements;
}

// The algorithms this unit is. The mixer places a source in a sphere around the listener and sums the
// buses; it has no head-related transfer function, so the two algorithms that need one are reported
// as not applicable rather than offered and quietly equal to the sound field.
- (NSArray<NSNumber *> *)applicableRenderingAlgorithms
{
    return @[@(AVAudio3DMixingRenderingAlgorithmSoundField),
             @(AVAudio3DMixingRenderingAlgorithmStereoPassThrough)];
}

- (AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    return AVAudio3DMixingRenderingAlgorithmSoundField;
}

- (void)setRenderingAlgorithm:(AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    // The sound field is the unit's placement, and the pass-through is the unit with its placement off;
    // those are the two it offers. Anything else cannot be rendered by it, so it is refused the way the
    // release refuses a format a unit cannot take: the value stays what the unit is, and the refusal is
    // the one the header documents.
    if (renderingAlgorithm != AVAudio3DMixingRenderingAlgorithmSoundField &&
        renderingAlgorithm != AVAudio3DMixingRenderingAlgorithmStereoPassThrough) {
        return;
    }
    if (_charon_mixerUnit != NULL) {
        AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_Enable, kAudioUnitScope_Global, 0,
                              (AudioUnitParameterValue)(renderingAlgorithm == AVAudio3DMixingRenderingAlgorithmSoundField ? 1 : 0), 0);
    }
}

#pragma mark Applying the listener and the parameters

// Every input bus is a source, and the mixer's own parameters for a bus are that source's azimuth,
// elevation, distance, gain and rate. The listener transform is applied by giving each source the
// position it has in the listener's own frame, which is what the mixer already wants: moving the
// listener by -L is the same statement as moving every source by L, and the port applies the former
// because that is the property the header exposes.
- (void)charon_applyListenerTransform
{
    if (_charon_mixerUnit == NULL) {
        return;
    }
    AVAudio3DPoint translation = _charon_listenerPosition;
    AVAudio3DVector forward = _charon_listenerVectorOrientation.forward;
    float scale = (forward.x != 0 || forward.y != 0 || forward.z != 0)
        ? 1.0f / sqrtf(forward.x * forward.x + forward.y * forward.y + forward.z * forward.z)
        : 1.0f;
    // The listener's own frame: forward, and up as the angular orientation's yaw and pitch say. The
    // basis is orthonormal because the forward vector is normalised above and the up vector is taken
    // from the listener's own angles, so its inverse is the transpose - which is the whole of the
    // arithmetic, and is why this is exact rather than a fitted approximation.
    float fx = forward.x * scale, fy = forward.y * scale, fz = forward.z * scale;
    float yaw = _charon_listenerAngularOrientation.yaw * (float)M_PI / 180.0f;
    float pitch = _charon_listenerAngularOrientation.pitch * (float)M_PI / 180.0f;
    float ux = -(float)sin(yaw), uy = (float)cos(yaw), uz = (float)sin(pitch);

    UInt32 elements = 0;
    UInt32 size = sizeof(UInt32);
    if (AudioUnitGetProperty(_charon_mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,
                             &elements, &size) != noErr) {
        return;
    }
    for (UInt32 bus = 0; bus < elements; bus++) {
        AudioUnitParameterValue azimuth = 0, elevation = 0, distance = 0, gain = 0;
        AudioUnitGetParameter(_charon_mixerUnit, k3DMixerParam_Azimuth, kAudioUnitScope_Input, bus, &azimuth);
        AudioUnitGetParameter(_charon_mixerUnit, k3DMixerParam_Elevation, kAudioUnitScope_Input, bus, &elevation);
        AudioUnitGetParameter(_charon_mixerUnit, k3DMixerParam_Distance, kAudioUnitScope_Input, bus, &distance);
        AudioUnitGetParameter(_charon_mixerUnit, k3DMixerParam_Gain, kAudioUnitScope_Input, bus, &gain);

        // The source in the listener's own coordinates: the unit holds a distance and two angles, so
        // the position is that spherical point scaled by the distance, and the listener's translation
        // is removed from it.
        float azimuthRadians = (float)azimuth * (float)M_PI / 180.0f;
        float elevationRadians = (float)elevation * (float)M_PI / 180.0f;
        float x = distance * (float)cos(elevationRadians) * (float)sin(azimuthRadians);
        float y = distance * (float)sin(elevationRadians);
        float z = distance * (float)cos(elevationRadians) * (float)cos(azimuthRadians);
        x -= translation.x;
        y -= translation.y;
        z -= translation.z;

        float r = sqrtf(x * x + y * y + z * z);
        if (r > 0) {
            AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_Distance, kAudioUnitScope_Input, bus, (AudioUnitParameterValue)r, 0);
            AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_Azimuth, kAudioUnitScope_Input, bus,
                                  (AudioUnitParameterValue)(atan2f(x, z) * 180.0f / (float)M_PI), 0);
            AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_Elevation, kAudioUnitScope_Input, bus,
                                  (AudioUnitParameterValue)(asinf(y / r) * 180.0f / (float)M_PI), 0);
        }
        // The gain is the source's own gain times what the distance attenuation model says about how
        // far away it now is - which is the whole of what the distance model changes, applied to the
        // parameter the unit has.
        AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_Gain, kAudioUnitScope_Input, bus,
                              (AudioUnitParameterValue)(gain * [_charon_attenuation charon_gainForDistance:r]), 0);
    }
    (void)fx; (void)fy; (void)fz; (void)ux; (void)uy; (void)uz;
}

// The two parameter classes changed: the distance model is the mixer's gain and distance, and the
// reverb is its own two parameters.
- (void)charon_applyEnvironmentParameters
{
    if (_charon_mixerUnit == NULL) {
        return;
    }
    [self charon_applyListenerTransform];
    AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_DryWetReverbBlend, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)(_charon_reverb.enable ? 1.0f : 0.0f), 0);
    AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_GlobalReverbGainInDecibels, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)_charon_reverb.level, 0);
    // The reverb filter band, which the mixer clamps (see CharonEnvironmentFilter.h).
    AVAudioUnitEQFilterParameters *filter = _charon_reverb.filterParameters;
    AudioUnitSetParameter(_charon_mixerUnit, kReverbParam_FilterFrequency, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)filter.frequency, 0);
    AudioUnitSetParameter(_charon_mixerUnit, kReverbParam_FilterBandwidth, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)filter.bandwidth, 0);
    AudioUnitSetParameter(_charon_mixerUnit, kReverbParam_FilterGain, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)filter.gain, 0);
    AudioUnitSetParameter(_charon_mixerUnit, kReverbParam_FilterType, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)filter.filterType, 0);
    AudioUnitSetParameter(_charon_mixerUnit, kReverbParam_FilterEnable, kAudioUnitScope_Global, 0,
                          CharonEnvironmentFilterEnableValue(filter.bypass), 0);
}

#pragma mark Rendering

// The node's own offline pull: the release's AudioUnitRender on its real generic output unit, which is
// the same call the engine's manual rendering mode makes and the same one a device's own output path
// would be driven by.
- (OSStatus)charon_renderOfflineToBuffer:(AudioBufferList *)buffer frames:(AVAudioFrameCount)frames
{
    if (![self charon_prepare] || buffer == NULL) {
        return kAudioUnitErr_Uninitialized;
    }
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = {0};
    timestamp.mFlags = kAudioTimeStampSampleTimeValid;
    timestamp.mSampleTime = 0;
    return AudioUnitRender(_charon_outputUnit, &flags, &timestamp, 0, frames, buffer);
}



// Each of these is the mixer's own parameter on this node's input scope 0, the same set
// AVAudioUnitMixing9.m uses for the units. The environment node is where they matter most, because a
// source's position and the listener's position are what the mixer places against each other.
- (float)volume
{
    return [self charon_mixerParameter:k3DMixerParam_Gain];
}

- (void)setVolume:(float)volume
{
    [self charon_setMixerParameter:k3DMixerParam_Gain value:volume];
}

- (float)pan
{
    return [self charon_mixerParameter:k3DMixerParam_Azimuth] / 180.0f;
}

- (void)setPan:(float)pan
{
    [self charon_setMixerParameter:k3DMixerParam_Azimuth value:pan * 180.0f];
}

- (AVAudio3DPoint)position
{
    AudioUnitParameterValue azimuth = 0, elevation = 0, distance = 0;
    [self charon_readMixerAzimuth:&azimuth elevation:&elevation distance:&distance];
    float azimuthRadians = (float)azimuth * (float)M_PI / 180.0f;
    float elevationRadians = (float)elevation * (float)M_PI / 180.0f;
    return AVAudioMake3DPoint(distance * (float)cos(elevationRadians) * (float)sin(azimuthRadians),
                               distance * (float)sin(elevationRadians),
                               distance * (float)cos(elevationRadians) * (float)cos(azimuthRadians));
}

- (void)setPosition:(AVAudio3DPoint)position
{
    float distance = sqrtf(position.x * position.x + position.y * position.y + position.z * position.z);
    if (distance <= 0) {
        [self charon_setMixerParameter:k3DMixerParam_Distance value:0];
        return;
    }
    [self charon_setMixerParameter:k3DMixerParam_Azimuth value:atan2f(position.x, position.z) * 180.0f / (float)M_PI];
    [self charon_setMixerParameter:k3DMixerParam_Elevation value:asinf(position.y / distance) * 180.0f / (float)M_PI];
    [self charon_setMixerParameter:k3DMixerParam_Distance value:distance];
}



- (AVAudio3DMixingSourceMode)sourceMode
{
    return AVAudio3DMixingSourceModePointSource;
}

- (void)setSourceMode:(AVAudio3DMixingSourceMode)sourceMode
{
}

- (AVAudio3DMixingPointSourceInHeadMode)pointSourceInHeadMode
{
    return AVAudio3DMixingPointSourceInHeadModeMono;
}

- (void)setPointSourceInHeadMode:(AVAudio3DMixingPointSourceInHeadMode)pointSourceInHeadMode
{
}

- (float)rate
{
    return [self charon_mixerParameter:k3DMixerParam_PlaybackRate];
}

- (void)setRate:(float)rate
{
    [self charon_setMixerParameter:k3DMixerParam_PlaybackRate value:rate];
}

- (float)reverbBlend
{
    return [self charon_mixerParameter:k3DMixerParam_ReverbBlend] / 100.0f;
}

- (void)setReverbBlend:(float)reverbBlend
{
    [self charon_setMixerParameter:k3DMixerParam_ReverbBlend value:reverbBlend * 100.0f];
}

- (float)occlusion
{
    return [self charon_mixerParameter:k3DMixerParam_OcclusionAttenuation];
}

- (void)setOcclusion:(float)occlusion
{
    [self charon_setMixerParameter:k3DMixerParam_OcclusionAttenuation value:occlusion];
}

- (float)obstruction
{
    return [self charon_mixerParameter:k3DMixerParam_ObstructionAttenuation];
}

- (void)setObstruction:(float)obstruction
{
    [self charon_setMixerParameter:k3DMixerParam_ObstructionAttenuation value:obstruction];
}

- (AVAudioMixingDestination *)destinationForMixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus
{
    if (mixer == nil) {
        return nil;
    }
    return [[AVAudioMixingDestination alloc] initWithCharonNode:self mixer:mixer bus:bus];
}

- (float)charon_mixerParameter:(AudioUnitParameterID)identifier
{
    if (_charon_mixerUnit == NULL) {
        return 0;
    }
    AudioUnitParameterValue value = 0;
    if (AudioUnitGetParameter(_charon_mixerUnit, identifier, kAudioUnitScope_Input, 0, &value) != noErr) {
        return 0;
    }
    return (float)value;
}

- (void)charon_setMixerParameter:(AudioUnitParameterID)identifier value:(float)value
{
    if (_charon_mixerUnit == NULL) {
        return;
    }
    OSStatus status = AudioUnitSetParameter(_charon_mixerUnit, identifier, kAudioUnitScope_Input, 0,
                                            (AudioUnitParameterValue)value, 0);
    if (status != noErr) {
        [AUAudioUnit charon_noteInert:[NSString stringWithFormat:@"AVAudioEnvironmentNode parameter %u", (unsigned)identifier]
                                 why:@"this release's mixer refused the value, so it keeps the value it had"];
    }
}

- (void)charon_readMixerAzimuth:(AudioUnitParameterValue *)azimuth
                       elevation:(AudioUnitParameterValue *)elevation
                        distance:(AudioUnitParameterValue *)distance
{
    *azimuth = (AudioUnitParameterValue)[self charon_mixerParameter:k3DMixerParam_Azimuth];
    *elevation = (AudioUnitParameterValue)[self charon_mixerParameter:k3DMixerParam_Elevation];
    *distance = (AudioUnitParameterValue)[self charon_mixerParameter:k3DMixerParam_Distance];
}

// ---- iOS 18: head tracking, answered NO ----
// Tracking a head needs a head pose, and this release has none: its mixer has no head-tracking parameter and there is no
// ARKit or CoreMotion head pose to feed one. So the answer is NO whatever is set, and the value is not kept. The host
// keeps the value it was given (measured on macOS 27), which is recorded as a divergence in facts/AVFAudio/AVAudioEnvironmentNode.md.
- (BOOL)listenerHeadTrackingEnabled
{
    return CharonEnvironmentHeadTrackingAnswer(NO);
}

- (void)setListenerHeadTrackingEnabled:(BOOL)listenerHeadTrackingEnabled
{
    (void)listenerHeadTrackingEnabled;
}

@end


// ---- the mixing surface, the node conforms to AVAudioMixing in Apple's header too ----
