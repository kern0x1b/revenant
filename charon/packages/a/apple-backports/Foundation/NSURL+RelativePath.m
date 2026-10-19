#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSURL *charon_url_from_bytes(NSData *data, NSURL *baseURL, BOOL absolute)
{
    if (!data.length) {
        NSURL *empty = [[NSURL alloc] initWithString:@"" relativeToURL:baseURL];
        return absolute ? empty.absoluteURL : empty;
    }
    CFURLRef url = absolute ? CFURLCreateAbsoluteURLWithBytes(kCFAllocatorDefault, data.bytes, (CFIndex)data.length, kCFStringEncodingUTF8, (__bridge CFURLRef)baseURL, true)
                            : CFURLCreateWithBytes(kCFAllocatorDefault, data.bytes, (CFIndex)data.length, kCFStringEncodingUTF8, (__bridge CFURLRef)baseURL);
    if (!url)
        url = absolute ? CFURLCreateAbsoluteURLWithBytes(kCFAllocatorDefault, data.bytes, (CFIndex)data.length, kCFStringEncodingISOLatin1, (__bridge CFURLRef)baseURL, true)
                       : CFURLCreateWithBytes(kCFAllocatorDefault, data.bytes, (CFIndex)data.length, kCFStringEncodingISOLatin1, (__bridge CFURLRef)baseURL);
    return CFBridgingRelease(url);
}

@implementation NSURL (CharonRelativePath)

+ (NSURL *)fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
    return [[self alloc] initFileURLWithPath:path isDirectory:isDir relativeToURL:baseURL];
}

+ (NSURL *)fileURLWithPath:(NSString *)path relativeToURL:(NSURL *)baseURL
{
    return [[self alloc] initFileURLWithPath:path relativeToURL:baseURL];
}

- (instancetype)initFileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
    if (!path.length)
        return nil;
    NSURL *url = CFBridgingRelease(CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorDefault, (__bridge CFStringRef)path, kCFURLPOSIXPathStyle, isDir, (__bridge CFURLRef)baseURL));
    if (!url || object_getClass(self) == [NSURL class])
        return url;
    return [self initWithString:url.relativeString relativeToURL:url.baseURL];
}

- (instancetype)initFileURLWithPath:(NSString *)path relativeToURL:(NSURL *)baseURL
{
    NSURL *asked = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO relativeToURL:baseURL].absoluteURL;
    NSNumber *directory = nil;
    if (asked.isFileURL)
        [asked getResourceValue:&directory forKey:NSURLIsDirectoryKey error:NULL];
    return [self initFileURLWithPath:path isDirectory:directory.boolValue relativeToURL:baseURL];
}

- (instancetype)initWithDataRepresentation:(NSData *)data relativeToURL:(NSURL *)baseURL
{
    NSURL *url = charon_url_from_bytes(data, baseURL, NO);
    if (!url || object_getClass(self) == [NSURL class])
        return url;
    return [self initWithString:url.relativeString relativeToURL:url.baseURL];
}

- (instancetype)initAbsoluteURLWithDataRepresentation:(NSData *)data relativeToURL:(NSURL *)baseURL
{
    NSURL *url = charon_url_from_bytes(data, baseURL, YES);
    if (!url || object_getClass(self) == [NSURL class])
        return url;
    return [self initWithString:url.relativeString relativeToURL:url.baseURL];
}

+ (NSURL *)URLWithDataRepresentation:(NSData *)data relativeToURL:(NSURL *)baseURL
{
    return [[self alloc] initWithDataRepresentation:data relativeToURL:baseURL];
}

+ (NSURL *)absoluteURLWithDataRepresentation:(NSData *)data relativeToURL:(NSURL *)baseURL
{
    return [[self alloc] initAbsoluteURLWithDataRepresentation:data relativeToURL:baseURL];
}

- (NSData *)dataRepresentation
{
    CFIndex length = CFURLGetBytes((__bridge CFURLRef)self, NULL, 0);
    if (length < 0)
        return [NSData data];
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)length];
    CFURLGetBytes((__bridge CFURLRef)self, data.mutableBytes, length);
    return data;
}

- (BOOL)hasDirectoryPath
{
    return CFURLHasDirectoryPath((__bridge CFURLRef)self);
}

@end
