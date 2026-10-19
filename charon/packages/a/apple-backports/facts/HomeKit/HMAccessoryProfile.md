# HMAccessoryProfile and HMCameraProfile

Two classes of **10.0**, in `HMAccessoryProfile10_0.m`: what an accessory publishes about itself, and the
profile of its camera.

## What the header declares, and what the port answers

`HMAccessoryProfile.h:19-20` marks the class
`API_AVAILABLE(ios(10.0), watchos(3.0), tvos(10.0), macCatalyst(14.0)) API_UNAVAILABLE(macos)`, and
declares three properties, **none of them nullable**:

| member | line | type | attributes |
|---|---|---|---|
| `uniqueIdentifier` | 27 | `NSUUID * _Nonnull` | readonly, copy, nonatomic |
| `services` | 32 | `NSArray<HMService *> * _Nonnull` | readonly, nonatomic |
| `accessory` | 37 | `HMAccessory * _Nullable` | readonly, nonatomic, **weak** |

`HMCameraProfile.h:25-26` subclasses it and adds four, **all nullable** — `streamControl` (33),
`snapshotControl` (38), `settingsControl` (43), `speakerControl` (48), each
`readonly, nonatomic, strong`. The difference in nullability between the two sets is the properties' own:
a profile always has an identity, a service list and an accessory-or-nil, while a camera publishes the
controls it has and says of the rest by answering nil.

The four controls are answered nil, and that is the answer rather than a stand-in: this library carries no
camera control class, and nil is what the header's own nullability allows an accessory that has published
nothing to say.

## How these rows are checked, and what each check is worth

**`tests/backports/host/homekit/ast_check.py` — the contract, and it runs.** It compiles the port's source
for `arm64-apple-ios12.0` against the 26.2 SDK and reads clang's AST. One dump carries both sides: the
header's declarations arrive through the port's own import and are tagged with the SDK file they came from,
and the port's are not. For every member above it compares the **type including nullability** and the
**attributes**, and each comparison prints the header line it came from. A hand-written accessor counts as
the port declaring the member, because this library writes its accessors out rather than redeclaring the
properties — requiring a property redeclaration would fail a correct port and teach the check nothing.

It carries a **control**: a scratch copy of the port's file with `streamControl`'s `nonatomic` changed to
`atomic` must be caught, and the run names what it caught. A check that cannot fail is not a check, so a
control that is *not* caught fails the run.

**`tests/backports/host/homekit/oracle.py` — structural, and weaker than it looks.** It counts selector
names in the 12.0 and 16.0 arm64 caches with a boundary after the name, and counts a positive control
(`HMAccessory`, which the held caches are measured to carry: 1259 at 12.0, 383 at 16.0) and a negative one
(a name this port invents: 0 in both). A wrong control fails the run.

Those counts are **global, not per class**: a cache holds one copy of a selector name, shared by every
class that uses it, so a count says the release spells the name, **not** that the class a row names has it,
and a short name like `home` is also a token inside many other identifiers. Answering per class needs the
release's own method list, which is the runtime half.

## What is not checked here, and the standing limit

The **runtime half** — whether the library answers what the header declares — is not checked by any of this,
and there is no way to check it on this machine: no `HomeKit.framework` exists in any macOS SDK, and the
SDK's own HomeKit types are marked `API_UNAVAILABLE(macos)`, so nothing of the model compiles for this host
at all. `xcrun simctl list runtimes` is empty, so there is no simulator either. The native fix is the
armv7 emulator, which is a heavy job to run when a slot is free; the registry rows' `source` and
`coordination/crutches.md` both say so. The crutch names it as the native fix.

## The `-init` and `+new` of thirty HomeKit classes, read out of a real release's own metadata

This host has no HomeKit binary at all - `/System/Library/Frameworks/HomeKit.framework` holds only a
`PlugIns` directory and there is no simulator - so the oracle for HomeKit is the release's own metadata,
read with the repository's own `tools/corpus/objc-inventory.lua` over the **arm64e cache of iOS 16.0**,
which is the newest held cache that still exports HomeKit's public classes (`_OBJC_CLASS_$_HMHome` is in
it; the cache of 18.0 exports none of them). It is a real release's own class list, which answers the
corpus row's question - is the selector in the class's own method list - and not the other one, what a
caller reaches at run time.

Thirty of this package's classes carry such a row today, and the cache splits them twenty and ten.

| what iOS 16.0's own class carries | classes | what the port does |
| --- | --- | --- |
| neither selector | 20 | carries neither; NSObject's pair answers, which is what the framework's own class answers |
| `-init` only | 10 | **undecided** - see below |

