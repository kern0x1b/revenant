#import <IOSurface/IOSurfaceRef.h>
#import <IOKit/IOReturn.h>
#import <dispatch/dispatch.h>
#import <pthread.h>
#import <stdlib.h>
#import <string.h>

#define RevenantIOSurfaceRowAlignment 16

typedef struct RevenantCFRuntimeBase {
    uintptr_t isa;
    uint8_t info[4];
#if __LP64__
    uint32_t rc;
#endif
} RevenantCFRuntimeBase;

typedef struct RevenantCFRuntimeClass {
    CFIndex version;
    const char *className;
    void (*init)(CFTypeRef cf);
    CFTypeRef (*copy)(CFAllocatorRef allocator, CFTypeRef cf);
    void (*finalize)(CFTypeRef cf);
    Boolean (*equal)(CFTypeRef cf1, CFTypeRef cf2);
    CFHashCode (*hash)(CFTypeRef cf);
    CFStringRef (*copyFormattingDesc)(CFTypeRef cf, CFDictionaryRef formatOptions);
    CFStringRef (*copyDebugDesc)(CFTypeRef cf);
    void (*reclaim)(CFTypeRef cf);
    void *refcount;
    uintptr_t requiredAlignment;
    void *reserved[4];
} RevenantCFRuntimeClass;

extern CFTypeID _CFRuntimeRegisterClass(const RevenantCFRuntimeClass *cls);
extern CFTypeRef _CFRuntimeCreateInstance(CFAllocatorRef allocator, CFTypeID typeID, CFIndex extraBytes, unsigned char *category);

const CFStringRef kIOSurfaceWidth = CFSTR("IOSurfaceWidth");
const CFStringRef kIOSurfaceHeight = CFSTR("IOSurfaceHeight");
const CFStringRef kIOSurfaceBytesPerRow = CFSTR("IOSurfaceBytesPerRow");
const CFStringRef kIOSurfaceBytesPerElement = CFSTR("IOSurfaceBytesPerElement");
const CFStringRef kIOSurfaceElementWidth = CFSTR("IOSurfaceElementWidth");
const CFStringRef kIOSurfaceElementHeight = CFSTR("IOSurfaceElementHeight");
const CFStringRef kIOSurfacePlaneInfo = CFSTR("IOSurfacePlaneInfo");
const CFStringRef kIOSurfacePlaneWidth = CFSTR("IOSurfacePlaneWidth");
const CFStringRef kIOSurfacePlaneHeight = CFSTR("IOSurfacePlaneHeight");
const CFStringRef kIOSurfacePlaneBytesPerRow = CFSTR("IOSurfacePlaneBytesPerRow");
const CFStringRef kIOSurfacePlaneBytesPerElement = CFSTR("IOSurfacePlaneBytesPerElement");
const CFStringRef kIOSurfacePlaneElementWidth = CFSTR("IOSurfacePlaneElementWidth");
const CFStringRef kIOSurfacePlaneElementHeight = CFSTR("IOSurfacePlaneElementHeight");
const CFStringRef kIOSurfacePlaneOffset = CFSTR("IOSurfacePlaneOffset");
const CFStringRef kIOSurfacePlaneSize = CFSTR("IOSurfacePlaneSize");
const CFStringRef kIOSurfaceCacheMode = CFSTR("IOSurfaceCacheMode");
const CFStringRef kIOSurfacePixelFormat = CFSTR("IOSurfacePixelFormat");
const CFStringRef kIOSurfaceColorSpace = CFSTR("IOSurfaceColorSpace");

struct RevenantIOSurfacePlane {
    size_t width;
    size_t height;
    size_t bytesPerElement;
    size_t elementWidth;
    size_t elementHeight;
    size_t bytesPerRow;
    size_t offset;
    size_t size;
};

struct RevenantPlaneKeys {
    CFStringRef width;
    CFStringRef height;
    CFStringRef bytesPerElement;
    CFStringRef elementWidth;
    CFStringRef elementHeight;
    CFStringRef bytesPerRow;
    CFStringRef offset;
    CFStringRef size;
};

struct __IOSurface {
    RevenantCFRuntimeBase base;
    IOSurfaceID identifier;
    OSType pixelFormat;
    uint32_t seed;
    uint32_t purgeableState;
    int32_t useCount;
    int32_t lockCount;
    struct RevenantIOSurfacePlane geometry;
    size_t planeCount;
    struct RevenantIOSurfacePlane *planes;
    uint8_t *storage;
    CFMutableDictionaryRef values;
};

