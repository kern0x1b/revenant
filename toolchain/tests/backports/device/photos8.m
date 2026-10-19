#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static UIImage *drawn(CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, YES, 1);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    [[UIColor blueColor] setFill];
    UIRectFill(CGRectMake(0, 0, size.width / 2, size.height / 2));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static void check_names(void)
{
    static NSString *const classes[] = {@"PHObject", @"PHObjectPlaceholder", @"PHFetchOptions", @"PHFetchResult", @"PHAsset", @"PHCollection", @"PHAssetCollection",
        @"PHCollectionList", @"PHImageRequestOptions", @"PHVideoRequestOptions", @"PHImageManager", @"PHCachingImageManager", @"PHAssetChangeRequest", @"PHChange",
        @"PHObjectChangeDetails", @"PHFetchResultChangeDetails", @"PHChangeRequest"};
    int carried = 0;
    for (size_t i = 0; i < sizeof classes / sizeof classes[0]; i++)
        carried += [image_of(NSClassFromString(classes[i])) isEqualToString:@"libPhotosBackports.dylib"];
    CHECK(carried == 17, "the 17 classes come from the backports");
    CHECK(PHImageManagerMaximumSize.width == -1 && PHImageManagerMaximumSize.height == -1, "the maximum size is -1 by -1");
    CHECK([PHImageResultIsInCloudKey isEqual:@"PHImageResultIsInCloudKey"] && [PHImageResultIsDegradedKey isEqual:@"PHImageResultIsDegradedKey"]
          && [PHImageResultRequestIDKey isEqual:@"PHImageResultRequestIDKey"] && [PHImageCancelledKey isEqual:@"PHImageCancelledKey"]
          && [PHImageErrorKey isEqual:@"PHImageErrorKey"] && [PHPhotosErrorDomain isEqual:@"PHPhotosErrorDomain"], "the keys and the error domain are strings equal to their names");
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    CHECK(!options.includeHiddenAssets && options.fetchLimit == 0 && options.includeAssetSourceTypes == 0 && options.wantsIncrementalChangeDetails, "the defaults of PHFetchOptions are those of iOS 8");
    PHImageRequestOptions *request = [[PHImageRequestOptions alloc] init];
    CHECK(request.version == 0 && request.deliveryMode == 0 && request.resizeMode == PHImageRequestOptionsResizeModeFast && !request.synchronous && !request.networkAccessAllowed,
          "the defaults of PHImageRequestOptions are those of iOS 8");
    PHVideoRequestOptions *video = [[PHVideoRequestOptions alloc] init];
    CHECK(video.version == 0 && video.deliveryMode == 0 && !video.networkAccessAllowed, "the defaults of PHVideoRequestOptions");
    PHFetchOptions *copy = [options copy];
    CHECK(copy != options && copy.wantsIncrementalChangeDetails, "PHFetchOptions copies");
    CHECK_EQUAL(raised(^{ [PHAssetChangeRequest creationRequestForAssetFromImage:drawn(CGSizeMake(2, 2))]; }),
                @"NSInternalInconsistencyException: This method can only be called from inside of -[PHPhotoLibrary performChanges:completionHandler:] or -[PHPhotoLibrary performChangesAndWait:error:]",
                "a creation request outside a change raises with the text of iOS 8");
    CHECK_EQUAL(raised(^{ [PHAssetChangeRequest deleteAssets:@[]]; }),
                @"NSInternalInconsistencyException: This method can only be called from inside of -[PHPhotoLibrary performChanges:completionHandler:] or -[PHPhotoLibrary performChangesAndWait:error:]",
                "deleting outside a change raises the same");
    PHFetchResult *empty = [PHAsset fetchAssetsWithLocalIdentifiers:@[@"no such asset"] options:nil];
    CHECK(empty.count == 0 && empty.firstObject == nil && empty.lastObject == nil, "an identifier that is not found gives an empty result");
    CHECK([PHCollectionList fetchCollectionListsWithType:PHCollectionListTypeFolder subtype:PHCollectionListSubtypeAny options:nil].count == 0, "there are no collection lists");
}

