# `-[X init]` on the sixteen iOS 11.0 Intents classes

What this page is for: `registry/Intents/ios11.json` carries sixteen `-[X init]` rows and this page
is where the measurement behind them is written down, with the command a reader can run and its
output beside it. The sibling page `Intents.md` carries the argument for the whole family of a
hundred and ten; this page carries what was measured for these sixteen, and it does not restate the
other ninety-four, which belong to other slices and are not measured here.

Every one of the sixteen rows is `implemented`, and the status is right for a reason the header does
not give: the SDK marks each of these initialisers

    - (instancetype)init NS_UNAVAILABLE;

which is a compile-time marker. It says a caller must not *name* the selector. It says nothing about
whether the system answers one, and the system answers one on fourteen of the sixteen.

## The port's side: every one of the sixteen has a definition in the 11.0 object

`implemented` needs a definition the band exports, so the first question is whether `IN11_0.m` carries
one. It does, on all sixteen, measured by building the object the way the 11.0 band builds it and
reading the symbols:

```
xcrun clang -target armv7-apple-ios6.0 -isysroot $HOME/Git/tools/sdks/iPhoneOS16.5.sdk \
    -fobjc-arc -w -Wno-deprecated-declarations -I packages/r/revenant-coding/files \
    -c packages/a/apple-backports/Intents/IN11_0.m -o "$OBJ"
xcrun nm "$OBJ"
```

| class | `-init` | `__OBJC_$_INSTANCE_METHODS_X` | `_OBJC_CLASS_$_X` |
|---|---|---|---|
| INAddTasksIntentResponse | `t` 0x00000852 | 0x0000d59c | `S` 0x00010c10 |
| INAppendToNoteIntentResponse | `t` 0x00000e58 | 0x0000d7f8 | `S` 0x00010c60 |
| INBalanceAmount | `t` 0x00001152 | 0x0000d98c | `S` 0x00010c88 |
| INCallRecord | `t` 0x0000183a | 0x0000dbec | `S` 0x00010d00 |
| INCancelRideIntent | `t` 0x000024a4 | 0x0000df14 | `S` 0x00010d50 |
| INCancelRideIntentResponse | `t` 0x0000281a | 0x0000e000 | `S` 0x00010d78 |
| INCreateNoteIntentResponse | `t` 0x00002e96 | 0x0000e284 | `S` 0x00010dc8 |
| INCreateTaskListIntentResponse | `t` 0x000034de | 0x0000e4d4 | `S` 0x00010e18 |
| INGetVisualCodeIntentResponse | `t` 0x00003b84 | 0x0000e74c | `S` 0x00010e90 |
| INRecurrenceRule | `t` 0x00004f04 | 0x0000ee7c | `S` 0x00010ff8 |
| INSearchForAccountsIntentResponse | `t` 0x00005834 | 0x0000f218 | `S` 0x00011098 |
| INSearchForNotebookItemsIntentResponse | `t` 0x0000653e | 0x0000f5c0 | `S` 0x000110e8 |
| INSendRideFeedbackIntent | `t` 0x00006de4 | 0x0000f908 | `S` 0x00011188 |
| INSendRideFeedbackIntentResponse | `t` 0x00007110 | 0x0000fa5c | `S` 0x000111b0 |
| INSetTaskAttributeIntentResponse | `t` 0x0000793a | 0x0000fcf0 | `S` 0x00011200 |
| INTransferMoneyIntentResponse | `t` 0x00009b6a | 0x00010940 | `S` 0x000113e0 |

Sixteen of sixteen. The reader matters here and it is a trap: **`nm -gU` sees none of these methods.**
It prints 231 symbols for this object and none of them is an instance method, because an
Objective-C method definition is a *local* symbol (`t`) and the exported part is the class plus its
method-list table. The first run of this measurement used `nm -gUm`, read zero, and would have
reported that the band exports none of the sixteen — which is the `:1952` unbuilt branch firing on a
reader, not on a defect. A C symbol needs the leading underscore and a method needs plain `nm`.

## The host's side: fourteen answer, two cannot be initialized at all

This is the per-class run the `source` of these rows used to say was owed, for these sixteen:

```
sh tests/backports/host/intents/run-init11.sh
```

