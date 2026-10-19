#import "CharonVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VTErrors.h>
#include <VideoToolbox/VTMultiPassStorage.h>
#import <objc/runtime.h>

// VTMultiPassStorage: the object a compression session keeps its per-frame pass data in.
//
// The 16.4 SDK this package builds against declares all three functions and the release exports none of
// them (tools/corpus/dump-cache.lua over $HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7, 2026-10-03:
// zero hits for _VTMultiPassStorageCreate, _VTMultiPassStorageClose and _VTMultiPassStorageGetTypeID), so
// the port exports all three.
//
// WHAT THE HEADER ASKS FOR, and what each line below is for. VTMultiPassStorage.h says the object is
// created using a temporary file, that fileURL says where to put the backing file, and that
// passing NULL leaves the framework to pick a unique temporary file name, and the whole of the
// options dictionary is one key:
//
//     kVTMultiPassStorageCreationOption_DoNotDelete: a file the storage created is deleted when the object is finalized,
//     unless this option holds kCFBooleanTrue, which the header describes as the way to keep it.
//
// So the file's lifecycle has three cases, and all three are implemented rather than described:
//   - the caller named a file that does not exist: this object creates it, owns it, and deletes it on
//     finalize unless the caller asked it not to;
//   - the caller named a file that ALREADY EXISTS: Apple's own Create REFUSES it. Measured on this host's
//     VideoToolbox, 2026-10-03: with a path whose file was written beforehand, Create returns
//     kVTMultiPassStorageInvalidErr (-12214) and no session. So the header's wording about a file that is missing at creation
//     describes a case that cannot arise - the object refuses the other one -
//     and this port answers the same way rather than inventing a case the release does not have;
//   - the caller passed NULL: a unique name is chosen here, the file is created, and the first case
//     applies. Measured: status 0 and a session.
//
// One thing this object does NOT do, stated here rather than left to be found: it writes no private header
// Apple's writes 20 bytes at Create (measured), and the header says what it stores is reserved to the video encoder, so a file
// this port writes is not readable by a
// real encoder, because the format is Apple's and private. Nothing in this port reads the file either: the
// 6.1.3 encoder never sees a multi-pass storage, because kVTCompressionPropertyKey_MultiPassStorage
// arrived with iOS 9. The file's LIFECYCLE is what this implements, because that is what the header
// specifies and what a caller can observe; its CONTENTS are Apple's, and they are not reproduced.
//
// -dealloc is where the deletion happens, because "when the VTMultiPassStorage object is finalized" is
// CFRelease taking the last reference - which is the same moment, and is the only moment the header names.

// The one CF type in this file. It is an ObjC object rather than a hand-rolled CF one because that is the
// mechanism the tree already uses for a CF type the 16.4 SDK does not carry -
// AVFoundation/CMTaggedBufferGroup17.m and Graphics/CVMetalTexture80.m both bridge a Charon class to an
// opaque CF ref exactly this way - and a second mechanism for the same job is what the self-review names
// first. The class is NOT called VTMultiPassStorage: a class with Apple's name would collide with the
// host's own class in any differential compiled against the host's SDK, and this library must compile in
// both places.
// -17913: the code Apple's own VTMultiPassStorageCreate answers when the path it was given has no parent
// directory. MEASURED on this host's own VideoToolbox, 2026-10-03, with a path one level under a directory
// that was never created.
//
// NO HEADER ON THIS MACHINE NAMES IT. It is not in VideoToolbox's VTErrors.h, and `grep -rn 17913` over
// every framework's headers in the 16.4 SDK, the iPhoneOS 26.2 SDK and the macOS SDK finds nothing, so the
// framework that owns the code could not be identified and is not guessed at here. It is spelled as a named
// constant with its source rather than as a bare literal in the middle of a function, because a number with
// no name next to it is a number nobody can check later.
static const OSStatus kCharonVTMultiPassStorageDirectoryMissing = -17913;

