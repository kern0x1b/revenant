#import "CharonPhotos.h"
#import <MobileCoreServices/MobileCoreServices.h>

// -[NSURL fileSystemRepresentation] is of iOS 7.0 (NSURL.h:118, API_AVAILABLE(macos(10.9), ios(7.0),
// watchos(2.0), tvos(9.0))) and this port builds for 4.3 and 6.1.3, so calling it raises
// "unrecognized selector sent to instance" on the device -- measured on an iPad 2 running 6.1.3 on
// 2026-10-01, where a creation request's move and a resource write both reached it. NSString's
// -fileSystemRepresentation has no such floor, and -[NSURL path] is of iOS 2, so the path comes
// through it. The index cannot settle this one by name: fileSystemRepresentation reads first-rung
// 3.0, which is some other class's selector of that name in a 32-bit cache.
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The file name extension a video's data is staged under. ALAssetsLibrary takes a video by its path and tells a movie by
// the path's extension: the same QuickTime bytes are written from a .mov file and refused from one with no extension
// (tests/backports/device/photosdata9.m, iPad 2, 2026-09-24). The type the options name comes first, then the extension
// of their original file name, then the data's own container: an ISO base media file names its brand in its first box,
// `ftyp`, and QuickTime's is "qt  "; a QuickTime movie from before `ftyp` has none.
static NSString *charon_movie_extension(NSData *data, PHAssetResourceCreationOptions *options)
{
    if (options.uniformTypeIdentifier.length) {
        NSString *extension = CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)options.uniformTypeIdentifier, kUTTagClassFilenameExtension));
        if (extension.length)
            return extension;
    }
    if (options.originalFilename.pathExtension.length)
        return options.originalFilename.pathExtension;
    const uint8_t *bytes = data.bytes;
    if (data.length >= 12 && memcmp(bytes + 4, "ftyp", 4) == 0 && memcmp(bytes + 8, "qt  ", 4) != 0)
        return @"mp4";
    return @"mov";
}

static CharonPhotosTransaction *charon_transaction(void)
{
    CharonPhotosTransaction *transaction = [CharonPhotosTransaction current];
    if (!transaction)
        [NSException raise:NSInternalInconsistencyException format:@"This method can only be called from inside of -[PHPhotoLibrary performChanges:completionHandler:] or -[PHPhotoLibrary performChangesAndWait:error:]"];
    return transaction;
}

@implementation PHAssetResourceCreationOptions
@synthesize originalFilename, uniformTypeIdentifier, shouldMoveFile;

- (id)copyWithZone:(NSZone *)zone
{
    PHAssetResourceCreationOptions *copy = [[PHAssetResourceCreationOptions alloc] init];
    copy.originalFilename = self.originalFilename;
    copy.uniformTypeIdentifier = self.uniformTypeIdentifier;
    copy.shouldMoveFile = self.shouldMoveFile;
    return copy;
}

@end

@implementation PHAssetCreationRequest {
    NSString *_token;
    PHObjectPlaceholder *_placeholder;
    BOOL _hasResource;
    PHAssetResourceType _resourceType;
    NSData *_resourceData;
    PHAssetResourceCreationOptions *_resourceOptions;
    NSURL *_resourceFileURL;
    BOOL _moveFile;
}

+ (instancetype)creationRequestForAsset
{
    CharonPhotosTransaction *transaction = charon_transaction();
    PHAssetCreationRequest *request = [[self alloc] init];
    request->_token = [[NSUUID UUID].UUIDString stringByAppendingString:@"/L0/001"];
    request->_placeholder = [[PHObjectPlaceholder alloc] initWithCharonLocalIdentifier:request->_token];
    [transaction addChange:request];
    return request;
}

+ (BOOL)supportsAssetResourceTypes:(NSArray<NSNumber *> *)types
{
    return types.count == 1 && (types.firstObject.integerValue == PHAssetResourceTypePhoto || types.firstObject.integerValue == PHAssetResourceTypeVideo);
}

- (PHObjectPlaceholder *)placeholderForCreatedAsset
{
    return _placeholder;
}

