#import <CoreFoundation/CoreFoundation.h>

// A recent-SDK app can bind directly to the private storage symbols behind kCFBooleanTrue and
// kCFBooleanFalse - __kCFBooleanTrue and __kCFBooleanFalse - the way it binds NSConstantArray's
// isa: as a compile-time-constant address embedded straight into a literal element, a default
// value or a call argument, never loaded back out through the public kCFBooleanTrue/kCFBooleanFalse
// pointer variables. iOS 6.1.3 does not export those two symbols at all (measured against
// dyld_shared_cache_armv7's own LC_SYMTAB for CoreFoundation: only the public, single-underscore
// kCFBooleanTrue/kCFBooleanFalse pointer variables are there), so an app compiled this way cannot
// launch without them - the two addresses have to exist, not merely resolve to a plausible value.

// The release's own private singletons were read directly (through the same cache): the
// kCFBooleanTrue/kCFBooleanFalse pointer variables at 0x3950313c/0x39503140 point at two structs
// 8 bytes apart, byte-for-byte identical - a bare CFRuntimeBase (isa 0, info 0x00000080) with no
// value field at all. `CFBooleanGetValue` (0x310b0378 in that same image) does not read a value
// out of the object; disassembled, its whole answer is `return cf == <the release's own kCFBooleanTrue
// address>;` - true and false are told apart purely by which of the two fixed addresses was passed,
// nothing in the object's own bytes says which is which. That confirms what distinguishes them, and
// it rules out copying the release's bytes into an object at a different address and expecting
// CFBooleanGetValue to recognise it - see facts/Foundation/CFBooleanConstants.md.

// What is carried instead is a genuine CF object of its own: `_CFRuntimeRegisterClass` and
// `_CFRuntimeCreateInstance` are exported by this same release (confirmed through the same cache
// read) and are the ordinary, documented way any CF type is minted, so nothing about the object's
// shape is guessed. `_CFGetTypeID`, disassembled the same way, decodes a legacy (isa == 0) object's
// type straight out of its own info bits - no address comparison - so the type these two instances
// report is self-consistent and genuinely theirs, not a borrowed or colliding one. CFEqual has no
// custom equal registered, so it falls back to pointer identity, which is exactly correct for a
// type with exactly two possible values. Both instances are retained once, here, and never released,
// so CFRetain/CFRelease from a caller only rebalance a real refcount that never reaches the release
// that would free them.

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
} CharonCFRuntimeClass;

extern CFTypeID _CFRuntimeRegisterClass(const CharonCFRuntimeClass *const cls);
extern CFTypeRef _CFRuntimeCreateInstance(CFAllocatorRef allocator, CFTypeID typeID, CFIndex extraBytes, unsigned char *category);

__attribute__((visibility("default"))) const void *__kCFBooleanTrue;
__attribute__((visibility("default"))) const void *__kCFBooleanFalse;

__attribute__((constructor)) static void charon_cfboolean_constants(void)
{
    static const CharonCFRuntimeClass booleanClass = {
        .version = 0,
        .className = "CharonCFBoolean",
    };
    CFTypeID typeID = _CFRuntimeRegisterClass(&booleanClass);
    __kCFBooleanTrue = (const void *)CFRetain(_CFRuntimeCreateInstance(NULL, typeID, 0, NULL));
    __kCFBooleanFalse = (const void *)CFRetain(_CFRuntimeCreateInstance(NULL, typeID, 0, NULL));
}
