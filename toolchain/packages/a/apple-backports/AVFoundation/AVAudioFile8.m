#import <AVFAudio/AVAudioFile.h>
#import <AVFAudio/AVAudioSettings.h>
#import <AudioToolbox/AudioConverter.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioToolbox/ExtendedAudioFile.h>
#import "RevenantAVAudioBuffer.h"

static NSString *const revenant_avfaudioErrorDomain = @"com.apple.coreaudio.avfaudio";
static NSString *const revenant_osstatusErrorDomain = @"NSOSStatusErrorDomain";
static const OSStatus revenant_eofErr = -39;
static const OSStatus revenant_paramErr = -50;

@interface AVAudioFile () {
    ExtAudioFileRef _extFile;
    NSURL *_fileURL;
    AVAudioFormat *_fileFormat;
    AVAudioFormat *_processingFormat;
}
@end

static void revenant_setError(NSError **outError, NSString *domain, NSInteger code)
{
    if (outError)
        *outError = [NSError errorWithDomain:domain code:code userInfo:nil];
}

static BOOL revenant_fileTypeForURL(NSURL *url, AudioFileTypeID *outType)
{
    CFStringRef extension = (__bridge CFStringRef)url.pathExtension;
    UInt32 size = 0;
    if (AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_TypesForExtension, sizeof(extension), &extension, &size) != noErr || size < sizeof(AudioFileTypeID))
        return NO;
    AudioFileTypeID *types = malloc(size);
    BOOL found = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_TypesForExtension, sizeof(extension), &extension, &size, types) == noErr && size >= sizeof(AudioFileTypeID);
    if (found)
        *outType = types[0];
    free(types);
    return found;
}

static AVAudioFormat *revenant_fileFormatFromSettings(NSDictionary<NSString *, id> *settings)
{
    UInt32 formatID = [settings[AVFormatIDKey] unsignedIntValue];
    if (formatID == kAudioFormatLinearPCM) {
        if ([settings[AVNumberOfChannelsKey] unsignedIntValue] == 0) {
            NSMutableDictionary<NSString *, id> *mono = [settings mutableCopy];
            mono[AVNumberOfChannelsKey] = @1;
            settings = mono;
        }
        return [[AVAudioFormat alloc] initWithSettings:settings];
    }
    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mFormatID = formatID;
    asbd.mSampleRate = [settings[AVSampleRateKey] doubleValue];
    asbd.mChannelsPerFrame = (UInt32)[settings[AVNumberOfChannelsKey] unsignedIntValue];
    return [[AVAudioFormat alloc] initWithStreamDescription:&asbd];
}

@implementation AVAudioFile

- (nullable instancetype)initForReading:(NSURL *)fileURL error:(NSError **)outError
{
    return [self initReadingURL:fileURL commonFormat:AVAudioOtherFormat interleaved:NO error:outError];
}

- (nullable instancetype)initForReading:(NSURL *)fileURL commonFormat:(AVAudioCommonFormat)format interleaved:(BOOL)interleaved error:(NSError **)outError
{
    return [self initReadingURL:fileURL commonFormat:format interleaved:interleaved error:outError];
}

- (nullable instancetype)initReadingURL:(NSURL *)fileURL commonFormat:(AVAudioCommonFormat)format interleaved:(BOOL)interleaved error:(NSError **)outError
{
    ExtAudioFileRef file = NULL;
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)fileURL, &file);
    if (status != noErr) {
        revenant_setError(outError, revenant_avfaudioErrorDomain, status);
        return nil;
    }
    AudioStreamBasicDescription fileASBD;
    UInt32 size = sizeof(fileASBD);
    status = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileASBD);
    AVAudioFormat *fileFormat = status == noErr ? [[AVAudioFormat alloc] initWithStreamDescription:&fileASBD] : nil;
    AVAudioFormat *processingFormat = nil;
    if (fileFormat) {
        if (format == AVAudioOtherFormat)
            processingFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:fileASBD.mSampleRate channels:fileASBD.mChannelsPerFrame];
        else
            processingFormat = [[AVAudioFormat alloc] initWithCommonFormat:format sampleRate:fileASBD.mSampleRate channels:fileASBD.mChannelsPerFrame interleaved:interleaved];
    }
    if (!processingFormat) {
        ExtAudioFileDispose(file);
        revenant_setError(outError, revenant_avfaudioErrorDomain, status != noErr ? status : kAudioFileUnsupportedDataFormatError);
        return nil;
    }
    status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), processingFormat.streamDescription);
    if (status != noErr) {
        ExtAudioFileDispose(file);
        revenant_setError(outError, revenant_avfaudioErrorDomain, status);
        return nil;
    }
    if ((self = [super init])) {
        _extFile = file;
        _fileURL = fileURL;
        _fileFormat = fileFormat;
        _processingFormat = processingFormat;
    } else {
        ExtAudioFileDispose(file);
    }
    return self;
}

- (nullable instancetype)initForWriting:(NSURL *)fileURL settings:(NSDictionary<NSString *, id> *)settings error:(NSError **)outError
{
    return [self initWritingURL:fileURL settings:settings commonFormat:AVAudioOtherFormat interleaved:NO error:outError];
}

- (nullable instancetype)initForWriting:(NSURL *)fileURL settings:(NSDictionary<NSString *, id> *)settings commonFormat:(AVAudioCommonFormat)format interleaved:(BOOL)interleaved error:(NSError **)outError
{
    return [self initWritingURL:fileURL settings:settings commonFormat:format interleaved:interleaved error:outError];
}

