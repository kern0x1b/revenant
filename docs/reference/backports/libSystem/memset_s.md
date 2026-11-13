# memset_s on iOS 6

`memset_s(void *s, rsize_t smax, int c, rsize_t n)` is C11 Annex K, which Apple's libSystem gained in iOS 7. The iOS 6.1.3 shared cache exports it neither from libSystem.B nor from libsystem_c (measured with `nm` on the images taken out of the cache). Code built against a newer SDK imports it, and so does the reCAPTCHA Enterprise SDK, as a weak import with no guard.

`libSystemBackports.dylib` exports `_memset_s` as `BACKPORT_IMPL(memset_s)` in `frameworks/Backports/src/libSystem/RevenantMemsetS.c`. The body is `revenant_memset_s` of the shared `apple-compat` library (`toolchain/src/apple-compat/src/memset_s.c`), the one the toolchain's own `memset_s` redirection calls, so there is one implementation. Where the release has the function (iOS 7 and later) the generated trampoline calls the release's.

The answers are Apple's: a NULL destination is `EINVAL`, a capacity above `RSIZE_MAX` is `E2BIG` and writes nothing, a count above `RSIZE_MAX` is `E2BIG` and fills the capacity, a count above the capacity is `EOVERFLOW` and fills the capacity, and a call that returns 0 has written every byte. The call is an exported function, so no caller's optimiser can remove it as a dead store, which is what the function exists for.

## Scope: who is affected

Every process that loads `libSystemBackports.dylib` on a release before iOS 7: applications built with the Revenant toolchain that link the backports, and prebuilt images named in `revenant.rebind` (the import moves from libSystem to the library, because libSystem does not export it). A stock iOS 6 application does not load the library and keeps no `memset_s`, as before. On iOS 7 and later nothing is replaced.

## Cost

No memory beyond the library's own page. The first call resolves the release's symbol with `dlsym` and keeps it in a slot; each call is then one indirect jump to the function, which checks its arguments and calls `memset`. Not timed apart from `memset`.

## Tests

`frameworks/Backports/tests/libsystem_dispatch/main.c`, built by `libsystem_dispatch_test.lua` on the host: seven argument shapes (a count inside, at and above the capacity, a count above `RSIZE_MAX`, a capacity above `RSIZE_MAX`, a NULL destination, zero capacity and count), each compared on both the return value and every byte of a 24-byte buffer with the macOS libSystem's `memset_s` found with `dlsym`, and with the values written in the table. The same fixture runs on the iPhone 4S through `libsystem_dispatch_device_test.lua`, where there is no system function to compare with and the table decides: all seven shapes passed on the iPhone 4S with iOS 6.1.3. The toolchain's own test of `revenant_memset_s` against Darwin's is `toolchain/tests/addon/compat/calls.c`.
