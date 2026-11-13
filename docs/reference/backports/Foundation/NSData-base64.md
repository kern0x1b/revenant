# NSData base64 on iOS 6

iOS 7 added four public members to `NSData`: `base64EncodedStringWithOptions:`, `base64EncodedDataWithOptions:`, `initWithBase64EncodedString:options:` and `initWithBase64EncodedData:options:`. The iOS 6.1.3 shared cache has two older public members on the same class (in CoreFoundation's `NSData` category, read from the Objective-C metadata of the image taken out of the cache): `-base64Encoding` and `-initWithBase64Encoding:`. It has none of the four. A call to one of them on a process that has not loaded the Backports library fails with `-[NSConcreteData base64EncodedStringWithOptions:]: unrecognized selector`, which the reCAPTCHA Enterprise SDK raised on an iPhone 4S in a test host that did not link `libFoundationBackports.dylib`.

## What the library does

`src/Foundation/NSData+Base64.m` adds the four members as a category of `NSData`. `attach.c` adds each with `class_addMethod` when `libFoundationBackports.dylib` loads, and only where the class has no such selector, so a release that has them keeps its own. The members follow the iOS 7 documentation: the encoder takes `NSDataBase64Encoding64CharacterLineLength` or `NSDataBase64Encoding76CharacterLineLength` (both bits, or neither, mean no line breaks) and the line ending bits (carriage return, line feed, both when neither is set); the decoder takes `NSDataBase64DecodingIgnoreUnknownCharacters`; a nil argument raises `NSInvalidArgumentException`.

## Reachability

The members exist in a process only after `libFoundationBackports.dylib` has loaded. In an application built with the Revenant toolchain it always has: the executable and the frameworks of the Telegram 13 build (pass68 and pass69d) carry a strong `LC_LOAD_DYLIB` for it, among them `RecaptchaEnterprise.dylib` itself, so dyld loads it before the SDK runs and the category is attached by the library's constructor. A process that links no Backports library (a test host built against the plain SDK) does not have them, as measured below.

## The release's two members

Measured on the iPhone 4S (iOS 6.1.3) against the macOS answers on 36 lengths and 79 decode inputs (`foundation_base64_device_test.lua`):

- `-base64Encoding` returns what macOS returns for `base64EncodedStringWithOptions:0`, for all 36 lengths from 0 to 4097. It takes no options, so it cannot make line breaks.
- `-initWithBase64Encoding:` is not the strict decoder: it skips characters outside the alphabet (spaces, line breaks, `-`, `_`, `!`, non-ASCII) whatever the caller wants, so it agrees with macOS in strict mode on 46 of 79 inputs and returns data where macOS returns nil. Against `NSDataBase64DecodingIgnoreUnknownCharacters` it agrees on 64 of 79: it differs in how it reads `=` (a lone `=`, `==`, `===` give empty data, `====` gives empty data where macOS gives one zero byte, and data after the padding such as `Zg==Zg==` is nil where macOS decodes it).

The release therefore has a public path for no-option encoding only, which the library's encoder already equals byte for byte. The strict decoder, the line lengths and the line endings have no release path, so the category keeps its own codec for all four members, and uses the release's for none, so that one code path is tested.

## Tests

`frameworks/Backports/tests/foundation_base64_test.lua` runs `tests/foundation_base64/main.m` twice on the host, against the macOS `NSData` and with the category compiled in, and compares 2,629 answers line by line: lengths 0 to 4097 with every combination of line length and line ending bits, as a string and as data, with a round trip; 79 decode inputs (padding in every position, spaces, line breaks, `-`, `_`, non-ASCII, a surrogate pair, the Latin-1 and euro characters) for both decoding options, from a string and from data; nil arguments; mutable data; unknown option bits. No answer differs. `foundation_base64_device_test.lua` runs the same fixture on the iPhone 4S in three forms: the category compiled into the fixture (2,629 equal), the fixture linked against the built `libFoundationBackports.dylib` and loaded from the installed package, so that `attach.c` adds the members (2,629 equal, and all four selectors answer), and the release probe, which finds the four members absent where nothing is linked and present once the library is.