The ten are `HMAccessControl`, `HMAction`, `HMActionSet`, `HMHome`, `HMHomeManager`, `HMRoom`,
`HMServiceGroup`, `HMTimerTrigger`, `HMUser` and `HMZone`. Their ten rows stay `missing` and the decision
is not this page's: the measurement says Apple's class implements `-init` and says nothing about what it
returns, and there is nothing on this machine that can say more - no host framework, no simulator, and a
dyld cache carries method lists rather than answers. What the table
(`tests/backports/host/unavailable-init/expectations.tsv`) can hold for such a class is already there: an
`oracle` column naming where the answer came from, and `port-init`/`port-new` read off `own-init` and
`own-new`. When the answer is known, a row is one line.

**Two of the twenty were not true when this was measured**, and both are fixed:
`HMCharacteristicWriteAction` defined an `-init` that only forwarded to NSObject's, and `HMEvent` defined
one that invented a fresh UUID for the event - a value no framework produces, since an event's
identifier is the framework's and one made through `-init` has none. Nothing in the tree called either, and
neither definition matches Apple's class; both are gone, and their rows say why.

The rule the port follows, from the coordinator's answer of 2026-10-03: where Apple's own class carries a
selector the port carries it with the measured body; where Apple's own class does not, the port does not
either, because a definition would change what the class is and answer the caller exactly what NSObject's
already answers.

## The ten `-init` IMPs are out of the cache, and what the first of them does

The ten rows above are decided by the code, not by the header, and the code is in the cache.
`apple.objc.method_imps` (added for this, commit b9089f454, held by the coordinator until the commit that
uses it lands) reads, in one pass over the arm64e cache of iOS 16.0, every method the ten classes define
themselves with the address and 512 bytes at it: 1060 methods over the ten classes, written to
`charon/.agent-work/worktrees/v-health/.agent-work/runs/cachewalk/hk-init-imp.out`. The addresses are the
cache's own UNSLID addresses, so a page-relative `adrp` inside a body resolves the same way whatever the
slide. A pass costs minutes - 157s measured on the cache of iOS 18.0, 525s on 16.0 - which is why the
reader takes the whole set of names at once.

**How to read those bytes.** A wrapper Mach-O is not needed and does not work: a hand-built one is called
malformed by llvm-objdump (measured, `offset field plus size field of section 0 in LC_SEGMENT_64 extends
past the end of the file`). What works is assembling them into an object file with clang and running
llvm-objdump over that. The first body read that way: **`-[HMZone init]` calls one function and returns
nil** - not a raise, and not a constructed object. Which function it calls is the next measurement, and
the answer for the row follows from it: a nil-returning `-init` is a third shape, neither the SensorKit
raise nor the HealthKit raise nor the NSObject forward, and the port has to match whichever it is.

Three traps in the reader, measured here and not to be paid for twice:

1. this tree's lua does not parse the `%` operator and has no `pcall` and no `os.args`; use
   `string.format` and `function main(arg, ...)`;
2. `method_list(read, address, names)` takes a collection and indexes it, while `method_entries(read,
   address, each)` is the one that yields `(name, imp)`; passing a function to the first is
   `attempt to index a function value (local 'names')`;
3. `method_entries` is a file-local defined near the end of `objc.lua`, so a function that uses it has to
   be defined after it.

## What the ten `-init` bodies do, read out of the code

Every one of the ten is decided below by its own body, out of the arm64e cache of iOS 16.0, read with
`tools/objc-method-imps.lua` (the driver for `apple.objc.method_imps`, which is the reader the bytes came
from). What a body names is resolved three ways, and which way it is is visible in what follows: a branch
into another image goes through a 12-byte stub the cache keeps between the images (`adrp x16, page; add
x16, x16, offset; br x16`), a branch inside HomeKit goes through a 24-byte thunk that loads the address
from a slot and signs the branch (`adrp x1, page; ldr x1, [x1, offset]; adrp x17, page; add x17, x17,
offset; ldr x16, [x17]; braa x16, x17`) whose second load carries the selector of the message it sends,
and a literal is an `adrp` page plus an `add`, read at the sum.

Three shapes, and no fourth:

| class | what the body does | the answer |
| --- | --- | --- |
| HMActionSet, HMHome, HMRoom, HMServiceGroup, HMTimerTrigger, HMZone | `bl` the stub for `_objc_release` with the receiver in `x0`, then `mov x0, #0` | nil |
| HMAccessControl, HMUser | build an exception and hand it to `_objc_exception_throw` | raises |
| HMAction | `[self initWithUUID:[NSUUID UUID]]` | an action with a fresh identifier |
| HMHomeManager | `[self initWithHomeMangerConfiguration:[HMHomeManagerConfiguration defaultConfiguration]]` | a manager with the default configuration |

**The six that answer nil.** Every one of the six bodies is the same seven instructions, at its own
address, and the one call resolves to `_objc_release`:

