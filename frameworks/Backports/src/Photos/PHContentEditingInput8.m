#include "../revenant_impl.h"
#import "RevenantPhotos.h"

NSString *const BACKPORT_IMPL(PHContentEditingInputCancelledKey) = @"PHContentEditingInputCancelledKey";
NSString *const BACKPORT_IMPL(PHContentEditingInputErrorKey) = @"PHContentEditingInputErrorKey";

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@interface PHContentEditingInput (RevenantContentEditing)
- (instancetype)initWithRevenantFullSizeImageURL:(NSURL *)url mediaType:(PHAssetMediaType)mediaType;
@end

@implementation PHContentEditingInput {
    NSURL *_fullSizeImageURL;
    PHAssetMediaType _mediaType;
}

@synthesize fullSizeImageURL = _fullSizeImageURL;
@synthesize mediaType = _mediaType;

- (instancetype)initWithRevenantFullSizeImageURL:(NSURL *)url mediaType:(PHAssetMediaType)mediaType
{
    if ((self = [super init])) {
        _fullSizeImageURL = url;
        _mediaType = mediaType;
    }
    return self;
}

@end

@implementation PHContentEditingInputRequestOptions
@synthesize canHandleAdjustmentData;
@synthesize networkAccessAllowed;
@synthesize progressHandler;
@end

@interface PHAsset (RevenantContentEditing)
- (PHContentEditingInputRequestID)requestContentEditingInputWithOptions:(PHContentEditingInputRequestOptions *)options completionHandler:(void (^)(PHContentEditingInput *contentEditingInput, NSDictionary *info))completionHandler;
- (void)cancelContentEditingInputRequest:(PHContentEditingInputRequestID)requestID;
@end

@implementation PHAsset (RevenantContentEditing)

- (PHContentEditingInputRequestID)requestContentEditingInputWithOptions:(PHContentEditingInputRequestOptions *)options completionHandler:(void (^)(PHContentEditingInput *, NSDictionary *))completionHandler
{
    void (^reply)(PHContentEditingInput *, NSDictionary *) = [completionHandler copy];
    if (self.mediaType != PHAssetMediaTypeImage) {
        PHContentEditingInput *input = [[PHContentEditingInput alloc] initWithRevenantFullSizeImageURL:nil mediaType:self.mediaType];
        dispatch_async(dispatch_get_main_queue(), ^{
            reply(input, @{});
        });
        return 0;
    }
    PHContentEditingInputRequestOptions *requested = options ?: [[PHContentEditingInputRequestOptions alloc] init];
    PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
    imageOptions.networkAccessAllowed = requested.networkAccessAllowed;
    imageOptions.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
        BOOL cancel = NO;
        if (requested.progressHandler)
            requested.progressHandler(progress, &cancel);
        *stop = cancel;
    };
    NSString *extension = [self revenant_asset].defaultRepresentation.filename.pathExtension;
    PHImageRequestID imageRequestID = [[PHImageManager defaultManager] requestImageDataForAsset:self options:imageOptions resultHandler:^(NSData *data, NSString *UTI, UIImageOrientation orientation, NSDictionary *info) {
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([info[PHImageCancelledKey] boolValue])
                    reply(nil, @{PHContentEditingInputCancelledKey: @YES});
                else {
                    NSError *error = info[PHImageErrorKey] ?: [RevenantPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the asset has no full-size image data"];
                    reply(nil, @{PHContentEditingInputErrorKey: error});
                }
            });
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *name = [[NSUUID UUID] UUIDString];
            if (extension.length)
                name = [name stringByAppendingPathExtension:extension];
            NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
            NSError *writeError = nil;
            PHContentEditingInput *input = nil;
            NSDictionary *result = @{};
            if ([data writeToURL:url options:NSDataWritingAtomic error:&writeError])
                input = [[PHContentEditingInput alloc] initWithRevenantFullSizeImageURL:url mediaType:PHAssetMediaTypeImage];
            else
                result = @{PHContentEditingInputErrorKey: writeError};
            dispatch_async(dispatch_get_main_queue(), ^{
                reply(input, result);
            });
        });
    }];
    return (PHContentEditingInputRequestID)imageRequestID;
}

- (void)cancelContentEditingInputRequest:(PHContentEditingInputRequestID)requestID
{
    [[PHImageManager defaultManager] cancelImageRequest:(PHImageRequestID)requestID];
}

@end
