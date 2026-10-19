#import <AVFAudio/AVAudioConverter.h>
#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioBuffer.h>
#import <AudioToolbox/AudioToolbox.h>

static const OSStatus kCharonConverterNoDataNow = 'noda';

typedef struct {
    __unsafe_unretained AVAudioConverterInputBlock block;
    BOOL reachedEnd;
} CharonConverterInputContext;

static OSStatus CharonConverterInputProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,
                                          AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    CharonConverterInputContext *ctx = (CharonConverterInputContext *)inUserData;
    if (ctx->reachedEnd) {
        *ioNumberDataPackets = 0;
        return noErr;
    }
    AVAudioConverterInputStatus status = AVAudioConverterInputStatus_NoDataNow;
    AVAudioBuffer *buffer = ctx->block(*ioNumberDataPackets, &status);
    if (status == AVAudioConverterInputStatus_HaveData && buffer != nil) {
        AudioBufferList *source = buffer.mutableAudioBufferList;
        memcpy(ioData, source, sizeof(AudioBufferList) + (source->mNumberBuffers - 1) * sizeof(AudioBuffer));
        *ioNumberDataPackets = [(AVAudioPCMBuffer *)buffer frameLength];
        return noErr;
    }
    *ioNumberDataPackets = 0;
    if (status == AVAudioConverterInputStatus_EndOfStream) {
        ctx->reachedEnd = YES;
        return noErr;
    }
    return kCharonConverterNoDataNow;
}

@implementation AVAudioConverter {
    AudioConverterRef _charon_converter;
    AVAudioFormat *_charon_inputFormat;
    AVAudioFormat *_charon_outputFormat;
    NSArray<NSNumber *> *_charon_channelMap;
    NSData *_charon_magicCookie;
    BOOL _charon_downmix;
    BOOL _charon_dither;
    NSInteger _charon_sampleRateConverterQuality;
    NSString *_charon_sampleRateConverterAlgorithm;
    AVAudioConverterPrimeMethod _charon_primeMethod;
    AVAudioConverterPrimeInfo _charon_primeInfo;
    NSInteger _charon_bitRate;
    NSString *_charon_bitRateStrategy;
}

- (instancetype)initFromFormat:(AVAudioFormat *)fromFormat toFormat:(AVAudioFormat *)toFormat
{
    if ((self = [super init])) {
        AudioConverterRef converter = NULL;
        OSStatus status = AudioConverterNew([fromFormat streamDescription], [toFormat streamDescription], &converter);
        if (status != noErr)
            return nil;
        _charon_converter = converter;
        _charon_inputFormat = fromFormat;
        _charon_outputFormat = toFormat;
        _charon_primeMethod = AVAudioConverterPrimeMethod_Normal;
    }
    return self;
}

- (void)dealloc
{
    if (_charon_converter)
        AudioConverterDispose(_charon_converter);
}

- (void)reset
{
    AudioConverterReset(_charon_converter);
}

- (AVAudioFormat *)inputFormat
{
    return _charon_inputFormat;
}

- (AVAudioFormat *)outputFormat
{
    return _charon_outputFormat;
}

- (NSArray<NSNumber *> *)channelMap
{
    return _charon_channelMap;
}

- (void)setChannelMap:(NSArray<NSNumber *> *)channelMap
{
    _charon_channelMap = [channelMap copy];
    NSUInteger count = channelMap.count;
    SInt32 *map = malloc(count * sizeof(SInt32));
    for (NSUInteger i = 0; i < count; i++)
        map[i] = [channelMap[i] intValue];
    AudioConverterSetProperty(_charon_converter, kAudioConverterChannelMap, (UInt32)(count * sizeof(SInt32)), map);
    free(map);
}

- (NSData *)magicCookie
{
    return _charon_magicCookie;
}

- (void)setMagicCookie:(NSData *)magicCookie
{
    _charon_magicCookie = [magicCookie copy];
}

- (BOOL)downmix
{
    return _charon_downmix;
}

- (void)setDownmix:(BOOL)downmix
{
    _charon_downmix = downmix;
}

- (BOOL)dither
{
    return _charon_dither;
}

- (void)setDither:(BOOL)dither
{
    _charon_dither = dither;
}

- (NSInteger)sampleRateConverterQuality
{
    return _charon_sampleRateConverterQuality;
}

- (void)setSampleRateConverterQuality:(NSInteger)sampleRateConverterQuality
{
    _charon_sampleRateConverterQuality = sampleRateConverterQuality;
    UInt32 value = (UInt32)sampleRateConverterQuality;
    AudioConverterSetProperty(_charon_converter, kAudioConverterSampleRateConverterQuality, sizeof(value), &value);
}

