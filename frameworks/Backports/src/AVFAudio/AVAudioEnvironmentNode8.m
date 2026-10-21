#import "RevenantAVFAudio.h"
#import <AVFAudio/AVAudioEnvironmentNode.h>
#import <AudioToolbox/AUComponent.h>
#import <AudioToolbox/AudioUnitParameters.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioToolbox/AudioSession.h>
#import "RevenantEnvironmentOutput.h"
#import "RevenantEnvironmentFilter.h"

static AudioComponent RevenantEnvironmentComponent(void)
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
    __weak AVAudioEnvironmentNode *_revenant_owner;
    AVAudioEnvironmentDistanceAttenuationModel _revenant_model;
    float _revenant_referenceDistance;
    float _revenant_maximumDistance;
    float _revenant_rolloffFactor;
}

- (instancetype)initWithRevenantOwner:(AVAudioEnvironmentNode *)owner
{
    if ((self = [super init])) {
        _revenant_owner = owner;
        _revenant_model = AVAudioEnvironmentDistanceAttenuationModelInverse;
        _revenant_referenceDistance = 1.0f;
        _revenant_maximumDistance = 100000.0f;
        _revenant_rolloffFactor = 1.0f;
    }
    return self;
}

- (AVAudioEnvironmentDistanceAttenuationModel)distanceAttenuationModel
{
    return _revenant_model;
}

