#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurfaceRef.h>
#import <dlfcn.h>

#if !defined(REVENANT_IOSURFACE_LIBRARY)
#define REVENANT_IOSURFACE_LIBRARY "/System/Library/PrivateFrameworks/IOSurface.framework/IOSurface"
#endif

static void *RevenantIOSurfaceLibrary(void)
{
    static void *library;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        library = dlopen(REVENANT_IOSURFACE_LIBRARY, RTLD_LAZY);
        if (!library) {
            NSLog(@"IOSurface: the system library cannot be opened: %s", dlerror());
            abort();
        }
    });
    return library;
}

static void *RevenantIOSurfaceSymbol(const char *name)
{
    void *symbol = dlsym(RevenantIOSurfaceLibrary(), name);
    if (!symbol) {
        NSLog(@"IOSurface: the system library does not export %s", name);
        abort();
    }
    return symbol;
}

CFTypeID BACKPORT_IMPL(IOSurfaceGetTypeID)(void)
{
    static CFTypeID (*function)(void);
    if (!function) {
        function = (CFTypeID (*)(void))RevenantIOSurfaceSymbol("IOSurfaceGetTypeID");
    }
    return function();
}

IOSurfaceRef BACKPORT_IMPL(IOSurfaceCreate)(CFDictionaryRef properties)
{
    static IOSurfaceRef (*function)(CFDictionaryRef);
    if (!function) {
        function = (IOSurfaceRef (*)(CFDictionaryRef))RevenantIOSurfaceSymbol("IOSurfaceCreate");
    }
    return function(properties);
}

IOSurfaceRef BACKPORT_IMPL(IOSurfaceLookup)(IOSurfaceID csid)
{
    static IOSurfaceRef (*function)(IOSurfaceID);
    if (!function) {
        function = (IOSurfaceRef (*)(IOSurfaceID))RevenantIOSurfaceSymbol("IOSurfaceLookup");
    }
    return function(csid);
}

IOSurfaceID BACKPORT_IMPL(IOSurfaceGetID)(IOSurfaceRef buffer)
{
    static IOSurfaceID (*function)(IOSurfaceRef);
    if (!function) {
        function = (IOSurfaceID (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetID");
    }
    return function(buffer);
}

kern_return_t BACKPORT_IMPL(IOSurfaceLock)(IOSurfaceRef buffer, IOSurfaceLockOptions options, uint32_t *seed)
{
    static kern_return_t (*function)(IOSurfaceRef, IOSurfaceLockOptions, uint32_t *);
    if (!function) {
        function = (kern_return_t (*)(IOSurfaceRef, IOSurfaceLockOptions, uint32_t *))RevenantIOSurfaceSymbol("IOSurfaceLock");
    }
    return function(buffer, options, seed);
}

kern_return_t BACKPORT_IMPL(IOSurfaceUnlock)(IOSurfaceRef buffer, IOSurfaceLockOptions options, uint32_t *seed)
{
    static kern_return_t (*function)(IOSurfaceRef, IOSurfaceLockOptions, uint32_t *);
    if (!function) {
        function = (kern_return_t (*)(IOSurfaceRef, IOSurfaceLockOptions, uint32_t *))RevenantIOSurfaceSymbol("IOSurfaceUnlock");
    }
    return function(buffer, options, seed);
}

size_t BACKPORT_IMPL(IOSurfaceGetAllocSize)(IOSurfaceRef buffer)
{
    static size_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetAllocSize");
    }
    return function(buffer);
}

size_t BACKPORT_IMPL(IOSurfaceGetWidth)(IOSurfaceRef buffer)
{
    static size_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetWidth");
    }
    return function(buffer);
}

size_t BACKPORT_IMPL(IOSurfaceGetHeight)(IOSurfaceRef buffer)
{
    static size_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetHeight");
    }
    return function(buffer);
}

size_t BACKPORT_IMPL(IOSurfaceGetBytesPerElement)(IOSurfaceRef buffer)
{
    static size_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetBytesPerElement");
    }
    return function(buffer);
}

size_t BACKPORT_IMPL(IOSurfaceGetBytesPerRow)(IOSurfaceRef buffer)
{
    static size_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetBytesPerRow");
    }
    return function(buffer);
}

void *BACKPORT_IMPL(IOSurfaceGetBaseAddress)(IOSurfaceRef buffer)
{
    static void *(*function)(IOSurfaceRef);
    if (!function) {
        function = (void *(*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetBaseAddress");
    }
    return function(buffer);
}

size_t BACKPORT_IMPL(IOSurfaceGetElementWidth)(IOSurfaceRef buffer)
{
    static size_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetElementWidth");
    }
    return function(buffer);
}

size_t BACKPORT_IMPL(IOSurfaceGetElementHeight)(IOSurfaceRef buffer)
{
    static size_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetElementHeight");
    }
    return function(buffer);
}