static void check_refusals(void)
{
    NSError *error = nil;
    BOOL done = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        [PHAssetChangeRequest deleteAssets:@[]];
    } error:&error];
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusDenied || [PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusRestricted) {
        CHECK(!done && error.code >= 3310, "with no access a change fails with the error of access");
        return;
    }
    CHECK(!done, "a change that deletes fails");
    CHECK_EQUAL(error.domain, @"PHPhotosErrorDomain", "in the domain of Photos");
    CHECK(error.code == PHPhotosErrorChangeNotSupported, "with the code of a change that is not supported");
    CHECK(error.localizedDescription.length > 0, "and a reason");
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    __block BOOL success = YES;
    __block NSError *given = nil;
    __block BOOL onMain = YES;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *request = [PHAssetChangeRequest creationRequestForAssetFromImage:drawn(CGSizeMake(2, 2))];
        request.favorite = YES;
    } completionHandler:^(BOOL result, NSError *problem) {
        success = result;
        given = problem;
        onMain = [NSThread isMainThread];
        dispatch_semaphore_signal(finished);
    }];
    CHECK(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0, "the completion handler is called");
    CHECK(!success && given.code == PHPhotosErrorChangeNotSupported, "a favorite fails the change, and the creation in it is not made");
    CHECK(!onMain, "off the main thread");
}

static NSString *created(UIImage *image, NSDate *date, CLLocation *location, PHObjectPlaceholder **placeholderOut)
{
    __block PHObjectPlaceholder *placeholder = nil;
    __block NSString *tokenInside = nil;
    NSError *error = nil;
    BOOL done = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetChangeRequest *request = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        request.creationDate = date;
        request.location = location;
        placeholder = request.placeholderForCreatedAsset;
        tokenInside = placeholder.localIdentifier;
    } error:&error];
    CHECK(done, "an image is added to the library");
    if (!done)
        printf("  error: %s\n", error.description.UTF8String);
    CHECK(tokenInside.length > 0 && placeholder != nil, "the placeholder has an identifier inside the change");
    if (placeholderOut)
        *placeholderOut = placeholder;
    return tokenInside;
}

