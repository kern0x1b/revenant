#import "../Foundation/check.h"
#import <SceneKit/SceneKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../../src/SceneKit/RevenantSCNAudio.h"
#include <math.h>

static NSString *const revenant_wave_name = @"scenekit_audio_test.wav";

static void revenant_put_u16(NSMutableData *data, uint16_t value)
{
    uint8_t bytes[2] = {value & 0xff, (value >> 8) & 0xff};
    [data appendBytes:bytes length:2];
}

static void revenant_put_u32(NSMutableData *data, uint32_t value)
{
    uint8_t bytes[4] = {value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff};
    [data appendBytes:bytes length:4];
}

static NSURL *revenant_write_wave(NSTimeInterval seconds)
{
    const uint32_t rate = 8000, samples = (uint32_t)(seconds * rate);
    const uint32_t dataLength = samples * 2;
    NSMutableData *wave = [NSMutableData data];
    [wave appendBytes:"RIFF" length:4];
    revenant_put_u32(wave, 36 + dataLength);
    [wave appendBytes:"WAVEfmt " length:8];
    revenant_put_u32(wave, 16);
    revenant_put_u16(wave, 1);
    revenant_put_u16(wave, 1);
    revenant_put_u32(wave, rate);
    revenant_put_u32(wave, rate * 2);
    revenant_put_u16(wave, 2);
    revenant_put_u16(wave, 16);
    [wave appendBytes:"data" length:4];
    revenant_put_u32(wave, dataLength);
    [wave increaseLengthBy:dataLength];
    NSURL *url = [NSURL fileURLWithPath:revenant_wave_name];
    [wave writeToURL:url atomically:NO];
    return url;
}

static BOOL revenant_close(double value, double expected, double tolerance)
{
    return fabs(value - expected) <= tolerance;
}

static void revenant_expect_number(const char *name, double value, double expected, double tolerance)
{
    revenant_check(revenant_close(value, expected, tolerance), name, [NSString stringWithFormat:@"%g is not %g", value, expected]);
}

static SCNMatrix4 revenant_rigid_inverse(SCNMatrix4 m)
{
    SCNMatrix4 r = m;
    r.m12 = m.m21;
    r.m13 = m.m31;
    r.m21 = m.m12;
    r.m23 = m.m32;
    r.m31 = m.m13;
    r.m32 = m.m23;
    r.m41 = -(m.m41 * m.m11 + m.m42 * m.m12 + m.m43 * m.m13);
    r.m42 = -(m.m41 * m.m21 + m.m42 * m.m22 + m.m43 * m.m23);
    r.m43 = -(m.m41 * m.m31 + m.m42 * m.m32 + m.m43 * m.m33);
    return r;
}

