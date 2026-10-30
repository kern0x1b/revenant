# The os_log fallback: what a message prints

An app calls `os_log` through the os overlay. When the Backports logging runtime is loaded, the overlay hands the message to it; when it is not, the overlay renders the message itself and sends the text to ASL. Both paths print the same text, because both render with one file. This page says where each rule comes from, and which rules are ours.

## Where the code is

- `toolchain/src/swift-runtime/overlay/os/os.swift`: the overlay. Its `OSLog` holds a handle only when `revenant_os_log_linked()` is non-zero, and the fallback is used otherwise.
- `toolchain/src/swift-runtime/overlay/os/RevenantOSOverlayShims.h`: `revenant_os_log_fallback`, which renders the message and passes the text to `asl_log`.
- `toolchain/src/swift-runtime/overlay/os/RevenantOSLogRender.h`: the renderer. The Backports runtime includes the same header through `frameworks/Backports/src/Foundation/RevenantOSLogFormat.m`.
- `frameworks/Backports/src/Foundation/OSLog9.m` takes the va_list path (`revenant_os_log_send`). `OSLog10.m`, `OSLog11.m` and `OSLog13.m` take the buffer path (`revenant_os_log_buffer`).

## The buffer layout

The compiler's `os_log` builtin packs the arguments into one buffer. Its layout is the one Apple's open-source Swift `os` code defines in `stdlib/private/OSLog/OSLogMessage.swift` in swiftlang/swift: a summary byte, an argument count byte, then for each argument a header byte, a size byte and the argument's bytes. The high four bits of the header are the argument type and the low four are the privacy flag. The flags are in `stdlib/private/OSLog/OSLogPrivacy.swift` (`argumentFlag`): private 0x1, public 0x2, and auto 0.

The types that file names are scalar 0, count 1, string 2, pointer 3, object 4 and mask 7. It does not name 5 or 6. The path `stdlib/public/Darwin/os/` that the layout was first looked for under does not exist on swiftlang/swift main; the sources are under `stdlib/private/OSLog/`.

## What is private by default

A specifier with no privacy flag (auto) takes the default of the renderer. The ABI leaves auto to the system, and the Swift sources do not say which way the system decides. The renderer's rule is:

- strings, objects and `%P` data are private;
- numbers, counts and pointers are public.

An explicit flag always wins: `%{public}` prints the value, and `%{private}`, `%{sensitive}` and mask values print as `<private>`. A private argument is still consumed from the va_list, so the next specifier reads the next argument. The Backports code once treated an unannotated string that lay in a read-only segment as public, and printed it in full; that exception is not in the sources and is gone.

## Behaviour the sources do not settle

The Swift sources do not say what an object without a description prints, or what happens when `description` raises. Both keep their earlier behaviour: an object without a description prints `(null)`, and an exception from `description` is caught in an Objective-C build. The C build has no exceptions to catch.

## Limits

Width and precision are capped at 128, for digits and for `*` arguments alike, so a format from an app cannot make the padding grow without bound. The whole message is capped at 8192 bytes. The format is parsed here and never passed to `printf`.

## What is verified

`toolchain/tests/addon/os_log_fallback_test.lua` (`toolchain_light/os_log_fallback_test`) checks the link and level behaviour of the fallback, and renders 52 cases through the renderer: the va_list cases, the buffer cases and the caps. It also compiles the shims as C++ (`-x c++`, macOS SDK). Swift's C++ interop builds `_SwiftRevenantOSOverlayShims` as C++ when `-cxx-interoperability-mode=default` is set, and C accepts the implicit `void *` conversions that C++ rejects, so the renderer casts them explicitly. The expected texts are the renderer's rules above. They have not been compared with macOS `os_log` output, so they are provisional until a run of `os_log` on macOS with the same formats agrees with them.