static pthread_mutex_t *RevenantIOSurfaceMutex(void)
{
    static pthread_mutex_t mutex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pthread_mutexattr_t attributes;
        pthread_mutexattr_init(&attributes);
        pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&mutex, &attributes);
        pthread_mutexattr_destroy(&attributes);
    });
    return &mutex;
}

static CFMutableArrayRef RevenantIOSurfaceRegistry;
static CFTypeID RevenantIOSurfaceTypeID;
static IOSurfaceID RevenantIOSurfaceLastIdentifier;

static void RevenantIOSurfaceFinalize(CFTypeRef cf)
{
    struct __IOSurface *surface = (struct __IOSurface *)cf;
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    if (RevenantIOSurfaceRegistry) {
        CFIndex index = CFArrayGetFirstIndexOfValue(RevenantIOSurfaceRegistry, CFRangeMake(0, CFArrayGetCount(RevenantIOSurfaceRegistry)), surface);
        if (index != kCFNotFound) {
            CFArrayRemoveValueAtIndex(RevenantIOSurfaceRegistry, index);
        }
    }
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    CFRelease(surface->values);
    free(surface->planes);
    free(surface->storage);
}

static size_t RevenantBytesPerElementForPixelFormat(size_t pixelFormat)
{
    switch (pixelFormat) {
        case 0x42475241: return 4;
        case 0x52476841: return 8;
        case 0x4C303038: return 1;
        default: return 0;
    }
}

static BOOL RevenantReadSize(CFDictionaryRef dictionary, CFStringRef key, size_t *value)
{
    CFTypeRef number = key ? CFDictionaryGetValue(dictionary, key) : NULL;
    long long integer = 0;
    if (!number || CFGetTypeID(number) != CFNumberGetTypeID() || !CFNumberGetValue(number, kCFNumberLongLongType, &integer) || integer < 0) {
        return NO;
    }
    *value = (size_t)integer;
    return YES;
}

static BOOL RevenantMultiply(size_t a, size_t b, size_t *product)
{
    if (a != 0 && b > SIZE_MAX / a) {
        return NO;
    }
    *product = a * b;
    return YES;
}

static BOOL RevenantAlignUp(size_t value, size_t *aligned)
{
    if (value > SIZE_MAX - (RevenantIOSurfaceRowAlignment - 1)) {
        return NO;
    }
    *aligned = (value + RevenantIOSurfaceRowAlignment - 1) / RevenantIOSurfaceRowAlignment * RevenantIOSurfaceRowAlignment;
    return YES;
}

static BOOL RevenantMakePlane(CFDictionaryRef description, const struct RevenantPlaneKeys *keys, size_t defaultBytesPerElement, size_t offset, struct RevenantIOSurfacePlane *plane)
{
    struct RevenantIOSurfacePlane result;
    memset(&result, 0, sizeof(result));
    if (!RevenantReadSize(description, keys->width, &result.width) || !RevenantReadSize(description, keys->height, &result.height) || result.width == 0 || result.height == 0) {
        return NO;
    }
    if (!RevenantReadSize(description, keys->bytesPerElement, &result.bytesPerElement)) {
        result.bytesPerElement = defaultBytesPerElement;
    }
    if (result.bytesPerElement == 0) {
        return NO;
    }
    result.elementWidth = 1;
    result.elementHeight = 1;
    RevenantReadSize(description, keys->elementWidth, &result.elementWidth);
    RevenantReadSize(description, keys->elementHeight, &result.elementHeight);
    if (result.elementWidth == 0 || result.elementHeight == 0) {
        return NO;
    }

    size_t minimumRowBytes = 0;
    size_t alignedRowBytes = 0;
    if (!RevenantMultiply(result.width, result.bytesPerElement, &minimumRowBytes) || !RevenantAlignUp(minimumRowBytes, &alignedRowBytes)) {
        return NO;
    }
    size_t bytesPerRow = 0;
    if (RevenantReadSize(description, keys->bytesPerRow, &bytesPerRow)) {
        if (bytesPerRow < minimumRowBytes) {
            return NO;
        }
    } else {
        bytesPerRow = alignedRowBytes;
    }
    result.bytesPerRow = bytesPerRow;

    size_t defaultSize = 0;
    if (!RevenantMultiply(result.bytesPerRow, result.height, &defaultSize)) {
        return NO;
    }
    result.offset = offset;
    RevenantReadSize(description, keys->offset, &result.offset);
    result.size = defaultSize;
    RevenantReadSize(description, keys->size, &result.size);
    if (result.size == 0) {
        return NO;
    }
    *plane = result;
    return YES;
}

