# The gamepad snapshots of iOS 7.0 and 9.0

A snapshot saves a game's own values into data and reads them back, so a game can be replayed. The
data is not a private blob: the header describes it, as a packed structure whose first four bytes are
a version and a size, and the fields after them in a stated order. So the port writes the header's
layout and not an approximation of it, and data the port wrote reads back through any of the ten
functions.

## What was measured, and against what

The host's own `GameController` under macOS 27, with no controller connected, is the oracle. The
harness is `tests/backports/host/gamecontroller`: the `snapshot functions` group drives the host's
ten functions and the port's ten over the same inputs and compares the answers line by line. It is
612 lines of that group inside a run of **9188 checks, 0 different**.

The three families of reader do not ask the data the same question, and the harness found all three
rules wrong on the port's first attempt:

| reader | what it takes | measured |
| --- | --- | --- |
| the gamepad's V100 | a whole 36-byte structure, and a version that is not zero | 35 bytes → 0; 36 bytes with version `0x4140` → 1; 36 bytes with version 0 → 0; empty data → 0 |
| the extended and micro readers | a header that declares no size larger than the structure | 63 bytes that declare 999 → 0; 63 that declare 63 → 1; 59 bytes whose declared size is `0x4141` → 0; 59 that declare 59 → 1 |
| all four extended and micro readers | data too short to hold a header | empty data → 1; 4 bytes of junk → 0 (its declared size is `0x4141`) |

The encoders are the header's own rule that data which declares no version and no size gets the
current version and `sizeof` implicitly:

| structure | bytes | first four |
| --- | --- | --- |
| `GCGamepadSnapShotDataV100` | 36 | `0001 2400` — version `0x0100`, size 36 |
| `GCExtendedGamepadSnapShotDataV100` | 60 | `0001 3c00` — version `0x0100`, size 60 |
| `GCExtendedGamepadSnapshotData` | 63 | `0101 3f00` — version `0x0101`, size 63 |
| `GCMicroGamepadSnapshotData` | 20 | `0001 1400` — version `0x0100`, size 20 |

and a structure that already carries a version and a size keeps both: version `0x0200` and size 999
encode as `0002 e703`.

The two version constants are the header's own enumerations, taken at compile time by
`GCSnapshots16.m` from the very enumeration the header names: `GCExtendedGamepadSnapshotDataVersion2`,
which is `0x0101`, and `GCMicroGamepadSnapshotDataVersion1`, which is `0x0100`. Nothing reads them out
of the host at run time, and cannot: the framework is cache-resident here, so a run-time lookup of
them is not a measurement of anything this port does. (An earlier draft of these rows named a run-time
lookup as the source; that was wrong about the mechanism, and the values were right because the header
states them.) There is no
version symbol for the plain gamepad, and the registry carries no row for one: its structure declares
`0x0100` in a comment, which is what this port writes.

## One object per release

The ten functions, the two constants and the three objects do not share a release, so they are four
objects, split by what the ladder first exports. The rung below is measured, not read off a header:
`xmake l tools/cache-index/first-rung.lua <name>`, which is what `measured_names()` and so
`check_releases` reads.

- `GCSnapshots7.m` — the plain game's V100 pair and the extended game's V100 pair, both at 7.0, and
  with them `GCGamepadSnapshot`, `-[GCGamepad saveSnapshot]` and `GCExtendedGamepadSnapshot`, which the
  ladder also places at 7.0;
- `GCSnapshots9.m` — the micro game's V100 pair, whose symbols the ladder first exports at 10.0.1,
  which is why `GCMicroGamepad9.m` is named for 9 and not for 10.0.1; and with them
  `GCMicroGamepadSnapshot` and `-[GCMicroGamepad saveSnapshot]`, which the ladder also places at 10.0.1;
- `GCSnapshots16.m` — the four current functions and both version constants, first exported at 16.0,
  the rule `GCConstants16.m` already follows;

The shared encoding and decoding are `static inline` in `RevenantGCSnapshot.h`, so each object holds
its own copy and no object names a symbol another one defines — which is the failure
`A C function shared between backport files` describes.

## The mutants

`sh tests/backports/host/gamecontroller/mutants.sh` changes one rule at a time and requires the
differential to fail. Each mutant is listed with the difference it was meant to produce; the count the
script prints is the number it ran.

| mutant | the difference |
| --- | --- |
| the gamepad reader takes one byte less | 35 bytes: host 0, port 1 |
| the gamepad reader stops reading the version | a 36-byte header of version 0: host 0, port 1 |
| the readers stop reading the declared size | a 24-byte header: host micro 0, port micro 1 |
| the encoders stop filling an empty version | `00012400` against `00002400` |
| the encoders stop filling an empty size | `00012400` against `00010000` |
| the touchpad's state rules, five of them | each one moves the `touchpad state` line |

