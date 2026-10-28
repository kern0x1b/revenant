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

typedef struct {
    uintptr_t isa;
    uint8_t info[4];
#if __LP64__
    uint32_t rc;
#endif
} RevenantCFRuntimeBase;

extern CFTypeID _CFRuntimeRegisterClass(const RevenantCFRuntimeClass *const cls);
extern CFTypeRef _CFRuntimeCreateInstance(CFAllocatorRef allocator, CFTypeID typeID, CFIndex extraBytes, unsigned char *category);
