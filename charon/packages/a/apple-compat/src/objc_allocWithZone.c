#include <objc/message.h>
#include <objc/runtime.h>

__asm__(".linker_option \"-lobjc\"");

__attribute__((visibility("hidden")))
id objc_allocWithZone(Class kind)
{
    if (!kind)
        return nil;
    return ((id (*)(Class, SEL, void *))objc_msgSend)(kind, sel_registerName("allocWithZone:"), NULL);
}
