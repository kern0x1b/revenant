#import "RevenantAVAudioUnit.h"
#import <AVFAudio/AVAudioMixing.h>
#import <AudioToolbox/AudioUnitParameters.h>

@interface AVAudioMixingDestination (RevenantImpl)
- (instancetype)initWithRevenantNode:(AVAudioNode *)node mixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus;
@end

@implementation AVAudioMixingDestination {
    __weak id<AVAudioMixing> _revenant_node;
    __weak AVAudioNode *_revenant_mixer;
    AVAudioNodeBus _revenant_bus;
}

- (instancetype)initWithRevenantNode:(AVAudioNode *)node mixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus
{
    if ((self = [super init])) {
        _revenant_node = (id<AVAudioMixing>)node;
        _revenant_mixer = mixer;
        _revenant_bus = bus;
    }
    return self;
}

- (AVAudioConnectionPoint *)connectionPoint
{
    if (_revenant_node == nil) {
        return nil;
    }
    return [[AVAudioConnectionPoint alloc] initWithNode:_revenant_mixer bus:_revenant_bus];
}

- (float)volume
{
    return _revenant_node.volume;
}

- (void)setVolume:(float)volume
{
    _revenant_node.volume = volume;
}

- (float)pan
{
    return _revenant_node.pan;
}

- (void)setPan:(float)pan
{
    _revenant_node.pan = pan;
}

- (AVAudio3DPoint)position
{
    return _revenant_node.position;
}

- (void)setPosition:(AVAudio3DPoint)position
{
    _revenant_node.position = position;
}

- (AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    return _revenant_node.renderingAlgorithm;
}

- (void)setRenderingAlgorithm:(AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    _revenant_node.renderingAlgorithm = renderingAlgorithm;
}

- (AVAudio3DMixingSourceMode)sourceMode
{
    return _revenant_node.sourceMode;
}

- (void)setSourceMode:(AVAudio3DMixingSourceMode)sourceMode
{
    _revenant_node.sourceMode = sourceMode;
}

- (AVAudio3DMixingPointSourceInHeadMode)pointSourceInHeadMode
{
    return _revenant_node.pointSourceInHeadMode;
}

- (void)setPointSourceInHeadMode:(AVAudio3DMixingPointSourceInHeadMode)pointSourceInHeadMode
{
    _revenant_node.pointSourceInHeadMode = pointSourceInHeadMode;
}

- (float)rate
{
    return _revenant_node.rate;
}

- (void)setRate:(float)rate
{
    _revenant_node.rate = rate;
}

- (float)reverbBlend
{
    return _revenant_node.reverbBlend;
}

- (void)setReverbBlend:(float)reverbBlend
{
    _revenant_node.reverbBlend = reverbBlend;
}

- (float)occlusion
{
    return _revenant_node.occlusion;
}

- (void)setOcclusion:(float)occlusion
{
    _revenant_node.occlusion = occlusion;
}

- (float)obstruction
{
    return _revenant_node.obstruction;
}

- (void)setObstruction:(float)obstruction
{
    _revenant_node.obstruction = obstruction;
}

@end

@interface AVAudioUnit (RevenantMixing9)
- (nullable AVAudioMixingDestination *)destinationForMixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus;
@end

@interface AUAudioUnit (RevenantLogging)
+ (void)revenant_noteInert:(NSString *)member why:(NSString *)why;
@end

@implementation AVAudioUnit (RevenantMixing9)

- (BOOL)bypass
{
    AudioUnit unit = self.audioUnit;
    if (unit == NULL) {
        return NO;
    }
    UInt32 bypass = 0;
    UInt32 size = sizeof(bypass);
    if (AudioUnitGetProperty(unit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &bypass, &size) != noErr) {
        return NO;
    }
    return bypass != 0;
}

- (void)setBypass:(BOOL)bypass
{
    AudioUnit unit = self.audioUnit;
    if (unit == NULL) {
        return;
    }
    UInt32 value = bypass ? 1u : 0u;
    AudioUnitSetProperty(unit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &value, sizeof(value));
}

- (float)volume
{
    return [self revenant_inputParameter:k3DMixerParam_Gain];
}

- (void)setVolume:(float)volume
{
    [self revenant_setInputParameter:k3DMixerParam_Gain value:volume];
}

- (float)pan
{
    return [self revenant_inputParameter:k3DMixerParam_Azimuth] / 180.0f;
}

