#include <stdint.h>
#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>

typedef struct __IOSurface *IOSurfaceRef;
typedef uint32_t IOSurfaceID;

extern IOSurfaceRef IOSurfaceCreate(CFDictionaryRef properties);
extern IOSurfaceRef IOSurfaceLookup(IOSurfaceID csid);
extern IOSurfaceID IOSurfaceGetID(IOSurfaceRef buffer);
extern size_t IOSurfaceGetWidth(IOSurfaceRef buffer);
extern size_t IOSurfaceGetHeight(IOSurfaceRef buffer);
extern size_t IOSurfaceGetBytesPerElement(IOSurfaceRef buffer);
extern size_t IOSurfaceGetBytesPerRow(IOSurfaceRef buffer);
extern uint32_t IOSurfaceGetPixelFormat(IOSurfaceRef buffer);
extern size_t IOSurfaceGetPlaneCount(IOSurfaceRef buffer);
extern int IOSurfaceLock(IOSurfaceRef buffer, uint32_t options, uint32_t *seed);
extern int IOSurfaceUnlock(IOSurfaceRef buffer, uint32_t options, uint32_t *seed);
extern void *IOSurfaceGetBaseAddress(IOSurfaceRef buffer);
extern void IOSurfaceSetValue(IOSurfaceRef buffer, CFStringRef key, CFTypeRef value);
extern CFTypeRef IOSurfaceCopyValue(IOSurfaceRef buffer, CFStringRef key);
extern void IOSurfaceIncrementUseCount(IOSurfaceRef buffer);
extern int32_t IOSurfaceGetUseCount(IOSurfaceRef buffer);
extern void IOSurfaceDecrementUseCount(IOSurfaceRef buffer);

static CFNumberRef number(int32_t value)
{
    return CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &value);
}

int main(void)
{
    CFStringRef keys[] = {CFSTR("IOSurfaceWidth"), CFSTR("IOSurfaceHeight"), CFSTR("IOSurfaceBytesPerElement"), CFSTR("IOSurfacePixelFormat")};
    CFNumberRef values[] = {number(64), number(32), number(4), number(0x42475241)};
    CFDictionaryRef properties = CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOSurfaceRef surface = IOSurfaceCreate(properties);
    if (!surface) {
        printf("create failed\n");
        return 1;
    }
    printf("width %zu\n", IOSurfaceGetWidth(surface));
    printf("height %zu\n", IOSurfaceGetHeight(surface));
    printf("bytes per element %zu\n", IOSurfaceGetBytesPerElement(surface));
    printf("bytes per row %zu\n", IOSurfaceGetBytesPerRow(surface));
    printf("pixel format %08x\n", IOSurfaceGetPixelFormat(surface));
    printf("planes %zu\n", IOSurfaceGetPlaneCount(surface));
    printf("id nonzero %d\n", IOSurfaceGetID(surface) != 0);
    IOSurfaceRef looked = IOSurfaceLookup(IOSurfaceGetID(surface));
    printf("lookup width %zu\n", looked ? IOSurfaceGetWidth(looked) : 0);
    uint32_t seed = 0;
    printf("lock %d\n", IOSurfaceLock(surface, 0, &seed));
    printf("base address set %d\n", IOSurfaceGetBaseAddress(surface) != NULL);
    printf("unlock %d\n", IOSurfaceUnlock(surface, 0, &seed));
    CFStringRef value = CFSTR("revenant");
    IOSurfaceSetValue(surface, CFSTR("RevenantKey"), value);
    CFTypeRef copied = IOSurfaceCopyValue(surface, CFSTR("RevenantKey"));
    char text[64] = "missing";
    if (copied) {
        CFStringGetCString((CFStringRef)copied, text, sizeof text, kCFStringEncodingUTF8);
        CFRelease(copied);
    }
    printf("value %s\n", text);
    IOSurfaceIncrementUseCount(surface);
    printf("use count %d\n", IOSurfaceGetUseCount(surface));
    IOSurfaceDecrementUseCount(surface);
    printf("use count %d\n", IOSurfaceGetUseCount(surface));
    return 0;
}
