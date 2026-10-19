#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_default_rate_key;

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
