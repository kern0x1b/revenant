#pragma once

#include <objc/objc.h>
#include <stddef.h>

extern unsigned long __stack_chk_guard;
void __stack_chk_fail(void) __attribute__((noreturn));

id objc_retain(id value);
void objc_release(id value);
id objc_autorelease(id value);
id objc_retainAutorelease(id value);
id objc_retainAutoreleasedReturnValue(id value);
id objc_autoreleaseReturnValue(id value);
id objc_retainAutoreleaseReturnValue(id value);
id objc_unsafeClaimAutoreleasedReturnValue(id value);
id objc_claimAutoreleasedReturnValue(id value);
id objc_retainBlock(id value);
void objc_storeStrong(id *location, id value);
id objc_initWeak(id *location, id value);
id objc_storeWeak(id *location, id value);
void objc_destroyWeak(id *location);
id objc_loadWeakRetained(id *location);
id objc_loadWeak(id *location);
void objc_copyWeak(id *to, id *from);
void objc_moveWeak(id *to, id *from);
void *objc_autoreleasePoolPush(void);
void objc_autoreleasePoolPop(void *context);
id objc_alloc(Class cls);
id objc_alloc_init(Class cls);
id objc_opt_new(Class cls);
Class objc_opt_class(id object);
BOOL objc_opt_isKindOfClass(id object, Class cls);
BOOL objc_opt_respondsToSelector(id object, SEL selector);
id objc_opt_self(id object);
void objc_setProperty_nonatomic(id self, SEL _cmd, id value, ptrdiff_t offset);
void objc_setProperty_nonatomic_copy(id self, SEL _cmd, id value, ptrdiff_t offset);
void objc_setProperty_atomic(id self, SEL _cmd, id value, ptrdiff_t offset);
void objc_setProperty_atomic_copy(id self, SEL _cmd, id value, ptrdiff_t offset);
id objc_getProperty(id self, SEL _cmd, ptrdiff_t offset, BOOL atomic);
void objc_setProperty(id self, SEL _cmd, ptrdiff_t offset, id value, BOOL atomic, signed char copy);
void objc_copyStruct(void *dest, const void *src, ptrdiff_t size, BOOL atomic, BOOL hasStrong);
void objc_enumerationMutation(id object);

// C++ ABI: registers a static/global destructor during load-time initialization. Not in
// the SDK headers, so declared here for the manual bridge (the guest destructor is guest
// code and must be invoked via the runtime, not called by the host C++ runtime).
int __cxa_atexit(void (*func)(void *), void *arg, void *dso);

// C++ ABI operator new/delete (and array forms). Declared with the C names that mangle to
// the imported symbols (_Znwm etc.), bridged to the host allocator so any translated C++
// code (e.g. an app that statically links a C++ library) can allocate and free.
void *_Znwm(unsigned long size);
void *_Znam(unsigned long size);
void _ZdlPv(void *ptr);
void _ZdaPv(void *ptr);

// The Swift runtime registers the classes it lays out itself through these, which the SDK headers do not declare (it
// declares _objc_realizeClassFromSwift and objc_setHook_lazyClassNamer). iOS 6 libobjc has none of the three; the
// bridge provides them (runtime/swift_classes.m).
Class objc_readClassPair(Class cls, const void *info);