- (nullable instancetype)initWritingURL:(NSURL *)fileURL settings:(NSDictionary<NSString *, id> *)settings commonFormat:(AVAudioCommonFormat)format interleaved:(BOOL)interleaved error:(NSError **)outError
{
    AudioFileTypeID fileType = 0;
    if (!revenant_fileTypeForURL(fileURL, &fileType)) {
        revenant_setError(outError, revenant_avfaudioErrorDomain, kAudioFileUnsupportedFileTypeError);
        return nil;
    }
    AVAudioFormat *fileFormat = revenant_fileFormatFromSettings(settings);
    AVAudioFormat *processingFormat = nil;
    if (fileFormat) {
        if (format == AVAudioOtherFormat)
            processingFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:fileFormat.sampleRate channels:fileFormat.channelCount];
        else
            processingFormat = [[AVAudioFormat alloc] initWithCommonFormat:format sampleRate:fileFormat.sampleRate channels:fileFormat.channelCount interleaved:interleaved];
    }
    if (!processingFormat) {
        revenant_setError(outError, revenant_avfaudioErrorDomain, kAudioFileUnsupportedDataFormatError);
        return nil;
    }
    AudioStreamBasicDescription fileASBD = *fileFormat.streamDescription;
    ExtAudioFileRef file = NULL;
    OSStatus status = ExtAudioFileCreateWithURL((__bridge CFURLRef)fileURL, fileType, &fileASBD, NULL, kAudioFileFlags_EraseFile, &file);
    if (status != noErr) {
        revenant_setError(outError, revenant_avfaudioErrorDomain, status);
        return nil;
    }
    status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), processingFormat.streamDescription);
    if (status == noErr && settings[AVEncoderBitRateKey] && fileASBD.mFormatID != kAudioFormatLinearPCM) {
        AudioConverterRef converter = NULL;
        UInt32 size = sizeof(converter);
        status = ExtAudioFileGetProperty(file, kExtAudioFileProperty_AudioConverter, &size, &converter);
        UInt32 bitRate = [settings[AVEncoderBitRateKey] unsignedIntValue];
        if (status == noErr)
            status = AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate);
    }
    if (status != noErr) {
        ExtAudioFileDispose(file);
        revenant_setError(outError, revenant_avfaudioErrorDomain, status);
        return nil;
    }
    if ((self = [super init])) {
        _extFile = file;
        _fileURL = fileURL;
        _fileFormat = fileFormat;
        _processingFormat = processingFormat;
    } else {
        ExtAudioFileDispose(file);
    }
    return self;
}

- (void)dealloc
{
    if (_extFile)
        ExtAudioFileDispose(_extFile);
}

- (NSURL *)url
{
    return _fileURL;
}

- (AVAudioFormat *)fileFormat
{
    return _fileFormat;
}

- (AVAudioFormat *)processingFormat
{
    return _processingFormat;
}

- (AVAudioFramePosition)length
{
    SInt64 frames = 0;
    UInt32 size = sizeof(frames);
    if (_extFile)
        ExtAudioFileGetProperty(_extFile, kExtAudioFileProperty_FileLengthFrames, &size, &frames);
    return frames;
}

- (AVAudioFramePosition)framePosition
{
    SInt64 position = 0;
    if (_extFile)
        ExtAudioFileTell(_extFile, &position);
    return position;
}

- (void)setFramePosition:(AVAudioFramePosition)framePosition
{
    if (_extFile)
        ExtAudioFileSeek(_extFile, framePosition);
}

- (BOOL)readIntoBuffer:(AVAudioPCMBuffer *)buffer error:(NSError **)outError
{
    return [self readIntoBuffer:buffer frameCount:buffer.frameCapacity error:outError];
}

- (BOOL)readIntoBuffer:(AVAudioPCMBuffer *)buffer frameCount:(AVAudioFrameCount)frames error:(NSError **)outError
{
    if (frames > buffer.frameCapacity)
        [NSException raise:revenant_avfaudioErrorDomain format:@"required condition is false: frames <= buffer.frameCapacity"];
    if (!_extFile || ![buffer.format isEqual:_processingFormat]) {
        revenant_setError(outError, revenant_avfaudioErrorDomain, revenant_paramErr);
        return NO;
    }
    AudioBufferList *list = buffer.mutableAudioBufferList;
    UInt32 bytesPerFrame = _processingFormat.streamDescription->mBytesPerFrame;
    for (UInt32 i = 0; i < list->mNumberBuffers; i++)
        list->mBuffers[i].mDataByteSize = frames * bytesPerFrame;
    UInt32 count = frames;
    OSStatus status = ExtAudioFileRead(_extFile, &count, list);
    if (status != noErr) {
        revenant_setError(outError, revenant_avfaudioErrorDomain, status);
        return NO;
    }
    if (count == 0 && frames > 0) {
        revenant_setError(outError, revenant_osstatusErrorDomain, revenant_eofErr);
        return NO;
    }
    [buffer setFrameLength:count];
    return YES;
}

- (BOOL)writeFromBuffer:(const AVAudioPCMBuffer *)buffer error:(NSError **)outError
{
    if (!_extFile || ![buffer.format isEqual:_processingFormat]) {
        revenant_setError(outError, revenant_avfaudioErrorDomain, revenant_paramErr);
        return NO;
    }
    OSStatus status = ExtAudioFileWrite(_extFile, buffer.frameLength, buffer.audioBufferList);
    if (status != noErr) {
        revenant_setError(outError, revenant_avfaudioErrorDomain, status);
        return NO;
    }
    return YES;
}

@end
