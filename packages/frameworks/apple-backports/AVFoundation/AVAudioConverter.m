#import <AVFAudio/AVAudioConverter.h>
#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioBuffer.h>
#import <AudioToolbox/AudioToolbox.h>

static const OSStatus kRevenantConverterNoDataNow = 'noda';

typedef struct {
    __unsafe_unretained AVAudioConverterInputBlock block;
    BOOL reachedEnd;
} RevenantConverterInputContext;

static OSStatus RevenantConverterInputProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,
                                          AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    RevenantConverterInputContext *ctx = (RevenantConverterInputContext *)inUserData;
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
    return kRevenantConverterNoDataNow;
}

@implementation AVAudioConverter {
    AudioConverterRef _revenant_converter;
    AVAudioFormat *_revenant_inputFormat;
    AVAudioFormat *_revenant_outputFormat;
    NSArray<NSNumber *> *_revenant_channelMap;
    NSData *_revenant_magicCookie;
    BOOL _revenant_downmix;
    BOOL _revenant_dither;
    NSInteger _revenant_sampleRateConverterQuality;
    NSString *_revenant_sampleRateConverterAlgorithm;
    AVAudioConverterPrimeMethod _revenant_primeMethod;
    AVAudioConverterPrimeInfo _revenant_primeInfo;
    NSInteger _revenant_bitRate;
    NSString *_revenant_bitRateStrategy;
}

- (instancetype)initFromFormat:(AVAudioFormat *)fromFormat toFormat:(AVAudioFormat *)toFormat
{
    if ((self = [super init])) {
        AudioConverterRef converter = NULL;
        OSStatus status = AudioConverterNew([fromFormat streamDescription], [toFormat streamDescription], &converter);
        if (status != noErr)
            return nil;
        _revenant_converter = converter;
        _revenant_inputFormat = fromFormat;
        _revenant_outputFormat = toFormat;
        _revenant_primeMethod = AVAudioConverterPrimeMethod_Normal;
    }
    return self;
}

- (void)dealloc
{
    if (_revenant_converter)
        AudioConverterDispose(_revenant_converter);
}

- (void)reset
{
    AudioConverterReset(_revenant_converter);
}

- (AVAudioFormat *)inputFormat
{
    return _revenant_inputFormat;
}

- (AVAudioFormat *)outputFormat
{
    return _revenant_outputFormat;
}

- (NSArray<NSNumber *> *)channelMap
{
    return _revenant_channelMap;
}

- (void)setChannelMap:(NSArray<NSNumber *> *)channelMap
{
    _revenant_channelMap = [channelMap copy];
    NSUInteger count = channelMap.count;
    SInt32 *map = malloc(count * sizeof(SInt32));
    for (NSUInteger i = 0; i < count; i++)
        map[i] = [channelMap[i] intValue];
    AudioConverterSetProperty(_revenant_converter, kAudioConverterChannelMap, (UInt32)(count * sizeof(SInt32)), map);
    free(map);
}

- (NSData *)magicCookie
{
    return _revenant_magicCookie;
}

- (void)setMagicCookie:(NSData *)magicCookie
{
    _revenant_magicCookie = [magicCookie copy];
}

- (BOOL)downmix
{
    return _revenant_downmix;
}

- (void)setDownmix:(BOOL)downmix
{
    _revenant_downmix = downmix;
}

- (BOOL)dither
{
    return _revenant_dither;
}

- (void)setDither:(BOOL)dither
{
    _revenant_dither = dither;
}

- (NSInteger)sampleRateConverterQuality
{
    return _revenant_sampleRateConverterQuality;
}

- (void)setSampleRateConverterQuality:(NSInteger)sampleRateConverterQuality
{
    _revenant_sampleRateConverterQuality = sampleRateConverterQuality;
    UInt32 value = (UInt32)sampleRateConverterQuality;
    AudioConverterSetProperty(_revenant_converter, kAudioConverterSampleRateConverterQuality, sizeof(value), &value);
}

- (NSString *)sampleRateConverterAlgorithm
{
    return _revenant_sampleRateConverterAlgorithm;
}

- (void)setSampleRateConverterAlgorithm:(NSString *)sampleRateConverterAlgorithm
{
    _revenant_sampleRateConverterAlgorithm = [sampleRateConverterAlgorithm copy];
    if (sampleRateConverterAlgorithm)
        AudioConverterSetProperty(_revenant_converter, kAudioConverterSampleRateConverterAlgorithm, sizeof(CFStringRef), (__bridge const void *)sampleRateConverterAlgorithm);
}

- (AVAudioConverterPrimeMethod)primeMethod
{
    return _revenant_primeMethod;
}

- (void)setPrimeMethod:(AVAudioConverterPrimeMethod)primeMethod
{
    _revenant_primeMethod = primeMethod;
    UInt32 value = (UInt32)primeMethod;
    AudioConverterSetProperty(_revenant_converter, kAudioConverterPrimeMethod, sizeof(value), &value);
}

- (AVAudioConverterPrimeInfo)primeInfo
{
    return _revenant_primeInfo;
}

- (void)setPrimeInfo:(AVAudioConverterPrimeInfo)primeInfo
{
    _revenant_primeInfo = primeInfo;
    AudioConverterPrimeInfo real = {.leadingFrames = primeInfo.leadingFrames, .trailingFrames = primeInfo.trailingFrames};
    AudioConverterSetProperty(_revenant_converter, kAudioConverterPrimeInfo, sizeof(real), &real);
}

- (BOOL)convertToBuffer:(AVAudioPCMBuffer *)outputBuffer fromBuffer:(const AVAudioPCMBuffer *)inputBuffer error:(NSError **)outError
{
    [outputBuffer setFrameLength:[inputBuffer frameLength]];
    OSStatus status = AudioConverterConvertComplexBuffer(_revenant_converter, [inputBuffer frameLength],
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
    RevenantConverterInputContext ctx = {.block = inputBlock, .reachedEnd = NO};
    UInt32 packetCount = [pcmOutput frameCapacity];
    [pcmOutput setFrameLength:packetCount];
    OSStatus status = AudioConverterFillComplexBuffer(_revenant_converter, RevenantConverterInputProc, &ctx, &packetCount,
                                                       [pcmOutput mutableAudioBufferList], NULL);
    [pcmOutput setFrameLength:packetCount];
    if (status != noErr && status != kRevenantConverterNoDataNow) {
        if (outError)
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return AVAudioConverterOutputStatus_Error;
    }
    if (ctx.reachedEnd && packetCount == 0)
        return AVAudioConverterOutputStatus_EndOfStream;
    if (status == kRevenantConverterNoDataNow)
        return AVAudioConverterOutputStatus_InputRanDry;
    return AVAudioConverterOutputStatus_HaveData;
}

@end

@implementation AVAudioConverter (Encoding)

- (NSInteger)bitRate
{
    return _revenant_bitRate;
}

- (void)setBitRate:(NSInteger)bitRate
{
    _revenant_bitRate = bitRate;
    UInt32 value = (UInt32)bitRate;
    AudioConverterSetProperty(_revenant_converter, kAudioConverterEncodeBitRate, sizeof(value), &value);
}

- (NSString *)bitRateStrategy
{
    return _revenant_bitRateStrategy;
}

- (void)setBitRateStrategy:(NSString *)bitRateStrategy
{
    _revenant_bitRateStrategy = [bitRateStrategy copy];
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
