#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

typedef NSString *AVMediaType;
typedef NSString *AVFileType;
typedef NSString *AVAssetExportPreset;

extern NSString *const AVMediaTypeVideo;
extern NSString *const AVFileTypeQuickTimeMovie;
extern NSString *const AVAssetExportPresetPassthrough;
extern NSString *const AVVideoCodecKey;
extern NSString *const AVVideoCodecTypeH264;
extern NSString *const AVVideoWidthKey;
extern NSString *const AVVideoHeightKey;

@interface AVURLAsset : NSObject
+ (AVURLAsset *)URLAssetWithURL:(NSURL *)url options:(NSDictionary *)options;
@end

@class AVAssetWriter;
@class AVAssetWriterInputPassDescription;

@interface AVAssetWriterInput : NSObject

- (instancetype)initWithMediaType:(AVMediaType)mediaType outputSettings:(NSDictionary *)outputSettings;
- (AVMediaType)mediaType;
- (NSDictionary *)outputSettings;
- (BOOL)isReadyForMoreMediaData;
- (BOOL)appendSampleBuffer:(id)sampleBuffer;
- (void)requestMediaDataWhenReadyOnQueue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block;
- (void)markAsFinished;

- (BOOL)performsMultiPassEncodingIfSupported;
- (void)setPerformsMultiPassEncodingIfSupported:(BOOL)flag;
- (BOOL)canPerformMultiplePasses;
- (AVAssetWriterInputPassDescription *)currentPassDescription;
- (void)respondToEachPassDescriptionOnQueue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block;
- (void)markCurrentPassAsFinished;

@end

@interface AVAssetWriterInputPassDescription : NSObject
- (NSArray *)sourceTimeRanges;
@end

@interface AVAssetWriterInput (RevenantStandin)
- (void)revenantAttachToWriter:(AVAssetWriter *)writer;
@end

@interface AVAssetWriter : NSObject

- (instancetype)initWithURL:(NSURL *)outputURL fileType:(AVFileType)outputFileType error:(NSError **)outError;
- (NSURL *)outputURL;
- (AVFileType)outputFileType;
- (BOOL)canApplyOutputSettings:(NSDictionary *)outputSettings forMediaType:(AVMediaType)mediaType;
- (BOOL)canAddInput:(AVAssetWriterInput *)input;
- (void)addInput:(AVAssetWriterInput *)input;
- (NSArray *)inputs;
- (BOOL)startWriting;
- (void)startSessionAtSourceTime:(CMTime)startTime;
- (void)endSessionAtSourceTime:(CMTime)endTime;
- (BOOL)finishWriting;
- (void)cancelWriting;

@end

@interface AVAssetExportSession : NSObject

- (instancetype)initWithAsset:(id)asset presetName:(AVAssetExportPreset)presetName;
- (NSURL *)outputURL;
- (void)setOutputURL:(NSURL *)outputURL;
- (AVFileType)outputFileType;
- (void)setOutputFileType:(AVFileType)outputFileType;
- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler;

- (BOOL)canPerformMultiplePassesOverSourceMediaData;
- (void)setCanPerformMultiplePassesOverSourceMediaData:(BOOL)flag;

@end

@interface NSValue (RevenantStandinCMTime)
+ (NSValue *)valueWithCMTimeRange:(CMTimeRange)timeRange;
- (CMTimeRange)CMTimeRangeValue;
@end
