#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// Every method below is one the 16.4 SDK declares on its own class and places at iOS 16, and the
// release this object is built for has no such member; the same diagnostic for that is what
// AVCaptureDevice+VideoZoom7.m:7 already carries.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// iOS 16's asynchronous half of AVFoundation, on 6.1.3. Nine rows of the 35 that
// `absent_AVFoundation.json` places at 16.0, and one of them is stored rather than applied.
//
// Every forward here is to a member the release already carries and the 16.4 SDK already declares as
// iOS 5.0 or iOS 6.0 API, so nothing new is exported to answer it:
//
//   +videoCompositionWithPropertiesOfAsset:                       AVVideoComposition.h:64, ios(6.0)
//   +videoCompositionWithPropertiesOfAsset:videoGravity:          AVVideoComposition.h:285
//   -isValidForAsset:timeRange:validationDelegate:                AVVideoComposition.h:968, ios(5.0)
//   -generateCGImagesAsynchronouslyForTimes:completionHandler:   AVAssetImageGenerator.h:193
//   -insertTimeRange:ofAsset:atTime:error:                        AVComposition.h:220, ios(4.0)
//
// The five method rows are that forward plus the async shape the SDK's own signature asks for, and the
// 16.0 prototype-instruction factory is the only one that is not a one-line forward: it builds the
// composition of the asset's own properties and then replaces its instructions with a mutable copy of
// the prototype spanning the asset. See facts/AVFoundation/AVFoundation160.md for the measurement that
// each of those members is on 6.1.3's own class table, and for the two rows that could not be carried.

static const char charon_default_rate_key;

// The queue the asynchronous factories below do their work on: a composition is read from the asset's
// tracks, which is disk-backed work, and the header hands the result to a handler rather than returning.
static dispatch_queue_t charon_avf_composition_queue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("org.charon.avf.composition", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

@interface NSValue (CharonAVFoundationVideoDimensions)
+ (NSValue *)valueWithCMVideoDimensions:(CMVideoDimensions)dimensions;
- (CMVideoDimensions)CMVideoDimensionsValue;
@end

@implementation NSValue (CharonAVFoundationVideoDimensions)

+ (NSValue *)valueWithCMVideoDimensions:(CMVideoDimensions)dimensions
{
    return [NSValue valueWithBytes:&dimensions objCType:@encode(CMVideoDimensions)];
}

- (CMVideoDimensions)CMVideoDimensionsValue
{
    CMVideoDimensions dimensions;
    [self getValue:&dimensions];
    return dimensions;
}

@end

@implementation AVPlayer (CharonAVFoundationDefaultRate)

- (float)defaultRate
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_default_rate_key);
    return stored ? (float)stored.doubleValue : 1.0f;
}

- (void)setDefaultRate:(float)defaultRate
{
    objc_setAssociatedObject(self, &charon_default_rate_key, @(defaultRate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation AVAssetImageGenerator (CharonAVFoundationSingleImage)

- (void)generateCGImageAsynchronouslyForTime:(CMTime)requestedTime completionHandler:(void (^)(CGImageRef image, CMTime actualTime, NSError *error))handler
{
    NSArray *times = @[[NSValue valueWithCMTime:requestedTime]];
    [self generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requested, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        handler(image, actualTime, error);
    }];
}

@end

@implementation AVMutableComposition (CharonAVFoundationAsyncInsert)

- (void)insertTimeRange:(CMTimeRange)timeRange ofAsset:(AVAsset *)asset atTime:(CMTime)startTime completionHandler:(void (^)(NSError *error))completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        [self insertTimeRange:timeRange ofAsset:asset atTime:startTime error:&failure];
        completionHandler(failure);
    });
}

@end

@implementation AVVideoComposition (CharonAVFoundationAsyncProperties)

+ (void)videoCompositionWithPropertiesOfAsset:(AVAsset *)asset completionHandler:(void (^)(AVVideoComposition *videoComposition, NSError *error))completionHandler
{
    dispatch_async(charon_avf_composition_queue(), ^{
        completionHandler([AVVideoComposition videoCompositionWithPropertiesOfAsset:asset], nil);
    });
}

- (void)determineValidityForAsset:(AVAsset *)asset timeRange:(CMTimeRange)timeRange validationDelegate:(id<AVVideoCompositionValidationHandling>)validationDelegate completionHandler:(void (^)(BOOL isValid, NSError *error))completionHandler
{
    BOOL isValid = [self isValidForAsset:asset timeRange:timeRange validationDelegate:validationDelegate];
    completionHandler(isValid, nil);
}

@end

@implementation AVMutableVideoComposition (CharonAVFoundationAsyncProperties)

+ (void)videoCompositionWithPropertiesOfAsset:(AVAsset *)asset completionHandler:(void (^)(AVMutableVideoComposition *videoComposition, NSError *error))completionHandler
{
    dispatch_async(charon_avf_composition_queue(), ^{
        completionHandler([AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset], nil);
    });
}

+ (void)videoCompositionWithPropertiesOfAsset:(AVAsset *)asset prototypeInstruction:(AVVideoCompositionInstruction *)prototypeInstruction completionHandler:(void (^)(AVMutableVideoComposition *videoComposition, NSError *error))completionHandler
{
    dispatch_async(charon_avf_composition_queue(), ^{
        if (![prototypeInstruction isKindOfClass:[AVVideoCompositionInstruction class]]) {
            // 6.1.3 has no AVVideoCompositionInstructionProtocol at all: of the 16 AV-named protocols in
            // its armv7 cache the composition instruction protocol is not one, and the instructions it
            // accepts are instances of the AVVideoCompositionInstruction class - a member of which is the
            // only shape this release can put into a composition. A prototype of any other shape cannot
            // be honoured here, and the release's own error vocabulary has no code for that either:
            // first-rung answers NONE for _AVErrorUnknown and for _AVErrorOperationNotSupportedForAsset.
            completionHandler(nil, [NSError errorWithDomain:@"org.charon.avf.composition" code:1 userInfo:@{NSLocalizedDescriptionKey: @"6.1.3 composes with AVVideoCompositionInstruction instances only"}]);
            return;
        }
        AVMutableVideoComposition *composition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset];
        AVMutableVideoCompositionInstruction *instruction = [(AVVideoCompositionInstruction *)prototypeInstruction mutableCopy];
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
        composition.instructions = @[instruction];
        completionHandler(composition, nil);
    });
}

@end