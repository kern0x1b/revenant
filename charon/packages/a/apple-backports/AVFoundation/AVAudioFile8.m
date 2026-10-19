#import <AVFAudio/AVAudioFile.h>
#import <AVFAudio/AVAudioSettings.h>
#import <AudioToolbox/AudioConverter.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioToolbox/ExtendedAudioFile.h>
#import "CharonAVAudioBuffer.h"

// AVAudioFile reads and writes a file through the release's own ExtAudioFile, which iOS 6 carries
// whole: it opens and creates every container and codec AudioToolbox knows, converts between the
// file's format and the client format a caller asks for, and does the seeking. Nothing here decodes
// or encodes a sample; the class only maps the AVAudioFile vocabulary onto ExtAudioFile's, and holds
// the AVAudioFormat and AVAudioPCMBuffer objects of this port at that boundary.
//
// The processing format is the standard format (Float32, deinterleaved, the file's rate and channel
// count) unless the init names a common format, in which case it is that format, interleaved or not.
// It is set as the client format, so ExtAudioFile does every conversion between the file and it.
//
// Errors carry the domain and the code the host gives, measured in tests/backports/host/avfaudio-file
// (the host's probe, run against Apple's AVFAudio): a missing file is AudioFile's 'wht?', a format it
// cannot write is 'fmt?', and the end of a file is an error, not an empty buffer, as on the host.
// A request for more frames than the buffer holds raises the exception the host raises.

// Named by its text, not by the NSString constant: NSOSStatusErrorDomain is not in iOS 6's Foundation,
// and a strong reference to it would stop the load of every application that carries this class.
static NSString *const charon_avfaudioErrorDomain = @"com.apple.coreaudio.avfaudio";
static NSString *const charon_osstatusErrorDomain = @"NSOSStatusErrorDomain";
static const OSStatus charon_eofErr = -39;       // MacErrors.h's eofErr: the end of the file
static const OSStatus charon_paramErr = -50;     // MacErrors.h's paramErr: a buffer of another format

@interface AVAudioFile () {
    ExtAudioFileRef _extFile;
    NSURL *_fileURL;
    AVAudioFormat *_fileFormat;
    AVAudioFormat *_processingFormat;
}
@end

static void charon_setError(NSError **outError, NSString *domain, NSInteger code)
{
    if (outError)
        *outError = [NSError errorWithDomain:domain code:code userInfo:nil];
}

// The file type a path's extension names, as AudioToolbox lists it; the first of the types it lists.
static BOOL charon_fileTypeForURL(NSURL *url, AudioFileTypeID *outType)
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

// The format of a file being created, from its settings. Linear PCM is what AVAudioFormat already
// builds from settings; any other format names only its ID, rate and channel count, and ExtAudioFile
// fills in the rest of a compressed description itself.
static AVAudioFormat *charon_fileFormatFromSettings(NSDictionary<NSString *, id> *settings)
{
    UInt32 formatID = [settings[AVFormatIDKey] unsignedIntValue];
    if (formatID == kAudioFormatLinearPCM) {
        // A channel count of zero makes a mono file, as the host does (measured by probe.m). A missing key reads as zero here; the host was not measured on that.
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
        charon_setError(outError, charon_avfaudioErrorDomain, status);
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
        charon_setError(outError, charon_avfaudioErrorDomain, status != noErr ? status : kAudioFileUnsupportedDataFormatError);
        return nil;
    }
    status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), processingFormat.streamDescription);
    if (status != noErr) {
        ExtAudioFileDispose(file);
        charon_setError(outError, charon_avfaudioErrorDomain, status);
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
    if (!charon_fileTypeForURL(fileURL, &fileType)) {
        charon_setError(outError, charon_avfaudioErrorDomain, kAudioFileUnsupportedFileTypeError);
        return nil;
    }
    AVAudioFormat *fileFormat = charon_fileFormatFromSettings(settings);
    AVAudioFormat *processingFormat = nil;
    if (fileFormat) {
        if (format == AVAudioOtherFormat)
            processingFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:fileFormat.sampleRate channels:fileFormat.channelCount];
        else
            processingFormat = [[AVAudioFormat alloc] initWithCommonFormat:format sampleRate:fileFormat.sampleRate channels:fileFormat.channelCount interleaved:interleaved];
    }
    if (!processingFormat) {
        charon_setError(outError, charon_avfaudioErrorDomain, kAudioFileUnsupportedDataFormatError);
        return nil;
    }
    AudioStreamBasicDescription fileASBD = *fileFormat.streamDescription;
    ExtAudioFileRef file = NULL;
    OSStatus status = ExtAudioFileCreateWithURL((__bridge CFURLRef)fileURL, fileType, &fileASBD, NULL, kAudioFileFlags_EraseFile, &file);
    if (status != noErr) {
        charon_setError(outError, charon_avfaudioErrorDomain, status);
        return nil;
    }
    status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), processingFormat.streamDescription);
    if (status == noErr && settings[AVEncoderBitRateKey] && fileASBD.mFormatID != kAudioFormatLinearPCM) {
        // An encoder is only there for a compressed file, and only once the client format is set.
        AudioConverterRef converter = NULL;
        UInt32 size = sizeof(converter);
        status = ExtAudioFileGetProperty(file, kExtAudioFileProperty_AudioConverter, &size, &converter);
        UInt32 bitRate = [settings[AVEncoderBitRateKey] unsignedIntValue];
        if (status == noErr)
            status = AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate);
    }
    if (status != noErr) {
        ExtAudioFileDispose(file);
        charon_setError(outError, charon_avfaudioErrorDomain, status);
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
    // Disposing an ExtAudioFile writes what a writer still holds, so a file written and released is whole.
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
        [NSException raise:charon_avfaudioErrorDomain format:@"required condition is false: frames <= buffer.frameCapacity"];
    if (!_extFile || ![buffer.format isEqual:_processingFormat]) {
        charon_setError(outError, charon_avfaudioErrorDomain, charon_paramErr);
        return NO;
    }
    // ExtAudioFile reads into the buffers it is given up to their byte sizes, so each is set to the request first.
    AudioBufferList *list = buffer.mutableAudioBufferList;
    UInt32 bytesPerFrame = _processingFormat.streamDescription->mBytesPerFrame;
    for (UInt32 i = 0; i < list->mNumberBuffers; i++)
        list->mBuffers[i].mDataByteSize = frames * bytesPerFrame;
    UInt32 count = frames;
    OSStatus status = ExtAudioFileRead(_extFile, &count, list);
    if (status != noErr) {
        charon_setError(outError, charon_avfaudioErrorDomain, status);
        return NO;
    }
    if (count == 0 && frames > 0) {
        charon_setError(outError, charon_osstatusErrorDomain, charon_eofErr);
        return NO;
    }
    [buffer setFrameLength:count];
    return YES;
}

- (BOOL)writeFromBuffer:(const AVAudioPCMBuffer *)buffer error:(NSError **)outError
{
    if (!_extFile || ![buffer.format isEqual:_processingFormat]) {
        charon_setError(outError, charon_avfaudioErrorDomain, charon_paramErr);
        return NO;
    }
    OSStatus status = ExtAudioFileWrite(_extFile, buffer.frameLength, buffer.audioBufferList);
    if (status != noErr) {
        charon_setError(outError, charon_avfaudioErrorDomain, status);
        return NO;
    }
    return YES;
}

@end
