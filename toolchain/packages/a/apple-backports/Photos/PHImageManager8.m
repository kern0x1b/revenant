#import "CharonPhotos.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#include <libkern/OSAtomic.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

const CGSize PHImageManagerMaximumSize = {-1, -1};
NSString *const PHImageResultIsInCloudKey = @"PHImageResultIsInCloudKey";
NSString *const PHImageResultIsDegradedKey = @"PHImageResultIsDegradedKey";
NSString *const PHImageResultRequestIDKey = @"PHImageResultRequestIDKey";
NSString *const PHImageCancelledKey = @"PHImageCancelledKey";
NSString *const PHImageErrorKey = @"PHImageErrorKey";

@implementation PHImageRequestOptions

- (instancetype)init
{
    self = [super init];
    if (self)
        self.resizeMode = PHImageRequestOptionsResizeModeFast;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    PHImageRequestOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.version = self.version;
    copy.deliveryMode = self.deliveryMode;
    copy.resizeMode = self.resizeMode;
    copy.normalizedCropRect = self.normalizedCropRect;
    copy.networkAccessAllowed = self.networkAccessAllowed;
    copy.synchronous = self.synchronous;
    copy.progressHandler = self.progressHandler;
    return copy;
}

@end

@implementation PHVideoRequestOptions
@end

static BOOL charon_turned(ALAssetOrientation orientation)
{
    return orientation == ALAssetOrientationLeft || orientation == ALAssetOrientationRight
        || orientation == ALAssetOrientationLeftMirrored || orientation == ALAssetOrientationRightMirrored;
}

static UIImage *charon_image(ALAsset *asset, CGSize target, PHImageContentMode mode, PHImageRequestOptions *options)
{
    ALAssetRepresentation *representation = asset.defaultRepresentation;
    if (!representation)
        return nil;
    ALAssetOrientation orientation = representation.orientation;
    CGSize stored = representation.dimensions;
    CGSize shown = charon_turned(orientation) ? CGSizeMake(stored.height, stored.width) : stored;
    BOOL maximum = target.width <= 0 || target.height <= 0;
    BOOL exact = options.resizeMode == PHImageRequestOptionsResizeModeExact;
    CGRect crop = options.normalizedCropRect;
    BOOL cropped = exact && !CGRectIsEmpty(crop);
    CGSize canvas = shown;
    CGSize drawn = shown;
    if (!maximum && shown.width > 0 && shown.height > 0) {
        CGFloat scale = mode == PHImageContentModeAspectFill ? MAX(target.width / shown.width, target.height / shown.height)
                                                             : MIN(target.width / shown.width, target.height / shown.height);
        if (scale > 1 && !exact)
            scale = 1;
        drawn = CGSizeMake(round(shown.width * scale), round(shown.height * scale));
        canvas = exact && (mode == PHImageContentModeAspectFill || cropped) ? target : drawn;
        if (cropped)
            drawn = CGSizeMake(target.width / crop.size.width, target.height / crop.size.height);
    }
    CGFloat needed = MAX(drawn.width, drawn.height);
    CGImageRef reference = NULL;
    UIImageOrientation imageOrientation = UIImageOrientationUp;
    if (!maximum) {
        CGImageRef thumbnail = asset.aspectRatioThumbnail;
        CGImageRef screen = representation.fullScreenImage;
        if (thumbnail && MAX(CGImageGetWidth(thumbnail), CGImageGetHeight(thumbnail)) >= needed)
            reference = thumbnail;
        else if (screen && MAX(CGImageGetWidth(screen), CGImageGetHeight(screen)) >= needed)
            reference = screen;
    }
    if (!reference) {
        reference = representation.fullResolutionImage;
        imageOrientation = (UIImageOrientation)orientation;
        if (!reference) {
            reference = representation.fullScreenImage ?: asset.aspectRatioThumbnail;
            imageOrientation = UIImageOrientationUp;
        }
    }
    if (!reference)
        return nil;
    UIImage *source = [UIImage imageWithCGImage:reference scale:1 orientation:imageOrientation];
    if (CGSizeEqualToSize(source.size, canvas) && !cropped)
        return source;
    UIGraphicsBeginImageContextWithOptions(canvas, NO, 1);
    CGRect rectangle = cropped ? CGRectMake(-crop.origin.x * drawn.width, -crop.origin.y * drawn.height, drawn.width, drawn.height)
                               : CGRectMake((canvas.width - drawn.width) / 2, (canvas.height - drawn.height) / 2, drawn.width, drawn.height);
    [source drawInRect:rectangle];
    UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return rendered;
}