Two more were added with the objects, and both are the shape of the defect the objects group found:
one changes the element a field is read from (`Button X` takes `buttonY`), the other reads the
direction pad as if it were an axis. Neither breaks the build and neither survives.

## `-[GCExtendedGamepad saveSnapshot]`: the wall, and what removed it

It was absent for a measured reason, recorded in `coordination/api-queue.md`: the method is 7.0
(`GCExtendedGamepad.h:65`), its return type was believed to be 9.0, and a method's IMP emits an
`objc-class-ref` for its return type, so the 6.1.3 band had nothing to satisfy it. The measurement
stands; **the premise did not**. The class was placed at 9.0 from the header's `API_AVAILABLE(ios(9.0))`
rather than off the ladder, and `first-rung.lua` answers 7.0. So the class and the method now share a
rung and an object, `GCSnapshots7.m`.

Measured on the port's own object, before and after, with `nm -u`:

| | undefined class references |
| --- | --- |
| `GCSnapshots7.o` without the method | `GCExtendedGamepad`, `GCGamepad`, `NSData`, `NSDictionary`, `NSNumber` |
| `GCSnapshots7.o` with it | the same five, and the object **defines** `GCExtendedGamepadSnapshot` |

That is the whole of the wall: the reference the method adds is answered inside the object that adds
it, so the dylib links.

**The oracle for the method is this Mac's own GameController, and it is the strongest the suite has.**
`+[GCController controllerWithExtendedGamepad].gamepad` is a real extended gamepad whose `-saveSnapshot`
returns a real `GCExtendedGamepadSnapshot` whose `snapshotData` is 63 bytes beginning `01 01 3f 00` with
byte 60 written `01`. So:

- `extended untouched saveSnapshot` -- the host's own **method** over its own untouched gamepad against
  the port's own **method** over the port's. An object against an object, and the only line in the
  suite that is one.
- Per matrix row, the host has no factory that writes values into a gamepad, so the port's method over
  a gamepad holding those values is held in the port-only `snapshot read back` group against the host's
  own `NSDataFromGCExtendedGamepadSnapshotData` for the same values, byte for byte, `MISMATCH` failing
  the run. An earlier draft of that line put the host's untouched gamepad on the host side and the port's
  written one on the port side; the harness answered `9420 checks, 2 different` and the diff showed the
  host encoding zeros against the port encoding the matrix -- a comparison that could never have passed,
  because there is no host factory that writes values.

## What it was waiting for while it was waiting

It was refused for a measured reason, recorded in `coordination/api-queue.md`: the method is 7.0, its
return type was believed to be 9.0, and a method's IMP emits an `objc-class-ref` for its return type,
so the 6.1.3 band had nothing to satisfy it. The measurement is still sound; **its premise was not**.
The class was placed at 9.0 from `GCExtendedGamepadSnapshot.h`'s `API_AVAILABLE(ios(9.0))`, and
`first-rung.lua` answers 7.0. So the class and the method are now on the same rung in the same object
and the reference has something to resolve against. The method is still `absent` and is not added
here: that is one more change, and it wants its own measurement on the gate's own path rather than a
claim in a facts page.

## The three snapshot objects

The three classes and the three `-saveSnapshot` methods that make them are not one release, and the
ladder is what splits them:

- `GCSnapshots7.m` -- `GCGamepadSnapshot` and `-[GCGamepad saveSnapshot]`, both first exported at 7.0;
- and, by what the ladder says rather than by what the SDK header says:
  `GCExtendedGamepadSnapshot` is at **7.0** and lives in `GCSnapshots7.m` beside `GCGamepadSnapshot`
  (`xmake l tools/cache-index/first-rung.lua GCExtendedGamepadSnapshot` -> 7.0), while
  `GCMicroGamepadSnapshot` is at **10.0.1** and lives in `GCSnapshots9.m` with the micro game's V100
  pair and `-[GCMicroGamepad saveSnapshot]` (first-rung -> 10.0.1). `measured_names()` reads classes
  and C functions off the held caches, so an Objective-C *method* measures `NONE` and its registry
  `introduced` is what places it; for `-[GCMicroGamepad saveSnapshot]` the floor it cannot precede is
  its own return type, which is 10.0.1. The SDK header's `API_AVAILABLE(ios(9.0))` on the classes says
  when the declaration appeared and the ladder says when the name arrived, and `check_releases` reads
  the ladder first - a class placed off the header lands in an object holding two releases, which is
  the error this note records;
