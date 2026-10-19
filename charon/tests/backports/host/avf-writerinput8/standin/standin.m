//  standin.m - the RELEASE side of tests/backports/host/avf-writerinput8, implemented.
//
//  What it is for: the port's AVAssetWriterInputMultiPass8.m needs an AVAssetWriterInput that has no pass
//  machinery, an AVAssetWriter whose -startWriting means something, and an AVAssetExportSession whose
//  export can start. On this Mac none of those classes is that class - Apple's own carry the whole 8.0
//  family - so the port's objects are linked against THESE instead, and every call they make is recorded.
//
//  It implements no member of the 8.0 family. That is the whole contract: the port's categories are what
//  answer -canPerformMultiplePasses, -currentPassDescription and the rest, and if the port's objects were
//  not in the link these would raise, which is a louder failure than a wrong number. AVAssetWriterInputPassDescription
//  is declared and not implemented here either: there is no such class below 8.0, and the port carries it.
//
//  -canApplyOutputSettings:forMediaType: answers YES for every settings dictionary. The harness asks it to
//  find a codec this machine can encode; here there is no encoder, and the row that names the settings is
//  printed by both halves alike, so the two tables still join.
#import <AVFoundation/AVFoundation.h>

NSString *const AVMediaTypeVideo = @"vide";
NSString *const AVFileTypeQuickTimeMovie = @"com.apple.quicktime-movie";
NSString *const AVAssetExportPresetPassthrough = @"AVAssetExportPresetPassthrough";
NSString *const AVVideoCodecKey = @"AVVideoCodecKey";
NSString *const AVVideoCodecTypeH264 = @"avc1";
NSString *const AVVideoWidthKey = @"AVVideoWidthKey";
NSString *const AVVideoHeightKey = @"AVVideoHeightKey";

@implementation NSValue (CharonStandinCMTime)

+ (NSValue *)valueWithCMTimeRange:(CMTimeRange)timeRange
{
    return [NSValue valueWithBytes:&timeRange objCType:@encode(CMTimeRange)];
}

- (CMTimeRange)CMTimeRangeValue
{
    CMTimeRange range;
    [self getValue:&range];
    return range;
}

@end

@implementation AVURLAsset

+ (AVURLAsset *)URLAssetWithURL:(NSURL *)url options:(NSDictionary *)options
{
    // The stand-in's asset is a marker. Apple's own class reads the file and hands the export session a
    // track list; nothing in this family reads either, and the harness only needs a non-nil asset so that
    // -initWithAsset:presetName: is asked with one.
    return [[AVURLAsset alloc] init];
}

@end

@implementation AVAssetWriterInput {
    AVMediaType _charon_mediaType;
    NSDictionary *_charon_outputSettings;
    __weak AVAssetWriter *_charon_writer;
}

- (instancetype)initWithMediaType:(AVMediaType)mediaType outputSettings:(NSDictionary *)outputSettings
{
    self = [super init];
    if (self) {
        _charon_mediaType = [mediaType copy];
        _charon_outputSettings = [outputSettings copy];
    }
    return self;
}

- (AVMediaType)mediaType
{
    return _charon_mediaType;
}

- (NSDictionary *)outputSettings
{
    return _charon_outputSettings;
}

- (BOOL)isReadyForMoreMediaData
{
    // The release's answer depends on the writer's own pipeline; nothing in this family reads it and no
    // row prints it. It is declared because the release's class declares it.
    return _charon_writer != nil;
}

- (BOOL)appendSampleBuffer:(id)sampleBuffer
{
    return NO;
}

- (void)requestMediaDataWhenReadyOnQueue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block
{
}

- (void)markAsFinished
{
}

// The stand-in's own bookkeeping, not the release's: -addInput: is what puts the two together.
- (void)charonAttachToWriter:(AVAssetWriter *)writer
{
    _charon_writer = writer;
}

@end

@implementation AVAssetWriter {
    NSURL *_charon_outputURL;
    AVFileType _charon_outputFileType;
    NSMutableArray *_charon_inputs;
    BOOL _charon_writing;
    BOOL _charon_cancelled;
}

- (instancetype)initWithURL:(NSURL *)outputURL fileType:(AVFileType)outputFileType error:(NSError **)outError
{
    self = [super init];
    if (self) {
        _charon_outputURL = [outputURL copy];
        _charon_outputFileType = [outputFileType copy];
        _charon_inputs = [NSMutableArray array];
    }
    return self;
}

- (NSURL *)outputURL
{
    return _charon_outputURL;
}

- (AVFileType)outputFileType
{
    return _charon_outputFileType;
}

- (BOOL)canApplyOutputSettings:(NSDictionary *)outputSettings forMediaType:(AVMediaType)mediaType
{
    return YES;
}

- (BOOL)canAddInput:(AVAssetWriterInput *)input
{
    return !_charon_writing;
}

- (void)addInput:(AVAssetWriterInput *)input
{
    [_charon_inputs addObject:input];
    [input charonAttachToWriter:self];
}

- (NSArray *)inputs
{
    return [_charon_inputs copy];
}

- (BOOL)startWriting
{
    if (_charon_writing || _charon_cancelled)
        return NO;
    _charon_writing = YES;
    return YES;
}

- (void)startSessionAtSourceTime:(CMTime)startTime
{
}

- (void)endSessionAtSourceTime:(CMTime)endTime
{
}

- (BOOL)finishWriting
{
    return _charon_writing;
}

- (void)cancelWriting
{
    _charon_cancelled = YES;
}

@end

@implementation AVAssetExportSession {
    NSURL *_charon_outputURL;
    AVFileType _charon_outputFileType;
    AVAssetExportPreset _charon_preset;
    NSMutableArray *_charon_exports;
}

- (instancetype)initWithAsset:(id)asset presetName:(AVAssetExportPreset)presetName
{
    self = [super init];
    if (self) {
        _charon_preset = [presetName copy];
        _charon_exports = [NSMutableArray array];
    }
    return self;
}

- (NSURL *)outputURL
{
    return _charon_outputURL;
}

- (void)setOutputURL:(NSURL *)outputURL
{
    _charon_outputURL = [outputURL copy];
}

- (AVFileType)outputFileType
{
    return _charon_outputFileType;
}

- (void)setOutputFileType:(AVFileType)outputFileType
{
    _charon_outputFileType = [outputFileType copy];
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler
{
    [_charon_exports addObject:@"exportAsynchronouslyWithCompletionHandler:"];
    if (handler)
        handler();
}

@end