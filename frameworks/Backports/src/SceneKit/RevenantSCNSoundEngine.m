#import "RevenantSCNSoundEngine.h"
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <math.h>

typedef ALenum (*RevenantASASetListenerProc)(ALuint property, ALvoid *data, ALuint dataSize);
typedef ALenum (*RevenantASASetSourceProc)(ALuint property, ALuint source, ALvoid *data, ALuint dataSize);

#define REVENANT_ASA_REVERB_ON 'rvon'
#define REVENANT_ASA_REVERB_SEND_LEVEL 'rvsl'

static ALCdevice *revenant_device;
static ALCcontext *revenant_context;
static RevenantASASetListenerProc revenant_set_listener;
static RevenantASASetSourceProc revenant_set_source;
static BOOL revenant_has_previous;
static SCNVector3 revenant_previous_position;
static CFTimeInterval revenant_previous_time;
static AVAudioEngine *revenant_node_engine;

static SCNVector3 revenant_normalized(SCNVector3 v)
{
    float length = sqrtf(v.x * v.x + v.y * v.y + v.z * v.z);
    if (length <= 0) {
        return SCNVector3Make(0, 0, 0);
    }
    return SCNVector3Make(v.x / length, v.y / length, v.z / length);
}

@implementation RevenantSCNSoundEngine

+ (BOOL)isActive
{
    return revenant_context != NULL;
}

+ (AVAudioEngine *)nodeEngine
{
    if (revenant_node_engine == nil) {
        revenant_node_engine = [[AVAudioEngine alloc] init];
    }
    return revenant_node_engine;
}

+ (void)prepare
{
    if (revenant_context) {
        return;
    }
    ALCdevice *device = alcOpenDevice(NULL);
    ALCcontext *context = device ? alcCreateContext(device, NULL) : NULL;
    if (context == NULL) {
        if (device) {
            alcCloseDevice(device);
        }
        [NSException raise:NSInternalInconsistencyException format:@"SCNAudioPlayer: OpenAL has no output device"];
    }
    revenant_device = device;
    revenant_context = context;
    alcMakeContextCurrent(context);
    alDistanceModel(AL_INVERSE_DISTANCE_CLAMPED);
    revenant_set_listener = (RevenantASASetListenerProc)alcGetProcAddress(device, "alcASASetListener");
    revenant_set_source = (RevenantASASetSourceProc)alcGetProcAddress(device, "alcASASetSource");
    if (revenant_set_listener) {
        ALuint on = 1;
        revenant_set_listener(REVENANT_ASA_REVERB_ON, &on, sizeof(on));
    }
}

+ (void)setListenerWorld:(SCNMatrix4)world atTime:(CFTimeInterval)now
{
    if (revenant_context == NULL) {
        return;
    }
    SCNVector3 position = SCNVector3Make(world.m41, world.m42, world.m43);
    SCNVector3 velocity = SCNVector3Make(0, 0, 0);
    if (revenant_has_previous && now > revenant_previous_time) {
        CFTimeInterval dt = now - revenant_previous_time;
        velocity = SCNVector3Make((position.x - revenant_previous_position.x) / dt,
                                  (position.y - revenant_previous_position.y) / dt,
                                  (position.z - revenant_previous_position.z) / dt);
    }
    SCNVector3 forward = revenant_normalized(SCNVector3Make(-world.m31, -world.m32, -world.m33));
    SCNVector3 up = revenant_normalized(SCNVector3Make(world.m21, world.m22, world.m23));
    alListener3f(AL_POSITION, position.x, position.y, position.z);
    alListener3f(AL_VELOCITY, velocity.x, velocity.y, velocity.z);
    ALfloat orientation[6] = {forward.x, forward.y, forward.z, up.x, up.y, up.z};
    alListenerfv(AL_ORIENTATION, orientation);
    revenant_has_previous = YES;
    revenant_previous_position = position;
    revenant_previous_time = now;
}

+ (unsigned int)newBuffer:(NSData *)data channels:(unsigned int)channels sampleRate:(double)sampleRate
{
    ALuint buffer = 0;
    alGenBuffers(1, &buffer);
    ALenum format = channels == 1 ? AL_FORMAT_MONO16 : AL_FORMAT_STEREO16;
    alBufferData(buffer, format, data.bytes, (ALsizei)data.length, (ALsizei)sampleRate);
    return buffer;
}

+ (void)deleteBuffer:(unsigned int)buffer
{
    if (buffer && revenant_context) {
        alDeleteBuffers(1, &buffer);
    }
}