static NSData *charon_data(ALAssetRepresentation *representation)
{
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)representation.size];
    NSUInteger read = 0;
    while (read < data.length) {
        NSError *error = nil;
        NSUInteger got = [representation getBytes:(uint8_t *)data.mutableBytes + read fromOffset:read length:MIN((NSUInteger)65536, data.length - read) error:&error];
        if (!got)
            return nil;
        read += got;
    }
    return data;
}

@implementation PHImageManager

+ (PHImageManager *)defaultManager
{
    static PHImageManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[PHImageManager alloc] init];
    });
    return manager;
}

+ (NSMutableSet *)cancelled
{
    static NSMutableSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSMutableSet set];
    });
    return set;
}

+ (PHImageRequestID)issue
{
    static int32_t last;
    return OSAtomicIncrement32(&last);
}

+ (BOOL)takeCancellation:(PHImageRequestID)requestID
{
    NSMutableSet *set = [self cancelled];
    @synchronized (set) {
        BOOL was = [set containsObject:@(requestID)];
        [set removeObject:@(requestID)];
        return was;
    }
}

- (void)cancelImageRequest:(PHImageRequestID)requestID
{
    NSMutableSet *set = [PHImageManager cancelled];
    @synchronized (set) {
        [set addObject:@(requestID)];
    }
}

- (PHImageRequestID)charon_request:(PHImageRequestID)requestID synchronous:(BOOL)synchronous work:(void (^)(BOOL cancelled, NSMutableDictionary *info))work
{
    NSMutableDictionary *(^fresh)(void) = ^NSMutableDictionary *{
        return [NSMutableDictionary dictionaryWithObjectsAndKeys:@(requestID), PHImageResultRequestIDKey, @NO, PHImageResultIsInCloudKey, nil];
    };
    if (synchronous) {
        work(NO, fresh());
        return requestID;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL cancelled = [PHImageManager takeCancellation:requestID];
        NSMutableDictionary *info = fresh();
        dispatch_async(dispatch_get_main_queue(), ^{
            work(cancelled, info);
        });
    });
    return requestID;
}

- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(PHImageRequestOptions *)options
                           resultHandler:(void (^)(UIImage *result, NSDictionary *info))resultHandler
{
    PHImageRequestID requestID = [PHImageManager issue];
    BOOL synchronous = options.synchronous;
    __block UIImage *rendered = nil;
    void (^render)(void) = ^{
        rendered = charon_image([asset charon_asset], targetSize, contentMode, options);
    };
    if (!synchronous) {
        return [self charon_request:requestID synchronous:NO work:^(BOOL cancelled, NSMutableDictionary *info) {
            info[PHImageResultIsDegradedKey] = @NO;
            if (cancelled) {
                info[PHImageCancelledKey] = @YES;
                resultHandler(nil, info);
                return;
            }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                render();
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!rendered)
                        info[PHImageErrorKey] = [CharonPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the image of the asset could not be read"];
                    resultHandler(rendered, info);
                });
            });
        }];
    }
    return [self charon_request:requestID synchronous:YES work:^(BOOL cancelled, NSMutableDictionary *info) {
        render();
        info[PHImageResultIsDegradedKey] = @NO;
        if (!rendered)
            info[PHImageErrorKey] = [CharonPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the image of the asset could not be read"];
        resultHandler(rendered, info);
    }];
}

