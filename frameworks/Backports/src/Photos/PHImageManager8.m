#import "RevenantPhotos.h"
#import "RevenantPhotosImageCache.h"
#import "RevenantPhotosImageSource.h"
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

- (id)copyWithZone:(NSZone *)zone
{
    PHVideoRequestOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.networkAccessAllowed = self.networkAccessAllowed;
    copy.version = self.version;
    copy.deliveryMode = self.deliveryMode;
    copy.progressHandler = self.progressHandler;
    return copy;
}

@end

static BOOL revenant_turned(ALAssetOrientation orientation)
{
    return orientation == ALAssetOrientationLeft || orientation == ALAssetOrientationRight
        || orientation == ALAssetOrientationLeftMirrored || orientation == ALAssetOrientationRightMirrored;
}

static UIImage *revenant_image(ALAsset *asset, CGSize target, PHImageContentMode mode, PHImageRequestOptions *options)
{
    ALAssetRepresentation *representation = asset.defaultRepresentation;
    if (!representation)
        return nil;
    ALAssetOrientation orientation = representation.orientation;
    CGSize stored = representation.dimensions;
    CGSize shown = revenant_turned(orientation) ? CGSizeMake(stored.height, stored.width) : stored;
    BOOL maximum = target.width < 0 || target.height < 0;
    if (!maximum && (target.width == 0 || target.height == 0))
        return nil;
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
    CGImageRef thumbnail = maximum ? NULL : asset.aspectRatioThumbnail;
    CGImageRef screen = !maximum && (!thumbnail || MAX(CGImageGetWidth(thumbnail), CGImageGetHeight(thumbnail)) < needed)
        ? representation.fullScreenImage : NULL;
    float thumbnailPixels = thumbnail ? MAX(CGImageGetWidth(thumbnail), CGImageGetHeight(thumbnail)) : 0;
    float screenPixels = screen ? MAX(CGImageGetWidth(screen), CGImageGetHeight(screen)) : 0;
    RevenantPhotosImageSource selection = RevenantPhotosImageSourceForRequest(needed, thumbnailPixels, screenPixels,
        thumbnail != NULL, screen != NULL, YES, maximum);
    CGImageRef reference = selection == RevenantPhotosImageSourceThumbnail ? thumbnail
        : selection == RevenantPhotosImageSourceFullScreen ? screen
        : selection == RevenantPhotosImageSourceFullResolution ? representation.fullResolutionImage : NULL;
    UIImageOrientation imageOrientation = selection == RevenantPhotosImageSourceFullResolution ? (UIImageOrientation)orientation : UIImageOrientationUp;
    if (!reference)
        return nil;
    UIImage *sourceImage = [UIImage imageWithCGImage:reference scale:1 orientation:imageOrientation];
    if (CGSizeEqualToSize(sourceImage.size, canvas) && !cropped)
        return sourceImage;
    UIGraphicsBeginImageContextWithOptions(canvas, NO, 1);
    CGRect rectangle = cropped ? CGRectMake(-crop.origin.x * drawn.width, -crop.origin.y * drawn.height, drawn.width, drawn.height)
                               : CGRectMake((canvas.width - drawn.width) / 2, (canvas.height - drawn.height) / 2, drawn.width, drawn.height);
    [sourceImage drawInRect:rectangle];
    UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return rendered;
}

static RevenantPhotosImageCache *revenant_image_cache(void)
{
    static RevenantPhotosImageCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[RevenantPhotosImageCache alloc] initWithCapacity:12 * 1024 * 1024];
    });
    return cache;
}

static NSString *revenant_image_cache_key(PHAsset *asset, CGSize targetSize, PHImageContentMode contentMode, PHImageRequestOptions *options)
{
    return [NSString stringWithFormat:@"%@|%a|%a|%lu|%lu|%lu|%lu|%a|%a|%a|%a", asset.localIdentifier ?: @"", targetSize.width,
        targetSize.height, (unsigned long)contentMode, (unsigned long)options.version, (unsigned long)options.deliveryMode,
        (unsigned long)options.resizeMode, options.normalizedCropRect.origin.x, options.normalizedCropRect.origin.y,
        options.normalizedCropRect.size.width, options.normalizedCropRect.size.height];
}

static NSUInteger revenant_image_cost(UIImage *image)
{
    CGImageRef cgImage = image.CGImage;
    return cgImage ? CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage) : 0;
}