```
intents-11 init, PLANTS=(none), 16 classes, control: 843 names beginning IN found in this run
  INAddTasksIntentResponse           ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INAppendToNoteIntentResponse       ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INBalanceAmount                    ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INCallRecord                       ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INCancelRideIntent                 ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
2026-10-01 15:12:40.443 init11[21779:61205327] Unable to initialize 'INCancelRideIntentResponse'. Please make sure that your intent definition file is valid.
  INCancelRideIntentResponse         ->  FAIL -init through its IMP returned nil
  INCancelRideIntentResponse         ->  FAIL the system's own -init crashed this process with signal 11
  INCreateNoteIntentResponse         ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INCreateTaskListIntentResponse     ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INGetVisualCodeIntentResponse      ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INRecurrenceRule                   ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INSearchForAccountsIntentResponse  ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INSearchForNotebookItemsIntentResponse ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INSendRideFeedbackIntent           ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
2026-10-01 15:12:40.478 init11[21830:61205343] Unable to initialize 'INSendRideFeedbackIntentResponse'. Please make sure that your intent definition file is valid.
  INSendRideFeedbackIntentResponse   ->  FAIL -init through its IMP returned nil
  INSendRideFeedbackIntentResponse   ->  FAIL the system's own -init crashed this process with signal 11
  INSetTaskAttributeIntentResponse   ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
  INTransferMoneyIntentResponse      ->  ok   IMP non-NULL, object returned, no exception, respondsToSelector:init 1, every own property at its zero
intents-11 init: 16 lines, 2 red
```

The two are **`INCancelRideIntentResponse`** and **`INSendRideFeedbackIntentResponse`**, both ride
responses, and both the same failure: the system's `-init` reaches intent machinery that needs an
intent definition file this process does not have, logs `Unable to initialize`, **returns nil**, and
then takes the process down with SIGSEGV when the object it could not initialize is released. The
`IMP non-NULL` half still holds for them — `class_getMethodImplementation` answers on all sixteen —
so a caller that checks the IMP first is told yes on a class whose `-init` does not return.

The control is in the first line and it is what makes the zeros mean anything: the same run walked
every class the process knows and found 843 beginning `IN`. A negative elsewhere is then the
release's answer and not a reader in the wrong image. `run-init11.sh` fails when the red set is not
exactly these two, when the control drops below 100, when the plant (`PLANTS=one-wrong`) does not add
a red line to the pair, and when a build with the table's names substituted reports fewer than 16
absent.

### Why the port still answers an object where the host cannot

The port's body forwards to the nearest implementation in the chain through
`class_getMethodImplementation(parent, @selector(init))`, which on iOS 6.1.3 is `NSObject`'s own and
returns an object with every property at its zero. So for these two rows the port answers *better*
than the host does, and that is the design `Intents.md` argues for: leaving `-init` undefined sends
the caller to a NULL IMP, and a nil return sends it to nothing usable either, while an object whose
properties are zero is something a caller can hold.

### Five defects measured while writing the harness

Each of these had the check reporting the reader instead of the release, and each is in the harness's
head comment so the next reader does not pay for it again.

1. **`nm -gU` cannot see an instance-method definition.** 231 symbols, zero methods. Plain `nm`.
2. **`class_copyPropertyList` returns inherited properties too.** `hash`, `superclass`, `description`
   and `debugDescription` are never nil, so the first build printed `INCallRecord.hash is 0` and made
   a line red for a reason that has nothing to do with `-init`.
3. **"every property is nil" is false for a scalar.** A bare `-init` cannot leave an `NSInteger`
   property nil; it leaves it 0, and `valueForKey:` hands back an `NSNumber(0)`. The eight classes
   the earlier hand measurement used carried no such property, which is why the claim survived them.
   The check now reads the property's own declared type: `@` must be nil, anything else 0.
4. **The receiver is an allocated instance, not the class.** The first build passed `(id)cls` and
   threw out of every line — `+[INAddTasksIntentResponse initWithCode:userActivity:]: unrecognized
   selector sent to class` — because `class_getMethodImplementation` finds an *instance* method.
5. **One class's `-init` ends the process,** so each class is measured in a forked child and a
   SIGSEGV becomes a line. Before that, `INCancelRideIntentResponse` lost the fifteen classes after
   it, and the redirected output was block buffered so the lines before it went too.

## Why the harness reads the host and cannot read the port