```
-[HMZone init] at 0x19d0a3e1c          ; the other five are the same shape at their own addresses
    pacibsp
    stp  x29, x30, [sp, #-0x10]!
    mov  x29, sp
    bl   0x1a0dd7ea0  -> _objc_release        ; [self release]
    mov  x0, #0x0                            ; return nil
    ldp  x29, x30, [sp], #0x10
    retab
```

So `-init` here is `[self release]; return nil;` and not a raise and not a constructed object. The port
answers nil; the release of the receiver has no ARC equivalent and the port does not perform one, which
is stated rather than approximated - what a caller reaches is what was measured.

**The two that raise.** The two bodies are the same, and every value in them is named:

```
-[HMAccessControl init] at 0x19d0dcc84      ; -[HMUser init] at 0x19d0aef98 is the same shape
    mov  x0, x1                             ; the selector
    adrp/ldr  x19                           ; _OBJC_CLASS_$_NSException
    adrp/ldr/ldr x20                        ; -> a __cfstring of NSInternalInconsistencyException
    adrp/ldr  x21                           ; _OBJC_CLASS_$_NSString
    bl  0x1a0dd7850  -> _NSStringFromSelector
    bl  0x1a0dd7d70  -> _objc_claimAutoreleasedReturnValue      ; the selector's name
    adrp x2, ... ; add x2, x2, #0x458       ; literal at 0x1dff71458: "%@ is unavailable"
    mov  x0, x21 ; bl 0x19d2024c0           ; +[NSString stringWithFormat:] with the selector's name
    bl  0x1a0dd7d70  -> _objc_claimAutoreleasedReturnValue
    mov  x0, x19 ; mov x2, x20 ; mov x3, x21 ; mov x4, #0x0
    bl  0x19d1ee300                         ; +[NSException exceptionWithName:reason:userInfo:]
    bl  0x1a0dd7d70 ; bl 0x1a0dd7d20         ; claim, then autorelease
    mov  x19, x0
    bl  0x1a0dd7ef0 ; bl 0x1a0dd7f00         ; release the two temporaries
    mov  x0, x19 ; bl 0x1a0dd7de0           ; _objc_exception_throw
    mov  w0, #0x1 ; ret                     ; unreachable after a throw
```

The reason is Apple's own sentence for the selector, `"init is unavailable"`, built from the literal
`"%@ is unavailable"` and the name of `_cmd`: the literal is a `__cfstring` at 0x1dff71458 of HomeKit's
`__AUTH_CONST` whose own length field is 17, which is exactly the length of the sentence, and the two
selectors are read out of HomeKit's own selector table (`stringWithFormat:` at 0x1d60c25d0,
`exceptionWithName:reason:userInfo:` at 0x1d60bbcd8). The name is `NSInternalInconsistencyException`, a
`__cfstring` of CoreFoundation at 0x1de2bc558 reached through two hops, and `userInfo` is nil.

**The two that construct.** `-[HMAction init]` reads the class `NSUUID` out of HomeKit's own data
(0x1dcee7a28), sends it `UUID` (selector at 0x1d60b8928) and sends itself `initWithUUID:` (selector at
0x1d60bde58) - an action with an identifier nobody supplied, which is what a fresh action has.
`-[HMHomeManager init]` sends `defaultConfiguration` (selector at 0x1d60bb720) to
`HMHomeManagerConfiguration` (0x1dd13cac0) and sends itself `initWithHomeMangerConfiguration:` (selector
at 0x1d60bd6e0, Apple's own spelling of that word). Both construct; neither raises; the port's own
construction for each is the measured shape.

**What the cache does not answer, stated.** A method body that calls a static helper of its own image
cannot be named: the arm64e cache of iOS 16.0 carries no local symbol table, so an address inside
HomeKit's text that no export names is anonymous, and the two thunks the raising bodies go through are of
that kind. It does not matter for any of the ten decisions, because in every body the value that decides
the answer is reached through something the cache does name: the selector of the message, the class, the
literal and the runtime entry point are all read out of it, and what the anonymous helper receives is the
argument one of them produced.

Three more traps in the reading, measured here the hard way and not to be paid for twice:

4. `tonumber("c")` is nil in this tree's lua and `tonumber("0xc")` is 12, so a filter that reads an
   instruction's offset without the prefix does not drop one line: it drops every instruction whose
   offset is spelled with letters only, and the listing still looks whole while every address after one
   of them belongs to the wrong instruction. Measured: `-[HMZone init]` read as a body that calls
   nothing, because its one call sat at offset `c`.
5. a Lua binary operator keeps only the first value of its right-hand side, so `rest and rest:match(p, q)`
   reads one capture of two and the second is nil. Measured: a stub's `add` never matched, so no stub was
   ever followed.
6. `io.readfile` hands back the file as one string here, not as lines, and `io.writefile(path, format,
   argument)` writes the format and drops the argument - it does not format. Measured: the assembled
   source was the three characters `%s`.
