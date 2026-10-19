#import "CharonAVFAudio.h"
#import "CharonAVFAudioNew.h"
#import <AVFAudio/AVAudioEnvironmentNode.h>
#import <AudioToolbox/AUComponent.h>
#import <AudioToolbox/AudioUnitParameters.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioToolbox/AudioSession.h>
#import "CharonEnvironmentOutput.h"
#import "CharonEnvironmentFilter.h"

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

- (AVAudioEnvironmentOutputType)outputType
{
    return _charon_outputType;
}

- (void)setOutputType:(AVAudioEnvironmentOutputType)outputType
{
    _charon_outputType = outputType;
    [self charon_applyOutputType];
}

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
        AudioUnitSetParameter(_charon_mixerUnit, k3DMixerParam_Gain, kAudioUnitScope_Input, bus,
                              (AudioUnitParameterValue)(gain * [_charon_attenuation charon_gainForDistance:r]), 0);
    }
    (void)fx; (void)fy; (void)fz; (void)ux; (void)uy; (void)uz;
}

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

- (BOOL)listenerHeadTrackingEnabled
{
    return CharonEnvironmentHeadTrackingAnswer(NO);
}

- (void)setListenerHeadTrackingEnabled:(BOOL)listenerHeadTrackingEnabled
{
    (void)listenerHeadTrackingEnabled;
}

@end
