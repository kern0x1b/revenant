#import "RevenantSCNStream.h"
#import "RevenantSCNSoundEngine.h"
#import <OpenAL/al.h>
#import <AudioToolbox/AudioToolbox.h>

#define RevenantSCNStreamBuffers 4
static const UInt32 RevenantSCNStreamChunkFrames = 16384;

@implementation RevenantSCNStream
{
    ExtAudioFileRef _file;
    unsigned int _channels;
    UInt32 _bytesPerFrame;
    double _sampleRate;
    ALuint _buffers[RevenantSCNStreamBuffers];
    NSUInteger _bufferCount;
    NSMutableData *_chunk;
    BOOL _endOfFile;
}

- (instancetype)initWithURL:(NSURL *)url channels:(unsigned int)channels
{
    ExtAudioFileRef file = NULL;
    if (ExtAudioFileOpenURL((__bridge CFURLRef)url, &file) != noErr || file == NULL) {
        return nil;
    }
    AudioStreamBasicDescription fileFormat;
    UInt32 size = sizeof(fileFormat);
    if (ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat) != noErr) {
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
    if ((self = [super init])) {
        _file = file;
        _channels = channels;
        _bytesPerFrame = client.mBytesPerFrame;
        _sampleRate = client.mSampleRate;
        _chunk = [NSMutableData dataWithLength:RevenantSCNStreamChunkFrames * client.mBytesPerFrame];
    } else {
        ExtAudioFileDispose(file);
    }
    return self;
}

- (void)dealloc
{
    [self dispose];
}

- (UInt32)readFrames:(UInt32)frames intoBytes:(void *)bytes loops:(BOOL)loops
{
    UInt32 total = 0;
    BOOL rewound = NO;
    while (total < frames) {
        UInt32 read = frames - total;
        AudioBufferList list;
        list.mNumberBuffers = 1;
        list.mBuffers[0].mNumberChannels = _channels;
        list.mBuffers[0].mDataByteSize = read * _bytesPerFrame;
        list.mBuffers[0].mData = (char *)bytes + total * _bytesPerFrame;
        if (ExtAudioFileRead(_file, &read, &list) != noErr) {
            _endOfFile = YES;
            break;
        }
        if (read > 0) {
            total += read;
            rewound = NO;
            continue;
        }
        if (!loops || rewound) {
            _endOfFile = YES;
            break;
        }
        ExtAudioFileSeek(_file, 0);
        rewound = YES;
    }
    return total;
}

- (BOOL)fillBuffer:(ALuint)buffer loops:(BOOL)loops
{
    UInt32 frames = [self readFrames:RevenantSCNStreamChunkFrames intoBytes:_chunk.mutableBytes loops:loops];
    if (frames == 0) {
        return NO;
    }
    alBufferData(buffer, _channels == 1 ? AL_FORMAT_MONO16 : AL_FORMAT_STEREO16, _chunk.bytes,
                 (ALsizei)(frames * _bytesPerFrame), (ALsizei)_sampleRate);
    return YES;
}

- (void)primeSource:(unsigned int)source loops:(BOOL)loops
{
    if (_bufferCount == 0) {
        alGenBuffers(RevenantSCNStreamBuffers, _buffers);
        _bufferCount = RevenantSCNStreamBuffers;
    }
    for (NSUInteger index = 0; index < _bufferCount; index++) {
        if ([self fillBuffer:_buffers[index] loops:loops]) {
            alSourceQueueBuffers(source, 1, &_buffers[index]);
        }
    }
}

- (void)refillSource:(unsigned int)source loops:(BOOL)loops
{
    ALint processed = 0;
    alGetSourcei(source, AL_BUFFERS_PROCESSED, &processed);
    while (processed-- > 0) {
        ALuint buffer = 0;
        alSourceUnqueueBuffers(source, 1, &buffer);
        if ([self fillBuffer:buffer loops:loops]) {
            alSourceQueueBuffers(source, 1, &buffer);
        }
    }
}

- (BOOL)isExhaustedOnSource:(unsigned int)source
{
    ALint queued = 0;
    alGetSourcei(source, AL_BUFFERS_QUEUED, &queued);
    return _endOfFile && queued == 0;
}

- (void)dispose
{
    if (_file) {
        ExtAudioFileDispose(_file);
        _file = NULL;
    }
    if (_bufferCount && [RevenantSCNSoundEngine isActive]) {
        alDeleteBuffers((ALsizei)_bufferCount, _buffers);
    }
    _bufferCount = 0;
}

@end