- (void)charon_addResourceOfType:(PHAssetResourceType)type
{
    if (type != PHAssetResourceTypePhoto && type != PHAssetResourceTypeVideo) {
        [charon_transaction() refuseWithReason:@"iOS 6 can only add a primary photo or video resource, not adjustment data, an alternate photo, or a live photo pairing"];
        return;
    }
    if (_hasResource) {
        [charon_transaction() refuseWithReason:@"iOS 6 can save only a single resource for a new asset"];
        return;
    }
    _hasResource = YES;
    _resourceType = type;
}

- (void)addResourceWithType:(PHAssetResourceType)type fileURL:(NSURL *)fileURL options:(PHAssetResourceCreationOptions *)options
{
    [self charon_addResourceOfType:type];
    _resourceFileURL = fileURL;
    _moveFile = options.shouldMoveFile;
}

- (void)addResourceWithType:(PHAssetResourceType)type data:(NSData *)data options:(PHAssetResourceCreationOptions *)options
{
    [self charon_addResourceOfType:type];
    _resourceData = data;
    _resourceOptions = [options copy];
}

- (BOOL)charon_validate:(NSError **)error
{
    if (!_hasResource) {
        if (error)
            *error = [CharonPhotosStore errorWithCode:PHPhotosErrorMissingResource reason:@"the creation request was never given a resource to save"];
        return NO;
    }
    if (_resourceType == PHAssetResourceTypePhoto && _resourceData && ![UIImage imageWithData:_resourceData]) {
        if (error)
            *error = [CharonPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the resource data is not an image this release can decode"];
        return NO;
    }
    // A move takes the file out of its folder once the asset is made. The header says a hard-linked file cannot be
    // moved; neither can one whose folder does not let it be removed. Both fail here, before anything is written.
    if (_moveFile && _resourceFileURL) {
        struct stat status;
        const char *path = _resourceFileURL.path.fileSystemRepresentation;
        NSString *refusal = nil;
        if (lstat(path, &status) != 0) {
            if (error)
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSURLErrorKey: _resourceFileURL}];
            return NO;
        }
        if (status.st_nlink > 1)
            refusal = @"a file with more than one hard link cannot be moved into the photo library";
        else if (access(_resourceFileURL.URLByDeletingLastPathComponent.path.fileSystemRepresentation, W_OK) != 0)
            refusal = @"the file's folder does not let it be removed, so it cannot be moved into the photo library";
        if (refusal) {
            if (error)
                *error = [CharonPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:refusal];
            return NO;
        }
    }
    return YES;
}

// A moved file is removed once the asset is made from it; a removal that then fails fails the change with the file
// system's error, like any other write of the change that fails after the ones before it were made.
- (BOOL)charon_removeMovedFile:(NSError **)error
{
    if (!_moveFile || !_resourceFileURL)
        return YES;
    if (unlink(_resourceFileURL.path.fileSystemRepresentation) == 0)
        return YES;
    if (error)
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSURLErrorKey: _resourceFileURL}];
    return NO;
}

- (BOOL)charon_commit:(NSError **)error
{
    NSDictionary *metadata = [self charon_metadata];
    NSString *identifier = nil;
    NSURL *staged = nil;
    if (_resourceType == PHAssetResourceTypePhoto) {
        NSData *data = _resourceData ?: (_resourceFileURL ? [NSData dataWithContentsOfURL:_resourceFileURL] : nil);
        identifier = [CharonPhotosStore writeImageData:data metadata:metadata error:error];
    } else if (_resourceFileURL) {
        identifier = [CharonPhotosStore writeVideoAtURL:_resourceFileURL error:error];
    } else {
        // ALAssetsLibrary takes a video only as a file: the data is staged in one of this process's own, named with the
        // extension of its type, which is removed once the library has copied it, whether the write succeeded or not.
        NSString *name = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:charon_movie_extension(_resourceData, _resourceOptions)];
        staged = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
        if (![_resourceData writeToURL:staged options:NSDataWritingAtomic error:error])
            return NO;
        identifier = [CharonPhotosStore writeVideoAtURL:staged error:error];
    }
    if (identifier)
        [CharonPhotosStore bindPlaceholderIdentifier:_token toIdentifier:identifier];
    // A write that failed keeps its own error, the cause; after one that succeeded, a staged file that cannot be removed
    // fails the change with the file system's error, as a moved file does.
    if (staged && unlink(staged.path.fileSystemRepresentation) != 0 && identifier) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSURLErrorKey: staged}];
        return NO;
    }
    if (!identifier)
        return NO;
    return [self charon_removeMovedFile:error];
}

@end
