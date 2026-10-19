#import <AVFoundation/AVFoundation.h>

NSString *const AVMediaTypeVideo = @"vide";
NSString *const AVFileTypeQuickTimeMovie = @"com.apple.quicktime-movie";
NSString *const AVAssetExportPresetPassthrough = @"AVAssetExportPresetPassthrough";
NSString *const AVVideoCodecKey = @"AVVideoCodecKey";
NSString *const AVVideoCodecTypeH264 = @"avc1";
NSString *const AVVideoWidthKey = @"AVVideoWidthKey";
NSString *const AVVideoHeightKey = @"AVVideoHeightKey";

@implementation NSValue (RevenantStandinCMTime)

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
    return [[AVURLAsset alloc] init];
}

@end

@implementation AVAssetWriterInput {
    AVMediaType _revenant_mediaType;
    NSDictionary *_revenant_outputSettings;
    __weak AVAssetWriter *_revenant_writer;
}

- (instancetype)initWithMediaType:(AVMediaType)mediaType outputSettings:(NSDictionary *)outputSettings
{
    self = [super init];
    if (self) {
        _revenant_mediaType = [mediaType copy];
        _revenant_outputSettings = [outputSettings copy];
    }
    return self;
}

- (AVMediaType)mediaType
{
    return _revenant_mediaType;
}

- (NSDictionary *)outputSettings
{
    return _revenant_outputSettings;
}

- (BOOL)isReadyForMoreMediaData
{
    return _revenant_writer != nil;
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

- (void)revenantAttachToWriter:(AVAssetWriter *)writer
{
    _revenant_writer = writer;
}

@end

@implementation AVAssetWriter {
    NSURL *_revenant_outputURL;
    AVFileType _revenant_outputFileType;
    NSMutableArray *_revenant_inputs;
    BOOL _revenant_writing;
    BOOL _revenant_cancelled;
}

- (instancetype)initWithURL:(NSURL *)outputURL fileType:(AVFileType)outputFileType error:(NSError **)outError
{
    self = [super init];
    if (self) {
        _revenant_outputURL = [outputURL copy];
        _revenant_outputFileType = [outputFileType copy];
        _revenant_inputs = [NSMutableArray array];
    }
    return self;
}

- (NSURL *)outputURL
{
    return _revenant_outputURL;
}

- (AVFileType)outputFileType
{
    return _revenant_outputFileType;
}

- (BOOL)canApplyOutputSettings:(NSDictionary *)outputSettings forMediaType:(AVMediaType)mediaType
{
    return YES;
}

- (BOOL)canAddInput:(AVAssetWriterInput *)input
{
    return !_revenant_writing;
}

- (void)addInput:(AVAssetWriterInput *)input
{
    [_revenant_inputs addObject:input];
    [input revenantAttachToWriter:self];
}

- (NSArray *)inputs
{
    return [_revenant_inputs copy];
}

- (BOOL)startWriting
{
    if (_revenant_writing || _revenant_cancelled)
        return NO;
    _revenant_writing = YES;
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
    return _revenant_writing;
}

- (void)cancelWriting
{
    _revenant_cancelled = YES;
}

@end

@implementation AVAssetExportSession {
    NSURL *_revenant_outputURL;
    AVFileType _revenant_outputFileType;
    AVAssetExportPreset _revenant_preset;
    NSMutableArray *_revenant_exports;
}

- (instancetype)initWithAsset:(id)asset presetName:(AVAssetExportPreset)presetName
{
    self = [super init];
    if (self) {
        _revenant_preset = [presetName copy];
        _revenant_exports = [NSMutableArray array];
    }
    return self;
}

- (NSURL *)outputURL
{
    return _revenant_outputURL;
}

- (void)setOutputURL:(NSURL *)outputURL
{
    _revenant_outputURL = [outputURL copy];
}

- (AVFileType)outputFileType
{
    return _revenant_outputFileType;
}

- (void)setOutputFileType:(AVFileType)outputFileType
{
    _revenant_outputFileType = [outputFileType copy];
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler
{
    [_revenant_exports addObject:@"exportAsynchronouslyWithCompletionHandler:"];
    if (handler)
        handler();
}

@end
