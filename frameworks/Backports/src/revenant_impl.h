#ifndef REVENANT_IMPL_H
#define REVENANT_IMPL_H

#define BACKPORT_IMPL(name) __revenant_fb_##name

#define BACKPORT_OVERRIDES(name) \
    __attribute__((used, visibility("default"))) const char __revenant_override_##name = 0

#endif
