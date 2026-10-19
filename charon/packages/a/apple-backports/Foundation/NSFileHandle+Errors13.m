#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>

static char CharonFileHandleClosedKey;

static NSInteger charon_file_code(int code, BOOL reading)
{
    if (reading) {
        switch (code) {
        case EPERM:
        case EACCES: return NSFileReadNoPermissionError;
        case ENOENT: return NSFileReadNoSuchFileError;
        case ENAMETOOLONG: return NSFileReadInvalidFileNameError;
        case EFBIG: return NSFileReadTooLargeError;
        default: return NSFileReadUnknownError;
        }
    }
    switch (code) {
    case EPERM:
    case EACCES: return NSFileWriteNoPermissionError;
    case ENOENT: return NSFileNoSuchFileError;
    case ENAMETOOLONG: return NSFileWriteInvalidFileNameError;
    case ENOSPC:
    case EDQUOT: return NSFileWriteOutOfSpaceError;
    case EROFS: return NSFileWriteVolumeReadOnlyError;
    case EEXIST: return NSFileWriteFileExistsError;
    default: return NSFileWriteUnknownError;
    }
}

static BOOL charon_file_fail(NSError **error, int code, BOOL reading)
{
    if (error) {
        NSError *underlying = [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:charon_file_code(code, reading) userInfo:@{NSUnderlyingErrorKey: underlying}];
    }
    return NO;
}

static int charon_file_descriptor(NSFileHandle *handle)
{
    if (objc_getAssociatedObject(handle, &CharonFileHandleClosedKey))
        return -1;
    int descriptor = -1;
    @try {
        descriptor = handle.fileDescriptor;
    } @catch (NSException *exception) {
        return -1;
    }
    if (descriptor < 0 || fcntl(descriptor, F_GETFD) < 0)
        return -1;
    return descriptor;
}

@implementation NSFileHandle (CharonErrors)

- (NSData *)readDataToEndOfFileAndReturnError:(NSError **)error
{
    return [self readDataUpToLength:NSUIntegerMax error:error];
}

- (NSData *)readDataUpToLength:(NSUInteger)length error:(NSError **)error
{
    int descriptor = charon_file_descriptor(self);
    if (descriptor < 0) {
        charon_file_fail(error, EBADF, YES);
        return nil;
    }
    struct stat status;
    if (fstat(descriptor, &status) == 0 && S_ISREG(status.st_mode)) {
        off_t offset = lseek(descriptor, 0, SEEK_CUR);
        if (offset >= 0 && offset >= status.st_size)
            return [NSData data];
    }
    int access = fcntl(descriptor, F_GETFL);
    if (access >= 0 && (access & O_ACCMODE) == O_WRONLY && length > 0) {
        charon_file_fail(error, EBADF, YES);
        return nil;
    }
    NSMutableData *data = [NSMutableData data];
    NSUInteger chunk = 65536;
    while (data.length < length) {
        NSUInteger wanted = MIN(chunk, length - data.length);
        NSUInteger before = data.length;
        data.length = before + wanted;
        ssize_t got = read(descriptor, (unsigned char *)data.mutableBytes + before, wanted);
        if (got < 0) {
            int code = errno;
            data.length = before;
            if (code == EINTR)
                continue;
            charon_file_fail(error, code, YES);
            return nil;
        }
        data.length = before + (NSUInteger)got;
        if (got == 0)
            break;
        if (chunk < 1048576)
            chunk *= 2;
    }
    return data;
}

- (BOOL)writeData:(NSData *)data error:(NSError **)error
{
    int descriptor = charon_file_descriptor(self);
    if (descriptor < 0)
        return charon_file_fail(error, EBADF, NO);
    const unsigned char *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (remaining) {
        ssize_t written = write(descriptor, bytes, remaining);
        if (written < 0) {
            if (errno == EINTR)
                continue;
            return charon_file_fail(error, errno, NO);
        }
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    return YES;
}

- (BOOL)getOffset:(unsigned long long *)offsetInFile error:(NSError **)error
{
    int descriptor = charon_file_descriptor(self);
    if (descriptor < 0)
        return charon_file_fail(error, EBADF, YES);
    off_t offset = lseek(descriptor, 0, SEEK_CUR);
    if (offset < 0)
        return charon_file_fail(error, errno, YES);
    if (offsetInFile)
        *offsetInFile = (unsigned long long)offset;
    return YES;
}

- (BOOL)seekToEndReturningOffset:(unsigned long long *)offsetInFile error:(NSError **)error
{
    int descriptor = charon_file_descriptor(self);
    if (descriptor < 0)
        return charon_file_fail(error, EBADF, YES);
    off_t offset = lseek(descriptor, 0, SEEK_END);
    if (offset < 0)
        return charon_file_fail(error, errno, YES);
    if (offsetInFile)
        *offsetInFile = (unsigned long long)offset;
    return YES;
}

- (BOOL)seekToOffset:(unsigned long long)offset error:(NSError **)error
{
    int descriptor = charon_file_descriptor(self);
    if (descriptor < 0)
        return charon_file_fail(error, EBADF, YES);
    if (lseek(descriptor, (off_t)offset, SEEK_SET) < 0)
        return charon_file_fail(error, errno, YES);
    return YES;
}

- (BOOL)truncateAtOffset:(unsigned long long)offset error:(NSError **)error
{
    int descriptor = charon_file_descriptor(self);
    if (descriptor < 0)
        return charon_file_fail(error, EBADF, NO);
    if (lseek(descriptor, (off_t)offset, SEEK_SET) < 0)
        return charon_file_fail(error, errno, NO);
    if (ftruncate(descriptor, (off_t)offset) < 0)
        return charon_file_fail(error, errno, NO);
    return YES;
}

- (BOOL)synchronizeAndReturnError:(NSError **)error
{
    int descriptor = charon_file_descriptor(self);
    if (descriptor < 0)
        return charon_file_fail(error, EBADF, NO);
    if (fsync(descriptor) < 0)
        return charon_file_fail(error, errno, NO);
    return YES;
}

- (BOOL)closeAndReturnError:(NSError **)error
{
    if (charon_file_descriptor(self) < 0)
        return YES;
    @try {
        [self closeFile];
    } @catch (NSException *exception) {
        return charon_file_fail(error, EBADF, NO);
    }
    objc_setAssociatedObject(self, &CharonFileHandleClosedKey, @YES, OBJC_ASSOCIATION_RETAIN);
    return YES;
}

@end
