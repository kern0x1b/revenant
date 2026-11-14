#pragma once

#include <objc/objc.h>
#include <stdint.h>

extern volatile int xl_proxy_classes_active;

uintptr_t xl_proxy_in(uintptr_t guest);
uint64_t xl_proxy_out(uintptr_t host);
void xl_proxy_note_class(uintptr_t guest_class);

Class xl_proxy_shadow_of(uintptr_t guest_class);
void xl_proxy_guest_retain(uintptr_t guest);
void xl_proxy_guest_release(uintptr_t guest);

static inline uint64_t xl_self_out(void *self)
{
    if (__builtin_expect(xl_proxy_classes_active, 0)) {
        uint64_t guest = xl_proxy_out((uintptr_t)self);
        if (guest)
            return guest;
    }
    return (uint64_t)(uintptr_t)self;
}
