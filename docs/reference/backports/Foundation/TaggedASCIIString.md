# The tagged ASCII string factory on iOS 6

The Swift runtime bridges a short ASCII `String` to Objective-C through a private class method of `NSString`,
`+newTaggedNSStringWithASCIIBytes_:length_:`. It is not public API: no SDK header declares it and no availability is published.
It is the factory of the tagged-pointer `NSString` that the Foundation of the systems this runtime was written for creates for
a short ASCII string; the iOS 6.1.3 release has no such factory (measured on the iPhone 4S by `host_bare`, below), and a 32-bit
process of that release has no tagged `NSString` to make. The Swift source this runtime is built from does not guard the call
by a system version: it sends the message unconditionally and treats nil as "cannot form a tagged pointer". A Swift library
translated for iOS 6 (the recompiler's guest `libswiftCore`) sends it whenever it hands a string of up to 15 ASCII bytes to code
that wants an `NSString`, so a library that does that stopped at its first short string with
`+[XLG._TtCs15__StringStorage newTaggedNSStringWithASCIIBytes_:length_:]: unrecognized selector sent to class` (the shadow class
of `__StringStorage` in the library's registry), after the runtime's own note `xlate: no bridge for ...`. That note names a
selector that has no typed bridge and is printed with `XL_LOG=1` also when the category answers, so it does not mean a failure. The first release
of Apple's Foundation that has the factory was not measured, and this page does not state one.

## What the runtime does with the answer

The caller is `String._bridgeToObjectiveCImpl` (`stdlib/public/core/StringBridge.swift`, `_createCFString`): for a small
string that is ASCII it sends the message to the class `__StringStorage`, an `NSString` subclass of the standard library, with a
pointer to the bytes on its own stack and the length, and it tests the result. The same code is in the guest `libswiftCore`
(the disassembly of the arm64 image shows the flag tests before the message and `_allocateStringStorage` after a nil). A non-nil
object is the bridged string; a nil goes on to `__StringStorage.create(initializingFrom:...)`, whose comment reads "we can't form
a tagged pointer String, so make a non-small String, and bridge that instead". That heap storage is the path every string of
16 bytes and more takes, and the libgenerics steps run it on the iPhone 4S.

## What the library does

`src/Foundation/NSString+TaggedASCII.m` adds the class method as a category of `NSString` and returns nil for every input.
`attach.c` adds it with `class_addMethod` when `libFoundationBackports.dylib` loads, and only where `NSString` has no such
selector, so a release that has it keeps its own. Nil is the answer of the real method too whenever the bytes cannot be tagged;
a 32-bit process has no tagged pointers at all, so no input can be, and nothing needs the bytes.

## Reachability

The method exists in a process only after `libFoundationBackports.dylib` has loaded (see the reachability section of
[NSData base64](NSData-base64.md)): a process that links no Backports library, such as a test host built against the plain SDK,
does not have it, and a Swift library that bridges a short string there stops as above. `recompiler/tests/libgenerics/check.lua`
runs `stepShortString` on two hosts for that reason: `host` has the category compiled in and must report `ok short.string`, and
`host_bare` has not and must not run to its end.

## Tests

`frameworks/Backports/tests/Foundation/tagged_ascii_test.m` runs on the host with the category compiled in, which replaces the
system's method of macOS and so exercises the library's answer: the selector is a class method of `NSString`, five lengths from 0
to 20 bytes return nil, and a subclass that Swift would allocate for its storage inherits the answer. With `--negative` the
expectations flip and the run must fail. `stepShortString` of the libgenerics fixture bridges `"abc"` to an `NSString` in a
translated library and reads its length and a character through Objective-C messages.
