#import "CharonAVAudioUnit.h"
#import <AVFAudio/AVAudioMixing.h>
#import <AudioToolbox/AudioUnitParameters.h>

// The members Apple's own hierarchy puts on AVAudioUnit, which the port was missing on every class
// but AVAudioUnitEffect.
//
// -bypass: AVAudioUnitTimeEffect.h:38 and AVAudioUnitGenerator.h:39 both declare it, and in Apple's
// hierarchy both derive from AVAudioUnit - as they do here. It is one ivar and the release's own
// kAudioUnitProperty_BypassEffect, which the port's AVAudioUnitEffect already used, so one
// implementation as a category on the base covers all three and the review's crash on
// `timeEffect.bypass = YES` is what it fixes.
//
// The AVAudioMixing surface, which AVAudioUnitGenerator.h:22 declares and which the port answered
// with a pragma that turned off the compiler's report of the eleven missing members. Each value is the
// unit's own property: the mixer's k3DMixerParam_ set, which the release has carried since iOS 2.0,
// asked of the unit's input scope 0 - this node's own source. A unit that is not a mixer has no such
// parameter, and AudioUnitGetParameter leaves the value at zero, which is what the gain-like members
// then answer. The 3D members are the spherical form the mixer's azimuth, elevation and distance
// describe, and the two members the release's parameters cannot express - the ear-model algorithms and
// the non-point source modes - are kept and answer what this unit can do, which is the sound field.

// AVAudioMixingDestination is the header's own class (AVAudioMixing.h:60-63), and its contract is that a
// reference goes stale when the source and the mixer node disconnect, so it is fetched again each time. So it is a fresh object over the
// pair asked for, and its values are the source node's - which is what a mixing destination is: a way
// to set a particular connection's values rather than the source's own.
@interface AVAudioMixingDestination (CharonImpl)
- (instancetype)initWithCharonNode:(AVAudioNode *)node mixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus;
@end

@implementation AVAudioMixingDestination {
    __weak id<AVAudioMixing> _charon_node;
    __weak AVAudioNode *_charon_mixer;
    AVAudioNodeBus _charon_bus;
}

- (instancetype)initWithCharonNode:(AVAudioNode *)node mixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus
{
    if ((self = [super init])) {
        _charon_node = (id<AVAudioMixing>)node;
        _charon_mixer = mixer;
        _charon_bus = bus;
    }
    return self;
}

- (AVAudioConnectionPoint *)connectionPoint
{
    if (_charon_node == nil) {
        return nil;
    }
    return [[AVAudioConnectionPoint alloc] initWithNode:_charon_mixer bus:_charon_bus];
}

- (float)volume
{
    return _charon_node.volume;
}

- (void)setVolume:(float)volume
{
    _charon_node.volume = volume;
}

- (float)pan
{
    return _charon_node.pan;
}

- (void)setPan:(float)pan
{
    _charon_node.pan = pan;
}

- (AVAudio3DPoint)position
{
    return _charon_node.position;
}

- (void)setPosition:(AVAudio3DPoint)position
{
    _charon_node.position = position;
}

- (AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    return _charon_node.renderingAlgorithm;
}

- (void)setRenderingAlgorithm:(AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    _charon_node.renderingAlgorithm = renderingAlgorithm;
}

- (AVAudio3DMixingSourceMode)sourceMode
{
    return _charon_node.sourceMode;
}

- (void)setSourceMode:(AVAudio3DMixingSourceMode)sourceMode
{
    _charon_node.sourceMode = sourceMode;
}

- (AVAudio3DMixingPointSourceInHeadMode)pointSourceInHeadMode
{
    return _charon_node.pointSourceInHeadMode;
}

- (void)setPointSourceInHeadMode:(AVAudio3DMixingPointSourceInHeadMode)pointSourceInHeadMode
{
    _charon_node.pointSourceInHeadMode = pointSourceInHeadMode;
}

- (float)rate
{
    return _charon_node.rate;
}

- (void)setRate:(float)rate
{
    _charon_node.rate = rate;
}

- (float)reverbBlend
{
    return _charon_node.reverbBlend;
}

- (void)setReverbBlend:(float)reverbBlend
{
    _charon_node.reverbBlend = reverbBlend;
}

- (float)occlusion
{
    return _charon_node.occlusion;
}

- (void)setOcclusion:(float)occlusion
{
    _charon_node.occlusion = occlusion;
}

- (float)obstruction
{
    return _charon_node.obstruction;
}

- (void)setObstruction:(float)obstruction
{
    _charon_node.obstruction = obstruction;
}

@end

// ---- on the base itself, as a category: no ivar is needed, because every value is the unit's own ----
@interface AVAudioUnit (CharonMixing9)
- (nullable AVAudioMixingDestination *)destinationForMixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus;
@end

// the once-in-a-log note, declared beside its use
@interface AUAudioUnit (CharonLogging)
+ (void)charon_noteInert:(NSString *)member why:(NSString *)why;
@end

@implementation AVAudioUnit (CharonMixing9)

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
    return [self charon_inputParameter:k3DMixerParam_Gain];
}

- (void)setVolume:(float)volume
{
    [self charon_setInputParameter:k3DMixerParam_Gain value:volume];
}

