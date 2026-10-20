#import "RevenantPhotos.h"

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@implementation PHAssetResourceRequestOptions
@synthesize networkAccessAllowed, progressHandler;

- (id)copyWithZone:(NSZone *)zone
{
    PHAssetResourceRequestOptions *copy = [[PHAssetResourceRequestOptions alloc] init];
    copy.networkAccessAllowed = self.networkAccessAllowed;
    copy.progressHandler = self.progressHandler;
    return copy;
}

@end

@implementation PHAssetResourceManager
{
    NSMutableSet<NSNumber *> *_revenantPending;
}

- (instancetype)init
{
    if ((self = [super init]))
        _revenantPending = [NSMutableSet set];
    return self;
}

+ (instancetype)defaultManager
{
    static PHAssetResourceManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

+ (PHAssetResourceDataRequestID)revenant_nextRequestID
{
    static int32_t counter = 0;
    @synchronized ([PHAssetResourceManager class]) {
        counter++;
        return counter;
    }
}

static const NSUInteger RevenantResourceChunkLength = 1024 * 1024;

- (BOOL)revenant_readResource:(PHAssetResource *)resource
                   progress:(PHAssetResourceProgressHandler)progress
                    deliver:(BOOL (^)(NSData *chunk))deliver
                      error:(NSError **)error
{
    PHAsset *asset = [RevenantPhotosStore assetWithIdentifier:resource.assetLocalIdentifier];
    if (!asset) {
        if (error)
            *error = [RevenantPhotosStore errorWithCode:PHPhotosErrorIdentifierNotFound reason:@"the asset this resource was made from no longer exists"];
        return NO;
    }
    ALAssetRepresentation *representation = [asset revenant_asset].defaultRepresentation;
    if (!representation) {
        if (error)
            *error = [RevenantPhotosStore errorWithCode:PHPhotosErrorMissingResource reason:@"the asset this resource was made from has no data to read"];
        return NO;
    }
    long long size = representation.size;
    for (long long offset = 0; offset < size;) {
        @autoreleasepool {
            NSUInteger length = (NSUInteger)MIN((long long)RevenantResourceChunkLength, size - offset);
            NSMutableData *chunk = [NSMutableData dataWithLength:length];
            NSError *readError = nil;
            NSUInteger got = [representation getBytes:chunk.mutableBytes fromOffset:offset length:length error:&readError];
            if (got == 0) {
                if (error)
                    *error = readError ?: [RevenantPhotosStore errorWithCode:PHPhotosErrorInternalError reason:@"the photo library gave fewer bytes than the resource's own size"];
                return NO;
            }
            chunk.length = got;
            offset += got;
            if (!deliver(chunk))
                return NO;
            if (progress)
                progress((double)offset / (double)size);
        }
    }
    return YES;
}

- (PHAssetResourceDataRequestID)requestDataForAssetResource:(PHAssetResource *)resource
                                                     options:(PHAssetResourceRequestOptions *)options
                                         dataReceivedHandler:(void (^)(NSData *data))handler
                                           completionHandler:(void (^)(NSError *error))completionHandler
{
    PHAssetResourceDataRequestID requestID = [PHAssetResourceManager revenant_nextRequestID];
    NSNumber *key = @(requestID);
    @synchronized (_revenantPending) {
        [_revenantPending addObject:key];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL (^pending)(void) = ^BOOL {
            @synchronized (self->_revenantPending) {
                return [self->_revenantPending containsObject:key];
            }
        };
        NSError *error = nil;
        BOOL read = pending() && [self revenant_readResource:resource progress:options.progressHandler deliver:^BOOL(NSData *chunk) {
            if (!pending())
                return NO;
            if (handler)
                handler(chunk);
            return YES;
        } error:&error];
        BOOL cancelled;
        @synchronized (self->_revenantPending) {
            cancelled = ![self->_revenantPending containsObject:key];
            [self->_revenantPending removeObject:key];
        }
        if (completionHandler)
            completionHandler(cancelled ? [RevenantPhotosStore errorWithCode:PHPhotosErrorUserCancelled reason:@"the data request was cancelled"]
                                        : read ? nil : error);
    });
    return requestID;
}

- (void)writeDataForAssetResource:(PHAssetResource *)resource
                            toFile:(NSURL *)fileURL
                           options:(PHAssetResourceRequestOptions *)options
                 completionHandler:(void (^)(NSError *error))completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *(^failure)(NSURL *) = ^NSError *(NSURL *url) {
            return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSURLErrorKey: url}];
        };
        NSString *name = [NSString stringWithFormat:@".%@.%@", fileURL.lastPathComponent, [NSUUID UUID].UUIDString];
        NSURL *partURL = [fileURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:name];
        const char *part = partURL.path.fileSystemRepresentation;
        int fd = open(part, O_WRONLY | O_CREAT | O_EXCL, 0644);
        NSError *error = fd < 0 ? failure(fileURL) : nil;
        __block NSError *writeError = nil;
        BOOL wrote = fd >= 0 && [self revenant_readResource:resource progress:options.progressHandler deliver:^BOOL(NSData *chunk) {
            for (NSUInteger done = 0; done < chunk.length;) {
                ssize_t put = write(fd, (const char *)chunk.bytes + done, chunk.length - done);
                if (put < 0) {
                    if (errno == EINTR)
                        continue;
                    writeError = failure(fileURL);
                    return NO;
                }
                done += (NSUInteger)put;
            }
            return YES;
        } error:&error];
        error = writeError ?: error;
        if (fd >= 0 && close(fd) != 0 && wrote) {
            error = failure(fileURL);
            wrote = NO;
        }
        if (wrote && rename(part, fileURL.path.fileSystemRepresentation) != 0) {
            error = failure(fileURL);
            wrote = NO;
        }
        if (fd >= 0 && !wrote)
            unlink(part);
        if (completionHandler)
            completionHandler(wrote ? nil : error);
    });
}

- (void)cancelDataRequest:(PHAssetResourceDataRequestID)requestID
{
    @synchronized (_revenantPending) {
        [_revenantPending removeObject:@(requestID)];
    }
}

@end