- `-[GCExtendedGamepad saveSnapshot]` is **not carried**, and the reason is the port's own shape
  rather than the work: the SDK declares the method at 7.0 (`GCExtendedGamepad.h:65`) returning a
  class that first appears at 9.0, and a method's implementation emits an `objc-class-ref` for its
  return type, which the 6.1.3 band has nothing to satisfy. Measured, with the numbers, in
  `coordination/api-queue.md` under "GCExtendedGamepad.saveSnapshot: a 7.0 method whose return type
  first appears at 9.0". The header agrees about the shape: `API_DEPRECATED(..., ios(7.0, 13.0))`.

What a snapshot object is, is the header's own: a profile of the game's elements that holds the
values it was saved from and answers them again. So each one keeps the data and pushes it through
the same accessors a live game uses, and the two initialisers are the header's own
(`GCExtendedGamepadSnapshot.h:27-29`, `GCMicroGamepadSnapshot.h:27-29`).

Two measurements of the host's own, both taken on this machine (macOS 27, no controller connected):

- `+[GCController controllerWithExtendedGamepad].gamepad -saveSnapshot` answers a real
  `GCExtendedGamepadSnapshot` whose `snapshotData` is **63 bytes beginning `01 01 3f 00`**, and byte
  60 -- `supportsClickableThumbsticks` in the header's own field order -- is written **`01`** for a
  controller nothing has touched.
- Its `elements` count is **34**, against the profile's **44**. The ten the snapshot does not carry
  are `Back Left Button 0`, `Back Left Button 1`, `Back Right Button 0`, `Back Right Button 1`,
  `Left Bumper`, `Right Bumper`, and four elements the host gives no `identifier` to.

The port's own snapshots carry the *parent* profile rather than a reduced one: the extended
snapshot carries the extended profile's elements and the micro snapshot the micro profile's. That is
one superset of the host's, and each extra element reads zero -- which is the value a released
control holds, and what the encoding writes for an untouched one. A caller reading one of the six
named elements gets a number the host would not have given it at all.

## The oracle for the objects, and the two defects it found

The `snapshot objects` group of `tests/backports/host/gamecontroller` uses two oracles, and each line
says which it used:

- the host's own `-saveSnapshot` on an untouched controller, against the port's own encoder over the
  same structure;
- **the host's own encoder over the same field values**, against the port's `-saveSnapshot` over a
  gamepad holding those values, compared byte for byte. This is the oracle that can see a field read
  from the wrong element, and it is the whole of the micro case: there is no host micro game
  (`+[GCController controllerWithMicroGamepad].gamepad` answers nil here and there is no
  `+controllerWithGamepad`), so the host's encoder is the other side.

The `snapshot read back` group is the port's alone, because the host cannot be the other side of an
initialiser -- `-[GCGamepadSnapshot setSnapshotData:]` reaches `-[GCControllerAxisInput
_setValue:queue:]` through the profile's own `setDpad:x:y:` and raises. Every line names the value
that went in and the value that came back, and a field read from the wrong element prints `MISMATCH`
and fails the run.

A run of the whole harness with the two groups in it: **9416 checks, 0 different**, of which the
read-back contributes 55 lines and the objects 10.

Two defects in what was already here came out of those groups, both in the direction pad:

1. `revenant_applyV100:` sent `revenant_setValue:` to the pad. That selector is declared on
   `GCControllerAxisInput`, and a pad does not answer it (`GCElements7.m` gives a pad its `xAxis` and
   `yAxis` as two elements of their own), so building a `GCGamepadSnapshot` from data raised
   `NSInvalidArgumentException` -- and it wrote both `dpadX` and `dpadY` to the same object besides.
   Each now goes to the axis it names.
2. `-saveSnapshot` read the pad's value with `revenant_gc_read_float(pad, @selector(xAxis))`, which
   asks the pad for a *float* through a selector that answers an *element*, so it read nothing and
   the byte was zero. Zero is what a released stick reads, so the plain game's direction pad held no
   value and every existing answer agreed with it. `revenant_gc_pad_axis()` in `RevenantGCSnapshot.h` is
   the read that answers the question, and the micro case is where the harness sees it: a `dpadX` of
   `-0.5` in the port's own bytes against the host encoder's is the whole difference.

The touchpad's own members are not here for the same kind of reason: the host answers
`[[GCControllerTouchpad alloc] init]` with nil and offers no `+initWithTouchSurfaceHandler:`, so with
no controller connected it has no touchpad for a differential to reach. `GCKeyboard` answers for
`keyboardInput` that it does not implement the member at all on macOS.