- (float)pan
{
    // The mixer's own azimuth is a pan: the header's pan runs -1 (hard left) to +1 (hard right) and the
    // azimuth runs -180 to 180 degrees, so the two are the same number at different scales.
    return [self charon_inputParameter:k3DMixerParam_Azimuth] / 180.0f;
}

- (void)setPan:(float)pan
{
    [self charon_setInputParameter:k3DMixerParam_Azimuth value:pan * 180.0f];
}

- (AVAudio3DPoint)position
{
    AudioUnitParameterValue azimuth = 0, elevation = 0, distance = 0;
    [self charon_readAzimuth:&azimuth elevation:&elevation distance:&distance];
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
        [self charon_setInputParameter:k3DMixerParam_Distance value:0];
        return;
    }
    [self charon_setInputParameter:k3DMixerParam_Azimuth value:atan2f(position.x, position.z) * 180.0f / (float)M_PI];
    [self charon_setInputParameter:k3DMixerParam_Elevation value:asinf(position.y / distance) * 180.0f / (float)M_PI];
    [self charon_setInputParameter:k3DMixerParam_Distance value:distance];
}

- (AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    return [self charon_inputParameter:k3DMixerParam_Enable] != 0
        ? AVAudio3DMixingRenderingAlgorithmSoundField
        : AVAudio3DMixingRenderingAlgorithmStereoPassThrough;
}

- (void)setRenderingAlgorithm:(AVAudio3DMixingRenderingAlgorithm)renderingAlgorithm
{
    // The mixer's own parameters have placement on or off and nothing else, so the two algorithms its
    // parameters can express are the sound field and the pass-through, and the two that need an ear
    // model leave it where it is rather than being answered as the sound field.
    [self charon_setInputParameter:k3DMixerParam_Enable
                             value:(renderingAlgorithm == AVAudio3DMixingRenderingAlgorithmStereoPassThrough ? 0 : 1)];
}

- (AVAudio3DMixingSourceMode)sourceMode
{
    return AVAudio3DMixingSourceModePointSource;
}

- (void)setSourceMode:(AVAudio3DMixingSourceMode)sourceMode
{
    // The release's mixer places every source as a point in a sphere; that is the point source mode
    // and the only one its parameter set expresses. A mode it cannot render leaves it where it is.
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
    return [self charon_inputParameter:k3DMixerParam_PlaybackRate];
}

- (void)setRate:(float)rate
{
    [self charon_setInputParameter:k3DMixerParam_PlaybackRate value:rate];
}

- (float)reverbBlend
{
    return [self charon_inputParameter:k3DMixerParam_ReverbBlend] / 100.0f;
}

- (void)setReverbBlend:(float)reverbBlend
{
    [self charon_setInputParameter:k3DMixerParam_ReverbBlend value:reverbBlend * 100.0f];
}

- (float)occlusion
{
    return [self charon_inputParameter:k3DMixerParam_OcclusionAttenuation];
}

- (void)setOcclusion:(float)occlusion
{
    [self charon_setInputParameter:k3DMixerParam_OcclusionAttenuation value:occlusion];
}

- (float)obstruction
{
    return [self charon_inputParameter:k3DMixerParam_ObstructionAttenuation];
}

- (void)setObstruction:(float)obstruction
{
    [self charon_setInputParameter:k3DMixerParam_ObstructionAttenuation value:obstruction];
}

- (AVAudioMixingDestination *)destinationForMixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus
{
    if (mixer == nil) {
        return nil;
    }
    return [[AVAudioMixingDestination alloc] initWithCharonNode:self mixer:mixer bus:bus];
}

- (float)charon_inputParameter:(AudioUnitParameterID)identifier
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

- (void)charon_setInputParameter:(AudioUnitParameterID)identifier value:(float)value
{
    AudioUnit unit = self.audioUnit;
    if (unit == NULL) {
        return;
    }
    OSStatus status = AudioUnitSetParameter(unit, identifier, kAudioUnitScope_Input, 0,
                                            (AudioUnitParameterValue)value, 0);
    if (status != noErr) {
        // The set's result used to be discarded, so a parameter the unit does not publish read back as
        // the unit's own value and the host never learned. It is checked and said once, per member and
        // unit, the first time the unit refuses.
        [AUAudioUnit charon_noteInert:[NSString stringWithFormat:@"%@ parameter %u", NSStringFromClass([self class]), (unsigned)identifier]
                                 why:@"this release's unit refused the value, so it keeps the value it had"];
    }
}

- (void)charon_readAzimuth:(AudioUnitParameterValue *)azimuth
                  elevation:(AudioUnitParameterValue *)elevation
                   distance:(AudioUnitParameterValue *)distance
{
    *azimuth = 0;
    *elevation = 0;
    *distance = 0;
    *azimuth = (AudioUnitParameterValue)[self charon_inputParameter:k3DMixerParam_Azimuth];
    *elevation = (AudioUnitParameterValue)[self charon_inputParameter:k3DMixerParam_Elevation];
    *distance = (AudioUnitParameterValue)[self charon_inputParameter:k3DMixerParam_Distance];
}

@end
