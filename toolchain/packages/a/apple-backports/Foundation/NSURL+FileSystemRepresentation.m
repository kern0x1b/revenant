#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <limits.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation NSURL (CharonFileSystemRepresentation)

+ (NSURL *)fileURLWithFileSystemRepresentation:(const char *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
    return [[self alloc] initFileURLWithFileSystemRepresentation:path isDirectory:isDir relativeToURL:baseURL];
}

- (instancetype)initFileURLWithFileSystemRepresentation:(const char *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
    BOOL plain = object_getClass(self) == [NSURL class];
    size_t length = strlen(path);
    if (!length) {
        if (!baseURL)
            return nil;
        return plain ? [baseURL copy] : [self initWithString:baseURL.relativeString relativeToURL:baseURL.baseURL];
    }
    if (path[0] != '/' && !baseURL) {
        NSString *directory = [[NSFileManager defaultManager] currentDirectoryPath];
        if (directory.length)
            baseURL = [NSURL fileURLWithPath:directory isDirectory:YES];
    }
    NSURL *url = CFBridgingRelease(CFURLCreateFromFileSystemRepresentationRelativeToBase(kCFAllocatorDefault, (const UInt8 *)path, (CFIndex)length, isDir, (__bridge CFURLRef)baseURL));
    if (!url || plain)
        return url;
    return [self initWithString:url.relativeString relativeToURL:url.baseURL];
}

- (const char *)fileSystemRepresentation
{
    NSURL *absolute = self.absoluteURL;
    NSString *path = CFBridgingRelease(CFURLCopyFileSystemPath((__bridge CFURLRef)absolute, kCFURLPOSIXPathStyle));
    if (!path.length)
        return NULL;
    CFIndex capacity = CFStringGetMaximumSizeOfFileSystemRepresentation((__bridge CFStringRef)path);
    if (capacity <= 0)
        return NULL;
    __autoreleasing NSMutableData *buffer = [NSMutableData dataWithLength:(NSUInteger)capacity];
    if (!CFURLGetFileSystemRepresentation((__bridge CFURLRef)absolute, false, buffer.mutableBytes, capacity))
        return NULL;
    return buffer.mutableBytes;
}

- (BOOL)getFileSystemRepresentation:(char *)buffer maxLength:(NSUInteger)maxBufferLength
{
    CFIndex capacity = maxBufferLength > LONG_MAX ? LONG_MAX : (CFIndex)maxBufferLength;
    return CFURLGetFileSystemRepresentation((__bridge CFURLRef)self, true, (UInt8 *)buffer, capacity);
}

@end