- (void)setDistanceAttenuationModel:(AVAudioEnvironmentDistanceAttenuationModel)distanceAttenuationModel
{
    _revenant_model = distanceAttenuationModel;
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (float)referenceDistance
{
    return _revenant_referenceDistance;
}

- (void)setReferenceDistance:(float)referenceDistance
{
    _revenant_referenceDistance = referenceDistance;
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (float)maximumDistance
{
    return _revenant_maximumDistance;
}

- (void)setMaximumDistance:(float)maximumDistance
{
    _revenant_maximumDistance = maximumDistance;
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (float)rolloffFactor
{
    return _revenant_rolloffFactor;
}

- (void)setRolloffFactor:(float)rolloffFactor
{
    _revenant_rolloffFactor = rolloffFactor;
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (float)revenant_gainForDistance:(float)distance
{
    float reference = _revenant_referenceDistance > 0 ? _revenant_referenceDistance : 1.0f;
    float rolloff = _revenant_rolloffFactor > 0 ? _revenant_rolloffFactor : 1.0f;
    switch (_revenant_model) {
        case AVAudioEnvironmentDistanceAttenuationModelInverse:
            return reference / (reference + rolloff * (distance - reference));
        case AVAudioEnvironmentDistanceAttenuationModelExponential:
            return (float)exp(-rolloff * (distance - reference));
        case AVAudioEnvironmentDistanceAttenuationModelLinear: {
            if (distance <= reference) {
                return 1.0f;
            }
            if (distance >= _revenant_maximumDistance) {
                return 0.0f;
            }
            float span = _revenant_maximumDistance - reference;
            return span > 0 ? (float)(1.0 - rolloff * (distance - reference) / span) : 0.0f;
        }
    }
    return 1.0f;
}

@end

@class AVAudioUnitEQ;
@interface AVAudioUnitEQFilterParameters (RevenantEnvironment)
- (instancetype)initForRevenantEQ:(AVAudioUnitEQ *)eq bandIndex:(NSUInteger)bandIndex;
@end

@interface RevenantEnvironmentFilterParameters : AVAudioUnitEQFilterParameters
- (instancetype)initWithRevenantOwner:(AVAudioEnvironmentNode *)owner;
@end

@implementation RevenantEnvironmentFilterParameters {
    __weak AVAudioEnvironmentNode *_revenant_owner;
}

- (instancetype)initWithRevenantOwner:(AVAudioEnvironmentNode *)owner
{
    if ((self = [super initForRevenantEQ:nil bandIndex:0])) {
        _revenant_owner = owner;
        self.frequency = RevenantEnvironmentFilterDefaultFrequency;
        self.bandwidth = RevenantEnvironmentFilterDefaultBandwidth;
        self.gain = RevenantEnvironmentFilterDefaultGain;
        self.filterType = AVAudioUnitEQFilterTypeParametric;
        self.bypass = NO;
    }
    return self;
}

- (void)setFilterType:(AVAudioUnitEQFilterType)filterType
{
    [super setFilterType:filterType];
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (void)setFrequency:(float)frequency
{
    [super setFrequency:frequency];
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (void)setBandwidth:(float)bandwidth
{
    [super setBandwidth:bandwidth];
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (void)setGain:(float)gain
{
    [super setGain:gain];
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (void)setBypass:(BOOL)bypass
{
    [super setBypass:bypass];
    [_revenant_owner revenant_applyEnvironmentParameters];
}

@end

@implementation AVAudioEnvironmentReverbParameters {
    __weak AVAudioEnvironmentNode *_revenant_owner;
    float _revenant_level;
    BOOL _revenant_enable;
    RevenantEnvironmentFilterParameters *_revenant_filter;
}

- (instancetype)initWithRevenantOwner:(AVAudioEnvironmentNode *)owner
{
    if ((self = [super init])) {
        _revenant_owner = owner;
        _revenant_filter = [[RevenantEnvironmentFilterParameters alloc] initWithRevenantOwner:owner];
    }
    return self;
}

- (AVAudioUnitEQFilterParameters *)filterParameters
{
    return _revenant_filter;
}

- (BOOL)enable
{
    return _revenant_enable;
}

- (void)setEnable:(BOOL)enable
{
    _revenant_enable = enable;
    [_revenant_owner revenant_applyEnvironmentParameters];
}

- (float)level
{
    return _revenant_level;
}

- (void)setLevel:(float)level
{
    _revenant_level = level;
    [_revenant_owner revenant_applyEnvironmentParameters];
}

@end

@implementation AVAudioEnvironmentNode {
    AUGraph _revenant_graph;
    AUNode _revenant_mixer;
    AudioUnit _revenant_mixerUnit;
    AUNode _revenant_output;
    AudioUnit _revenant_outputUnit;
    BOOL _revenant_initialized;
    AVAudio3DPoint _revenant_listenerPosition;
    AVAudio3DVectorOrientation _revenant_listenerVectorOrientation;
    AVAudio3DAngularOrientation _revenant_listenerAngularOrientation;
    float _revenant_outputVolume;
    AVAudioEnvironmentDistanceAttenuationParameters *_revenant_attenuation;
    AVAudioEnvironmentReverbParameters *_revenant_reverb;
    AVAudioEnvironmentOutputType _revenant_outputType;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _revenant_listenerPosition = AVAudioMake3DPoint(0, 0, 0);
        _revenant_listenerVectorOrientation = AVAudioMake3DVectorOrientation(AVAudioMake3DVector(1, 0, 0), AVAudioMake3DVector(0, 1, 0));
        _revenant_listenerAngularOrientation = AVAudioMake3DAngularOrientation(0, 0, 0);
        _revenant_outputVolume = 1.0f;
        _revenant_attenuation = [[AVAudioEnvironmentDistanceAttenuationParameters alloc] initWithRevenantOwner:self];
        _revenant_reverb = [[AVAudioEnvironmentReverbParameters alloc] initWithRevenantOwner:self];

        AudioComponent component = RevenantEnvironmentComponent();
        if (component != NULL) {
            NewAUGraph(&_revenant_graph);
            AUGraphOpen(_revenant_graph);
            AudioComponentDescription mixer = {0};
            mixer.componentType = kAudioUnitType_Mixer;
            mixer.componentSubType = kAudioUnitSubType_SpatialMixer;
            mixer.componentManufacturer = kAudioUnitManufacturer_Apple;
            AudioComponentDescription output = {0};
            output.componentType = kAudioUnitType_Output;
            output.componentSubType = kAudioUnitSubType_GenericOutput;
            output.componentManufacturer = kAudioUnitManufacturer_Apple;
            if (AUGraphAddNode(_revenant_graph, &mixer, &_revenant_mixer) == noErr &&
                AUGraphAddNode(_revenant_graph, &output, &_revenant_output) == noErr) {
                AUGraphConnectNodeInput(_revenant_graph, _revenant_mixer, 0, _revenant_output, 0);
                AUGraphNodeInfo(_revenant_graph, _revenant_mixer, NULL, &_revenant_mixerUnit);
                AUGraphNodeInfo(_revenant_graph, _revenant_output, NULL, &_revenant_outputUnit);
                [self revenant_setEngine:nil auNode:_revenant_mixer audioUnit:_revenant_mixerUnit];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    if (_revenant_graph != NULL) {
        AUGraphStop(_revenant_graph);
        AUGraphClose(_revenant_graph);
        DisposeAUGraph(_revenant_graph);
        _revenant_graph = NULL;
    }
}

- (BOOL)revenant_prepare
{
    if (_revenant_initialized) {
        return YES;
    }
    if (_revenant_graph == NULL || _revenant_mixerUnit == NULL) {
        return NO;
    }
    _revenant_initialized = AUGraphInitialize(_revenant_graph) == noErr;
    if (_revenant_initialized) {
        [self revenant_applyOutputType];
        [self revenant_applyEnvironmentParameters];
    }
    return _revenant_initialized;
}

#pragma mark The listener

- (AVAudio3DPoint)listenerPosition
{
    return _revenant_listenerPosition;
}

- (void)setListenerPosition:(AVAudio3DPoint)listenerPosition
{
    _revenant_listenerPosition = listenerPosition;
    [self revenant_applyListenerTransform];
}

- (AVAudio3DVectorOrientation)listenerVectorOrientation
{
    return _revenant_listenerVectorOrientation;
}

- (void)setListenerVectorOrientation:(AVAudio3DVectorOrientation)listenerVectorOrientation
{
    _revenant_listenerVectorOrientation = listenerVectorOrientation;
    [self revenant_applyListenerTransform];
}

- (AVAudio3DAngularOrientation)listenerAngularOrientation
{
    return _revenant_listenerAngularOrientation;
}

- (void)setListenerAngularOrientation:(AVAudio3DAngularOrientation)listenerAngularOrientation
{
    _revenant_listenerAngularOrientation = listenerAngularOrientation;
    [self revenant_applyListenerTransform];
}

#pragma mark The environment

- (AVAudioEnvironmentDistanceAttenuationParameters *)distanceAttenuationParameters
{
    return _revenant_attenuation;
}

- (AVAudioEnvironmentReverbParameters *)reverbParameters
{
    return _revenant_reverb;
}

- (float)outputVolume
{
    return _revenant_outputVolume;
}

- (void)setOutputVolume:(float)outputVolume
{
    _revenant_outputVolume = outputVolume;
    if (_revenant_mixerUnit != NULL) {
        AudioUnitSetParameter(_revenant_mixerUnit, k3DMixerParam_Gain, kAudioUnitScope_Output, 0,
                              (AudioUnitParameterValue)outputVolume, 0);
    }
}

- (AVAudioEnvironmentOutputType)outputType
{
    return _revenant_outputType;
}

- (void)setOutputType:(AVAudioEnvironmentOutputType)outputType
{
    _revenant_outputType = outputType;
    [self revenant_applyOutputType];
}

static RevenantEnvironmentRouteClass RevenantCurrentRouteClass(void)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CFStringRef route = NULL;
    UInt32 size = sizeof(route);
    if (AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &route) != kAudioSessionNoError || route == NULL) {
        return RevenantEnvironmentRouteClassUnknown;
    }
    RevenantEnvironmentRouteClass routeClass = RevenantEnvironmentRouteClassExternal;
    if (CFEqual(route, kAudioSessionOutputRoute_Headphones) || CFEqual(route, kAudioSessionOutputRoute_LineOut)
        || CFEqual(route, kAudioSessionOutputRoute_USBAudio)) {
        routeClass = RevenantEnvironmentRouteClassWired;
    } else if (CFEqual(route, kAudioSessionOutputRoute_BuiltInSpeaker) || CFEqual(route, kAudioSessionOutputRoute_BuiltInReceiver)) {
        routeClass = RevenantEnvironmentRouteClassBuiltIn;
    }
    CFRelease(route);
    return routeClass;
#pragma clang diagnostic pop
}

- (void)revenant_applyOutputType
{
    if (_revenant_mixerUnit == NULL) {
        return;
    }
    UInt32 resolved = (UInt32)RevenantResolveEnvironmentOutputType(_revenant_outputType, RevenantCurrentRouteClass());
    OSStatus status = AudioUnitSetProperty(_revenant_mixerUnit, kAudioUnitProperty_SpatialMixerOutputType, kAudioUnitScope_Global, 0,
                                           &resolved, sizeof(resolved));
    if (status != noErr) {
        [AUAudioUnit revenant_noteInert:@"AVAudioEnvironmentNode.outputType" why:@"this release's mixer refused the output type, so it renders for the type it had"];
    }
}

- (AVAudioNodeBus)nextAvailableInputBus
{
    UInt32 elements = 0;
    UInt32 size = sizeof(UInt32);
    if (_revenant_mixerUnit == NULL ||
        AudioUnitGetProperty(_revenant_mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,
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
    if (_revenant_mixerUnit != NULL) {
        AudioUnitSetParameter(_revenant_mixerUnit, k3DMixerParam_Enable, kAudioUnitScope_Global, 0,
                              (AudioUnitParameterValue)(renderingAlgorithm == AVAudio3DMixingRenderingAlgorithmSoundField ? 1 : 0), 0);
    }
}

#pragma mark Applying the listener and the parameters

- (void)revenant_applyListenerTransform
{
    if (_revenant_mixerUnit == NULL) {
        return;
    }
    AVAudio3DPoint translation = _revenant_listenerPosition;
    AVAudio3DVector forward = _revenant_listenerVectorOrientation.forward;
    float scale = (forward.x != 0 || forward.y != 0 || forward.z != 0)
        ? 1.0f / sqrtf(forward.x * forward.x + forward.y * forward.y + forward.z * forward.z)
        : 1.0f;
    float fx = forward.x * scale, fy = forward.y * scale, fz = forward.z * scale;
    float yaw = _revenant_listenerAngularOrientation.yaw * (float)M_PI / 180.0f;
    float pitch = _revenant_listenerAngularOrientation.pitch * (float)M_PI / 180.0f;
    float ux = -(float)sin(yaw), uy = (float)cos(yaw), uz = (float)sin(pitch);

    UInt32 elements = 0;
    UInt32 size = sizeof(UInt32);
    if (AudioUnitGetProperty(_revenant_mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,
                             &elements, &size) != noErr) {
        return;
    }
    for (UInt32 bus = 0; bus < elements; bus++) {
        AudioUnitParameterValue azimuth = 0, elevation = 0, distance = 0, gain = 0;
        AudioUnitGetParameter(_revenant_mixerUnit, k3DMixerParam_Azimuth, kAudioUnitScope_Input, bus, &azimuth);
        AudioUnitGetParameter(_revenant_mixerUnit, k3DMixerParam_Elevation, kAudioUnitScope_Input, bus, &elevation);
        AudioUnitGetParameter(_revenant_mixerUnit, k3DMixerParam_Distance, kAudioUnitScope_Input, bus, &distance);
        AudioUnitGetParameter(_revenant_mixerUnit, k3DMixerParam_Gain, kAudioUnitScope_Input, bus, &gain);

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
            AudioUnitSetParameter(_revenant_mixerUnit, k3DMixerParam_Distance, kAudioUnitScope_Input, bus, (AudioUnitParameterValue)r, 0);
            AudioUnitSetParameter(_revenant_mixerUnit, k3DMixerParam_Azimuth, kAudioUnitScope_Input, bus,
                                  (AudioUnitParameterValue)(atan2f(x, z) * 180.0f / (float)M_PI), 0);
            AudioUnitSetParameter(_revenant_mixerUnit, k3DMixerParam_Elevation, kAudioUnitScope_Input, bus,
                                  (AudioUnitParameterValue)(asinf(y / r) * 180.0f / (float)M_PI), 0);
        }
        AudioUnitSetParameter(_revenant_mixerUnit, k3DMixerParam_Gain, kAudioUnitScope_Input, bus,
                              (AudioUnitParameterValue)(gain * [_revenant_attenuation revenant_gainForDistance:r]), 0);
    }
    (void)fx; (void)fy; (void)fz; (void)ux; (void)uy; (void)uz;
}

- (void)revenant_applyEnvironmentParameters
{
    if (_revenant_mixerUnit == NULL) {
        return;
    }
    [self revenant_applyListenerTransform];
    AudioUnitSetParameter(_revenant_mixerUnit, k3DMixerParam_DryWetReverbBlend, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)(_revenant_reverb.enable ? 1.0f : 0.0f), 0);
    AudioUnitSetParameter(_revenant_mixerUnit, k3DMixerParam_GlobalReverbGainInDecibels, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)_revenant_reverb.level, 0);
    AVAudioUnitEQFilterParameters *filter = _revenant_reverb.filterParameters;
    AudioUnitSetParameter(_revenant_mixerUnit, kReverbParam_FilterFrequency, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)filter.frequency, 0);
    AudioUnitSetParameter(_revenant_mixerUnit, kReverbParam_FilterBandwidth, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)filter.bandwidth, 0);
    AudioUnitSetParameter(_revenant_mixerUnit, kReverbParam_FilterGain, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)filter.gain, 0);
    AudioUnitSetParameter(_revenant_mixerUnit, kReverbParam_FilterType, kAudioUnitScope_Global, 0,
                          (AudioUnitParameterValue)filter.filterType, 0);
    AudioUnitSetParameter(_revenant_mixerUnit, kReverbParam_FilterEnable, kAudioUnitScope_Global, 0,
                          RevenantEnvironmentFilterEnableValue(filter.bypass), 0);
}

#pragma mark Rendering

- (OSStatus)revenant_renderOfflineToBuffer:(AudioBufferList *)buffer frames:(AVAudioFrameCount)frames
{
    if (![self revenant_prepare] || buffer == NULL) {
        return kAudioUnitErr_Uninitialized;
    }
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = {0};
    timestamp.mFlags = kAudioTimeStampSampleTimeValid;
    timestamp.mSampleTime = 0;
    return AudioUnitRender(_revenant_outputUnit, &flags, &timestamp, 0, frames, buffer);
}

- (float)volume
{
    return [self revenant_mixerParameter:k3DMixerParam_Gain];
}

- (void)setVolume:(float)volume
{
    [self revenant_setMixerParameter:k3DMixerParam_Gain value:volume];
}

- (float)pan
{
    return [self revenant_mixerParameter:k3DMixerParam_Azimuth] / 180.0f;
}

- (void)setPan:(float)pan
{
    [self revenant_setMixerParameter:k3DMixerParam_Azimuth value:pan * 180.0f];
}

- (AVAudio3DPoint)position
{
    AudioUnitParameterValue azimuth = 0, elevation = 0, distance = 0;
    [self revenant_readMixerAzimuth:&azimuth elevation:&elevation distance:&distance];
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
        [self revenant_setMixerParameter:k3DMixerParam_Distance value:0];
        return;
    }
    [self revenant_setMixerParameter:k3DMixerParam_Azimuth value:atan2f(position.x, position.z) * 180.0f / (float)M_PI];
    [self revenant_setMixerParameter:k3DMixerParam_Elevation value:asinf(position.y / distance) * 180.0f / (float)M_PI];
    [self revenant_setMixerParameter:k3DMixerParam_Distance value:distance];
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
    return [self revenant_mixerParameter:k3DMixerParam_PlaybackRate];
}

- (void)setRate:(float)rate
{
    [self revenant_setMixerParameter:k3DMixerParam_PlaybackRate value:rate];
}

- (float)reverbBlend
{
    return [self revenant_mixerParameter:k3DMixerParam_ReverbBlend] / 100.0f;
}

- (void)setReverbBlend:(float)reverbBlend
{
    [self revenant_setMixerParameter:k3DMixerParam_ReverbBlend value:reverbBlend * 100.0f];
}

- (float)occlusion
{
    return [self revenant_mixerParameter:k3DMixerParam_OcclusionAttenuation];
}

- (void)setOcclusion:(float)occlusion
{
    [self revenant_setMixerParameter:k3DMixerParam_OcclusionAttenuation value:occlusion];
}

- (float)obstruction
{
    return [self revenant_mixerParameter:k3DMixerParam_ObstructionAttenuation];
}

- (void)setObstruction:(float)obstruction
{
    [self revenant_setMixerParameter:k3DMixerParam_ObstructionAttenuation value:obstruction];
}

- (AVAudioMixingDestination *)destinationForMixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus
{
    if (mixer == nil) {
        return nil;
    }
    return [[AVAudioMixingDestination alloc] initWithRevenantNode:self mixer:mixer bus:bus];
}

- (float)revenant_mixerParameter:(AudioUnitParameterID)identifier
{
    if (_revenant_mixerUnit == NULL) {
        return 0;
    }
    AudioUnitParameterValue value = 0;
    if (AudioUnitGetParameter(_revenant_mixerUnit, identifier, kAudioUnitScope_Input, 0, &value) != noErr) {
        return 0;
    }
    return (float)value;
}

- (void)revenant_setMixerParameter:(AudioUnitParameterID)identifier value:(float)value
{
    if (_revenant_mixerUnit == NULL) {
        return;
    }
    OSStatus status = AudioUnitSetParameter(_revenant_mixerUnit, identifier, kAudioUnitScope_Input, 0,
                                            (AudioUnitParameterValue)value, 0);
    if (status != noErr) {
        [AUAudioUnit revenant_noteInert:[NSString stringWithFormat:@"AVAudioEnvironmentNode parameter %u", (unsigned)identifier]
                                 why:@"this release's mixer refused the value, so it keeps the value it had"];
    }
}

- (void)revenant_readMixerAzimuth:(AudioUnitParameterValue *)azimuth
                       elevation:(AudioUnitParameterValue *)elevation
                        distance:(AudioUnitParameterValue *)distance
{
    *azimuth = (AudioUnitParameterValue)[self revenant_mixerParameter:k3DMixerParam_Azimuth];
    *elevation = (AudioUnitParameterValue)[self revenant_mixerParameter:k3DMixerParam_Elevation];
    *distance = (AudioUnitParameterValue)[self revenant_mixerParameter:k3DMixerParam_Distance];
}

- (BOOL)listenerHeadTrackingEnabled
{
    return RevenantEnvironmentHeadTrackingAnswer(NO);
}

- (void)setListenerHeadTrackingEnabled:(BOOL)listenerHeadTrackingEnabled
{
    (void)listenerHeadTrackingEnabled;
}

@end
