#include <objc/message.h>
#include <objc/runtime.h>

/* The Objective-C runtime is not part of libSystem; the image that pulls this shim in links it. */
__asm__(".linker_option \"-lobjc\"");

/* objc4-551 (iOS 7): allocate as +allocWithZone: does, with a nil class answering nil. Swift calls it for a class that
   inherits from NSObject. */
__attribute__((visibility("hidden")))
id objc_allocWithZone(Class kind)
{
    if (!kind)
        return nil;
    return ((id (*)(Class, SEL, void *))objc_msgSend)(kind, sel_registerName("allocWithZone:"), NULL);
}
