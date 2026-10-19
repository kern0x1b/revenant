#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioTypes.h>
#import <AVFAudio/AVAudioSettings.h>

// AVAudioFormat wraps a Core Audio AudioStreamBasicDescription, and iOS 6 carries Core Audio in
// full - the struct, the format IDs and flags, and every function that reads one, all the way
// down to the device's own AUGraph. Nothing here is emulated: the ASBD this class holds is one
// AudioUnitSetProperty or AudioConverterNew already knows how to read, because it is exactly the
// struct those calls have always taken. The four common formats (deinterleaved and interleaved
// float32/float64/int16/int32) are the only ones this port builds by hand; more than two channels
// without an explicit AVAudioChannelLayout is refused, matching the real class's own documented
// behaviour, since this port carries no AVAudioChannelLayout to describe a wider layout with.

@implementation AVAudioFormat

- (instancetype)initWithStreamDescription:(const AudioStreamBasicDescription *)asbd
{
    return [self initWithStreamDescription:asbd channelLayout:nil];
}

- (instancetype)initWithStreamDescription:(const AudioStreamBasicDescription *)asbd channelLayout:(AVAudioChannelLayout *)layout
{
    if (!asbd)
        return nil;
    if (asbd->mChannelsPerFrame > 2 && !layout)
        return nil;
    if ((self = [super init])) {
        _asbd = *asbd;
        _layout = layout;
        if (_asbd.mFormatID == kAudioFormatLinearPCM) {
            BOOL isFloat = (_asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0;
            BOOL nonInterleaved = (_asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
            if (isFloat && _asbd.mBitsPerChannel == 32)
                _commonFormat = AVAudioPCMFormatFloat32;
            else if (isFloat && _asbd.mBitsPerChannel == 64)
                _commonFormat = AVAudioPCMFormatFloat64;
            else if (!isFloat && _asbd.mBitsPerChannel == 16)
                _commonFormat = AVAudioPCMFormatInt16;
            else if (!isFloat && _asbd.mBitsPerChannel == 32)
                _commonFormat = AVAudioPCMFormatInt32;
            else
                _commonFormat = AVAudioOtherFormat;
            (void)nonInterleaved;
        } else {
            _commonFormat = AVAudioOtherFormat;
        }
    }
    return self;
}

// The only place the four common formats turn into an ASBD by hand: everywhere else in this
// class either takes a caller's own ASBD or defers to this.
static void charon_fillASBD(AudioStreamBasicDescription *asbd, AVAudioCommonFormat format, double sampleRate, AVAudioChannelCount channels, BOOL interleaved)
{
    memset(asbd, 0, sizeof(*asbd));
    asbd->mSampleRate = sampleRate;
    asbd->mFormatID = kAudioFormatLinearPCM;
    asbd->mFramesPerPacket = 1;
    asbd->mChannelsPerFrame = channels;
    UInt32 bitsPerChannel;
    UInt32 flags = kAudioFormatFlagIsPacked;
    switch (format) {
        case AVAudioPCMFormatFloat64:
            bitsPerChannel = 64;
            flags |= kAudioFormatFlagIsFloat;
            break;
        case AVAudioPCMFormatInt16:
            bitsPerChannel = 16;
            flags |= kAudioFormatFlagIsSignedInteger;
            break;
        case AVAudioPCMFormatInt32:
            bitsPerChannel = 32;
            flags |= kAudioFormatFlagIsSignedInteger;
            break;
        case AVAudioPCMFormatFloat32:
        default:
            bitsPerChannel = 32;
            flags |= kAudioFormatFlagIsFloat;
            break;
    }
    if (!interleaved)
        flags |= kAudioFormatFlagIsNonInterleaved;
    asbd->mFormatFlags = flags;
    asbd->mBitsPerChannel = bitsPerChannel;
    // Non-interleaved PCM's ASBD describes one buffer of the AudioBufferList, which holds one
    // channel - the convention every Core Audio unit on this device already reads bytesPerFrame
    // this way, not a choice this port invented.
    UInt32 bytesPerSample = bitsPerChannel / 8;
    asbd->mBytesPerFrame = interleaved ? bytesPerSample * channels : bytesPerSample;
    asbd->mBytesPerPacket = asbd->mBytesPerFrame;
}

- (instancetype)initStandardFormatWithSampleRate:(double)sampleRate channels:(AVAudioChannelCount)channels
{
    if (channels > 2)
        return nil;
    AudioStreamBasicDescription asbd;
    charon_fillASBD(&asbd, AVAudioPCMFormatFloat32, sampleRate, channels, NO);
    return [self initWithStreamDescription:&asbd];
}

- (instancetype)initStandardFormatWithSampleRate:(double)sampleRate channelLayout:(AVAudioChannelLayout *)layout
{
    if (!layout)
        return nil;
    AudioStreamBasicDescription asbd;
    charon_fillASBD(&asbd, AVAudioPCMFormatFloat32, sampleRate, [layout channelCount], NO);
    return [self initWithStreamDescription:&asbd channelLayout:layout];
}

- (instancetype)initWithCommonFormat:(AVAudioCommonFormat)format sampleRate:(double)sampleRate channels:(AVAudioChannelCount)channels interleaved:(BOOL)interleaved
{
    if (channels > 2 || format == AVAudioOtherFormat)
        return nil;
    AudioStreamBasicDescription asbd;
    charon_fillASBD(&asbd, format, sampleRate, channels, interleaved);
    return [self initWithStreamDescription:&asbd];
}

- (instancetype)initWithCommonFormat:(AVAudioCommonFormat)format sampleRate:(double)sampleRate interleaved:(BOOL)interleaved channelLayout:(AVAudioChannelLayout *)layout
{
    if (!layout || format == AVAudioOtherFormat)
        return nil;
    AudioStreamBasicDescription asbd;
    charon_fillASBD(&asbd, format, sampleRate, [layout channelCount], interleaved);
    return [self initWithStreamDescription:&asbd channelLayout:layout];
}

- (instancetype)initWithSettings:(NSDictionary<NSString *, id> *)settings
{
    NSNumber *formatID = settings[AVFormatIDKey];
    if (formatID && [formatID unsignedIntValue] != kAudioFormatLinearPCM)
        return nil;
    double sampleRate = [settings[AVSampleRateKey] doubleValue];
    AVAudioChannelCount channels = (AVAudioChannelCount)[settings[AVNumberOfChannelsKey] unsignedIntValue];
    if (channels > 2 || sampleRate <= 0)
        return nil;
    NSInteger bits = [settings[AVLinearPCMBitDepthKey] integerValue] ?: 16;
    BOOL isFloat = [settings[AVLinearPCMIsFloatKey] boolValue];
    BOOL nonInterleaved = [settings[AVLinearPCMIsNonInterleaved] boolValue];
    AVAudioCommonFormat format;
    if (isFloat && bits == 64)
        format = AVAudioPCMFormatFloat64;
    else if (isFloat)
        format = AVAudioPCMFormatFloat32;
    else if (bits == 32)
        format = AVAudioPCMFormatInt32;
    else if (bits == 16)
        format = AVAudioPCMFormatInt16;
    else
        return nil;
    return [self initWithCommonFormat:format sampleRate:sampleRate channels:channels interleaved:!nonInterleaved];
}

@dynamic standard, commonFormat, channelCount, sampleRate, interleaved, streamDescription, channelLayout, settings;

- (BOOL)isStandard
{
    return _commonFormat == AVAudioPCMFormatFloat32 && ![self isInterleaved];
}

- (AVAudioCommonFormat)commonFormat
{
    return _commonFormat;
}

- (AVAudioChannelCount)channelCount
{
    return _asbd.mChannelsPerFrame;
}

- (double)sampleRate
{
    return _asbd.mSampleRate;
}

- (BOOL)isInterleaved
{
    return (_asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0;
}

- (const AudioStreamBasicDescription *)streamDescription
{
    return &_asbd;
}

- (AVAudioChannelLayout *)channelLayout
{
    return _layout;
}

- (NSDictionary<NSString *, id> *)settings
{
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    settings[AVFormatIDKey] = @(_asbd.mFormatID);
    settings[AVSampleRateKey] = @(_asbd.mSampleRate);
    settings[AVNumberOfChannelsKey] = @(_asbd.mChannelsPerFrame);
    settings[AVLinearPCMBitDepthKey] = @(_asbd.mBitsPerChannel);
    settings[AVLinearPCMIsFloatKey] = @((_asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0);
    settings[AVLinearPCMIsBigEndianKey] = @((_asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) != 0);
    settings[AVLinearPCMIsNonInterleaved] = @((_asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0);
    return settings;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[AVAudioFormat class]])
        return NO;
    AVAudioFormat *other = object;
    const AudioStreamBasicDescription *a = &_asbd, *b = [other streamDescription];
    return a->mSampleRate == b->mSampleRate && a->mFormatID == b->mFormatID && a->mFormatFlags == b->mFormatFlags &&
           a->mBytesPerPacket == b->mBytesPerPacket && a->mFramesPerPacket == b->mFramesPerPacket &&
           a->mBytesPerFrame == b->mBytesPerFrame && a->mChannelsPerFrame == b->mChannelsPerFrame &&
           a->mBitsPerChannel == b->mBitsPerChannel;
}

- (NSUInteger)hash
{
    return (NSUInteger)_asbd.mSampleRate ^ _asbd.mFormatID ^ _asbd.mChannelsPerFrame ^ _asbd.mBitsPerChannel;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVAudioFormat %p: %u ch, %gHz, %@%@>", self, (unsigned)_asbd.mChannelsPerFrame, _asbd.mSampleRate,
                                      [self isStandard] ? @"Float32" : @(_commonFormat), [self isInterleaved] ? @", interleaved" : @""];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
