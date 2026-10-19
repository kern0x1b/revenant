//  The RELEASE's own surface, as the 8.0 multi-pass family composes over it, and nothing else.
//
//  What the release carries is measured, not assumed: the selector table of
//  ~/.charon/dyld/6.1.3/selectors_armv7.txt holds -markAsFinished, -appendSampleBuffer:,
//  -isReadyForMoreMediaData, -initWithMediaType:outputSettings:, -requestMediaDataWhenReadyOnQueue:usingBlock:,
//  -mediaType and -outputSettings on 6.1.3 and carries none of the eight 8.0 names this family adds
//  (performsMultiPassEncodingIfSupported, canPerformMultiplePasses, currentPassDescription,
//  respondToEachPassDescriptionOnQueue:usingBlock:, markCurrentPassAsFinished, sourceTimeRanges,
//  preferredMediaChunkDuration, sampleReferenceBaseURL), and `strings -a` over the armv7 caches of 4.3,
//  6.0, 6.1.3, 7.0, 7.1 and 8.0 answers 0 for all of them below 8.0 and 2 at 8.0. -startWriting and
//  -exportAsynchronouslyWithCompletionHandler: are 4.3's own members and are here for the same reason.
//
//  Two rules this header keeps, and both are the point of linking the port's real objects against it
//  instead of compiling a copy of them:
//
//    1. It declares NO member of the 8.0 family as the release's. The port's categories add all eight, and
//       a member declared here AND implemented there would hide a duplicate.
//    2. It declares the port's own members - the ones the release does not have - so the harness can call
//       what it has to call. standin.m does NOT implement them. The classes themselves are declared, and
//       not implemented, for the same reason: AVAssetWriterInputPassDescription exists nowhere below 8.0,
//       and the port is what brings it.
//
//  So the port's file compiles UNMODIFIED against this header, its category lands on the classes below, and
//  a call it sends to a receiver the release does not have raises here instead of going unnoticed.
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

// AVFoundation's own string-typed members, spelled as the SDK spells them.
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

// Forwarded as the SDK forwards them: the pass description and the writer are both named before they are
// declared, exactly as AVAssetWriterInput.h:442 and :671 do.
@class AVAssetWriter;
@class AVAssetWriterInputPassDescription;

@interface AVAssetWriterInput : NSObject

// The release's own. A media type and its output settings, -markAsFinished, -appendSampleBuffer: and
// -isReadyForMoreMediaData are 4.3's; the initialiser's sourceFormatHint twin is 6.0's.
- (instancetype)initWithMediaType:(AVMediaType)mediaType outputSettings:(NSDictionary *)outputSettings;
- (AVMediaType)mediaType;
- (NSDictionary *)outputSettings;
- (BOOL)isReadyForMoreMediaData;
- (BOOL)appendSampleBuffer:(id)sampleBuffer;
- (void)requestMediaDataWhenReadyOnQueue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block;
- (void)markAsFinished;

// The port's own, declared so the harness can call what it has to call. The stand-in does not implement
// any of them: the port's AVAssetWriterInputMultiPass8.m does, which is what is under test.
- (BOOL)performsMultiPassEncodingIfSupported;
- (void)setPerformsMultiPassEncodingIfSupported:(BOOL)flag;
- (BOOL)canPerformMultiplePasses;
- (AVAssetWriterInputPassDescription *)currentPassDescription;
- (void)respondToEachPassDescriptionOnQueue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block;
- (void)markCurrentPassAsFinished;

@end

// The pass description the writer hands out. Declared, not implemented: there is no such class below 8.0
// (0 hits for AVAssetWriterInputPassDescription in 6.1.3's 113981-name selector set and in every held
// cache below 8.0), and the port is what carries it.
@interface AVAssetWriterInputPassDescription : NSObject
- (NSArray *)sourceTimeRanges;
@end

// The stand-in's own bookkeeping, not the release's and not the port's: -addInput: calls it to pair an
// input with the writer it was added to, and nothing in the 8.0 family reads it.
@interface AVAssetWriterInput (CharonStandin)
- (void)charonAttachToWriter:(AVAssetWriter *)writer;
@end

@interface AVAssetWriter : NSObject

// The release's own: the URL initialiser from 4.3, the rest beside it.
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

// The release's own: the asset initialiser from 4.3 and -exportAsynchronouslyWithCompletionHandler: with
// it, -outputURL and -outputFileType beside them. The asset is typed id because the stand-in carries no
// AVAsset class and nothing below this line reads one.
- (instancetype)initWithAsset:(id)asset presetName:(AVAssetExportPreset)presetName;
- (NSURL *)outputURL;
- (void)setOutputURL:(NSURL *)outputURL;
- (AVFileType)outputFileType;
- (void)setOutputFileType:(AVFileType)outputFileType;
- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler;

// The port's own, not the release's, and not implemented here.
- (BOOL)canPerformMultiplePassesOverSourceMediaData;
- (void)setCanPerformMultiplePassesOverSourceMediaData:(BOOL)flag;

@end

// CoreMedia's time values inside NSValue, which AVFoundation declares in AVTime.h. Declared here because
// the harness needs them and the stand-in does not link AVFoundation: standin.m implements this category,
// so nothing here reaches the real framework.
@interface NSValue (CharonStandinCMTime)
+ (NSValue *)valueWithCMTimeRange:(CMTimeRange)timeRange;
- (CMTimeRange)CMTimeRangeValue;
@end