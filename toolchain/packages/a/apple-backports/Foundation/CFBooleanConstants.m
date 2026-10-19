#import <CoreFoundation/CoreFoundation.h>

typedef struct {
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
    unsigned long (*refcount)(intptr_t op, CFTypeRef cf);
} RevenantCFRuntimeClass;

extern CFTypeID _CFRuntimeRegisterClass(const RevenantCFRuntimeClass *const cls);
extern CFTypeRef _CFRuntimeCreateInstance(CFAllocatorRef allocator, CFTypeID typeID, CFIndex extraBytes, unsigned char *category);

__attribute__((visibility("default"))) const void *__kCFBooleanTrue;
__attribute__((visibility("default"))) const void *__kCFBooleanFalse;

__attribute__((constructor)) static void revenant_cfboolean_constants(void)
{
    static const RevenantCFRuntimeClass booleanClass = {
        .version = 0,
        .className = "RevenantCFBoolean",
    };
    CFTypeID typeID = _CFRuntimeRegisterClass(&booleanClass);
    __kCFBooleanTrue = (const void *)CFRetain(_CFRuntimeCreateInstance(NULL, typeID, 0, NULL));
    __kCFBooleanFalse = (const void *)CFRetain(_CFRuntimeCreateInstance(NULL, typeID, 0, NULL));
}
