#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenAL/al.h>
#import "RevenantSCNAudio.h"
#import "RevenantSCNSoundEngine.h"
#import "RevenantSCNStream.h"
#import <objc/runtime.h>

static const void *RevenantSCNAudioPlayerSourceKey = &RevenantSCNAudioPlayerSourceKey;
static const void *RevenantSCNAudioPlayerStreamKey = &RevenantSCNAudioPlayerStreamKey;
static const void *RevenantSCNAudioPlayerAppliedVolumeKey = &RevenantSCNAudioPlayerAppliedVolumeKey;
static const void *RevenantSCNAudioPlayerAppliedRateKey = &RevenantSCNAudioPlayerAppliedRateKey;
static const void *RevenantSCNAudioPlayerAppliedReverbKey = &RevenantSCNAudioPlayerAppliedReverbKey;
static const void *RevenantSCNAudioPlayerNodeKey = &RevenantSCNAudioPlayerNodeKey;
static const void *RevenantSCNAudioPlayerLastPositionKey = &RevenantSCNAudioPlayerLastPositionKey;
static const void *RevenantSCNAudioPlayerLastTimeKey = &RevenantSCNAudioPlayerLastTimeKey;
static const void *RevenantSCNAudioPlayerHasLastPositionKey = &RevenantSCNAudioPlayerHasLastPositionKey;

@implementation SCNAudioPlayer (RevenantSCNAudio)

- (unsigned int)revenantSourceValue
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioPlayerSourceKey);
    return value ? value.unsignedIntValue : 0;
}

- (void)setRevenantSourceValue:(unsigned int)source
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerSourceKey, @(source), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (RevenantSCNStream *)revenantStream
{
    return objc_getAssociatedObject(self, RevenantSCNAudioPlayerStreamKey);
}

- (void)setRevenantStream:(RevenantSCNStream *)stream
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerStreamKey, stream, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (float)revenantAppliedVolume
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioPlayerAppliedVolumeKey);
    return value ? value.floatValue : 0;
}

- (void)setRevenantAppliedVolume:(float)volume
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerAppliedVolumeKey, @(volume), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (float)revenantAppliedRate
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioPlayerAppliedRateKey);
    return value ? value.floatValue : 0;
}

- (void)setRevenantAppliedRate:(float)rate
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerAppliedRateKey, @(rate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (float)revenantAppliedReverb
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioPlayerAppliedReverbKey);
    return value ? value.floatValue : 0;
}

- (void)setRevenantAppliedReverb:(float)reverb
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerAppliedReverbKey, @(reverb), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SCNNode *)revenantNode
{
    return objc_getAssociatedObject(self, RevenantSCNAudioPlayerNodeKey);
}

- (void)setRevenantNode:(SCNNode *)node
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerNodeKey, node, OBJC_ASSOCIATION_ASSIGN);
}

- (SCNVector3)revenantLastPosition
{
    NSValue *value = objc_getAssociatedObject(self, RevenantSCNAudioPlayerLastPositionKey);
    return value ? value.SCNVector3Value : SCNVector3Zero;
}

- (void)setRevenantLastPosition:(SCNVector3)position
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerLastPositionKey, [NSValue valueWithSCNVector3:position], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CFTimeInterval)revenantLastTime
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioPlayerLastTimeKey);
    return value ? value.doubleValue : 0;
}

- (void)setRevenantLastTime:(CFTimeInterval)time
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerLastTimeKey, @(time), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)revenantHasLastPosition
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioPlayerHasLastPositionKey);
    return value ? value.boolValue : NO;
}