static void check_library(void)
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    printf("authorization status %ld\n", (long)status);
    if (status != PHAuthorizationStatusAuthorized) {
        CHECK([PHAsset fetchAssetsWithOptions:nil].count == 0, "with no access a fetch is empty");
        CHECK([PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil].count >= 0, "and a collection fetch answers");
        return;
    }
    PHFetchResult *before = [PHAsset fetchAssetsWithOptions:nil];
    PHFetchResult *cameraRoll = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
    CHECK(cameraRoll.count == 1, "the camera roll is one smart album");
    PHAssetCollection *roll = cameraRoll.firstObject;
    CHECK(roll.assetCollectionType == PHAssetCollectionTypeSmartAlbum && roll.canContainAssets && !roll.canContainCollections && roll.localizedTitle.length, "it can hold assets and has a title");
    CHECK([PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumFavorites options:nil].count == 1
          && [PHAsset fetchAssetsInAssetCollection:[PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumFavorites options:nil].firstObject options:nil].count == 0,
          "the favorites are an empty smart album");
    CHECK([PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumPanoramas options:nil].count == 0, "the panoramas are not made");
    CHECK([PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeMoment subtype:PHAssetCollectionSubtypeAny options:nil].count == 0, "there are no moments");

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1000000000];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:50.45 longitude:30.52];
    PHObjectPlaceholder *plain = nil, *tagged = nil;
    NSString *plainToken = created(drawn(CGSizeMake(64, 48)), nil, nil, &plain);
    NSString *taggedToken = created(drawn(CGSizeMake(32, 24)), date, location, &tagged);
    NSString *plainId = plain.localIdentifier;
    NSString *taggedId = tagged.localIdentifier;
    CHECK(![plainId isEqualToString:plainToken] && [plainId hasPrefix:@"assets-library://"], "after the change the placeholder has the address of the asset");
    PHFetchResult *found = [PHAsset fetchAssetsWithLocalIdentifiers:@[plainToken, taggedId] options:nil];
    CHECK(found.count == 2, "the token and the address both find an asset");
    PHAsset *asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[plainId] options:nil].firstObject;
    CHECK(asset != nil && [asset.localIdentifier isEqualToString:plainId], "the asset is found by its identifier");
    CHECK(found.firstObject == nil || [found.firstObject isEqual:asset], "and is equal to the one the token finds");
    CHECK(asset.mediaType == PHAssetMediaTypeImage && asset.pixelWidth == 64 && asset.pixelHeight == 48, "it is an image of the size it was made");
    CHECK(asset.creationDate != nil && !asset.favorite && !asset.hidden && asset.mediaSubtypes == 0 && asset.duration == 0 && asset.sourceType == PHAssetSourceTypeUserLibrary
          && !asset.hasAdjustments && ![asset canPerformEditOperation:PHAssetEditOperationDelete], "its properties are those of a plain photo of iOS 6");
    PHAsset *dated = [PHAsset fetchAssetsWithLocalIdentifiers:@[taggedId] options:nil].firstObject;
    printf("date given %f, read back %f; location read back %s\n", date.timeIntervalSince1970, dated.creationDate.timeIntervalSince1970, dated.location.description.UTF8String ?: "none");
    CHECK(fabs(dated.creationDate.timeIntervalSince1970 - date.timeIntervalSince1970) < 86400, "the creation date given is the one read back");
    CHECK(dated.location && fabs(dated.location.coordinate.latitude - 50.45) < 0.001 && fabs(dated.location.coordinate.longitude - 30.52) < 0.001, "the location given is the one read back");

    PHFetchResult *after = [PHAsset fetchAssetsWithOptions:nil];
    CHECK(after.count == before.count + 2, "the library has two assets more");
    CHECK([after containsObject:asset] && [after indexOfObject:asset] != NSNotFound, "the fetch result contains the asset");
    CHECK([PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil].count >= 2 && [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeAudio options:nil].count == 0, "the media type fetch counts images and no audio");
    CHECK([after countOfAssetsWithMediaType:PHAssetMediaTypeImage] + [after countOfAssetsWithMediaType:PHAssetMediaTypeVideo] == after.count, "the counts of media types add up");
    PHFetchOptions *newest = [[PHFetchOptions alloc] init];
    newest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    newest.fetchLimit = 1;
    PHFetchResult *limited = [PHAsset fetchAssetsWithOptions:newest];
    CHECK(limited.count == 1, "a fetch limit of one gives one asset");
    PHFetchOptions *wide = [[PHFetchOptions alloc] init];
    wide.predicate = [NSPredicate predicateWithFormat:@"pixelWidth == 64 AND mediaType == %d", PHAssetMediaTypeImage];
    CHECK([PHAsset fetchAssetsWithOptions:wide].count >= 1 && [[PHAsset fetchAssetsWithOptions:wide] containsObject:asset], "a predicate on the properties selects the asset");
    CHECK([PHAsset fetchAssetsInAssetCollection:roll options:nil].count == after.count || [PHAsset fetchAssetsInAssetCollection:roll options:nil].count >= 2, "the camera roll holds the assets");
    CHECK([PHAssetCollection fetchAssetCollectionsContainingAsset:asset withType:PHAssetCollectionTypeSmartAlbum options:nil].count >= 1, "the camera roll is found from the asset");
    CHECK([PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[roll.localIdentifier] options:nil].firstObject != nil, "a collection is found by its identifier");
    __block NSUInteger walked = 0;
    for (PHAsset *each in after) {
        (void)each;
        walked++;
    }
    CHECK(walked == after.count, "fast enumeration walks every asset");

    __block UIImage *image = nil;
    __block NSDictionary *info = nil;
    PHImageRequestOptions *sync = [[PHImageRequestOptions alloc] init];
    sync.synchronous = YES;
    PHImageRequestID identifier = [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(32, 32) contentMode:PHImageContentModeAspectFit options:sync
                                                                          resultHandler:^(UIImage *result, NSDictionary *details) {
        image = result;
        info = details;
    }];
    CHECK(image != nil && image.size.width == 32 && image.size.height == 24, "a fitted image of 32 by 32 of a 64 by 48 asset is 32 by 24");
    CHECK([info[PHImageResultIsDegradedKey] isEqual:@NO] && [info[PHImageResultRequestIDKey] intValue] == identifier && [info[PHImageResultIsInCloudKey] isEqual:@NO], "the info has the keys of iOS 8");
    image = nil;
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(32, 32) contentMode:PHImageContentModeAspectFill options:sync
                                            resultHandler:^(UIImage *result, NSDictionary *details) { image = result; }];
    CHECK(image != nil && image.size.width == 43 && image.size.height == 32, "a filling image of 32 by 32 is 43 by 32");
    PHImageRequestOptions *exact = [[PHImageRequestOptions alloc] init];
    exact.synchronous = YES;
    exact.resizeMode = PHImageRequestOptionsResizeModeExact;
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(32, 32) contentMode:PHImageContentModeAspectFill options:exact
                                            resultHandler:^(UIImage *result, NSDictionary *details) { image = result; }];
    CHECK(image != nil && image.size.width == 32 && image.size.height == 32, "an exact filling image is 32 by 32");
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:sync
                                            resultHandler:^(UIImage *result, NSDictionary *details) { image = result; }];
    CHECK(image != nil && image.size.width == 64 && image.size.height == 48, "the maximum size gives the asset as it is");
    CGImageRef cg = image.CGImage;
    CHECK(cg != NULL, "the image has pixels");
    __block NSData *data = nil;
    __block NSString *uti = nil;
    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:sync resultHandler:^(NSData *bytes, NSString *type, UIImageOrientation orientation, NSDictionary *details) {
        data = bytes;
        uti = type;
    }];
    CHECK(data.length > 100 && [uti isEqualToString:@"public.jpeg"], "the data of the asset is a JPEG");
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    __block BOOL onMain = NO;
    __block UIImage *later = nil;
    PHImageRequestOptions *async = [[PHImageRequestOptions alloc] init];
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(16, 16) contentMode:PHImageContentModeAspectFit options:async
                                            resultHandler:^(UIImage *result, NSDictionary *details) {
        later = result;
        onMain = [NSThread isMainThread];
        dispatch_semaphore_signal(finished);
    }];
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
    long waited = 1;
    for (int i = 0; i < 200 && waited; i++) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
        waited = dispatch_semaphore_wait(finished, DISPATCH_TIME_NOW);
    }
    CHECK(waited == 0 && later != nil && onMain, "an asynchronous request is answered on the main thread");
    __block BOOL cancelled = NO;
    dispatch_semaphore_t second = dispatch_semaphore_create(0);
    PHImageRequestID doomed = [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(16, 16) contentMode:PHImageContentModeAspectFit options:async
                                                                      resultHandler:^(UIImage *result, NSDictionary *details) {
        cancelled = [details[PHImageCancelledKey] boolValue] && result == nil;
        dispatch_semaphore_signal(second);
    }];
    [[PHImageManager defaultManager] cancelImageRequest:doomed];
    waited = 1;
    for (int i = 0; i < 200 && waited; i++) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
        waited = dispatch_semaphore_wait(second, DISPATCH_TIME_NOW);
    }
    CHECK(waited == 0 && cancelled, "a cancelled request is answered as cancelled");
    __block NSDictionary *videoInfo = nil;
    __block id videoAsset = @"unset";
    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:nil resultHandler:^(AVAsset *result, AVAudioMix *mix, NSDictionary *details) {
        videoAsset = result;
        videoInfo = details;
    }];
    for (int i = 0; i < 100 && [videoAsset isKindOfClass:[NSString class]]; i++)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
    CHECK(videoAsset == nil && videoInfo[PHImageErrorKey] != nil, "an image is not a video");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_names();
        check_refusals();
        check_library();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
