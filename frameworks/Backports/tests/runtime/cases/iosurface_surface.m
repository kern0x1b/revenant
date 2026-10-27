#import "../app/revenant_check.h"
#import <CoreFoundation/CoreFoundation.h>

extern void *IOSurfaceCreate(CFDictionaryRef properties);
extern void *IOSurfaceLookup(uint32_t csid);
extern uint32_t IOSurfaceGetID(void *buffer);
extern size_t IOSurfaceGetWidth(void *buffer);
extern size_t IOSurfaceGetHeight(void *buffer);
extern size_t IOSurfaceGetBytesPerElement(void *buffer);
extern size_t IOSurfaceGetBytesPerRow(void *buffer);
extern uint32_t IOSurfaceGetPixelFormat(void *buffer);
extern size_t IOSurfaceGetPlaneCount(void *buffer);
extern int IOSurfaceLock(void *buffer, uint32_t options, uint32_t *seed);
extern int IOSurfaceUnlock(void *buffer, uint32_t options, uint32_t *seed);
extern void *IOSurfaceGetBaseAddress(void *buffer);
extern void IOSurfaceSetValue(void *buffer, CFStringRef key, CFTypeRef value);
extern CFTypeRef IOSurfaceCopyValue(void *buffer, CFStringRef key);
extern void IOSurfaceIncrementUseCount(void *buffer);
extern int32_t IOSurfaceGetUseCount(void *buffer);
extern void IOSurfaceDecrementUseCount(void *buffer);

static CFNumberRef revenant_surface_number(int32_t value)
{
    return CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &value);
}

static void revenant_surface_integer(NSString *name, long long value, long long expected, int negative)
{
    revenant_expect_true(name, (value == expected) != (BOOL)negative,
                         [NSString stringWithFormat:@"%lld, expected %lld", value, expected]);
}

REVENANT_CASE(iosurface_surface)
{
    CFStringRef keys[] = {CFSTR("IOSurfaceWidth"), CFSTR("IOSurfaceHeight"), CFSTR("IOSurfaceBytesPerElement"), CFSTR("IOSurfacePixelFormat")};
    CFNumberRef values[] = {revenant_surface_number(64), revenant_surface_number(32), revenant_surface_number(4), revenant_surface_number(0x42475241)};
    CFDictionaryRef properties = CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    void *surface = IOSurfaceCreate(properties);
    revenant_expect_true(@"IOSurfaceCreate returns a surface", surface != NULL, @"NULL");
    if (!surface) {
        return;
    }
    revenant_surface_integer(@"width", IOSurfaceGetWidth(surface), 64, negative);
    revenant_surface_integer(@"height", IOSurfaceGetHeight(surface), 32, negative);
    revenant_surface_integer(@"bytes per element", IOSurfaceGetBytesPerElement(surface), 4, negative);
    revenant_surface_integer(@"bytes per row", IOSurfaceGetBytesPerRow(surface), 256, negative);
    revenant_surface_integer(@"pixel format", IOSurfaceGetPixelFormat(surface), 0x42475241, negative);
    revenant_surface_integer(@"plane count", IOSurfaceGetPlaneCount(surface), 0, negative);
    revenant_surface_integer(@"id is nonzero", IOSurfaceGetID(surface) != 0, 1, negative);
    void *looked = IOSurfaceLookup(IOSurfaceGetID(surface));
    revenant_surface_integer(@"lookup width", looked ? IOSurfaceGetWidth(looked) : 0, 64, negative);
    uint32_t seed = 0;
    revenant_surface_integer(@"lock", IOSurfaceLock(surface, 0, &seed), 0, negative);
    revenant_surface_integer(@"base address is set", IOSurfaceGetBaseAddress(surface) != NULL, 1, negative);
    revenant_surface_integer(@"unlock", IOSurfaceUnlock(surface, 0, &seed), 0, negative);
    IOSurfaceSetValue(surface, CFSTR("RevenantKey"), CFSTR("revenant"));
    CFTypeRef copied = IOSurfaceCopyValue(surface, CFSTR("RevenantKey"));
    char text[64] = "missing";
    if (copied) {
        CFStringGetCString((CFStringRef)copied, text, sizeof text, kCFStringEncodingUTF8);
        CFRelease(copied);
    }
    revenant_expect_true(@"the value round-trips", strcmp(text, "revenant") == 0, [NSString stringWithUTF8String:text]);
    IOSurfaceIncrementUseCount(surface);
    revenant_surface_integer(@"use count after increment", IOSurfaceGetUseCount(surface), 1, negative);
    IOSurfaceDecrementUseCount(surface);
    revenant_surface_integer(@"use count after decrement", IOSurfaceGetUseCount(surface), 0, negative);
}