@interface CharonVTMultiPassStorage : NSObject {
@public
    CFStringRef _path;          // the backing file's path; released in -dealloc
    CFURLRef _url;              // the same file as a URL, for CFURLCreateCopyFileSystemRepresentation
    Boolean _createdTheFile;     // true when this object created it, which is the header's delete condition
    Boolean _doNotDelete;        // kVTMultiPassStorageCreationOption_DoNotDelete
    CMTimeRange _timeRange;      // "a hint ... about valid time stamps for data"; may be kCMTimeRangeInvalid
    Boolean _closed;             // set by -VTMultiPassStorageClose; after it "all methods ... will fail"
}
- (instancetype)charon_initWithPath:(NSString *)path
                             isURL:(CFURLRef)url
                      createdFile:(Boolean)createdTheFile
                        doNotDelete:(Boolean)doNotDelete
                          timeRange:(CMTimeRange)timeRange
    __attribute__((objc_method_family(init)));
@end

@implementation CharonVTMultiPassStorage

- (instancetype)charon_initWithPath:(NSString *)path
                             isURL:(CFURLRef)url
                      createdFile:(Boolean)createdTheFile
                        doNotDelete:(Boolean)doNotDelete
                          timeRange:(CMTimeRange)timeRange
{
    self = [super init];
    if (self) {
        _path = (CFStringRef)CFBridgingRetain(path);
        _url = url ? (CFURLRef)CFRetain(url) : NULL;  // a CFTypeRef from the caller, so CFRetain is right here
        _createdTheFile = createdTheFile;
        _doNotDelete = doNotDelete;
        _timeRange = timeRange;
        _closed = false;
    }
    return self;
}

- (void)dealloc
{
    // The header's condition, verbatim in behaviour: this object deletes the file only if IT created it
    // and the caller did not ask it not to. A file the caller pointed at and that already existed is the
    // caller's, and a file the caller pointed at that did not exist is this object's to clean up.
    // NSFileManager is the release's own way to remove a file by path, and the port links Foundation
    // already for the seventeen frame-processor classes.
    if (_createdTheFile && !_doNotDelete && _path)
        [[NSFileManager defaultManager] removeItemAtPath:(NSString *)(__bridge NSString *)_path error:NULL];
    if (_url)
        CFRelease(_url);
    if (_path)
        CFRelease(_path);
}

// The bridge in both directions. __bridge_retained gives the caller the +1 the header's
// CM_RETURNS_RETAINED_PARAMETER promises, and the cast goes through void * because VTMultiPassStorageRef
// is an opaque struct pointer with no toll-free-bridged class of that name on this side.
static VTMultiPassStorageRef charon_from(CharonVTMultiPassStorage *storage)
{
    // CFBridgingRetain is the +1 that CM_RETURNS_RETAINED_PARAMETER promises, written as the retain rather
    // than as a cast pair because VTMultiPassStorageRef is a struct pointer with no toll-free-bridged class
    // on this side and there is nothing for __bridge_retained to name.
    return (VTMultiPassStorageRef)CFBridgingRetain(storage);
}

static CharonVTMultiPassStorage *charon_to(VTMultiPassStorageRef storage)
{
    return (CharonVTMultiPassStorage *)(__bridge id)storage;
}

