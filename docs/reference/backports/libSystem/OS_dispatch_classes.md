# OS_dispatch_queue and OS_dispatch_source on iOS 6

On iOS 6 `dispatch_queue_t` and `dispatch_source_t` are Objective-C objects. The 6.1.3 libdispatch registers fifteen classes (`OS_object`, `OS_dispatch_object`, `OS_dispatch_queue`, `OS_dispatch_source`, `OS_dispatch_group`, `OS_dispatch_semaphore`, `OS_dispatch_data` and others, `__objc_classlist` of the image taken out of the shared cache, each with a `+load`). Only `_OBJC_CLASS_$_OS_object` and its metaclass are exported. The others are local symbols, so an image that binds `_OBJC_CLASS_$_OS_dispatch_queue` or `_OBJC_CLASS_$_OS_dispatch_source` gets NULL for a weak import and a refusal for a strong one. Code reaches those symbols from Swift, and from Objective-C compiled with `OS_OBJECT_SWIFT3`; the SDK header otherwise declares the queue as a protocol and looks the class up by name at run time, which needs no symbol. The reCAPTCHA Enterprise SDK imports both symbols weakly.

`libSystemBackports.dylib` exports both symbols (`src/libSystem/RevenantDispatchClasses.m`, `REVENANT_ALIAS` of `revenant_alias.h`): `_OBJC_CLASS_$_OS_dispatch_queue` is an alias of the library's proxy `RevenantOS_dispatch_queue`, and the same for the source. The mechanism is the one every backported class uses (`docs/explanation/backports-loading.md`): the proxy's `+class`, `+alloc`, `+superclass` and the related class methods answer for the system's class, which `objc_getClass` finds, and `attach.c` puts the proxy under it at load. The proxy registers a class of the public name only when the system has none, and the system has both.

## Scope: who is affected

Every process that loads the library on any release: a native application that links the backports before libSystem, and a prebuilt image named in `revenant.rebind`. On iOS 7 and later the proxy still answers for the system's class, so the answers do not depend on the release.

## Limits

- The bound symbol is the proxy, not the system's class. `[bound class]`, `+alloc`, `+superclass`, `+isSubclassOfClass:` and `+description` answer for the system's class, so `[object isKindOfClass:[OS_dispatch_queue class]]` is true for a queue. A test that hands the symbol's own address to `isKindOfClass:` without the `class` message asks about the proxy, which sits under the system's class, and answers NO. This is true of every class that Backports aliases (`revenant_alias.h`).
- The proxy can sit under the system's class only if the two have one instance size, because `attach.c` refuses otherwise and logs it. Measured on the iPhone 4S: `OS_dispatch_queue` and `OS_dispatch_source` have an instance size of 4 bytes (the `isa`), as does the proxy, so both are reparented (the fixture checks that the proxy's superclass is the system's class) and nothing is logged. The fixture prints the two sizes as `INFO` lines and does not assert them.

## Device result

On the iPhone 4S with iOS 6.1.3 (`libsystem_dispatch_device_test.lua`, the fixture linked against the built library): 20 checks passed, the class checks for both classes, the cross checks, the superclass, and the retain and release count: an object retain and release, `dispatch_retain` and `dispatch_release` on one queue leave the queue alive, and the last release runs the finalizer once.

## Cost

Two classes, registered by the library's load: the proxies' metadata and the aliased method lists, a few kilobytes. No per-object cost: queues and sources are the system's.

## Tests

`frameworks/Backports/tests/libsystem_dispatch/classes.m`, run on the iPhone 4S by `libsystem_dispatch_device_test.lua`, linked against the built library so that the two class symbols bind to it: the system registers both classes, the bound symbol is the proxy and its `class` message answers the system's class, the class answers its own name, a queue and a source are kinds of their classes and not of each other's, the proxy's superclass is the system's class, and one retain and release count is shared by the object calls and the C calls and ends in one finalizer call. There is no host run: the macOS libdispatch exports the classes itself.
