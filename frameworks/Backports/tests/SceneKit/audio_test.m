#import "../Foundation/check.h"
#import "wave_file.h"
#import <AVFoundation/AVFoundation.h>
#import <SceneKit/SceneKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#import "../../src/SceneKit/RevenantSCNAudio.h"
#import "../../src/SceneKit/RevenantSCNSoundEngine.h"
#include <math.h>
#include <unistd.h>

typedef void (*RevenantCapturePrepare)(ALCuint, ALCenum, ALCsizei);
typedef void (*RevenantCaptureStart)(void);
typedef void (*RevenantCaptureStop)(void);
typedef ALint (*RevenantCaptureAvailable)(void);
typedef void (*RevenantCaptureSamples)(ALCvoid *, ALCsizei);
typedef ALenum (*RevenantASAGetSource)(ALuint, ALuint, ALvoid *, ALuint *);

static BOOL revenant_close(double value, double expected, double tolerance)
{
    return fabs(value - expected) <= tolerance;
}

static void revenant_expect_number(const char *name, double value, double expected, double tolerance)
{
    revenant_check(revenant_close(value, expected, tolerance), name, [NSString stringWithFormat:@"%g is not %g", value, expected]);
}

static SCNMatrix4 revenant_at(SCNVector3 p)
{
    SCNMatrix4 m = SCNMatrix4Identity;
    m.m41 = p.x;
    m.m42 = p.y;
    m.m43 = p.z;
    return m;
}

static double revenant_rms(NSData *data, int channel)
{
    const int16_t *samples = data.bytes;
    NSUInteger frames = data.length / 4;
    double sum = 0;
    for (NSUInteger index = 0; index < frames; index++) {
        double value = samples[index * 2 + channel] / 32768.0;
        sum += value * value;
    }
    return frames ? sqrt(sum / frames) : 0;
}

static double revenant_frequency(NSData *data)
{
    const int16_t *samples = data.bytes;
    NSUInteger frames = data.length / 4;
    NSUInteger crossings = 0;
    for (NSUInteger index = 1; index < frames; index++) {
        if ((samples[(index - 1) * 2] < 0) != (samples[index * 2] < 0)) {
            crossings++;
        }
    }
    return frames ? crossings / 2.0 / (frames / 44100.0) : 0;
}

static NSData *revenant_capture(NSTimeInterval seconds)
{
    RevenantCapturePrepare prepare = (RevenantCapturePrepare)[RevenantSCNSoundEngine procedureNamed:"alcOutputCapturerPrepare"];
    RevenantCaptureStart start = (RevenantCaptureStart)[RevenantSCNSoundEngine procedureNamed:"alcOutputCapturerStart"];
    RevenantCaptureStop stop = (RevenantCaptureStop)[RevenantSCNSoundEngine procedureNamed:"alcOutputCapturerStop"];
    RevenantCaptureAvailable available = (RevenantCaptureAvailable)[RevenantSCNSoundEngine procedureNamed:"alcOutputCapturerAvailableSamples"];
    RevenantCaptureSamples samples = (RevenantCaptureSamples)[RevenantSCNSoundEngine procedureNamed:"alcOutputCapturerSamples"];
    if (!prepare || !start || !stop || !available || !samples) {
        return nil;
    }
    ALCsizei count = (ALCsizei)(seconds * 44100);
    prepare(44100, AL_FORMAT_STEREO16, count);
    start();
    NSMutableData *data = [NSMutableData data];
    CFTimeInterval until = CACurrentMediaTime() + seconds;
    while (CACurrentMediaTime() < until) {
        usleep(20000);
        ALint ready = available();
        if (ready > 0) {
            NSUInteger offset = data.length;
            [data increaseLengthBy:(NSUInteger)ready * 4];
            samples((char *)data.mutableBytes + offset, ready);
        }
    }
    stop();
    return data;
}