+ (unsigned int)newSourceWithBuffer:(unsigned int)buffer relative:(BOOL)relative
{
    ALuint source = 0;
    alGenSources(1, &source);
    if (source == 0) {
        return 0;
    }
    alSourcei(source, AL_BUFFER, buffer);
    alSourcei(source, AL_SOURCE_RELATIVE, relative ? AL_TRUE : AL_FALSE);
    alSourcef(source, AL_REFERENCE_DISTANCE, 1);
    alSourcef(source, AL_MAX_DISTANCE, 100000);
    alSourcef(source, AL_ROLLOFF_FACTOR, 1);
    return source;
}

+ (void)deleteSource:(unsigned int)source
{
    if (source && revenant_context) {
        alSourceStop(source);
        alDeleteSources(1, &source);
    }
}

+ (void)setSource:(unsigned int)source position:(SCNVector3)position velocity:(SCNVector3)velocity
{
    alSource3f(source, AL_POSITION, position.x, position.y, position.z);
    alSource3f(source, AL_VELOCITY, velocity.x, velocity.y, velocity.z);
}

+ (nullable void *)procedureNamed:(const char *)name
{
    return revenant_device ? alcGetProcAddress(revenant_device, name) : NULL;
}

+ (BOOL)supportsReverb
{
    return revenant_set_source != NULL;
}

+ (BOOL)setSource:(unsigned int)source reverbSend:(float)level
{
    if (revenant_set_source == NULL) {
        return NO;
    }
    ALfloat send = fminf(fmaxf(level, 0), 1);
    return revenant_set_source(REVENANT_ASA_REVERB_SEND_LEVEL, source, &send, sizeof(send)) == AL_NO_ERROR;
}

+ (BOOL)probeURL:(NSURL *)url sampleRate:(double *)sampleRate frames:(unsigned long long *)frames
{
    ExtAudioFileRef file = NULL;
    if (ExtAudioFileOpenURL((__bridge CFURLRef)url, &file) != noErr || file == NULL) {
        return NO;
    }
    AudioStreamBasicDescription fileFormat;
    UInt32 size = sizeof(fileFormat);
    SInt64 length = 0;
    UInt32 lengthSize = sizeof(length);
    BOOL ok = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat) == noErr &&
              ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &lengthSize, &length) == noErr;
    ExtAudioFileDispose(file);
    if (ok) {
        *sampleRate = fileFormat.mSampleRate;
        *frames = (unsigned long long)length;
    }
    return ok;
}

+ (nullable NSData *)decodeURL:(NSURL *)url channels:(unsigned int)channels sampleRate:(double *)sampleRate frames:(unsigned long long *)frames
{
    ExtAudioFileRef file = NULL;
    if (ExtAudioFileOpenURL((__bridge CFURLRef)url, &file) != noErr || file == NULL) {
        return nil;
    }
    AudioStreamBasicDescription fileFormat;
    UInt32 size = sizeof(fileFormat);
    SInt64 length = 0;
    UInt32 lengthSize = sizeof(length);
    if (ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat) != noErr ||
        ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &lengthSize, &length) != noErr) {
        ExtAudioFileDispose(file);
        return nil;
    }
    AudioStreamBasicDescription client = {0};
    client.mSampleRate = fileFormat.mSampleRate;
    client.mFormatID = kAudioFormatLinearPCM;
    client.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
    client.mChannelsPerFrame = channels;
    client.mBitsPerChannel = 16;
    client.mBytesPerFrame = 2 * channels;
    client.mBytesPerPacket = 2 * channels;
    client.mFramesPerPacket = 1;
    if (ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(client), &client) != noErr) {
        ExtAudioFileDispose(file);
        return nil;
    }
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)(length * client.mBytesPerFrame)];
    AudioBufferList list;
    list.mNumberBuffers = 1;
    list.mBuffers[0].mNumberChannels = channels;
    list.mBuffers[0].mDataByteSize = (UInt32)data.length;
    list.mBuffers[0].mData = data.mutableBytes;
    UInt32 read = (UInt32)length;
    OSStatus status = ExtAudioFileRead(file, &read, &list);
    ExtAudioFileDispose(file);
    if (status != noErr) {
        return nil;
    }
    data.length = (NSUInteger)(read * client.mBytesPerFrame);
    if (sampleRate) {
        *sampleRate = client.mSampleRate;
    }
    if (frames) {
        *frames = read;
    }
    return data;
}

@end
