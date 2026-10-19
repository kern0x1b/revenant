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
* every one of them is then **called**, with neutral arguments of the type the header declares:
  `nil` for an object, a block, a pointer or a `Class`; `0` for a number, an enumeration or a
  `BOOL`; a zeroed compound literal for a structure; a real error variable for an `NSError **`;
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
| `sh tests/backports/callgen/run-host.sh` | the host's own `Intents.framework` (a macOS framework, in the macOS SDK) | the oracle |
| `sh tests/backports/emulate/calls/run.sh` | `libIntentsBackports` at 6.1.3, through `xmake emulate` | the thing under test |

The same generated file in both, so the two digests are the same measurement of the same
registry and `compare.py` puts them side by side.

A Mac Catalyst run cannot be the oracle for Intents: the Command Line Tools'
`MacOSX.sdk/System/iOSSupport` carries `IntentsUI` and **not** `Intents` (measured 2026-09-27), so
the host run is a macOS binary linked against the system's own Intents — Siri's and Shortcuts'
framework. What it does not carry are the iOS-only classes, and `compare.py` says so rather than
failing.

## Generating

    tests/backports/callgen/gen-calls.py --sdk <iPhoneOS*.sdk> --registry <registry dir>... \
        --out <Calls.m> --manifest <calls.json> [--dump <ast.json>]

`--dump` is the Objective-C AST the argument types are read from; without it the generator writes
it once beside the SDK and reuses it. For another framework, only the `--registry` and the
framework's umbrella change.
