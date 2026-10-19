# The generated call test

Every class and every member a registry says a framework implements, called.

## Why

`check_registry` in `modules/apple/backports.lua` marks a member built as soon as its **owner
class** is exported, so a class with twelve properties and no accessors at all is green at the
gate. That is what the gate is for; it is not a job for the gate, and a review of the first
Intents group found exactly that class. The generated call test is the other half: it asks the
runtime, and a declaration, a synthesised property and a missing accessor do not all pass what it
asks.

## What it does

* every class the registry carries is looked up **by name** and must exist;
* every selector it carries is asked for with `respondsToSelector:`, which must answer YES;
* every one of them is then **called**, through an `id` return with `nil` for every argument: the
  generator does not read a method's declaration, so a number, a structure or an `NSError **` is
  passed as `nil` too, and a method that returns a structure or a scalar is read as an `id` (this is
  what the generator has always emitted, see "Generating");
* every property is asked for **by the accessor its declaration names** — `INPerson`'s
  `contactSuggestion` is declared `getter=isContactSuggestion`, and asking for the property's
  name is a question no caller asks;
* **each case runs in a forked child**, so a call that takes the process down is one member's
  verdict and the other thousand still run;
* a member that *refuses* the neutral value by raising is recorded as a refusal, not a crash:
  the system's own `+[INAccountTypeResolutionResult confirmationRequiredWithAccountTypeToConfirm:]`
  raises `NSInvalidArgumentException` for a value it will not ask a user to confirm, and calling
  that a crash would report the API's refusal as a defect of the port.

The calls go through `objc_msgSend` and not through the declarations, because a call written
against the header cannot be missing: the header is what declares it.

## The two runs

| run | what it binds | what it is |
|---|---|---|
| `xmake l tests/backports/callgen/run-host.lua [registry-dir]` | the host's own `Intents.framework` (a macOS framework, in the macOS SDK) | the oracle |
| `xmake l tests/backports/emulate/calls/run.lua` | `libIntentsBackports` at 6.1.3, through `xmake emulate` | the thing under test |

The same generated file in both, so the two digests are the same measurement of the same
registry and `xmake l tests/backports/callgen/compare.lua <host.log> <port.log> [--strict]` puts
them side by side. `FRAMEWORK=<name>` picks another registry folder for the host run, `BUILD` and
`OUT` name its folder and digest (default: a fresh folder under `$HOME/.cache/hades/<task>/`).

A Mac Catalyst run cannot be the oracle for Intents: the Command Line Tools'
`MacOSX.sdk/System/iOSSupport` carries `IntentsUI` and **not** `Intents` (measured 2026-09-27), so
the host run is a macOS binary linked against the system's own Intents — Siri's and Shortcuts'
framework. What it does not carry are the iOS-only classes, and `compare.lua` says so rather than
failing.

## Generating

    xmake l tests/backports/callgen/gen-calls.lua --sdk <iPhoneOS*.sdk> --registry <registry dir>... \
        --dump <ast.json> --out <Calls.m> --manifest <calls.json>

or, from Lua, `import("gen-calls", {rootdir = ...}).generate({sdk = ..., registries = {...}, dump = ...,
out = ..., manifest = ...})`. The callers pass `modules/workspace.lua`'s `sdk()`. `--dump` is the
Objective-C AST of the registry's frameworks; when the file is not there the generator writes it
(clang's `-ast-dump=json` of an umbrella that imports each framework) and reads it. What the
generator takes from it is each property's declared getter, setter and `readonly`, from the
`@interface` of a registry class and from a category whose name is a registry class's name. It
matches no method declaration: the generator this was ported from looked a selector up in a set of
labels, so no declaration was ever found, and the port emits the same file.
For another framework, only the `--registry` and the framework's umbrella change.

## The two smaller checks

* `xmake l tests/backports/callgen/ownership-test.lua` - the copy's ownership decision in
  `packages/c/charon-coding/files/CharonCoding.m`, against properties declared the way the SDK's
  headers declare them; the negative control for the guard that matches a property to its ivar.
* `xmake l tests/backports/callgen/collection-test.lua [factory.m]` - the five
  `+successesWithResolved…:` factories on the host's own Intents, then the port's generated factory
  and a mutant of it (`collection-mutant.lua`, one element fewer). The port's factory is the
  generated Intents object that holds them (`tools/intents/objects.lua` writes them into the run
  folder). Its port half does not run on a Mac: the port's object is compiled for armv7 and the
  macOS runner asks for `CharonPortMediaItemResolutionResult`, a class no build defines, so it stops
  at "is not in this build". The port's table is `tests/backports/emulate/calls`'s collection run.