The sixteen rows need two halves — the port has to carry a definition, and the system's own `-init`
has to answer — and the first half is measured by `nm` above while the second can only be read on a
host. That is a limit of this machine and it was measured rather than assumed, because "nothing runs
the port's own code" is the kind of sentence that hides a step nobody took.

The port's sources do not build for the host, and there are three separate reasons, each with the
error it produces.

**1. Unmodified, the port's own header collides with the host's framework.**

```
xcrun clang -fobjc-arc -target arm64-apple-macos13.0 \
    -isysroot "$(xcrun --show-sdk-path --sdk macosx)" -fsyntax-only -w \
    -I packages/r/revenant-coding/files packages/a/apple-backports/Intents/IN11_0.m
```

```
packages/a/apple-backports/Intents/RevenantIntents262.h:39:1: error: duplicate interface definition for class 'INMessageLinkMetadata'
packages/a/apple-backports/Intents/RevenantIntents262.h:47:71: error: property has a previous declaration
```

`RevenantIntents262.h` re-declares the classes the port's own SDK lacks, and `INMessageLinkMetadata` is
one the macOS framework has. This is the error the removed intents rename script
exists to answer, and its head comment described the same command.

**2. Renaming the classes fixes that and breaks the superclasses.** The port's `.m` files carry
`@implementation` and no `@interface`: every class here gets its declaration from Apple's headers, and
The removed intents rename script rewrote the port's sources and not the SDK's. So a renamed implementation has no
renamed declaration:

```
error: cannot find interface declaration for 'crevenantHost_INIntentResponse', superclass of 'crevenantHost_INUnsendMessagesIntentResponse'
error: cannot find interface declaration for 'crevenantHost_INAddTasksIntent'; did you mean 'crevenantHost_INEditMessageIntent'?
```

The rename list is read off `_OBJC_CLASS_$_` symbols and carries classes and protocols only; the
identifiers that collide and are not classes are the four `NS_ENUM` typedefs `RevenantIntents262.h`
declares — `INEditMessageIntentResponseCode`, `INMessageReactionType`, `INStickerType`,
`INUnsendMessagesIntentResponseCode` — and their enumerators, thirty-six names in all, and adding
them is a change to a tool every Intents slice shares. Fixing this properly means giving the harness
a renamed copy of the SDK's own Intents headers as its umbrella, which is a port's worth of work and
is not this slice's.

**3. And the iOS-only types cannot be used on the host at all.**

```
error: 'INAccountType' is unavailable: not available on macOS
error: 'INTaskPriority' is unavailable: not available on macOS
error: no known class method for selector 'revenant_resolutionWithStatus:resolvedValue:valuesToDisambiguate:valueToConfirm:'
```

Apple's macOS headers mark these `API_UNAVAILABLE(macos)`. An explicit `unavailable` is an error, not
a warning, so no flag suppresses it and the only way past it is to not use Apple's headers.

**4. And there is no target on this machine that would run the result.** The SDKs here are iPhoneOS
device SDKs, 9.3 through 16.5, under `$HOME/Git/tools/sdks`; there is no iPhoneSimulator SDK at all,
`xcrun --sdk iphonesimulator --show-sdk-path` answering `SDK "iphonesimulator" cannot be located`. An
armv7 iOS 6.1.3 binary needs `xmake emulate` or a device, and neither ran for this slice.

So the port's `-init` is proven to exist and to forward through its superclass's IMP, and its runtime
answer is owed. That is the honest end of it here, and the harness above is deliberately built to
measure only the half this machine can measure, rather than to report a port result it cannot get.

## What is not proven here, and is owed

- **The port's own `-init` has never been executed.** Both halves above are host answers plus a symbol
  reading; the objects are armv7 iOS 6.1.3 and no iOS runtime was involved in either, and the section
  above is the measurement of why. That the port's `-init` returns an object at runtime is the link
  step's and a device's job, not this page's.
- **The other ninety-four are not measured here.** They belong to the iOS 10.0, 12.0 and 16.0 slices
  and to the rest of 11.0's family in `Intents.md`. A run like this one for each of them is the
  harness that page still owes.
- **The two failing classes are a host answer on this machine, not a claim about the release.** They
  fail because there is no intent definition file in the process; inside a real intent the system has
  one and the same `-init` may well return. Nothing here says which.
- **`gates: coordinator`.** Not run by the author.