OSType BACKPORT_IMPL(IOSurfaceGetPixelFormat)(IOSurfaceRef buffer)
{
    static OSType (*function)(IOSurfaceRef);
    if (!function) {
        function = (OSType (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetPixelFormat");
    }
    return function(buffer);
}

uint32_t BACKPORT_IMPL(IOSurfaceGetSeed)(IOSurfaceRef buffer)
{
    static uint32_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (uint32_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetSeed");
    }
    return function(buffer);
}

size_t BACKPORT_IMPL(IOSurfaceGetPlaneCount)(IOSurfaceRef buffer)
{
    static size_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetPlaneCount");
    }
    return function(buffer);
}

size_t BACKPORT_IMPL(IOSurfaceGetWidthOfPlane)(IOSurfaceRef buffer, size_t planeIndex)
{
    static size_t (*function)(IOSurfaceRef, size_t);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef, size_t))RevenantIOSurfaceSymbol("IOSurfaceGetWidthOfPlane");
    }
    return function(buffer, planeIndex);
}

size_t BACKPORT_IMPL(IOSurfaceGetHeightOfPlane)(IOSurfaceRef buffer, size_t planeIndex)
{
    static size_t (*function)(IOSurfaceRef, size_t);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef, size_t))RevenantIOSurfaceSymbol("IOSurfaceGetHeightOfPlane");
    }
    return function(buffer, planeIndex);
}

size_t BACKPORT_IMPL(IOSurfaceGetBytesPerElementOfPlane)(IOSurfaceRef buffer, size_t planeIndex)
{
    static size_t (*function)(IOSurfaceRef, size_t);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef, size_t))RevenantIOSurfaceSymbol("IOSurfaceGetBytesPerElementOfPlane");
    }
    return function(buffer, planeIndex);
}

size_t BACKPORT_IMPL(IOSurfaceGetBytesPerRowOfPlane)(IOSurfaceRef buffer, size_t planeIndex)
{
    static size_t (*function)(IOSurfaceRef, size_t);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef, size_t))RevenantIOSurfaceSymbol("IOSurfaceGetBytesPerRowOfPlane");
    }
    return function(buffer, planeIndex);
}

void *BACKPORT_IMPL(IOSurfaceGetBaseAddressOfPlane)(IOSurfaceRef buffer, size_t planeIndex)
{
    static void *(*function)(IOSurfaceRef, size_t);
    if (!function) {
        function = (void *(*)(IOSurfaceRef, size_t))RevenantIOSurfaceSymbol("IOSurfaceGetBaseAddressOfPlane");
    }
    return function(buffer, planeIndex);
}

size_t BACKPORT_IMPL(IOSurfaceGetElementWidthOfPlane)(IOSurfaceRef buffer, size_t planeIndex)
{
    static size_t (*function)(IOSurfaceRef, size_t);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef, size_t))RevenantIOSurfaceSymbol("IOSurfaceGetElementWidthOfPlane");
    }
    return function(buffer, planeIndex);
}

size_t BACKPORT_IMPL(IOSurfaceGetElementHeightOfPlane)(IOSurfaceRef buffer, size_t planeIndex)
{
    static size_t (*function)(IOSurfaceRef, size_t);
    if (!function) {
        function = (size_t (*)(IOSurfaceRef, size_t))RevenantIOSurfaceSymbol("IOSurfaceGetElementHeightOfPlane");
    }
    return function(buffer, planeIndex);
}

void BACKPORT_IMPL(IOSurfaceSetValue)(IOSurfaceRef buffer, CFStringRef key, CFTypeRef value)
{
    static void (*function)(IOSurfaceRef, CFStringRef, CFTypeRef);
    if (!function) {
        function = (void (*)(IOSurfaceRef, CFStringRef, CFTypeRef))RevenantIOSurfaceSymbol("IOSurfaceSetValue");
    }
    function(buffer, key, value);
}

CFTypeRef BACKPORT_IMPL(IOSurfaceCopyValue)(IOSurfaceRef buffer, CFStringRef key)
{
    static CFTypeRef (*function)(IOSurfaceRef, CFStringRef);
    if (!function) {
        function = (CFTypeRef (*)(IOSurfaceRef, CFStringRef))RevenantIOSurfaceSymbol("IOSurfaceCopyValue");
    }
    return function(buffer, key);
}

void BACKPORT_IMPL(IOSurfaceRemoveValue)(IOSurfaceRef buffer, CFStringRef key)
{
    static void (*function)(IOSurfaceRef, CFStringRef);
    if (!function) {
        function = (void (*)(IOSurfaceRef, CFStringRef))RevenantIOSurfaceSymbol("IOSurfaceRemoveValue");
    }
    function(buffer, key);
}

void BACKPORT_IMPL(IOSurfaceSetValues)(IOSurfaceRef buffer, CFDictionaryRef keysAndValues)
{
    static void (*function)(IOSurfaceRef, CFDictionaryRef);
    if (!function) {
        function = (void (*)(IOSurfaceRef, CFDictionaryRef))RevenantIOSurfaceSymbol("IOSurfaceSetValues");
    }
    function(buffer, keysAndValues);
}