static struct RevenantPlaneKeys RevenantSurfaceKeys(void)
{
    struct RevenantPlaneKeys keys = {
        kIOSurfaceWidth, kIOSurfaceHeight, kIOSurfaceBytesPerElement,
        kIOSurfaceElementWidth, kIOSurfaceElementHeight, kIOSurfaceBytesPerRow,
        NULL, NULL,
    };
    return keys;
}

static struct RevenantPlaneKeys RevenantPlaneKeysForPlanes(void)
{
    struct RevenantPlaneKeys keys = {
        kIOSurfacePlaneWidth, kIOSurfacePlaneHeight, kIOSurfacePlaneBytesPerElement,
        kIOSurfacePlaneElementWidth, kIOSurfacePlaneElementHeight, kIOSurfacePlaneBytesPerRow,
        kIOSurfacePlaneOffset, kIOSurfacePlaneSize,
    };
    return keys;
}

static BOOL RevenantPlaneIsValid(IOSurfaceRef buffer, size_t index)
{
    return buffer->planeCount == 0 ? index == 0 : index < buffer->planeCount;
}

static struct RevenantIOSurfacePlane RevenantPlaneOf(IOSurfaceRef buffer, size_t index)
{
    struct RevenantIOSurfacePlane plane;
    memset(&plane, 0, sizeof(plane));
    if (buffer->planeCount == 0) {
        if (index == 0) {
            plane = buffer->geometry;
        }
    } else if (index < buffer->planeCount) {
        plane = buffer->planes[index];
    }
    return plane;
}

CFTypeID IOSurfaceGetTypeID(void)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    if (!RevenantIOSurfaceTypeID) {
        static RevenantCFRuntimeClass klass;
        klass.className = "IOSurface";
        klass.finalize = RevenantIOSurfaceFinalize;
        RevenantIOSurfaceTypeID = _CFRuntimeRegisterClass(&klass);
    }
    CFTypeID typeID = RevenantIOSurfaceTypeID;
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return typeID;
}

IOSurfaceRef IOSurfaceCreate(CFDictionaryRef properties)
{
    if (!properties) {
        return NULL;
    }
    size_t pixelFormat = 0;
    RevenantReadSize(properties, kIOSurfacePixelFormat, &pixelFormat);

    struct RevenantIOSurfacePlane geometry;
    struct RevenantPlaneKeys surfaceKeys = RevenantSurfaceKeys();
    CFTypeRef planeInfo = CFDictionaryGetValue(properties, kIOSurfacePlaneInfo);
    if (planeInfo) {
        memset(&geometry, 0, sizeof(geometry));
        if (!RevenantReadSize(properties, kIOSurfaceWidth, &geometry.width) || !RevenantReadSize(properties, kIOSurfaceHeight, &geometry.height) || geometry.width == 0 || geometry.height == 0) {
            return NULL;
        }
        geometry.elementWidth = 1;
        geometry.elementHeight = 1;
        RevenantReadSize(properties, kIOSurfaceElementWidth, &geometry.elementWidth);
        RevenantReadSize(properties, kIOSurfaceElementHeight, &geometry.elementHeight);
    } else if (!RevenantMakePlane(properties, &surfaceKeys, RevenantBytesPerElementForPixelFormat(pixelFormat), 0, &geometry)) {
        return NULL;
    }

    struct RevenantIOSurfacePlane *planes = NULL;
    size_t planeCount = 0;
    if (planeInfo) {
        if (CFGetTypeID(planeInfo) != CFArrayGetTypeID()) {
            return NULL;
        }
        CFArrayRef descriptions = (CFArrayRef)planeInfo;
        planeCount = (size_t)CFArrayGetCount(descriptions);
        if (planeCount == 0) {
            return NULL;
        }
        planes = calloc(planeCount, sizeof(*planes));
        if (!planes) {
            return NULL;
        }
        struct RevenantPlaneKeys planeKeys = RevenantPlaneKeysForPlanes();
        size_t end = 0;
        for (size_t index = 0; index < planeCount; index++) {
            CFTypeRef description = CFArrayGetValueAtIndex(descriptions, (CFIndex)index);
            size_t offset = end;
            if (index > 0) {
                size_t aligned = 0;
                if (!RevenantAlignUp(end, &aligned)) {
                    free(planes);
                    return NULL;
                }
                offset = aligned;
            }
            if (CFGetTypeID(description) != CFDictionaryGetTypeID() || !RevenantMakePlane((CFDictionaryRef)description, &planeKeys, 0, offset, &planes[index])) {
                free(planes);
                return NULL;
            }
            size_t planeEnd = planes[index].offset + planes[index].size;
            if (planeEnd < planes[index].offset) {
                free(planes);
                return NULL;
            }
            end = planeEnd > end ? planeEnd : end;
        }
        geometry.offset = 0;
        geometry.size = end;
    }

    uint8_t *storage = calloc(1, geometry.size);
    if (!storage) {
        free(planes);
        return NULL;
    }
    CFMutableDictionaryRef values = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, properties);
    if (!values) {
        free(planes);
        free(storage);
        return NULL;
    }

    CFTypeID typeID = IOSurfaceGetTypeID();
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    struct __IOSurface *surface = (struct __IOSurface *)_CFRuntimeCreateInstance(kCFAllocatorDefault, typeID, sizeof(struct __IOSurface) - sizeof(RevenantCFRuntimeBase), NULL);
    if (!surface) {
        pthread_mutex_unlock(RevenantIOSurfaceMutex());
        CFRelease(values);
        free(planes);
        free(storage);
        return NULL;
    }
    do {
        RevenantIOSurfaceLastIdentifier++;
    } while (RevenantIOSurfaceLastIdentifier == 0);
    surface->identifier = RevenantIOSurfaceLastIdentifier;
    surface->pixelFormat = (OSType)pixelFormat;
    surface->seed = 0;
    surface->purgeableState = kIOSurfacePurgeableNonVolatile;
    surface->useCount = 0;
    surface->lockCount = 0;
    surface->geometry = geometry;
    surface->planeCount = planeCount;
    surface->planes = planes;
    surface->storage = storage;
    surface->values = values;
    if (!RevenantIOSurfaceRegistry) {
        RevenantIOSurfaceRegistry = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    }
    CFArrayAppendValue(RevenantIOSurfaceRegistry, surface);
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return surface;
}

