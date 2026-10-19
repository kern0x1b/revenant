#import "CharonPhotos.h"

// -[NSURL fileSystemRepresentation] is of iOS 7.0 (NSURL.h:118, API_AVAILABLE(macos(10.9), ios(7.0),
// watchos(2.0), tvos(9.0))) and this port builds for 4.3 and 6.1.3, so calling it raises
// "unrecognized selector sent to instance" on the device -- measured on an iPad 2 running 6.1.3 on
// 2026-10-01, where a creation request's move and a resource write both reached it. NSString's
// -fileSystemRepresentation has no such floor, and -[NSURL path] is of iOS 2, so the path comes
// through it. The index cannot settle this one by name: fileSystemRepresentation reads first-rung
// 3.0, which is some other class's selector of that name in a 32-bit cache.
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

// The data requests not yet completed. A request cancelled before its read has handed data over is taken out
// here, and its read completes with PHPhotosErrorUserCancelled instead of delivering.
@implementation PHAssetResourceManager
{
    NSMutableSet<NSNumber *> *_charonPending;
}

- (instancetype)init
{
    if ((self = [super init]))
        _charonPending = [NSMutableSet set];
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

+ (PHAssetResourceDataRequestID)charon_nextRequestID
{
    static int32_t counter = 0;
    @synchronized ([PHAssetResourceManager class]) {
        counter++;
        return counter;
    }
}

// Photos of iOS 9 and later hands a resource over in chunks of a size of its own, which only a library holding real
// assets could show, and the one library of this machine is the owner's. The size here is the port's: a read holds
// one chunk at a time, so a video of any length stays within a small part of a 512 MB device's memory.
static const NSUInteger CharonResourceChunkLength = 1024 * 1024;

// Reads the representation of the resource's asset one chunk after another and hands each to deliver, which answers
// NO to stop the read. NO, with the error, when the asset or its data is gone or the library gives no more bytes before
// the representation's own size; a read stopped by deliver answers NO and leaves the error as it was.
- (BOOL)charon_readResource:(PHAssetResource *)resource
                   progress:(PHAssetResourceProgressHandler)progress
                    deliver:(BOOL (^)(NSData *chunk))deliver
                      error:(NSError **)error
{
    PHAsset *asset = [CharonPhotosStore assetWithIdentifier:resource.assetLocalIdentifier];
    if (!asset) {
        if (error)
            *error = [CharonPhotosStore errorWithCode:PHPhotosErrorIdentifierNotFound reason:@"the asset this resource was made from no longer exists"];
        return NO;
    }
    ALAssetRepresentation *representation = [asset charon_asset].defaultRepresentation;
    if (!representation) {
        if (error)
            *error = [CharonPhotosStore errorWithCode:PHPhotosErrorMissingResource reason:@"the asset this resource was made from has no data to read"];
        return NO;
    }
    long long size = representation.size;
    for (long long offset = 0; offset < size;) {
        @autoreleasepool {
            NSUInteger length = (NSUInteger)MIN((long long)CharonResourceChunkLength, size - offset);
            NSMutableData *chunk = [NSMutableData dataWithLength:length];
            NSError *readError = nil;
            NSUInteger got = [representation getBytes:chunk.mutableBytes fromOffset:offset length:length error:&readError];
            if (got == 0) {
                if (error)
                    *error = readError ?: [CharonPhotosStore errorWithCode:PHPhotosErrorInternalError reason:@"the photo library gave fewer bytes than the resource's own size"];
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
    PHAssetResourceDataRequestID requestID = [PHAssetResourceManager charon_nextRequestID];
    NSNumber *key = @(requestID);
    @synchronized (_charonPending) {
        [_charonPending addObject:key];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL (^pending)(void) = ^BOOL {
            @synchronized (self->_charonPending) {
                return [self->_charonPending containsObject:key];
            }
        };
        // A cancel is looked at before every chunk: a request cancelled before its first one delivers nothing, one
        // cancelled during the read stops there. Either completes once, with PHPhotosErrorUserCancelled.
        NSError *error = nil;
        BOOL read = pending() && [self charon_readResource:resource progress:options.progressHandler deliver:^BOOL(NSData *chunk) {
            if (!pending())
                return NO;
            if (handler)
                handler(chunk);
            return YES;
        } error:&error];
        BOOL cancelled;
        @synchronized (self->_charonPending) {
            cancelled = ![self->_charonPending containsObject:key];
            [self->_charonPending removeObject:key];
        }
        if (completionHandler)
            completionHandler(cancelled ? [CharonPhotosStore errorWithCode:PHPhotosErrorUserCancelled reason:@"the data request was cancelled"]
                                        : read ? nil : error);
    });
    return requestID;
}

// Photos writes the data into the file as it reads it. This writes it one chunk at a time into a file of its own
// beside the given one and renames that into place once every chunk is in, and leaves the given file as it was when
// the read or a write fails. A file already there is replaced on success: the port's choice, not measured against
// Photos (facts/Photos/Changes.md).
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
        BOOL wrote = fd >= 0 && [self charon_readResource:resource progress:options.progressHandler deliver:^BOOL(NSData *chunk) {
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
    @synchronized (_charonPending) {
        [_charonPending removeObject:@(requestID)];
    }
}

@end
