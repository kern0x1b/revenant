#include <objc/message.h>
#include <objc/runtime.h>

/* The Objective-C runtime is not part of libSystem; the image that pulls this shim in links it. */
__asm__(".linker_option \"-lobjc\"");

/* objc4-723 (iOS 11, macOS 10.13) added objc_opt_self as the fast path of -self: it answers the object itself unless the
   class overrides the method, and for a class object it realizes the class on the way. No 32-bit release ever had it, since
   iOS 10.3.4 is the last one for armv7. Here it is the message it stands in for, which realizes the class as well. Swift
   emits the call for a class whose metadata is fixed. */
__attribute__((visibility("hidden")))
id objc_opt_self(id object)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName("self"));
}