IOSurfaceRef IOSurfaceLookup(IOSurfaceID csid)
{
    IOSurfaceRef found = NULL;
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    if (RevenantIOSurfaceRegistry) {
        CFIndex count = CFArrayGetCount(RevenantIOSurfaceRegistry);
        for (CFIndex index = 0; index < count; index++) {
            IOSurfaceRef candidate = (IOSurfaceRef)CFArrayGetValueAtIndex(RevenantIOSurfaceRegistry, index);
            if (candidate->identifier == csid) {
                found = (IOSurfaceRef)CFRetain(candidate);
                break;
            }
        }
    }
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return found;
}

IOSurfaceID IOSurfaceGetID(IOSurfaceRef buffer)
{
    return buffer->identifier;
}

kern_return_t IOSurfaceLock(IOSurfaceRef buffer, IOSurfaceLockOptions options, uint32_t *seed)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    buffer->lockCount++;
    if (seed) {
        *seed = buffer->seed;
    }
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return kIOReturnSuccess;
}

kern_return_t IOSurfaceUnlock(IOSurfaceRef buffer, IOSurfaceLockOptions options, uint32_t *seed)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    if (buffer->lockCount == 0) {
        pthread_mutex_unlock(RevenantIOSurfaceMutex());
        return kIOReturnBadArgument;
    }
    buffer->lockCount--;
    if (!(options & kIOSurfaceLockReadOnly)) {
        buffer->seed++;
    }
    if (seed) {
        *seed = buffer->seed;
    }
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return kIOReturnSuccess;
}

size_t IOSurfaceGetAllocSize(IOSurfaceRef buffer)
{
    return buffer->geometry.size;
}

size_t IOSurfaceGetWidth(IOSurfaceRef buffer)
{
    return buffer->geometry.width;
}

size_t IOSurfaceGetHeight(IOSurfaceRef buffer)
{
    return buffer->geometry.height;
}

size_t IOSurfaceGetBytesPerElement(IOSurfaceRef buffer)
{
    return buffer->geometry.bytesPerElement;
}

size_t IOSurfaceGetBytesPerRow(IOSurfaceRef buffer)
{
    return buffer->geometry.bytesPerRow;
}

void *IOSurfaceGetBaseAddress(IOSurfaceRef buffer)
{
    return buffer->storage;
}

size_t IOSurfaceGetElementWidth(IOSurfaceRef buffer)
{
    return buffer->geometry.elementWidth;
}

size_t IOSurfaceGetElementHeight(IOSurfaceRef buffer)
{
    return buffer->geometry.elementHeight;
}

OSType IOSurfaceGetPixelFormat(IOSurfaceRef buffer)
{
    return buffer->pixelFormat;
}

