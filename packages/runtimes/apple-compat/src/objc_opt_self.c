#include <objc/message.h>
#include <objc/runtime.h>

__asm__(".linker_option \"-lobjc\"");

__attribute__((visibility("hidden")))
id objc_opt_self(id object)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName("self"));
}
