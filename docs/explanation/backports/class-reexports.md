# Class re-exports: what an old image binds, and the export baseline

An app or a library that was linked against a Backports build binds the classes it uses by name, and the binding names the
Backports library that held the class when it was linked: the linker takes a symbol from the first library on its command
line that exports it, and the Backports libraries come before the system ones. When a later Backports build stops
exporting such a class, the old image no longer loads. dyld stops the launch before any code runs:

    dyld: Symbol not found: _OBJC_CLASS_$_AVSampleBufferDisplayLayer
      Referenced from: .../TelegramUIFramework
      Expected in: /usr/lib/revenant/org.revenant.backports/libAVFoundationBackports.dylib

That is what happened to Telegram13 on the iPhone 4S on 2026-11-21, when `AVSampleBufferDisplayLayer` became a category on the
system class and the library stopped defining it, and to the React Native host (`rnhost`, built on 2026-11-17) on
`_OBJC_CLASS_$_NSAssertionHandler` after the generator, on 2026-11-19, stopped giving a proxy to a class that the device
exports (`docs/explanation/backports/shadowed-classes.md`). Both are the same fault: a class symbol left the export trie of a
library that an installed image still binds to.

## The fix: re-export the system's own class

A library that no longer defines a class re-exports it from the system framework that does. The export trie then holds a
re-export entry (flag `0x08`: the ordinal of the framework and the name to import) instead of a definition, and dyld follows
it to the framework's class when an image binds the symbol to the Backports library. The old image gets the system class,
the same object `objc_getClass` answers, and no second class is registered. `ld64` writes the entry from
`-Wl,-reexported_symbols_list,<file>`; the framework must be linked so that the linker finds the symbol in it (the libraries
that do not already link it add it weakly, as every other framework of a Backports library is linked).

The real dyld of iOS 6.1.3 executes such an entry. Measured in the emulator (2026-11-23): an image bound to
`_OBJC_CLASS_$_AVSampleBufferDisplayLayer` in a library that re-exported it from AVFoundation loaded, the class it bound was
the address `objc_getClass` answered, it was registered once, and `class_getImageName` said
`/System/Library/Frameworks/AVFoundation.framework/AVFoundation`. The same image with a library that did not re-export the
symbol stopped with the message above.

`frameworks/Backports/tools/reexported-classes.txt` lists what each library re-exports, one line per symbol:

    <library> <symbol> <framework>

for example `AVFoundationBackports _OBJC_CLASS_$_AVSampleBufferDisplayLayer AVFoundation` and
`FoundationBackports _OBJC_CLASS_$_NSAssertionHandler Foundation`. Every class and its metaclass are listed. The list was made
from the export baseline below: every class symbol that some earlier build exported and the current one does not, where the
iOS 6.1.3 shared cache shows that the system framework (the library's own, or one it links) exports it. `tools/reexports.lua`
reads the file; `frameworks/Backports/xmake.lua` writes each library's lines to a file named by their content in the target's
generated folder and passes it to the linker, so a changed list relinks the library. The file is an input of the package
`backports` (`frameworks/Backports/tools/**` is in its digest).

The case `tests/runtime/cases/avfoundation_class_reexport.m` runs the fault in the emulator: a probe linked against a
link-time stand-in that has the install name of `libAVFoundationBackports.dylib` and defines the class (the shape of an image
linked against an old build) is loaded against the real new library, and its two bindings must be the system's class and
metaclass, registered once. The negative control flips every expectation and must fail.

## The export baseline

`frameworks/Backports/tests/data/export-baseline.txt` lists, one line per symbol (`<library file> <symbol>`), every public
class and metaclass symbol that a Backports build exported: the union of the installs of the package `backports` in
the store, the Debian packages of the builds that ran on the phone, and the current build. It only grows. `export_baseline_test.lua` reads the export tries of the
libraries of a build, re-exports included, and fails when a symbol of the baseline is gone from the library that had it. A
symbol is gone for good only when it is listed in `frameworks/Backports/tests/data/export-retired.txt`:

    <library file> <symbol> <reason>

A retired line must have a reason, must name a symbol of the baseline, and must not be exported any more (a symbol that
comes back leaves the list). Today it holds four lines: `NSTextList` and `NSTextTab` and their metaclasses in
`libUIKitBackports.dylib`, which iOS 6.1.3 keeps in a private image that exports no symbol, so no re-export reaches them; an
image linked before 2026-11-19 needs a rebuild.

The check is the prepush step `backports exports`, after `backports build`: it reads the libraries of the gate tree. The step
`export baseline test` runs the judge on fixtures without a build. On the build of `e0c5f1b1e` (the main of 2026-11-21, with
neither re-exports nor proxy exports) the check fails on 554 symbols (128 of them in `libFoundationBackports.dylib`), among them `AVSampleBufferDisplayLayer` and its
metaclass and the Foundation classes `rnhost` binds; the four retired symbols are not counted. It would have stopped `avf-native-class`.

Adding a class to the baseline is `./xmakew l -P . frameworks/Backports/tests/export_baseline_test.lua update` on a build that
exports it; the command never removes a line. Removing an export on purpose is a line in `export-retired.txt` with the reason,
reviewed like any other change.

    ./xmakew l -P . frameworks/Backports/tests/export_baseline_test.lua test
    ./xmakew l -P . frameworks/Backports/tests/export_baseline_test.lua check

## What it does not cover

The baseline holds classes and metaclasses only; the functions and constants that an image binds from a Backports library are
not in it. A class that the baseline has never seen is not protected until a build that exports it is added with
`update`. An image whose bindings are to a class that iOS 6.1.3 itself does not export cannot be rescued by a re-export, which
is the retired case.