- (void)setPan:(float)pan
{
    [self revenant_setInputParameter:k3DMixerParam_Azimuth value:pan * 180.0f];
}

- (AVAudio3DPoint)position
{
    AudioUnitParameterValue azimuth = 0, elevation = 0, distance = 0;
    [self revenant_readAzimuth:&azimuth elevation:&elevation distance:&distance];
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
        [self revenant_setInputParameter:k3DMixerParam_Distance value:0];
        return;
    }
    [self revenant_setInputParameter:k3DMixerParam_Azimuth value:atan2f(position.x, position.z) * 180.0f / (float)M_PI];
    [self revenant_setInputParameter:k3DMixerParam_Elevation value:asinf(position.y / distance) * 180.0f / (float)M_PI];
    [self revenant_setInputParameter:k3DMixerParam_Distance value:distance];
}

- (AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    return [self revenant_inputParameter:k3DMixerParam_Enable] != 0
        ? AVAudio3DMixingRenderingAlgorithmSoundField
        : AVAudio3DMixingRenderingAlgorithmStereoPassThrough;
}

- (void)setRenderingAlgorithm:(AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    [self revenant_setInputParameter:k3DMixerParam_Enable
                             value:(renderingAlgorithm == AVAudio3DMixingRenderingAlgorithmStereoPassThrough ? 0 : 1)];
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
    return [self revenant_inputParameter:k3DMixerParam_PlaybackRate];
}

- (void)setRate:(float)rate
{
    [self revenant_setInputParameter:k3DMixerParam_PlaybackRate value:rate];
}

- (float)reverbBlend
{
    return [self revenant_inputParameter:k3DMixerParam_ReverbBlend] / 100.0f;
}

- (void)setReverbBlend:(float)reverbBlend
{
    [self revenant_setInputParameter:k3DMixerParam_ReverbBlend value:reverbBlend * 100.0f];
}

- (float)occlusion
{
    return [self revenant_inputParameter:k3DMixerParam_OcclusionAttenuation];
}

- (void)setOcclusion:(float)occlusion
{
    [self revenant_setInputParameter:k3DMixerParam_OcclusionAttenuation value:occlusion];
}

- (float)obstruction
{
    return [self revenant_inputParameter:k3DMixerParam_ObstructionAttenuation];
}

- (void)setObstruction:(float)obstruction
{
    [self revenant_setInputParameter:k3DMixerParam_ObstructionAttenuation value:obstruction];
}

- (AVAudioMixingDestination *)destinationForMixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus
{
    if (mixer == nil) {
        return nil;
    }
    return [[AVAudioMixingDestination alloc] initWithRevenantNode:self mixer:mixer bus:bus];
}

- (float)revenant_inputParameter:(AudioUnitParameterID)identifier
{
    AudioUnit unit = self.audioUnit;
    if (unit == NULL) {
        return 0;
    }
    AudioUnitParameterValue value = 0;
    if (AudioUnitGetParameter(unit, identifier, kAudioUnitScope_Input, 0, &value) != noErr) {
        return 0;
    }
    return (float)value;
}

- (void)revenant_setInputParameter:(AudioUnitParameterID)identifier value:(float)value
{
    AudioUnit unit = self.audioUnit;
    if (unit == NULL) {
        return;
    }
    OSStatus status = AudioUnitSetParameter(unit, identifier, kAudioUnitScope_Input, 0,
                                            (AudioUnitParameterValue)value, 0);
    if (status != noErr) {
        [AUAudioUnit revenant_noteInert:[NSString stringWithFormat:@"%@ parameter %u", NSStringFromClass([self class]), (unsigned)identifier]
                                 why:@"this release's unit refused the value, so it keeps the value it had"];
    }
}

- (void)revenant_readAzimuth:(AudioUnitParameterValue *)azimuth
                  elevation:(AudioUnitParameterValue *)elevation
                   distance:(AudioUnitParameterValue *)distance
{
    *azimuth = 0;
    *elevation = 0;
    *distance = 0;
    *azimuth = (AudioUnitParameterValue)[self revenant_inputParameter:k3DMixerParam_Azimuth];
    *elevation = (AudioUnitParameterValue)[self revenant_inputParameter:k3DMixerParam_Elevation];
    *distance = (AudioUnitParameterValue)[self revenant_inputParameter:k3DMixerParam_Distance];
}

@end