CFTypeID VTMultiPassStorageGetTypeID(void)
{
    // The class pointer, which is the same answer AVFoundation/CMTaggedBufferGroup17.m gives
    // CMTaggedBufferGroupGetTypeID and which is unique, stable, and cannot collide with a numeric slot.
    return (CFTypeID)objc_getClass("CharonVTMultiPassStorage");
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
    // Written before anything can fail, so a caller that ignores the status cannot read a stale pointer
    // for a storage object.
    *multiPassStorageOut = NULL;

    Boolean doNotDelete = false;
    if (options) {
        // The one key the header documents, read as the header types it: a CFBoolean. Anything else in the
        // dictionary is not read, because the header says "Reserved, pass NULL" nowhere here but names no
        // other key, and rejecting an unknown key would be stricter than Apple's own Create.
        CFTypeRef value = NULL;
        if (CFDictionaryGetValueIfPresent(options, kVTMultiPassStorageCreationOption_DoNotDelete, &value)
            && value && CFGetTypeID(value) == CFBooleanGetTypeID())
            doNotDelete = CFBooleanGetValue((CFBooleanRef)value) ? true : false;
    }

    CFURLRef url = NULL;
    CFStringRef path = NULL;
    if (fileURL) {
        url = (CFURLRef)CFRetain(fileURL);
        // A URL that names no file on disk is a parameter error, not a storage object: the header says
        // this is where the backing file goes, and "somewhere that does not exist" is not a path.
        path = CFURLCopyFileSystemPath(fileURL, kCFURLPOSIXPathStyle);
        if (!path) {
            CFRelease(url);
            return kVTParameterErr;
        }
    } else {
        // When fileURL is NULL the header leaves the choice of a unique temporary file name to the framework. A UUID
        // in the process's temporary directory is unique in the way the header asks for, and this port has
        // no other source of one: the session's own name generator is the release's, and there is none.
        NSString *unique = [NSTemporaryDirectory()
            stringByAppendingPathComponent:[NSString stringWithFormat:@"CharonVTMultiPassStorage-%@",
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

    // The file must NOT already exist, which is what Apple's own Create requires (measured:
    // kVTMultiPassStorageInvalidErr, -12214, for a path that was written beforehand). Checked before
    // anything is created, so a refused path is left exactly as the caller had it.
    NSString *pathString = (NSString *)(__bridge id)path;
    if ([[NSFileManager defaultManager] fileExistsAtPath:pathString]) {
        CFRelease(url);
        CFRelease(path);
        return kVTMultiPassStorageInvalidErr;
    }
    // The parent directory is checked on its own, so the measured code answers the measured condition and
    // is not stretched over conditions nobody measured. Apple's Create gives -17913 for a path whose parent
    // directory does not exist; for a file that cannot be created for some other reason this port answers
    // the release's own kVTAllocationFailedErr rather than borrowing -17913 for a case it was not measured
    // giving it.
    NSString *parent = [pathString stringByDeletingLastPathComponent];
    if (![parent length] || ![[NSFileManager defaultManager] fileExistsAtPath:parent]) {
        CFRelease(url);
        CFRelease(path);
        return kCharonVTMultiPassStorageDirectoryMissing;
    }
    if (![[NSFileManager defaultManager] createFileAtPath:pathString
                                                contents:[NSData data]
                                              attributes:nil]) {
        CFRelease(url);
        CFRelease(path);
        return kVTAllocationFailedErr;
    }

    CharonVTMultiPassStorage *storage =
        [[CharonVTMultiPassStorage alloc] charon_initWithPath:pathString
                                                        isURL:url
                                                 createdFile:true
                                                   doNotDelete:doNotDelete
                                                     timeRange:timeRange];
    CFRelease(url);
    CFRelease(path);
    if (!storage)
        return kVTAllocationFailedErr;
    *multiPassStorageOut = charon_from(storage);
    return noErr;
}

OSStatus VTMultiPassStorageClose(VTMultiPassStorageRef multiPassStorage)
{
    CharonVTMultiPassStorage *storage = charon_to(multiPassStorage);
    if (!storage)
        return kVTMultiPassStorageInvalidErr;
    // Once this function has been called, every method on the multipass storage object fails, as the header says. Closing twice
    // is one of those methods, so it fails - and the code is MEASURED, not chosen: Apple's own Close answers
    // -12214 on a second call, which is kVTMultiPassStorageInvalidErr, the release's own code for exactly
    // this object being invalid. kVTInvalidSessionErr (-12903) is what this file answered before the host
    // was asked and it was the wrong code.
    if (storage->_closed)
        return kVTMultiPassStorageInvalidErr;
    storage->_closed = true;
    return noErr;
}

@end