uint32_t IOSurfaceGetSeed(IOSurfaceRef buffer)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    uint32_t seed = buffer->seed;
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return seed;
}

size_t IOSurfaceGetPlaneCount(IOSurfaceRef buffer)
{
    return buffer->planeCount;
}

size_t IOSurfaceGetWidthOfPlane(IOSurfaceRef buffer, size_t planeIndex)
{
    return RevenantPlaneOf(buffer, planeIndex).width;
}

size_t IOSurfaceGetHeightOfPlane(IOSurfaceRef buffer, size_t planeIndex)
{
    return RevenantPlaneOf(buffer, planeIndex).height;
}

size_t IOSurfaceGetBytesPerElementOfPlane(IOSurfaceRef buffer, size_t planeIndex)
{
    return RevenantPlaneOf(buffer, planeIndex).bytesPerElement;
}

size_t IOSurfaceGetBytesPerRowOfPlane(IOSurfaceRef buffer, size_t planeIndex)
{
    return RevenantPlaneOf(buffer, planeIndex).bytesPerRow;
}

void *IOSurfaceGetBaseAddressOfPlane(IOSurfaceRef buffer, size_t planeIndex)
{
    uint8_t *base = NULL;
    if (RevenantPlaneIsValid(buffer, planeIndex)) {
        base = buffer->storage + RevenantPlaneOf(buffer, planeIndex).offset;
    }
    return base;
}

size_t IOSurfaceGetElementWidthOfPlane(IOSurfaceRef buffer, size_t planeIndex)
{
    return RevenantPlaneOf(buffer, planeIndex).elementWidth;
}

size_t IOSurfaceGetElementHeightOfPlane(IOSurfaceRef buffer, size_t planeIndex)
{
    return RevenantPlaneOf(buffer, planeIndex).elementHeight;
}

static void RevenantIOSurfaceSetOne(const void *key, const void *value, void *context)
{
    CFDictionarySetValue((CFMutableDictionaryRef)context, key, value);
}

void IOSurfaceSetValue(IOSurfaceRef buffer, CFStringRef key, CFTypeRef value)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    if (value) {
        CFDictionarySetValue(buffer->values, key, value);
    } else {
        CFDictionaryRemoveValue(buffer->values, key);
    }
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
}

CFTypeRef IOSurfaceCopyValue(IOSurfaceRef buffer, CFStringRef key)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    CFTypeRef value = CFDictionaryGetValue(buffer->values, key);
    if (value) {
        CFRetain(value);
    }
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return value;
}

void IOSurfaceRemoveValue(IOSurfaceRef buffer, CFStringRef key)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    CFDictionaryRemoveValue(buffer->values, key);
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
}

void IOSurfaceSetValues(IOSurfaceRef buffer, CFDictionaryRef keysAndValues)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    CFDictionaryApplyFunction(keysAndValues, RevenantIOSurfaceSetOne, buffer->values);
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
}

CFDictionaryRef IOSurfaceCopyAllValues(IOSurfaceRef buffer)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    CFDictionaryRef copy = CFDictionaryCreateCopy(kCFAllocatorDefault, buffer->values);
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return copy;
}

void IOSurfaceRemoveAllValues(IOSurfaceRef buffer)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    CFDictionaryRemoveAllValues(buffer->values);
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
}

void IOSurfaceIncrementUseCount(IOSurfaceRef buffer)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    buffer->useCount++;
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
}

void IOSurfaceDecrementUseCount(IOSurfaceRef buffer)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    if (buffer->useCount > 0) {
        buffer->useCount--;
    }
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
}

int32_t IOSurfaceGetUseCount(IOSurfaceRef buffer)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    int32_t count = buffer->useCount;
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return count;
}

Boolean IOSurfaceIsInUse(IOSurfaceRef buffer)
{
    return IOSurfaceGetUseCount(buffer) > 0;
}

kern_return_t IOSurfaceSetPurgeable(IOSurfaceRef buffer, uint32_t newState, uint32_t *oldState)
{
    pthread_mutex_lock(RevenantIOSurfaceMutex());
    if (oldState) {
        *oldState = buffer->purgeableState;
    }
    if (newState != kIOSurfacePurgeableKeepCurrent) {
        buffer->purgeableState = newState;
        if (newState == kIOSurfacePurgeableEmpty) {
            memset(buffer->storage, 0, buffer->geometry.size);
        }
    }
    pthread_mutex_unlock(RevenantIOSurfaceMutex());
    return kIOReturnSuccess;
}
