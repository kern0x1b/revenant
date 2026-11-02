#import <Foundation/Foundation.h>

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// Where the host writes its output: /var/tmp/<last part of the bundle id>/. Nothing is read or run from there, because
// /var/tmp takes files from any process.
static inline NSString *RNHostRunPath(NSString *file)
{
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *name = identifier ? [[identifier componentsSeparatedByString:@"."] lastObject] : @"rnhost";
    return [[@"/var/tmp" stringByAppendingPathComponent:name] stringByAppendingPathComponent:file];
}

// The configuration (rnhost.conf), the bundle, the command file and the flags are read only from the application bundle.
// deploy writes them there as root, so a process of the phone's user cannot change them.
static inline BOOL RNHostTrustedDirectory(const char *path)
{
    struct stat info;
    return stat(path, &info) == 0 && S_ISDIR(info.st_mode) && info.st_uid == 0 && !(info.st_mode & (S_IWGRP | S_IWOTH));
}

// The real path of the application bundle, nil when that folder is not owned by root or can be written by others.
static inline NSString *RNHostAppRoot(void)
{
    char root[PATH_MAX];
    if (!realpath([[NSBundle mainBundle] bundlePath].fileSystemRepresentation, root)) {
        return nil;
    }
    if (!RNHostTrustedDirectory(root)) {
        NSLog(@"rn-host: refusing the application folder %s: it must be owned by root and not writable by group or others", root);
        return nil;
    }
    return [NSString stringWithUTF8String:root];
}

// The real path of a file of the application, relative to the bundle or absolute. Nil when it is missing or when it resolves
// outside the application bundle (symlinks included).
static inline NSString *RNHostAppFilePath(NSString *file)
{
    NSString *root = RNHostAppRoot();
    if (!root) {
        return nil;
    }
    NSString *joined = [file hasPrefix:@"/"] ? file : [root stringByAppendingPathComponent:file];
    char resolved[PATH_MAX];
    if (!realpath(joined.fileSystemRepresentation, resolved)) {
        return nil;
    }
    NSString *path = [NSString stringWithUTF8String:resolved];
    if (![path hasPrefix:[root stringByAppendingString:@"/"]]) {
        NSLog(@"rn-host: refusing %@: it resolves outside the application bundle", file);
        return nil;
    }
    return path;
}

// Opens a regular file owned by root that group and others cannot write. Refusals are logged, a missing file is not.
static inline int RNHostOpenTrusted(const char *path, struct stat *identity)
{
    int fd = open(path, O_RDONLY | O_NOFOLLOW);
    if (fd < 0) {
        return -1;
    }
    struct stat info;
    if (fstat(fd, &info) != 0 || !S_ISREG(info.st_mode) || info.st_uid != 0 || (info.st_mode & (S_IWGRP | S_IWOTH))) {
        NSLog(@"rn-host: refusing %s: it must be a regular file owned by root and not writable by group or others", path);
        close(fd);
        return -1;
    }
    if (identity) {
        *identity = info;
    }
    return fd;
}

// The path of a file of the application when it exists and is trusted, nil otherwise.
static inline NSString *RNHostTrustedAppFile(NSString *file)
{
    NSString *path = RNHostAppFilePath(file);
    if (!path) {
        return nil;
    }
    int fd = RNHostOpenTrusted(path.fileSystemRepresentation, NULL);
    if (fd < 0) {
        return nil;
    }
    close(fd);
    return path;
}

// The contents of a file of the application, nil when it is missing or not trusted. identity, when given, receives its status.
static inline NSData *RNHostReadAppFile(NSString *file, struct stat *identity)
{
    @autoreleasepool {
        NSString *path = RNHostAppFilePath(file);
        int fd = path ? RNHostOpenTrusted(path.fileSystemRepresentation, identity) : -1;
        if (fd < 0) {
            return nil;
        }
        NSMutableData *data = [NSMutableData data];
        uint8_t buffer[4096];
        ssize_t count;
        while ((count = read(fd, buffer, sizeof(buffer))) > 0) {
            [data appendBytes:buffer length:(NSUInteger)count];
        }
        close(fd);
        return data;
    }
}

static inline NSString *RNHostReadAppText(NSString *file)
{
    NSData *data = RNHostReadAppFile(file, NULL);
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

// True when the flag file is present in the application bundle (its contents do not matter).
static inline BOOL RNHostAppFileExists(NSString *file)
{
    return RNHostAppFilePath(file) != nil;
}