CFDictionaryRef BACKPORT_IMPL(IOSurfaceCopyAllValues)(IOSurfaceRef buffer)
{
    static CFDictionaryRef (*function)(IOSurfaceRef);
    if (!function) {
        function = (CFDictionaryRef (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceCopyAllValues");
    }
    return function(buffer);
}

void BACKPORT_IMPL(IOSurfaceRemoveAllValues)(IOSurfaceRef buffer)
{
    static void (*function)(IOSurfaceRef);
    if (!function) {
        function = (void (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceRemoveAllValues");
    }
    function(buffer);
}

mach_port_t BACKPORT_IMPL(IOSurfaceCreateMachPort)(IOSurfaceRef buffer)
{
    static mach_port_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (mach_port_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceCreateMachPort");
    }
    return function(buffer);
}

IOSurfaceRef BACKPORT_IMPL(IOSurfaceLookupFromMachPort)(mach_port_t port)
{
    static IOSurfaceRef (*function)(mach_port_t);
    if (!function) {
        function = (IOSurfaceRef (*)(mach_port_t))RevenantIOSurfaceSymbol("IOSurfaceLookupFromMachPort");
    }
    return function(port);
}

size_t BACKPORT_IMPL(IOSurfaceGetPropertyMaximum)(CFStringRef property)
{
    static size_t (*function)(CFStringRef);
    if (!function) {
        function = (size_t (*)(CFStringRef))RevenantIOSurfaceSymbol("IOSurfaceGetPropertyMaximum");
    }
    return function(property);
}

size_t BACKPORT_IMPL(IOSurfaceGetPropertyAlignment)(CFStringRef property)
{
    static size_t (*function)(CFStringRef);
    if (!function) {
        function = (size_t (*)(CFStringRef))RevenantIOSurfaceSymbol("IOSurfaceGetPropertyAlignment");
    }
    return function(property);
}

size_t BACKPORT_IMPL(IOSurfaceAlignProperty)(CFStringRef property, size_t value)
{
    static size_t (*function)(CFStringRef, size_t);
    if (!function) {
        function = (size_t (*)(CFStringRef, size_t))RevenantIOSurfaceSymbol("IOSurfaceAlignProperty");
    }
    return function(property, value);
}

void BACKPORT_IMPL(IOSurfaceIncrementUseCount)(IOSurfaceRef buffer)
{
    static void (*function)(IOSurfaceRef);
    if (!function) {
        function = (void (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceIncrementUseCount");
    }
    function(buffer);
}

void BACKPORT_IMPL(IOSurfaceDecrementUseCount)(IOSurfaceRef buffer)
{
    static void (*function)(IOSurfaceRef);
    if (!function) {
        function = (void (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceDecrementUseCount");
    }
    function(buffer);
}

int32_t BACKPORT_IMPL(IOSurfaceGetUseCount)(IOSurfaceRef buffer)
{
    static int32_t (*function)(IOSurfaceRef);
    if (!function) {
        function = (int32_t (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceGetUseCount");
    }
    return function(buffer);
}

Boolean BACKPORT_IMPL(IOSurfaceIsInUse)(IOSurfaceRef buffer)
{
    static Boolean (*function)(IOSurfaceRef);
    if (!function) {
        function = (Boolean (*)(IOSurfaceRef))RevenantIOSurfaceSymbol("IOSurfaceIsInUse");
    }
    return function(buffer);
}

kern_return_t BACKPORT_IMPL(IOSurfaceSetPurgeable)(IOSurfaceRef buffer, uint32_t newState, uint32_t *oldState)
{
    static kern_return_t (*function)(IOSurfaceRef, uint32_t, uint32_t *);
    if (!function) {
        function = (kern_return_t (*)(IOSurfaceRef, uint32_t, uint32_t *))RevenantIOSurfaceSymbol("IOSurfaceSetPurgeable");
    }
    return function(buffer, newState, oldState);
}

const CFStringRef BACKPORT_IMPL(kIOSurfaceWidth) = CFSTR("IOSurfaceWidth");
const CFStringRef BACKPORT_IMPL(kIOSurfaceHeight) = CFSTR("IOSurfaceHeight");
const CFStringRef BACKPORT_IMPL(kIOSurfaceBytesPerElement) = CFSTR("IOSurfaceBytesPerElement");
const CFStringRef BACKPORT_IMPL(kIOSurfaceBytesPerRow) = CFSTR("IOSurfaceBytesPerRow");
const CFStringRef BACKPORT_IMPL(kIOSurfacePixelFormat) = CFSTR("IOSurfacePixelFormat");
const CFStringRef BACKPORT_IMPL(kIOSurfaceColorSpace) = CFSTR("IOSurfaceColorSpace");
const CFStringRef BACKPORT_IMPL(kIOSurfaceCacheMode) = CFSTR("IOSurfaceCacheMode");
