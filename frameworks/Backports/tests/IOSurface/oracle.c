#include <dlfcn.h>
#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>

typedef struct __IOSurface *IOSurfaceRef;
typedef uint32_t IOSurfaceID;

static void *OracleLibrary(void)
{
    static void *library;
    if (!library) {
        library = dlopen("/System/Library/Frameworks/IOSurface.framework/IOSurface", RTLD_LAZY);
    }
    return library;
}

#define OracleSymbol(name) dlsym(OracleLibrary(), #name)

IOSurfaceRef IOSurfaceCreate(CFDictionaryRef properties)
{
    return ((IOSurfaceRef (*)(CFDictionaryRef))OracleSymbol(IOSurfaceCreate))(properties);
}

IOSurfaceRef IOSurfaceLookup(IOSurfaceID csid)
{
    return ((IOSurfaceRef (*)(IOSurfaceID))OracleSymbol(IOSurfaceLookup))(csid);
}

IOSurfaceID IOSurfaceGetID(IOSurfaceRef buffer)
{
    return ((IOSurfaceID (*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetID))(buffer);
}

size_t IOSurfaceGetWidth(IOSurfaceRef buffer)
{
    return ((size_t (*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetWidth))(buffer);
}

size_t IOSurfaceGetHeight(IOSurfaceRef buffer)
{
    return ((size_t (*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetHeight))(buffer);
}

size_t IOSurfaceGetBytesPerElement(IOSurfaceRef buffer)
{
    return ((size_t (*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetBytesPerElement))(buffer);
}

size_t IOSurfaceGetBytesPerRow(IOSurfaceRef buffer)
{
    return ((size_t (*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetBytesPerRow))(buffer);
}

uint32_t IOSurfaceGetPixelFormat(IOSurfaceRef buffer)
{
    return ((uint32_t (*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetPixelFormat))(buffer);
}

size_t IOSurfaceGetPlaneCount(IOSurfaceRef buffer)
{
    return ((size_t (*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetPlaneCount))(buffer);
}

int IOSurfaceLock(IOSurfaceRef buffer, uint32_t options, uint32_t *seed)
{
    return ((int (*)(IOSurfaceRef, uint32_t, uint32_t *))OracleSymbol(IOSurfaceLock))(buffer, options, seed);
}

int IOSurfaceUnlock(IOSurfaceRef buffer, uint32_t options, uint32_t *seed)
{
    return ((int (*)(IOSurfaceRef, uint32_t, uint32_t *))OracleSymbol(IOSurfaceUnlock))(buffer, options, seed);
}

void *IOSurfaceGetBaseAddress(IOSurfaceRef buffer)
{
    return ((void *(*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetBaseAddress))(buffer);
}

void IOSurfaceSetValue(IOSurfaceRef buffer, CFStringRef key, CFTypeRef value)
{
    ((void (*)(IOSurfaceRef, CFStringRef, CFTypeRef))OracleSymbol(IOSurfaceSetValue))(buffer, key, value);
}

CFTypeRef IOSurfaceCopyValue(IOSurfaceRef buffer, CFStringRef key)
{
    return ((CFTypeRef (*)(IOSurfaceRef, CFStringRef))OracleSymbol(IOSurfaceCopyValue))(buffer, key);
}

void IOSurfaceIncrementUseCount(IOSurfaceRef buffer)
{
    ((void (*)(IOSurfaceRef))OracleSymbol(IOSurfaceIncrementUseCount))(buffer);
}

int32_t IOSurfaceGetUseCount(IOSurfaceRef buffer)
{
    return ((int32_t (*)(IOSurfaceRef))OracleSymbol(IOSurfaceGetUseCount))(buffer);
}

void IOSurfaceDecrementUseCount(IOSurfaceRef buffer)
{
    ((void (*)(IOSurfaceRef))OracleSymbol(IOSurfaceDecrementUseCount))(buffer);
}
