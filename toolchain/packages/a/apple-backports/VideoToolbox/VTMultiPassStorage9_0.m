#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VTErrors.h>
#include <VideoToolbox/VTMultiPassStorage.h>
#import <objc/runtime.h>

static const OSStatus kRevenantVTMultiPassStorageDirectoryMissing = -17913;

@interface RevenantVTMultiPassStorage : NSObject {
@public
    CFStringRef _path;
    CFURLRef _url;
    Boolean _createdTheFile;
    Boolean _doNotDelete;
    CMTimeRange _timeRange;
    Boolean _closed;
}
- (instancetype)revenant_initWithPath:(NSString *)path
                             isURL:(CFURLRef)url
                      createdFile:(Boolean)createdTheFile
                        doNotDelete:(Boolean)doNotDelete
                          timeRange:(CMTimeRange)timeRange
    __attribute__((objc_method_family(init)));
@end

@implementation RevenantVTMultiPassStorage

- (instancetype)revenant_initWithPath:(NSString *)path
                             isURL:(CFURLRef)url
                      createdFile:(Boolean)createdTheFile
                        doNotDelete:(Boolean)doNotDelete
                          timeRange:(CMTimeRange)timeRange
{
    self = [super init];
    if (self) {
        _path = (CFStringRef)CFBridgingRetain(path);
        _url = url ? (CFURLRef)CFRetain(url) : NULL;
        _createdTheFile = createdTheFile;
        _doNotDelete = doNotDelete;
        _timeRange = timeRange;
        _closed = false;
    }
    return self;
}

- (void)dealloc
{
    if (_createdTheFile && !_doNotDelete && _path)
        [[NSFileManager defaultManager] removeItemAtPath:(NSString *)(__bridge NSString *)_path error:NULL];
    if (_url)
        CFRelease(_url);
    if (_path)
        CFRelease(_path);
}

static VTMultiPassStorageRef revenant_from(RevenantVTMultiPassStorage *storage)
{
    return (VTMultiPassStorageRef)CFBridgingRetain(storage);
}

static RevenantVTMultiPassStorage *revenant_to(VTMultiPassStorageRef storage)
{
    return (RevenantVTMultiPassStorage *)(__bridge id)storage;
}

CFTypeID VTMultiPassStorageGetTypeID(void)
{
    return (CFTypeID)objc_getClass("RevenantVTMultiPassStorage");
}

OSStatus VTMultiPassStorageCreate(
    CFAllocatorRef CM_NULLABLE allocator,
    CFURLRef CM_NULLABLE fileURL,
    CMTimeRange timeRange,
    CFDictionaryRef CM_NULLABLE options,
    VTMultiPassStorageRef CM_NULLABLE * CM_NONNULL multiPassStorageOut)
{
    if (!multiPassStorageOut)
        return kVTParameterErr;
    *multiPassStorageOut = NULL;

    Boolean doNotDelete = false;
    if (options) {
        CFTypeRef value = NULL;
        if (CFDictionaryGetValueIfPresent(options, kVTMultiPassStorageCreationOption_DoNotDelete, &value)
            && value && CFGetTypeID(value) == CFBooleanGetTypeID())
            doNotDelete = CFBooleanGetValue((CFBooleanRef)value) ? true : false;
    }

    CFURLRef url = NULL;
    CFStringRef path = NULL;
    if (fileURL) {
        url = (CFURLRef)CFRetain(fileURL);
        path = CFURLCopyFileSystemPath(fileURL, kCFURLPOSIXPathStyle);
        if (!path) {
            CFRelease(url);
            return kVTParameterErr;
        }
    } else {
        NSString *unique = [NSTemporaryDirectory()
            stringByAppendingPathComponent:[NSString stringWithFormat:@"RevenantVTMultiPassStorage-%@",
                                                   [[NSUUID UUID] UUIDString]]];
        path = CFStringCreateWithCString(kCFAllocatorDefault, [unique UTF8String], kCFStringEncodingUTF8);
        if (!path)
            return kVTAllocationFailedErr;
        url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path, kCFURLPOSIXPathStyle, false);
        if (!url) {
            CFRelease(path);
            return kVTAllocationFailedErr;
        }
    }

    NSString *pathString = (NSString *)(__bridge id)path;
    if ([[NSFileManager defaultManager] fileExistsAtPath:pathString]) {
        CFRelease(url);
        CFRelease(path);
        return kVTMultiPassStorageInvalidErr;
    }
    NSString *parent = [pathString stringByDeletingLastPathComponent];
    if (![parent length] || ![[NSFileManager defaultManager] fileExistsAtPath:parent]) {
        CFRelease(url);
        CFRelease(path);
        return kRevenantVTMultiPassStorageDirectoryMissing;
    }
    if (![[NSFileManager defaultManager] createFileAtPath:pathString
                                                contents:[NSData data]
                                              attributes:nil]) {
        CFRelease(url);
        CFRelease(path);
        return kVTAllocationFailedErr;
    }

    RevenantVTMultiPassStorage *storage =
        [[RevenantVTMultiPassStorage alloc] revenant_initWithPath:pathString
                                                        isURL:url
                                                 createdFile:true
                                                   doNotDelete:doNotDelete
                                                     timeRange:timeRange];
    CFRelease(url);
    CFRelease(path);
    if (!storage)
        return kVTAllocationFailedErr;
    *multiPassStorageOut = revenant_from(storage);
    return noErr;
}

OSStatus VTMultiPassStorageClose(VTMultiPassStorageRef multiPassStorage)
{
    RevenantVTMultiPassStorage *storage = revenant_to(multiPassStorage);
    if (!storage)
        return kVTMultiPassStorageInvalidErr;
    if (storage->_closed)
        return kVTMultiPassStorageInvalidErr;
    storage->_closed = true;
    return noErr;
}

@end
