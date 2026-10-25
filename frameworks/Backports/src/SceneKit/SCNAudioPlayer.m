#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenAL/al.h>
#import "RevenantSCNAudio.h"
#import "RevenantSCNSoundEngine.h"
#import "RevenantSCNStream.h"

@implementation SCNAudioPlayer
{
    unsigned int _source;
    RevenantSCNStream *_stream;
    float _appliedVolume;
    float _appliedRate;
    float _appliedReverb;
    __weak SCNNode *_node;
    SCNVector3 _lastPosition;
    CFTimeInterval _lastTime;
    BOOL _hasLastPosition;
}

@synthesize audioSource = _audioSource;
@synthesize willStartPlayback = _willStartPlayback;
@synthesize didFinishPlayback = _didFinishPlayback;
@synthesize audioNode = _audioNode;

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

- (instancetype)initWithAVAudioNode:(AVAudioNode *)audioNode
{
    if (audioNode == nil) {
        return nil;
    }
    if ((self = [super init])) {
        _audioNode = audioNode;
    }
    return self;
}

+ (instancetype)audioPlayerWithAVAudioNode:(AVAudioNode *)audioNode
{
    return [[self alloc] initWithAVAudioNode:audioNode];
}

- (BOOL)revenantIsSpatial
{
    return _audioSource.positional;
}

- (void)applyMixToSource:(unsigned int)source
{
    float volume = _audioSource.volume;
    float rate = _audioSource.rate;
    float reverb = _audioSource.reverbBlend;
    alSourcef(source, AL_GAIN, volume * (1 - reverb));
    alSourcef(source, AL_PITCH, rate);
    if (reverb > 0 || _appliedReverb > 0) {
        if (![RevenantSCNSoundEngine setSource:source reverbSend:reverb] && reverb > 0) {
            [NSException raise:NSInternalInconsistencyException format:@"SCNAudioSource: reverb needs the ASA extension, which this device does not provide"];
        }
    }
    _appliedVolume = volume;
    _appliedRate = rate;
    _appliedReverb = reverb;
}

- (void)revenantStartOnNode:(SCNNode *)node
{
    _node = node;
    if (_audioNode) {
        AVAudioEngine *engine = [RevenantSCNSoundEngine nodeEngine];
        if (_audioNode.engine == nil) {
            [engine attachNode:_audioNode];
        }
        [engine connect:_audioNode to:engine.mainMixerNode format:nil];
        NSError *error = nil;
        if (![engine startAndReturnError:&error]) {
            [NSException raise:NSInternalInconsistencyException format:@"SCNAudioPlayer: the audio engine did not start: %@", error];
        }
        if (_willStartPlayback) {
            _willStartPlayback();
        }
        return;
    }
    [RevenantSCNSoundEngine prepare];
    BOOL spatial = [self revenantIsSpatial];
    BOOL streaming = _audioSource.shouldStream;
    unsigned int buffer = streaming ? 0 : [_audioSource revenantBufferForSpatial:spatial];
    unsigned int source = [RevenantSCNSoundEngine newSourceWithBuffer:buffer relative:!spatial];
    if (source == 0) {
        [node removeAudioPlayer:self];
        return;
    }
    if (streaming) {
        RevenantSCNStream *stream = [[RevenantSCNStream alloc] initWithURL:[_audioSource revenantURL] channels:spatial ? 1 : 2];
        if (stream == nil) {
            [RevenantSCNSoundEngine deleteSource:source];
            [NSException raise:NSInvalidArgumentException format:@"SCNAudioSource: %@ cannot be streamed", [_audioSource revenantURL]];
        }
        _stream = stream;
        [stream primeSource:source loops:_audioSource.loops];
    }
    _source = source;
    _hasLastPosition = NO;
    alSourcei(source, AL_LOOPING, (_audioSource.loops && !streaming) ? AL_TRUE : AL_FALSE);
    [self applyMixToSource:source];
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
    if (_audioSource.volume != _appliedVolume || _audioSource.rate != _appliedRate || _audioSource.reverbBlend != _appliedReverb) {
        [self applyMixToSource:_source];
    }
    ALint state = AL_STOPPED;
    if (_stream) {
        [_stream refillSource:_source loops:_audioSource.loops];
        alGetSourcei(_source, AL_SOURCE_STATE, &state);
        if (state != AL_PLAYING) {
            if ([_stream isExhaustedOnSource:_source]) {
                [self revenantDidFinishPlayback];
            } else {
                alSourcePlay(_source);
            }
        }
        return;
    }
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
    [_stream dispose];
    _stream = nil;
    if (_audioNode.engine) {
        [_audioNode.engine detachNode:_audioNode];
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