static NSError *revenant_unavailable_asset_error(PHAsset *asset)
{
    NSString *reason = asset.sourceType == PHAssetSourceTypeCloudShared
        ? @"iOS 6 AssetsLibrary cannot retrieve an iCloud-only photo stream asset"
        : @"the asset has no local representation in AssetsLibrary";
    return [RevenantPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:reason];
}

static ALAsset *revenant_requested_asset(PHAsset *asset, PHImageRequestOptionsVersion version)
{
    ALAsset *source = [asset revenant_asset];
    return version == PHImageRequestOptionsVersionCurrent ? source : source.originalAsset ?: source;
}

static NSData *revenant_data(ALAssetRepresentation *representation, PHAssetImageProgressHandler progressHandler, NSDictionary *info, BOOL *stopped)
{
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)representation.size];
    NSUInteger read = 0;
    BOOL stop = NO;
    if (progressHandler)
        progressHandler(data.length == 0 ? 1.0 : 0.0, nil, &stop, info);
    if (stop) {
        *stopped = YES;
        return nil;
    }
    while (read < data.length) {
        NSError *error = nil;
        NSUInteger got = [representation getBytes:(uint8_t *)data.mutableBytes + read fromOffset:read length:MIN((NSUInteger)65536, data.length - read) error:&error];
        if (!got)
            return nil;
        read += got;
        stop = NO;
        if (progressHandler)
            progressHandler((double)read / data.length, nil, &stop, info);
        if (stop) {
            *stopped = YES;
            return nil;
        }
    }
    return data;
}

static NSMutableDictionary *revenant_pending(void)
{
    static NSMutableDictionary *pending;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pending = [NSMutableDictionary dictionary];
    });
    return pending;
}

static void revenant_cancel(PHImageRequestID requestID)
{
    NSMutableDictionary *pending = revenant_pending();
    @synchronized (pending) {
        if (pending[@(requestID)])
            pending[@(requestID)] = @YES;
    }
}

static BOOL revenant_cancelled(PHImageRequestID requestID)
{
    NSMutableDictionary *pending = revenant_pending();
    @synchronized (pending) {
        return [pending[@(requestID)] boolValue];
    }
}

static BOOL revenant_complete(PHImageRequestID requestID)
{
    NSMutableDictionary *pending = revenant_pending();
    @synchronized (pending) {
        BOOL cancelled = [pending[@(requestID)] boolValue];
        [pending removeObjectForKey:@(requestID)];
        return cancelled;
    }
}

static void revenant_deliver_image(PHImageRequestID requestID, UIImage *image, NSMutableDictionary *info, void (^handler)(UIImage *result, NSDictionary *info))
{
    if (revenant_complete(requestID)) {
        info[PHImageCancelledKey] = @YES;
        handler(nil, info);
        return;
    }
    handler(image, info);
}

static void revenant_deliver_data(PHImageRequestID requestID, NSData *data, NSString *uti, UIImageOrientation orientation, NSMutableDictionary *info,
                                  void (^handler)(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info))
{
    if (revenant_complete(requestID)) {
        info[PHImageCancelledKey] = @YES;
        handler(nil, nil, UIImageOrientationUp, info);
        return;
    }
    handler(data, uti, orientation, info);
}

@implementation PHImageManager

- (instancetype)init
{
    self = [super init];
    if (self)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(revenant_memoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)revenant_memoryWarning:(NSNotification *)notification
{
    [revenant_image_cache() removeAllObjects];
}

+ (PHImageManager *)defaultManager
{
    static PHImageManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[PHImageManager alloc] init];
    });
    return manager;
}

+ (PHImageRequestID)issue
{
    static int32_t last;
    return OSAtomicIncrement32(&last);
}

- (void)cancelImageRequest:(PHImageRequestID)requestID
{
    revenant_cancel(requestID);
}

- (PHImageRequestID)revenant_request:(PHImageRequestID)requestID synchronous:(BOOL)synchronous work:(void (^)(NSMutableDictionary *info))work
{
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(requestID), PHImageResultRequestIDKey, @NO, PHImageResultIsInCloudKey, nil];
    if (synchronous) {
        work(info);
        return requestID;
    }
    NSMutableDictionary *pending = revenant_pending();
    @synchronized (pending) {
        pending[@(requestID)] = @NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        work(info);
    });
    return requestID;
}

- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(PHImageRequestOptions *)options
                           resultHandler:(void (^)(UIImage *result, NSDictionary *info))resultHandler
{
    PHImageRequestID requestID = [PHImageManager issue];
    PHImageRequestOptions *requestOptions = [options copy] ?: [[PHImageRequestOptions alloc] init];
    NSString *key = revenant_image_cache_key(asset, targetSize, contentMode, requestOptions);
    __block UIImage *rendered = nil;
    void (^render)(void) = ^{
        rendered = revenant_image(revenant_requested_asset(asset, requestOptions.version), targetSize, contentMode, requestOptions);
        if (rendered)
            [revenant_image_cache() setObject:rendered forKey:key cost:revenant_image_cost(rendered)];
    };
    if (requestOptions.synchronous) {
        return [self revenant_request:requestID synchronous:YES work:^(NSMutableDictionary *info) {
            if (!asset.isLocallyAvailable) {
                info[PHImageErrorKey] = revenant_unavailable_asset_error(asset);
                resultHandler(nil, info);
                return;
            }
            rendered = [revenant_image_cache() objectForKey:key];
            if (!rendered)
                render();
            info[PHImageResultIsDegradedKey] = @NO;
            if (!rendered)
                info[PHImageErrorKey] = [RevenantPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the image of the asset could not be read"];
            resultHandler(rendered, info);
        }];
    }
    return [self revenant_request:requestID synchronous:NO work:^(NSMutableDictionary *info) {
        info[PHImageResultIsDegradedKey] = @NO;
        if (revenant_cancelled(requestID)) {
            revenant_deliver_image(requestID, nil, info, resultHandler);
            return;
        }
        if (!asset.isLocallyAvailable) {
            info[PHImageErrorKey] = revenant_unavailable_asset_error(asset);
            revenant_deliver_image(requestID, nil, info, resultHandler);
            return;
        }
        UIImage *cached = [revenant_image_cache() objectForKey:key];
        if (cached) {
            revenant_deliver_image(requestID, cached, info, resultHandler);
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            render();
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!rendered)
                    info[PHImageErrorKey] = [RevenantPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the image of the asset could not be read"];
                revenant_deliver_image(requestID, rendered, info, resultHandler);
            });
        });
    }];
}

- (PHImageRequestID)requestLivePhotoForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(PHLivePhotoRequestOptions *)options
                               resultHandler:(void (^)(PHLivePhoto *livePhoto, NSDictionary *info))resultHandler
{
    PHImageRequestID requestID = [PHImageManager issue];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(requestID), PHImageResultRequestIDKey, @NO, PHImageResultIsInCloudKey, nil];
    info[PHImageErrorKey] = [RevenantPhotosStore errorWithCode:PHPhotosErrorRequestNotSupportedForAsset reason:@"a Live Photo needs iOS 9.1; the AssetsLibrary on iOS 6 keeps no paired video"];
    dispatch_async(dispatch_get_main_queue(), ^{
        resultHandler(nil, info);
    });
    return requestID;
}

- (PHImageRequestID)requestImageDataForAsset:(PHAsset *)asset options:(PHImageRequestOptions *)options
                               resultHandler:(void (^)(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info))resultHandler
{
    PHImageRequestID requestID = [PHImageManager issue];
    PHImageRequestOptions *requestOptions = [options copy] ?: [[PHImageRequestOptions alloc] init];
    void (^read)(NSMutableDictionary *, void (^)(NSData *, NSString *, UIImageOrientation)) =
        ^(NSMutableDictionary *info, void (^completion)(NSData *, NSString *, UIImageOrientation)) {
        if (!asset.isLocallyAvailable) {
            NSError *error = revenant_unavailable_asset_error(asset);
            info[PHImageErrorKey] = error;
            BOOL stop = YES;
            if (requestOptions.progressHandler)
                requestOptions.progressHandler(0, error, &stop, info);
            completion(nil, nil, UIImageOrientationUp);
            return;
        }
        ALAssetRepresentation *representation = revenant_requested_asset(asset, requestOptions.version).defaultRepresentation;
        BOOL stopped = NO;
        NSData *data = representation ? revenant_data(representation, requestOptions.progressHandler, info, &stopped) : nil;
        if (stopped)
            info[PHImageCancelledKey] = @YES;
        else if (!data)
            info[PHImageErrorKey] = [RevenantPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the data of the asset could not be read"];
        completion(data, data ? representation.UTI : nil, data ? (UIImageOrientation)representation.orientation : UIImageOrientationUp);
    };
    if (requestOptions.synchronous) {
        return [self revenant_request:requestID synchronous:YES work:^(NSMutableDictionary *info) {
            read(info, ^(NSData *data, NSString *uti, UIImageOrientation orientation) {
                resultHandler(data, uti, orientation, info);
            });
        }];
    }
    return [self revenant_request:requestID synchronous:NO work:^(NSMutableDictionary *info) {
        if (revenant_cancelled(requestID)) {
            revenant_deliver_data(requestID, nil, nil, UIImageOrientationUp, info, resultHandler);
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            read(info, ^(NSData *data, NSString *uti, UIImageOrientation orientation) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    revenant_deliver_data(requestID, data, uti, orientation, info, resultHandler);
                });
            });
        });
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