static void revenant_hold_listener(SCNVector3 position)
{
    [RevenantSCNSoundEngine setListenerWorld:revenant_at(position) atTime:CACurrentMediaTime()];
    [RevenantSCNSoundEngine setListenerWorld:revenant_at(position) atTime:CACurrentMediaTime() + 0.05];
}

static SCNAudioPlayer *revenant_start(SCNAudioSource *source, SCNVector3 position)
{
    SCNAudioPlayer *player = [SCNAudioPlayer audioPlayerWithSource:source];
    [player revenantStartOnNode:nil];
    [player revenantUpdateWithWorld:revenant_at(position) time:CACurrentMediaTime()];
    return player;
}

static double revenant_level(NSURL *toneURL, SCNVector3 position, int channel)
{
    SCNAudioSource *tone = [[SCNAudioSource alloc] initWithURL:toneURL];
    SCNAudioPlayer *player = revenant_start(tone, position);
    NSData *data = revenant_capture(0.25);
    [player revenantStop];
    return revenant_rms(data, channel);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);
        [RevenantSCNSoundEngine prepare];
        NSString *fixtures = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        [[NSFileManager defaultManager] createDirectoryAtPath:fixtures withIntermediateDirectories:YES attributes:nil error:NULL];
        NSURL *tone = revenant_write_tone([fixtures stringByAppendingPathComponent:@"scenekit_audio_tone.wav"], 2.0, 440);
        NSURL *clip = revenant_write_wave([fixtures stringByAppendingPathComponent:@"scenekit_audio_clip.wav"], 0.1);

        revenant_check(alGetInteger(AL_DISTANCE_MODEL) == AL_INVERSE_DISTANCE_CLAMPED, "the distance model is inverse clamped", @"the distance model is not inverse clamped");
        revenant_expect_number("doppler factor is one", alGetFloat(AL_DOPPLER_FACTOR), 1, 1e-6);
        revenant_expect_number("doppler velocity scale is one", alGetFloat(AL_DOPPLER_VELOCITY), 1, 1e-6);
        revenant_expect_number("the speed of sound is OpenAL's default", alGetFloat(AL_SPEED_OF_SOUND), 343.3, 1e-3);

        SCNAudioSource *source = [[SCNAudioSource alloc] initWithURL:tone];
        revenant_check(source.isPositional, "audio sources are positional by default", @"positional is not the default");
        revenant_expect_number("audio source volume defaults to full", source.volume, 1, 1e-6);
        revenant_expect_number("audio source rate defaults to the original rate", source.rate, 1, 1e-6);
        revenant_expect_number("audio source reverb defaults to dry", source.reverbBlend, 0, 1e-6);
        revenant_check(!source.loops, "audio sources do not loop by default", @"loops by default");
        revenant_check(!source.shouldStream, "audio sources do not stream by default", @"streams by default");
        revenant_expect_number("the tone lasts as long as the file", [source revenantDuration], 2.0, 1e-3);

        source.volume = 0.5;
        source.loops = YES;
        source.rate = 2;
        SCNAudioPlayer *player = revenant_start(source, SCNVector3Make(0, 0, 0));
        ALuint handle = [player revenantSource];
        revenant_check(handle != 0, "a player gets an OpenAL source", @"the player has no source");
        ALfloat referenceDistance = 0, maximumDistance = 0, rolloffFactor = 0;
        alGetSourcef(handle, AL_REFERENCE_DISTANCE, &referenceDistance);
        alGetSourcef(handle, AL_MAX_DISTANCE, &maximumDistance);
        alGetSourcef(handle, AL_ROLLOFF_FACTOR, &rolloffFactor);
        revenant_expect_number("the reference distance is AVAudioEnvironmentNode's default", referenceDistance, 1, 1e-6);
        revenant_expect_number("the maximum distance is AVAudioEnvironmentNode's default", maximumDistance, 100000, 1e-3);
        revenant_expect_number("the rolloff factor is AVAudioEnvironmentNode's default", rolloffFactor, 1, 1e-6);
        ALint looping = AL_FALSE;
        alGetSourcei(handle, AL_LOOPING, &looping);
        revenant_check(looping == AL_TRUE, "a looping source loops", @"the source does not loop");
        ALfloat gain = 0, pitch = 0;
        alGetSourcef(handle, AL_GAIN, &gain);
        alGetSourcef(handle, AL_PITCH, &pitch);
        revenant_expect_number("the source volume is the gain", gain, 0.5, 1e-6);
        revenant_expect_number("the source rate is the pitch", pitch, 2, 1e-6);
        ALint relative = AL_TRUE;
        alGetSourcei(handle, AL_SOURCE_RELATIVE, &relative);
        revenant_check(relative == AL_FALSE, "a positional source is not head relative", @"the positional source is head relative");
        [player revenantStop];
        revenant_check([player revenantSource] == 0, "a stopped player has no source", @"the player kept its source");

        source.loops = NO;
        source.rate = 1;
        source.volume = 1;
        SCNAudioSource *unspatial = [[SCNAudioSource alloc] initWithURL:tone];
        unspatial.positional = NO;
        SCNAudioPlayer *flat = [SCNAudioPlayer audioPlayerWithSource:unspatial];
        [flat revenantStartOnNode:nil];
        ALint flatRelative = AL_FALSE;
        alGetSourcei([flat revenantSource], AL_SOURCE_RELATIVE, &flatRelative);
        revenant_check(flatRelative == AL_TRUE, "a non-positional source is head relative", @"the non-positional source is spatial");
        revenant_check(![flat revenantIsSpatial], "a non-positional source is not spatial", @"non-positional source is spatial");
        [flat revenantStop];

        SCNAudioSource *streamed = [[SCNAudioSource alloc] initWithURL:tone];
        streamed.shouldStream = YES;
        revenant_check([[SCNAudioPlayer audioPlayerWithSource:streamed] revenantIsSpatial], "a streamed positional source is spatial", @"a streamed source is not spatial");
        streamed.positional = NO;
        revenant_check(![[SCNAudioPlayer audioPlayerWithSource:streamed] revenantIsSpatial], "a streamed non-positional source is not spatial", @"a non-positional streamed source is spatial");
        streamed.positional = YES;
        revenant_expect_number("a streamed source lasts as long as the file", [streamed revenantDuration], 2.0, 1e-3);
        revenant_check([streamed revenantData] == nil, "a streamed source is not loaded into memory", @"a streamed source has data");
        streamed.shouldStream = NO;
        [streamed load];
        revenant_check([streamed revenantData] != nil, "loading a source puts its data in memory", @"no data after load");

        SCNMatrix4 listenerAt = revenant_at(SCNVector3Make(3, 4, 5));
        [RevenantSCNSoundEngine setListenerWorld:listenerAt atTime:CACurrentMediaTime()];
        ALfloat listenerPosition[3] = {0, 0, 0};
        alGetListenerfv(AL_POSITION, listenerPosition);
        revenant_expect_number("the listener takes its node's position: x", listenerPosition[0], 3, 1e-4);
        revenant_expect_number("the listener takes its node's position: y", listenerPosition[1], 4, 1e-4);
        revenant_expect_number("the listener takes its node's position: z", listenerPosition[2], 5, 1e-4);
        ALfloat orientation[6] = {0, 0, 0, 0, 0, 0};
        alGetListenerfv(AL_ORIENTATION, orientation);
        revenant_expect_number("an unrotated listener faces down minus z: x", orientation[0], 0, 1e-4);
        revenant_expect_number("an unrotated listener faces down minus z: z", orientation[2], -1, 1e-4);
        revenant_expect_number("an unrotated listener has up along y", orientation[4], 1, 1e-4);

        revenant_hold_listener(SCNVector3Make(0, 0, 0));
        double right = 0, left = 0, centre = 0;
        SCNAudioPlayer *toRight = revenant_start(source, SCNVector3Make(2, 0, 0));
        NSData *rightData = revenant_capture(0.25);
        [toRight revenantStop];
        right = revenant_rms(rightData, 1);
        left = revenant_rms(rightData, 0);
        revenant_check(right > left * 1.2, "a source to the listener's right is louder on the right", @"the right channel is not louder");
        SCNAudioPlayer *toLeft = revenant_start(source, SCNVector3Make(-2, 0, 0));
        NSData *leftData = revenant_capture(0.25);
        [toLeft revenantStop];
        revenant_check(revenant_rms(leftData, 0) > revenant_rms(leftData, 1) * 1.2, "a source to the listener's left is louder on the left", @"the left channel is not louder");
        SCNAudioPlayer *ahead = revenant_start(source, SCNVector3Make(0, 0, -2));
        NSData *aheadData = revenant_capture(0.25);
        [ahead revenantStop];
        centre = fabs(revenant_rms(aheadData, 0) - revenant_rms(aheadData, 1)) / fmax(revenant_rms(aheadData, 0), 1e-9);
        revenant_check(centre < 0.1, "a source ahead of the listener is centred", @"a source ahead is not centred");

        double near = revenant_level(tone, SCNVector3Make(0, 0, -1), 0);
        double far = revenant_level(tone, SCNVector3Make(0, 0, -4), 0);
        revenant_check(far < near, "a source farther away is quieter", @"distance does not attenuate");
        revenant_check(far / near > 0.15 && far / near < 0.35, "the falloff is the inverse distance model", @"the falloff is not the inverse distance model");

        SCNAudioSource *flatSource = [[SCNAudioSource alloc] initWithURL:tone];
        flatSource.positional = NO;
        revenant_hold_listener(SCNVector3Make(0, 0, 0));
        SCNAudioPlayer *plain = [SCNAudioPlayer audioPlayerWithSource:flatSource];
        [plain revenantStartOnNode:nil];
        NSData *beforeMove = revenant_capture(0.25);
        [RevenantSCNSoundEngine setListenerWorld:revenant_at(SCNVector3Make(10, 0, 0)) atTime:CACurrentMediaTime()];
        NSData *afterMove = revenant_capture(0.25);
        [plain revenantStop];
        double ratio = revenant_rms(afterMove, 0) / fmax(revenant_rms(beforeMove, 0), 1e-9);
        revenant_check(ratio > 0.9 && ratio < 1.1, "a non-positional source ignores the listener's position", @"moving the listener changed the volume");

        revenant_hold_listener(SCNVector3Make(0, 0, 0));
        const int dopplerRounds = 3;
        double oursTotal = 0;
        double referenceTotal = 0;
        for (int round = 0; round < dopplerRounds; round++) {
            SCNAudioPlayer *still = [SCNAudioPlayer audioPlayerWithSource:source];
            [still revenantStartOnNode:nil];
            [still revenantUpdateWithWorld:revenant_at(SCNVector3Make(0, 0, -10)) time:CACurrentMediaTime()];
            double stillFrequency = revenant_frequency(revenant_capture(0.6));
            [still revenantStop];

            SCNAudioPlayer *approach = [SCNAudioPlayer audioPlayerWithSource:source];
            [approach revenantStartOnNode:nil];
            CFTimeInterval now = CACurrentMediaTime();
            [approach revenantUpdateWithWorld:revenant_at(SCNVector3Make(0, 0, -10)) time:now];
            [approach revenantUpdateWithWorld:revenant_at(SCNVector3Make(0, 0, -10 + 3.433)) time:now + 0.1];
            double approachingFrequency = revenant_frequency(revenant_capture(0.6));
            [approach revenantStop];

            ALuint raw = 0;
            alGenSources(1, &raw);
            alSourcei(raw, AL_BUFFER, [source revenantBufferForSpatial:YES]);
            alSourcei(raw, AL_SOURCE_RELATIVE, AL_FALSE);
            alSource3f(raw, AL_POSITION, 0, 0, -10);
            alSource3f(raw, AL_VELOCITY, 0, 0, 0);
            alSourcePlay(raw);
            double rawStill = revenant_frequency(revenant_capture(0.6));
            alSource3f(raw, AL_VELOCITY, 0, 0, 34.33);
            alSourcePlay(raw);
            double rawApproaching = revenant_frequency(revenant_capture(0.6));
            alSourceStop(raw);
            alDeleteSources(1, &raw);

            oursTotal += approachingFrequency / stillFrequency;
            referenceTotal += rawApproaching / rawStill;
        }
        double ours = oursTotal / dopplerRounds;
        double reference = referenceTotal / dopplerRounds;
        revenant_check(ours > 1.02, "a source approaching rises in pitch", @"an approaching source does not rise");
        revenant_check(fabs(ours - reference) < 0.03, "the doppler shift matches Apple's OpenAL for the same velocity", [NSString stringWithFormat:@"%g is not Apple's %g", ours, reference]);

        SCNAudioPlayer *reverbPlayer = revenant_start(source, SCNVector3Make(0, 0, -2));
        ALuint reverbHandle = [reverbPlayer revenantSource];
        revenant_check([RevenantSCNSoundEngine setSource:reverbHandle reverbSend:0.5], "the reverb send is accepted", @"the reverb send is refused");
        RevenantASAGetSource getSend = (RevenantASAGetSource)[RevenantSCNSoundEngine procedureNamed:"alcASAGetSource"];
        ALfloat send = 0;
        ALuint sendSize = sizeof(send);
        revenant_check(getSend && getSend('rvsl', reverbHandle, &send, &sendSize) == AL_NO_ERROR, "the reverb send reads back", @"the reverb send cannot be read");
        revenant_expect_number("the reverb send reads back as set", send, 0.5, 1e-4);
        [reverbPlayer revenantStop];

        SCNAudioSource *wet = [[SCNAudioSource alloc] initWithURL:tone];
        wet.volume = 0.5;
        wet.reverbBlend = 0.25;
        SCNAudioPlayer *wetPlayer = revenant_start(wet, SCNVector3Make(0, 0, -2));
        ALuint wetHandle = [wetPlayer revenantSource];
        ALfloat dry = 0;
        alGetSourcef(wetHandle, AL_GAIN, &dry);
        revenant_expect_number("the dry share is the volume times one minus the blend", dry, 0.375, 1e-5);
        ALfloat wetSend = -1;
        ALuint wetSendSize = sizeof(wetSend);
        revenant_check(getSend && getSend('rvsl', wetHandle, &wetSend, &wetSendSize) == AL_NO_ERROR, "the reverb send of a blended source reads back", @"the reverb send cannot be read");
        revenant_expect_number("the reverb send is the blend", wetSend, 0.25, 1e-4);
        wet.reverbBlend = 0;
        [wetPlayer revenantUpdateWithWorld:revenant_at(SCNVector3Make(0, 0, -2)) time:CACurrentMediaTime()];
        alGetSourcef(wetHandle, AL_GAIN, &dry);
        revenant_expect_number("a blend of zero restores the full dry share", dry, 0.5, 1e-5);
        wetSend = -1;
        getSend('rvsl', wetHandle, &wetSend, &wetSendSize);
        revenant_expect_number("a blend of zero clears the reverb send", wetSend, 0, 1e-4);
        [wetPlayer revenantStop];

        revenant_check([SCNAudioSource supportsSecureCoding], "audio sources support secure coding", @"audio sources do not support secure coding");
        SCNAudioSource *coded = [[SCNAudioSource alloc] initWithURL:tone];
        coded.positional = NO;
        coded.volume = 0.5;
        coded.rate = 1.5;
        coded.reverbBlend = 0.25;
        coded.loops = YES;
        coded.shouldStream = YES;
        NSError *codingError = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:coded requiringSecureCoding:YES error:&codingError];
        revenant_check(archive != nil && codingError == nil, "an audio source archives with secure coding", [NSString stringWithFormat:@"archiving failed: %@", codingError]);
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archive error:&codingError];
        unarchiver.requiresSecureCoding = YES;
        [unarchiver setClass:[SCNAudioSource class] forClassName:@"SCNAudioSource"];
        SCNAudioSource *decoded = [unarchiver decodeObjectOfClass:[SCNAudioSource class] forKey:NSKeyedArchiveRootObjectKey];
        [unarchiver finishDecoding];
        revenant_check(decoded != nil && codingError == nil, "an audio source unarchives with secure coding", [NSString stringWithFormat:@"unarchiving failed: %@", codingError]);
        revenant_check(!decoded.positional && decoded.loops && decoded.shouldStream, "the flags survive an archive", @"a flag is lost in the archive");
        revenant_expect_number("the volume survives an archive", decoded.volume, 0.5, 1e-6);
        revenant_expect_number("the rate survives an archive", decoded.rate, 1.5, 1e-6);
        revenant_expect_number("the reverb blend survives an archive", decoded.reverbBlend, 0.25, 1e-6);
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archive options:0 format:NULL error:NULL];
        NSSet *archivedKeys = nil;
        for (id object in plist[@"$objects"]) {
            if ([object isKindOfClass:[NSDictionary class]] && [object objectForKey:@"volume"]) {
                NSMutableSet *keys = [NSMutableSet setWithArray:[object allKeys]];
                [keys removeObject:@"$class"];
                archivedKeys = keys;
            }
        }
        NSSet *appleKeys = [NSSet setWithObjects:@"loops", @"positional", @"rate", @"reverbBlend", @"shouldStream", @"url", @"volume", nil];
        revenant_check([archivedKeys isEqualToSet:appleKeys], "the archive keys are the keys of SceneKit's archive", [NSString stringWithFormat:@"the archive keys are %@", archivedKeys]);

        SCNAudioPlayer *ending = [SCNAudioPlayer audioPlayerWithSource:[[SCNAudioSource alloc] initWithURL:clip]];
        __block BOOL endedOnItsOwn = NO;
        ending.didFinishPlayback = ^{
            endedOnItsOwn = YES;
        };
        [ending revenantStartOnNode:nil];
        CFTimeInterval started = CACurrentMediaTime();
        while (!endedOnItsOwn && CACurrentMediaTime() - started < 2.0) {
            [ending revenantUpdateWithWorld:revenant_at(SCNVector3Make(0, 0, 0)) time:CACurrentMediaTime()];
            usleep(10000);
        }
        revenant_check(endedOnItsOwn, "playback announces its end when the audio finishes", @"didFinishPlayback was not called");
        revenant_check([ending revenantSource] == 0, "a finished player releases its source", @"the finished player kept its source");

        SCNAudioSource *streamTone = [[SCNAudioSource alloc] initWithURL:tone];
        streamTone.positional = NO;
        streamTone.shouldStream = YES;
        SCNAudioSource *plainTone = [[SCNAudioSource alloc] initWithURL:tone];
        plainTone.positional = NO;
        const int pitchRounds = 3;
        double pitchTotal = 0;
        for (int round = 0; round < pitchRounds; round++) {
            SCNAudioPlayer *streaming = [SCNAudioPlayer audioPlayerWithSource:streamTone];
            [streaming revenantStartOnNode:nil];
            double streamedFrequency = revenant_frequency(revenant_capture(0.5));
            [streaming revenantStop];
            SCNAudioPlayer *plainPlayer = [SCNAudioPlayer audioPlayerWithSource:plainTone];
            [plainPlayer revenantStartOnNode:nil];
            double plainFrequency = revenant_frequency(revenant_capture(0.5));
            [plainPlayer revenantStop];
            pitchTotal += streamedFrequency / plainFrequency;
        }
        revenant_expect_number("a streamed tone keeps the pitch of the same tone loaded in memory", pitchTotal / pitchRounds, 1, 0.02);

        revenant_hold_listener(SCNVector3Make(0, 0, 0));
        SCNAudioSource *streamedPan = [[SCNAudioSource alloc] initWithURL:tone];
        streamedPan.shouldStream = YES;
        SCNAudioPlayer *panRight = [SCNAudioPlayer audioPlayerWithSource:streamedPan];
        [panRight revenantStartOnNode:nil];
        [panRight revenantUpdateWithWorld:revenant_at(SCNVector3Make(2, 0, 0)) time:CACurrentMediaTime()];
        NSData *streamRightData = revenant_capture(0.25);
        [panRight revenantStop];
        revenant_check(revenant_rms(streamRightData, 1) > revenant_rms(streamRightData, 0) * 1.2, "a streamed source to the listener's right is louder on the right", @"the streamed right channel is not louder");

        SCNAudioSource *streamedClip = [[SCNAudioSource alloc] initWithURL:clip];
        streamedClip.shouldStream = YES;
        __block BOOL streamEnded = NO;
        SCNAudioPlayer *streamEnding = [SCNAudioPlayer audioPlayerWithSource:streamedClip];
        streamEnding.didFinishPlayback = ^{
            streamEnded = YES;
        };
        [streamEnding revenantStartOnNode:nil];
        CFTimeInterval streamStarted = CACurrentMediaTime();
        while (!streamEnded && CACurrentMediaTime() - streamStarted < 2.0) {
            [streamEnding revenantUpdateWithWorld:revenant_at(SCNVector3Make(0, 0, 0)) time:CACurrentMediaTime()];
            usleep(10000);
        }
        revenant_check(streamEnded && [streamEnding revenantSource] == 0, "a streamed clip announces its end and releases its source", @"a streamed clip did not finish");

        SCNAudioSource *loopingClip = [[SCNAudioSource alloc] initWithURL:clip];
        loopingClip.shouldStream = YES;
        loopingClip.loops = YES;
        __block BOOL loopEnded = NO;
        SCNAudioPlayer *loopingStream = [SCNAudioPlayer audioPlayerWithSource:loopingClip];
        loopingStream.didFinishPlayback = ^{
            loopEnded = YES;
        };
        [loopingStream revenantStartOnNode:nil];
        CFTimeInterval loopStarted = CACurrentMediaTime();
        while (CACurrentMediaTime() - loopStarted < 0.6) {
            [loopingStream revenantUpdateWithWorld:revenant_at(SCNVector3Make(0, 0, 0)) time:CACurrentMediaTime()];
            usleep(10000);
        }
        revenant_check(!loopEnded && [loopingStream revenantIsPlaying], "a looping stream keeps playing past the end of its clip", @"a looping stream stopped");
        [loopingStream revenantStop];

        AVAudioPlayerNode *customNode = [[AVAudioPlayerNode alloc] init];
        SCNAudioPlayer *nodePlayer = [SCNAudioPlayer audioPlayerWithAVAudioNode:customNode];
        revenant_check(nodePlayer.audioNode == customNode, "a node player returns its node", @"the node player lost its node");
        revenant_check(nodePlayer.audioSource == nil, "a node player has no source", @"the node player has a source");
        [nodePlayer revenantStartOnNode:nil];
        revenant_check(customNode.engine != nil, "a started node player attaches its node to the engine", @"the node is not attached");
        [nodePlayer revenantStop];
        revenant_check(customNode.engine == nil, "a stopped node player detaches its node", @"the node is still attached");

        [[NSFileManager defaultManager] removeItemAtPath:fixtures error:NULL];
        revenant_check(revenant_negative ? NO : YES, "negative control", @"the negative control is inverted");
    }
    return revenant_finish();
}