- (PHImageRequestID)requestImageDataForAsset:(PHAsset *)asset options:(PHImageRequestOptions *)options
                               resultHandler:(void (^)(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info))resultHandler
{
    PHImageRequestID requestID = [PHImageManager issue];
    void (^deliver)(NSMutableDictionary *) = ^(NSMutableDictionary *info) {
        ALAssetRepresentation *representation = [asset charon_asset].defaultRepresentation;
        NSData *data = representation ? charon_data(representation) : nil;
        if (!data)
            info[PHImageErrorKey] = [CharonPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the data of the asset could not be read"];
        resultHandler(data, data ? representation.UTI : nil, data ? (UIImageOrientation)representation.orientation : UIImageOrientationUp, info);
    };
    return [self charon_request:requestID synchronous:options.synchronous work:^(BOOL cancelled, NSMutableDictionary *info) {
        if (cancelled) {
            info[PHImageCancelledKey] = @YES;
            resultHandler(nil, nil, UIImageOrientationUp, info);
            return;
        }
        deliver(info);
    }];
}

- (PHImageRequestID)requestImageDataAndOrientationForAsset:(PHAsset *)asset options:(PHImageRequestOptions *)options
                                             resultHandler:(void (^)(NSData *imageData, NSString *dataUTI, CGImagePropertyOrientation orientation, NSDictionary *info))resultHandler
{
    static const CGImagePropertyOrientation mapped[] = {kCGImagePropertyOrientationUp, kCGImagePropertyOrientationDown, kCGImagePropertyOrientationLeft,
        kCGImagePropertyOrientationRight, kCGImagePropertyOrientationUpMirrored, kCGImagePropertyOrientationDownMirrored,
        kCGImagePropertyOrientationLeftMirrored, kCGImagePropertyOrientationRightMirrored};
    return [self requestImageDataForAsset:asset options:options resultHandler:^(NSData *data, NSString *UTI, UIImageOrientation orientation, NSDictionary *info) {
        resultHandler(data, UTI, mapped[orientation & 7], info);
    }];
}

- (NSURL *)charon_videoURL:(PHAsset *)asset
{
    return asset.mediaType == PHAssetMediaTypeVideo ? [asset charon_asset].defaultRepresentation.url : nil;
}

- (PHImageRequestID)charon_requestVideo:(PHAsset *)asset result:(void (^)(AVURLAsset *video, NSMutableDictionary *info))result
{
    PHImageRequestID requestID = [PHImageManager issue];
    return [self charon_request:requestID synchronous:NO work:^(BOOL cancelled, NSMutableDictionary *info) {
        NSURL *url = cancelled ? nil : [self charon_videoURL:asset];
        if (cancelled)
            info[PHImageCancelledKey] = @YES;
        else if (!url)
            info[PHImageErrorKey] = [CharonPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the asset is not a video that can be read"];
        result(url ? [AVURLAsset URLAssetWithURL:url options:nil] : nil, info);
    }];
}

- (PHImageRequestID)requestAVAssetForVideo:(PHAsset *)asset options:(PHVideoRequestOptions *)options
                             resultHandler:(void (^)(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info))resultHandler
{
    return [self charon_requestVideo:asset result:^(AVURLAsset *video, NSMutableDictionary *info) {
        resultHandler(video, nil, info);
    }];
}

- (PHImageRequestID)requestPlayerItemForVideo:(PHAsset *)asset options:(PHVideoRequestOptions *)options
                                resultHandler:(void (^)(AVPlayerItem *playerItem, NSDictionary *info))resultHandler
{
    return [self charon_requestVideo:asset result:^(AVURLAsset *video, NSMutableDictionary *info) {
        resultHandler(video ? [AVPlayerItem playerItemWithAsset:video] : nil, info);
    }];
}

- (PHImageRequestID)requestExportSessionForVideo:(PHAsset *)asset options:(PHVideoRequestOptions *)options exportPreset:(NSString *)exportPreset
                                   resultHandler:(void (^)(AVAssetExportSession *exportSession, NSDictionary *info))resultHandler
{
    return [self charon_requestVideo:asset result:^(AVURLAsset *video, NSMutableDictionary *info) {
        resultHandler(video ? [AVAssetExportSession exportSessionWithAsset:video presetName:exportPreset] : nil, info);
    }];
}

@end

@implementation PHCachingImageManager {
    BOOL _allowsCachingHighQualityImages;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _allowsCachingHighQualityImages = YES;
    return self;
}

- (BOOL)allowsCachingHighQualityImages
{
    return _allowsCachingHighQualityImages;
}

- (void)setAllowsCachingHighQualityImages:(BOOL)allows
{
    _allowsCachingHighQualityImages = allows;
}

- (void)startCachingImagesForAssets:(NSArray<PHAsset *> *)assets targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(PHImageRequestOptions *)options
{
}

- (void)stopCachingImagesForAssets:(NSArray<PHAsset *> *)assets targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(PHImageRequestOptions *)options
{
}

- (void)stopCachingImagesForAllAssets
{
}

@end