- (void)setRevenantHasLastPosition:(BOOL)hasLastPosition
{
    objc_setAssociatedObject(self, RevenantSCNAudioPlayerHasLastPositionKey, @(hasLastPosition), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)revenantIsSpatial
{
    return self.audioSource.positional;
}

- (void)applyMixToSource:(unsigned int)source
{
    float volume = self.audioSource.volume;
    float rate = self.audioSource.rate;
    float reverb = self.audioSource.reverbBlend;
    alSourcef(source, AL_GAIN, volume * (1 - reverb));
    alSourcef(source, AL_PITCH, rate);
    if (reverb > 0 || [self revenantAppliedReverb] > 0) {
        if (![RevenantSCNSoundEngine setSource:source reverbSend:reverb] && reverb > 0) {
            [NSException raise:NSInternalInconsistencyException format:@"SCNAudioSource: reverb needs the ASA extension, which this device does not provide"];
        }
    }
    [self setRevenantAppliedVolume:volume];
    [self setRevenantAppliedRate:rate];
    [self setRevenantAppliedReverb:reverb];
}

- (void)revenantStartOnNode:(SCNNode *)node
{
    [self setRevenantNode:node];
    if (self.audioNode) {
        AVAudioEngine *engine = [RevenantSCNSoundEngine nodeEngine];
        if (self.audioNode.engine == nil) {
            [engine attachNode:self.audioNode];
        }
        [engine connect:self.audioNode to:engine.mainMixerNode format:nil];
        NSError *error = nil;
        if (![engine startAndReturnError:&error]) {
            [NSException raise:NSInternalInconsistencyException format:@"SCNAudioPlayer: the audio engine did not start: %@", error];
        }
        if (self.willStartPlayback) {
            self.willStartPlayback();
        }
        return;
    }
    [RevenantSCNSoundEngine prepare];
    BOOL spatial = [self revenantIsSpatial];
    BOOL streaming = self.audioSource.shouldStream;
    unsigned int buffer = streaming ? 0 : [self.audioSource revenantBufferForSpatial:spatial];
    unsigned int source = [RevenantSCNSoundEngine newSourceWithBuffer:buffer relative:!spatial];
    if (source == 0) {
        [node removeAudioPlayer:self];
        return;
    }
    if (streaming) {
        RevenantSCNStream *stream = [[RevenantSCNStream alloc] initWithURL:[self.audioSource revenantURL] channels:spatial ? 1 : 2];
        if (stream == nil) {
            [RevenantSCNSoundEngine deleteSource:source];
            [NSException raise:NSInvalidArgumentException format:@"SCNAudioSource: %@ cannot be streamed", [self.audioSource revenantURL]];
        }
        [self setRevenantStream:stream];
        [stream primeSource:source loops:self.audioSource.loops];
    }
    [self setRevenantSourceValue:source];
    [self setRevenantHasLastPosition:NO];
    alSourcei(source, AL_LOOPING, (self.audioSource.loops && !streaming) ? AL_TRUE : AL_FALSE);
    [self applyMixToSource:source];
    if (spatial) {
        SCNMatrix4 world = node ? [node worldTransform] : SCNMatrix4Identity;
        [RevenantSCNSoundEngine setSource:source position:SCNVector3Make(world.m41, world.m42, world.m43) velocity:SCNVector3Make(0, 0, 0)];
    }
    if (self.willStartPlayback) {
        self.willStartPlayback();
    }
    alSourcePlay(source);
}

- (void)revenantUpdateWithWorld:(SCNMatrix4)world time:(CFTimeInterval)now
{
    unsigned int source = [self revenantSourceValue];
    if (source == 0) {
        return;
    }
    if ([self revenantIsSpatial]) {
        SCNVector3 position = SCNVector3Make(world.m41, world.m42, world.m43);
        SCNVector3 velocity = SCNVector3Make(0, 0, 0);
        if ([self revenantHasLastPosition] && now > [self revenantLastTime]) {
            CFTimeInterval dt = now - [self revenantLastTime];
            velocity = SCNVector3Make((position.x - [self revenantLastPosition].x) / dt,
                                      (position.y - [self revenantLastPosition].y) / dt,
                                      (position.z - [self revenantLastPosition].z) / dt);
        }
        [RevenantSCNSoundEngine setSource:source position:position velocity:velocity];
        [self setRevenantLastPosition:position];
        [self setRevenantLastTime:now];
        [self setRevenantHasLastPosition:YES];
    }
    if (self.audioSource.volume != [self revenantAppliedVolume] || self.audioSource.rate != [self revenantAppliedRate] || self.audioSource.reverbBlend != [self revenantAppliedReverb]) {
        [self applyMixToSource:source];
    }
    ALint state = AL_STOPPED;
    if ([self revenantStream]) {
        [[self revenantStream] refillSource:source loops:self.audioSource.loops];
        alGetSourcei(source, AL_SOURCE_STATE, &state);
        if (state != AL_PLAYING) {
            if ([[self revenantStream] isExhaustedOnSource:source]) {
                [self revenantDidFinishPlayback];
            } else {
                alSourcePlay(source);
            }
        }
        return;
    }
    alGetSourcei(source, AL_SOURCE_STATE, &state);
    if (state == AL_STOPPED) {
        [self revenantDidFinishPlayback];
    }
}

- (void)revenantStop
{
    unsigned int source = [self revenantSourceValue];
    if (source) {
        [RevenantSCNSoundEngine deleteSource:source];
        [self setRevenantSourceValue:0];
    }
    [[self revenantStream] dispose];
    [self setRevenantStream:nil];
    if (self.audioNode.engine) {
        [self.audioNode.engine detachNode:self.audioNode];
    }
}

- (void)revenantDidFinishPlayback
{
    unsigned int source = [self revenantSourceValue];
    if (source == 0) {
        return;
    }
    SCNNode *node = [self revenantNode];
    [self revenantStop];
    [node revenantRemoveFinishedAudioPlayer:self];
    if (self.didFinishPlayback) {
        self.didFinishPlayback();
    }
}

- (BOOL)revenantIsPlaying
{
    ALint state = AL_STOPPED;
    unsigned int source = [self revenantSourceValue];
    if (source) {
        alGetSourcei(source, AL_SOURCE_STATE, &state);
    }
    return state == AL_PLAYING;
}

- (unsigned int)revenantSource
{
    return [self revenantSourceValue];
}

@end