- (NSURL *)revenant_videoURL:(PHAsset *)asset version:(PHVideoRequestOptionsVersion)version
{
    ALAsset *source = version == PHVideoRequestOptionsVersionCurrent
        ? [asset revenant_asset] : [asset revenant_asset].originalAsset ?: [asset revenant_asset];
    return asset.mediaType == PHAssetMediaTypeVideo && asset.isLocallyAvailable ? source.defaultRepresentation.url : nil;
}

- (PHImageRequestID)revenant_requestVideo:(PHAsset *)asset options:(PHVideoRequestOptions *)options result:(void (^)(AVURLAsset *video, NSMutableDictionary *info))result
{
    PHVideoRequestOptions *requestOptions = [options copy] ?: [[PHVideoRequestOptions alloc] init];
    PHImageRequestID requestID = [PHImageManager issue];
    return [self revenant_request:requestID synchronous:NO work:^(NSMutableDictionary *info) {
        if (revenant_complete(requestID)) {
            info[PHImageCancelledKey] = @YES;
            result(nil, info);
            return;
        }
        NSURL *url = [self revenant_videoURL:asset version:requestOptions.version];
        NSError *error = nil;
        if (!url) {
            error = asset.isLocallyAvailable
                ? [RevenantPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the asset is not a video that can be read"]
                : revenant_unavailable_asset_error(asset);
            info[PHImageErrorKey] = error;
        }
        BOOL stop = NO;
        if (requestOptions.progressHandler)
            requestOptions.progressHandler(url ? 1.0 : 0.0, error, &stop, info);
        if (stop) {
            info[PHImageCancelledKey] = @YES;
            url = nil;
        }
        result(url ? [AVURLAsset URLAssetWithURL:url options:nil] : nil, info);
    }];
}

- (PHImageRequestID)requestAVAssetForVideo:(PHAsset *)asset options:(PHVideoRequestOptions *)options
                             resultHandler:(void (^)(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info))resultHandler
{
    return [self revenant_requestVideo:asset options:options result:^(AVURLAsset *video, NSMutableDictionary *info) {
        resultHandler(video, nil, info);
    }];
}

- (PHImageRequestID)requestPlayerItemForVideo:(PHAsset *)asset options:(PHVideoRequestOptions *)options
                                resultHandler:(void (^)(AVPlayerItem *playerItem, NSDictionary *info))resultHandler
{
    return [self revenant_requestVideo:asset options:options result:^(AVURLAsset *video, NSMutableDictionary *info) {
        resultHandler(video ? [AVPlayerItem playerItemWithAsset:video] : nil, info);
    }];
}

- (PHImageRequestID)requestExportSessionForVideo:(PHAsset *)asset options:(PHVideoRequestOptions *)options exportPreset:(NSString *)exportPreset
                                   resultHandler:(void (^)(AVAssetExportSession *exportSession, NSDictionary *info))resultHandler
{
    return [self revenant_requestVideo:asset options:options result:^(AVURLAsset *video, NSMutableDictionary *info) {
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
    PHImageRequestOptions *requestOptions = [options copy] ?: [[PHImageRequestOptions alloc] init];
    requestOptions.synchronous = NO;
    for (PHAsset *asset in assets)
        [self requestImageForAsset:asset targetSize:targetSize contentMode:contentMode options:requestOptions resultHandler:^(UIImage *image, NSDictionary *info) {}];
}

- (void)stopCachingImagesForAssets:(NSArray<PHAsset *> *)assets targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(PHImageRequestOptions *)options
{
    for (PHAsset *asset in assets)
        [revenant_image_cache() removeObjectForKey:revenant_image_cache_key(asset, targetSize, contentMode, options ?: [[PHImageRequestOptions alloc] init])];
}

- (void)stopCachingImagesForAllAssets
{
    [revenant_image_cache() removeAllObjects];
}

@end