static RevenantSCNAudioMix revenant_mix(SCNNode *listener, SCNVector3 position, float volume)
{
    return RevenantSCNAudioMixFor(revenant_rigid_inverse([listener worldTransform]), position, volume);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);
        NSURL *wave = revenant_write_wave(0.1);

        SCNAudioSource *source = [[SCNAudioSource alloc] initWithURL:wave];
        revenant_check(source.isPositional, "audio sources are positional by default", @"positional is not the default");
        revenant_expect_number("audio source volume defaults to full", source.volume, 1, 1e-6);
        revenant_expect_number("audio source rate defaults to the original rate", source.rate, 1, 1e-6);
        revenant_check(!source.loops, "audio sources do not loop by default", @"loops by default");
        revenant_check(!source.shouldStream, "audio sources do not stream by default", @"streams by default");

        source.volume = 0.5;
        source.loops = YES;
        revenant_expect_number("volume is set on the source", source.volume, 0.5, 1e-6);

        SCNAudioPlayer *player = [SCNAudioPlayer audioPlayerWithSource:source];
        revenant_check(player.audioSource == source, "a player keeps its source", @"the player lost its source");
        AVAudioPlayer *av = [player revenantAVPlayer];
        revenant_check(av != nil, "a player plays its source through AVAudioPlayer", @"no AVAudioPlayer was made");
        revenant_check(av.numberOfLoops < 0, "a looping source loops forever", @"the player does not loop");
        revenant_expect_number("the source volume reaches the player", av.volume, 0.5, 1e-6);

        source.loops = NO;
        SCNAudioPlayer *single = [SCNAudioPlayer audioPlayerWithSource:source];
        revenant_check([single revenantAVPlayer].numberOfLoops == 0, "a non-looping source plays once", @"the player loops");

        SCNAudioSource *streamed = [[SCNAudioSource alloc] initWithURL:wave];
        streamed.shouldStream = YES;
        revenant_check([streamed revenantData] == nil, "a streamed source is not loaded into memory", @"a streamed source has data");
        streamed.shouldStream = NO;
        [streamed load];
        revenant_check([streamed revenantData] != nil, "loading a source puts its data in memory", @"no data after load");

        streamed.shouldStream = YES;
        SCNAudioPlayer *streamedPlayer = [SCNAudioPlayer audioPlayerWithSource:streamed];
        revenant_check(![streamedPlayer revenantIsSpatial], "a streamed source is not positional", @"a streamed source is spatial");
        streamed.shouldStream = NO;
        revenant_check([streamedPlayer revenantIsSpatial], "a source that stops streaming is positional again", @"the source is still not positional");
        SCNAudioSource *unspatial = [[SCNAudioSource alloc] initWithURL:wave];
        unspatial.positional = NO;
        revenant_check(![[SCNAudioPlayer audioPlayerWithSource:unspatial] revenantIsSpatial], "a non-positional source is not spatial", @"non-positional source is spatial");
        revenant_check([[SCNAudioPlayer audioPlayerWithSource:[[SCNAudioSource alloc] initWithURL:wave]] revenantIsSpatial], "a default source is spatial", @"default source is not spatial");

        SCNNode *listener = [SCNNode node];
        SCNMatrix4 world = [listener worldTransform];
        SCNVector3 right = SCNVector3Make(world.m11 * 2, world.m12 * 2, world.m13 * 2);
        RevenantSCNAudioMix toRight = revenant_mix(listener, right, 1);
        revenant_expect_number("a node to the listener's right is panned fully right", toRight.pan, 1, 1e-4);
        RevenantSCNAudioMix toLeft = revenant_mix(listener, SCNVector3Make(-right.x, -right.y, -right.z), 1);
        revenant_expect_number("a node to the listener's left is panned fully left", toLeft.pan, -1, 1e-4);
        RevenantSCNAudioMix ahead = revenant_mix(listener, SCNVector3Make(0, 0, 0), 1);
        revenant_expect_number("a node at the listener is centred", ahead.pan, 0, 1e-6);

        RevenantSCNAudioMix near = revenant_mix(listener, SCNVector3Make(right.x / 2, right.y / 2, right.z / 2), 1);
        RevenantSCNAudioMix mid = revenant_mix(listener, SCNVector3Make(right.x, right.y, right.z), 1);
        RevenantSCNAudioMix far = revenant_mix(listener, SCNVector3Make(right.x * 2, right.y * 2, right.z * 2), 1);
        revenant_check(near.volume >= mid.volume && mid.volume > far.volume, "volume falls with distance from the listener", @"volume does not fall with distance");
        revenant_expect_number("a node inside the reference distance is not louder than the source", near.volume, 1, 1e-6);

        listener.eulerAngles = SCNVector3Make(0, M_PI / 2, 0);
        SCNMatrix4 turned = [listener worldTransform];
        SCNVector3 turnedRight = SCNVector3Make(turned.m11 * 2, turned.m12 * 2, turned.m13 * 2);
        RevenantSCNAudioMix followed = revenant_mix(listener, turnedRight, 1);
        revenant_expect_number("turning the listener keeps a node on its right on the right", followed.pan, 1, 1e-4);
        revenant_check(fabs(revenant_mix(listener, right, 1).pan) < 0.999, "turning the listener moves a fixed node across the field", @"the fixed node did not move");

        __block BOOL started = NO;
        SCNAudioSource *clip = [[SCNAudioSource alloc] initWithURL:wave];
        SCNAudioPlayer *played = [SCNAudioPlayer audioPlayerWithSource:clip];
        played.willStartPlayback = ^{
            started = YES;
        };
        [played revenantStartOnNode:nil];
        revenant_check(started, "playback announces its start", @"willStartPlayback was not called");
        revenant_check([played revenantAVPlayer].isPlaying, "a started player is playing", @"the player is not playing");
        [played revenantStop];
        revenant_check(![played revenantAVPlayer].isPlaying, "a stopped player is not playing", @"the player still plays");

        __block BOOL endedOnItsOwn = NO;
        SCNAudioPlayer *ending = [SCNAudioPlayer audioPlayerWithSource:clip];
        ending.didFinishPlayback = ^{
            endedOnItsOwn = YES;
        };
        [ending revenantStartOnNode:nil];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        revenant_check(endedOnItsOwn, "playback announces its end when the audio finishes", @"didFinishPlayback was not called");

        [[NSFileManager defaultManager] removeItemAtURL:wave error:NULL];
        revenant_check(revenant_negative ? NO : YES, "negative control", @"the negative control is inverted");
    }
    return revenant_finish();
}