- (NSString *)sampleRateConverterAlgorithm
{
    return _charon_sampleRateConverterAlgorithm;
}

- (void)setSampleRateConverterAlgorithm:(NSString *)sampleRateConverterAlgorithm
{
    _charon_sampleRateConverterAlgorithm = [sampleRateConverterAlgorithm copy];
    if (sampleRateConverterAlgorithm)
        AudioConverterSetProperty(_charon_converter, kAudioConverterSampleRateConverterAlgorithm, sizeof(CFStringRef), (__bridge const void *)sampleRateConverterAlgorithm);
}

- (AVAudioConverterPrimeMethod)primeMethod
{
    return _charon_primeMethod;
}

- (void)setPrimeMethod:(AVAudioConverterPrimeMethod)primeMethod
{
    _charon_primeMethod = primeMethod;
    UInt32 value = (UInt32)primeMethod;
    AudioConverterSetProperty(_charon_converter, kAudioConverterPrimeMethod, sizeof(value), &value);
}

- (AVAudioConverterPrimeInfo)primeInfo
{
    return _charon_primeInfo;
}

- (void)setPrimeInfo:(AVAudioConverterPrimeInfo)primeInfo
{
    _charon_primeInfo = primeInfo;
    AudioConverterPrimeInfo real = {.leadingFrames = primeInfo.leadingFrames, .trailingFrames = primeInfo.trailingFrames};
    AudioConverterSetProperty(_charon_converter, kAudioConverterPrimeInfo, sizeof(real), &real);
}

- (BOOL)convertToBuffer:(AVAudioPCMBuffer *)outputBuffer fromBuffer:(const AVAudioPCMBuffer *)inputBuffer error:(NSError **)outError
{
    [outputBuffer setFrameLength:[inputBuffer frameLength]];
    OSStatus status = AudioConverterConvertComplexBuffer(_charon_converter, [inputBuffer frameLength],
                                                          [inputBuffer audioBufferList], [outputBuffer mutableAudioBufferList]);
    if (status != noErr) {
        if (outError)
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return NO;
    }
    return YES;
}

- (AVAudioConverterOutputStatus)convertToBuffer:(AVAudioBuffer *)outputBuffer error:(NSError **)outError withInputFromBlock:(AVAudioConverterInputBlock)inputBlock
{
    AVAudioPCMBuffer *pcmOutput = (AVAudioPCMBuffer *)outputBuffer;
    CharonConverterInputContext ctx = {.block = inputBlock, .reachedEnd = NO};
    UInt32 packetCount = [pcmOutput frameCapacity];
    [pcmOutput setFrameLength:packetCount];
    OSStatus status = AudioConverterFillComplexBuffer(_charon_converter, CharonConverterInputProc, &ctx, &packetCount,
                                                       [pcmOutput mutableAudioBufferList], NULL);
    [pcmOutput setFrameLength:packetCount];
    if (status != noErr && status != kCharonConverterNoDataNow) {
        if (outError)
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return AVAudioConverterOutputStatus_Error;
    }
    if (ctx.reachedEnd && packetCount == 0)
        return AVAudioConverterOutputStatus_EndOfStream;
    if (status == kCharonConverterNoDataNow)
        return AVAudioConverterOutputStatus_InputRanDry;
    return AVAudioConverterOutputStatus_HaveData;
}

@end

@implementation AVAudioConverter (Encoding)

- (NSInteger)bitRate
{
    return _charon_bitRate;
}

- (void)setBitRate:(NSInteger)bitRate
{
    _charon_bitRate = bitRate;
    UInt32 value = (UInt32)bitRate;
    AudioConverterSetProperty(_charon_converter, kAudioConverterEncodeBitRate, sizeof(value), &value);
}

- (NSString *)bitRateStrategy
{
    return _charon_bitRateStrategy;
}

- (void)setBitRateStrategy:(NSString *)bitRateStrategy
{
    _charon_bitRateStrategy = [bitRateStrategy copy];
}

- (NSInteger)maximumOutputPacketSize
{
    return 0;
}

- (NSArray<NSNumber *> *)availableEncodeBitRates
{
    return nil;
}

- (NSArray<NSNumber *> *)applicableEncodeBitRates
{
    return nil;
}

- (NSArray<NSNumber *> *)availableEncodeSampleRates
{
    return nil;
}

- (NSArray<NSNumber *> *)applicableEncodeSampleRates
{
    return nil;
}

- (NSArray<NSNumber *> *)availableEncodeChannelLayoutTags
{
    return nil;
}

@end
