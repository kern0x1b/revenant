#import <QuartzCore/QuartzCore.h>
#import <OpenAL/al.h>
#import "RevenantSCNAudio.h"
#import "RevenantSCNSoundEngine.h"

@implementation SCNAudioPlayer
{
    unsigned int _source;
    float _appliedReverb;
    __weak SCNNode *_node;
    SCNVector3 _lastPosition;
    CFTimeInterval _lastTime;
    BOOL _hasLastPosition;
}

@synthesize audioSource = _audioSource;
@synthesize willStartPlayback = _willStartPlayback;
@synthesize didFinishPlayback = _didFinishPlayback;

- (instancetype)initWithSource:(SCNAudioSource *)source
{
    if (source == nil) {
        return nil;
    }
    if ((self = [super init])) {
        _audioSource = source;
    }
    return self;
}

+ (instancetype)audioPlayerWithSource:(SCNAudioSource *)source
{
    return [[self alloc] initWithSource:source];
}

- (BOOL)revenantIsSpatial
{
    return _audioSource.positional && !_audioSource.shouldStream;
}

- (void)revenantStartOnNode:(SCNNode *)node
{
    _node = node;
    [RevenantSCNSoundEngine prepare];
    BOOL spatial = [self revenantIsSpatial];
    unsigned int buffer = [_audioSource revenantBufferForSpatial:spatial];
    unsigned int source = [RevenantSCNSoundEngine newSourceWithBuffer:buffer relative:!spatial];
    if (source == 0) {
        [node removeAudioPlayer:self];
        return;
    }
    _source = source;
    _hasLastPosition = NO;
    alSourcei(source, AL_LOOPING, _audioSource.loops ? AL_TRUE : AL_FALSE);
    alSourcef(source, AL_GAIN, _audioSource.volume);
    alSourcef(source, AL_PITCH, _audioSource.rate);
    _appliedReverb = _audioSource.reverbBlend;
    if (![RevenantSCNSoundEngine setSource:source reverbSend:_appliedReverb]) {
        [NSException raise:NSInternalInconsistencyException format:@"SCNAudioSource: reverb needs the ASA extension, which this device does not provide"];
    }
    if (spatial) {
        SCNMatrix4 world = node ? [node worldTransform] : SCNMatrix4Identity;
        [RevenantSCNSoundEngine setSource:source position:SCNVector3Make(world.m41, world.m42, world.m43) velocity:SCNVector3Make(0, 0, 0)];
    }
    if (_willStartPlayback) {
        _willStartPlayback();
    }
    alSourcePlay(source);
}

- (void)revenantUpdateWithWorld:(SCNMatrix4)world time:(CFTimeInterval)now
{
    if (_source == 0) {
        return;
    }
    if ([self revenantIsSpatial]) {
        SCNVector3 position = SCNVector3Make(world.m41, world.m42, world.m43);
        SCNVector3 velocity = SCNVector3Make(0, 0, 0);
        if (_hasLastPosition && now > _lastTime) {
            CFTimeInterval dt = now - _lastTime;
            velocity = SCNVector3Make((position.x - _lastPosition.x) / dt,
                                      (position.y - _lastPosition.y) / dt,
                                      (position.z - _lastPosition.z) / dt);
        }
        [RevenantSCNSoundEngine setSource:_source position:position velocity:velocity];
        _lastPosition = position;
        _lastTime = now;
        _hasLastPosition = YES;
    }
    if (_audioSource.reverbBlend != _appliedReverb) {
        _appliedReverb = _audioSource.reverbBlend;
        if (![RevenantSCNSoundEngine setSource:_source reverbSend:_appliedReverb]) {
            [NSException raise:NSInternalInconsistencyException format:@"SCNAudioSource: reverb needs the ASA extension, which this device does not provide"];
        }
    }
    ALint state = AL_STOPPED;
    alGetSourcei(_source, AL_SOURCE_STATE, &state);
    if (state == AL_STOPPED) {
        [self revenantDidFinishPlayback];
    }
}

- (void)revenantStop
{
    if (_source) {
        [RevenantSCNSoundEngine deleteSource:_source];
        _source = 0;
    }
}

- (void)revenantDidFinishPlayback
{
    if (_source == 0) {
        return;
    }
    SCNNode *node = _node;
    [self revenantStop];
    [node revenantRemoveFinishedAudioPlayer:self];
    if (_didFinishPlayback) {
        _didFinishPlayback();
    }
}

- (BOOL)revenantIsPlaying
{
    ALint state = AL_STOPPED;
    if (_source) {
        alGetSourcei(_source, AL_SOURCE_STATE, &state);
    }
    return state == AL_PLAYING;
}

- (unsigned int)revenantSource
{
    return _source;
}

@end
