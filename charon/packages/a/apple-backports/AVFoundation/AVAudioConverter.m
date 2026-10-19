#import <AVFAudio/AVAudioConverter.h>
#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioBuffer.h>
#import <AudioToolbox/AudioToolbox.h>

// AVAudioConverter over the real AudioConverterServices C API (AudioConverterNew/Reset/Dispose,
// AudioConverterConvertComplexBuffer, AudioConverterFillComplexBuffer) - every one of those symbols
// resolves via dlsym in a running armv7 process on the 6.1.3 guest, confirmed before this was
// written (facts/AVFoundation/AVAudioEngine.md). This class carries no class name that collides
// with anything native to 6.0/6.1.3 (objc.inventory, same source).
//
// -convertToBuffer:fromBuffer:error: is documented by Apple (AVAudioConverter.h:273-286) as a simple conversion that
// involves neither codecs nor a change of sample rate, and it maps directly onto
// AudioConverterConvertComplexBuffer, which carries the identical restriction (fixed input/output
// frame count). -convertToBuffer:error:withInputFromBlock: is the general path and maps onto
// AudioConverterFillComplexBuffer, which does support sample-rate conversion and variable-length
// codecs; this port's own C input proc bridges it to the caller's block.

// AudioConverterComplexInputDataProc's OSStatus return only ever means "a real error happened,
// stop" per Apple's own docs ("If the callback returns an error ... FillComplexBuffer will stop
// producing output"); it has no vocabulary for "no data *right now*, call me again". This port's
// bridge invents one: a private, deliberately-unregistered four-char code returned only by this
// proc and only ever inspected by the wrapper that installed it, never surfaced past this file.
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
    // Real, but only decoders/encoders of a compressed format read this back - this port's
    // AudioConverterNew calls are PCM-to-PCM/PCM-to-linear so far (demand-driven, see facts); kept
    // as a real stored value rather than silently dropped, not yet wired to
    // kAudioConverterDecompressionMagicCookie/kAudioConverterCompressionMagicCookie.
    _charon_magicCookie = [magicCookie copy];
}

// AudioConverterServices carries no public property for either of these on iOS: downmixing has no
// matching constant in AudioConverter.h at all (checked, not assumed), and
// kAudioConverterPropertyDithering/kDitherAlgorithm_* are declared under `#if !TARGET_OS_IPHONE` -
// macOS only, never available on this platform, iOS 6 or otherwise. Real state, kept and readable
// exactly as a caller set it, with no fabricated C property behind it - an invented constant here
// would have been exactly the AVAudioUnitEQFilterParameters.active mistake again, at the C-symbol
// level instead of the Objective-C one.
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
    // kAudioConverterSampleRateConverterAlgorithm is the real, CFString-valued C property this
    // ObjC property has always mapped onto - Apple's header marks it deprecated in favour of
    // kAudioConverterSampleRateConverterComplexity, which takes a different kind of value (a
    // complexity level, not an algorithm name) and is not a drop-in replacement for what this
    // property's own real semantics call for, so the deprecated-but-still-real property is used
    // deliberately, not by oversight.
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
    // A freshly allocated AVAudioPCMBuffer's AudioBufferList carries real, already-calloc'd sample
    // memory at its full frameCapacity (AVAudioPCMBuffer8.m), but mDataByteSize starts at 0 -
    // mirroring the real class, it tracks frameLength, not capacity. AudioConverterConvertComplexBuffer
    // reads mDataByteSize as how much room it has to write into, so an output buffer nobody has
    // written to yet looks like zero capacity to it and the call fails paramErr (-50) - measured
    // directly, the same shape of bug AVAudioEngine's own Output-scope-format trap was. Setting
    // frameLength to the exact frame count this call will produce first gives the converter a real
    // byte capacity to write into, matching this call's own fixed-ratio, no-resampling contract.
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
    // Same capacity-vs-frameLength fact as -convertToBuffer:fromBuffer:error: above, and Apple's own
    // docs for this call say so explicitly: "on entry, the buffers' mDataByteSize fields ... reflect
    // buffer capacity" - claim the whole capacity as valid bytes before the call so the converter has
    // real room to write into, then correct frameLength to what was actually produced afterward.
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

// bitRateStrategy is real, writable state (kept exactly as the caller set it, `nil` until then,
// matching a fresh non-encoding converter). The four read-only arrays below are not: a
// PCM-to-PCM/PCM-to-linear converter is not encoding, and Apple's own header documents every one of
// them as answering nil in exactly that case - the honest answer for every converter this port
// builds today, not a stub standing in for a codec path nobody has asked for yet.
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
