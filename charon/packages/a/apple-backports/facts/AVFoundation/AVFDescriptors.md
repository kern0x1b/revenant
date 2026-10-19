# The avf-3a descriptor classes: the criteria, the bracket settings, the renewal request, the selection

Seven rows in three objects, and the differential that holds them honest is one program linked twice
rather than a probe per class.

## The ladder, and why there are three objects

Measured over **every held cache** — 4.3, 6.1.3, 7.0, 7.1, 7.1.1, 7.1.2 and 8.0 (armv7), 8.1.3, 8.2 and
8.4.1 (armv7s), 9.3.6 (armv7), 10.0.1, 11.0 and 12.0 (arm64), 16.0 (arm64e) — for each class's own
`_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` symbols, with `_NSFileSize` planted as a control (it answers
**4.3** on this set, so a run that answered nothing for it is a broken measurement) and a nonsense
symbol in **none** of the fifteen.

| first held rung | rows | object | `minimum` |
| --- | --- | --- | --- |
| 7.0 | 1 | `AVPlayerMediaSelectionCriteria7.m` | 6.0 |
| 8.0 | 4 | `AVCaptureBracket8.m`, `AVAssetResourceRenewalRequest8.m` | 6.0 |
| 9.3.6 | 2 | `AVMediaSelection9.m` | 6.0 |

One `minimum` per object, and it is the port's floor: below each class's own rung the release has no
such class at all, so the port defines it and carries it from 6.0. A class symbol is dropped from its
rung up, where the release's own class answers — which is why the members that arrived **after** a
class's rung are a separate category object (`AVPlayerMediaSelectionCriteria7Members.m`), because a
category defines no symbol and is never dropped.

## The 12.0 initializer: the warning is the intended shape, and it works at run time

`AVPlayerMediaSelectionCriteria.m` warns that
`-initWithPrincipalMediaCharacteristics:preferredLanguages:preferredMediaCharacteristics:` has no
definition in the class's own `@implementation`, because it is in the category beside it. That warning
is the build stating the split, and the shape has to WORK, so the probe asks an instance whether it
answers the selector and then calls it — on both sides, from the run:

    12.0-INITIALIZER responds (instance)   host = yes    port = yes
    ~VALUES 12.0 initializer answers principalMediaCharacteristics   = (public.video)
    ~VALUES 12.0 initializer kept the preferred languages            = (en)

**Host: no oracle for the call.** This host's own
`+[AVPlayerMediaSelectionCriteria preferredMediaSelectionCriteriaWith…]` is
`API_UNAVAILABLE(macos)`, so the values come back `no-oracle-forwarding-object` and those rows are
**port-only**, held against the port's own unmutated baseline rather than against the host. The port
side is a real measurement; the host side is a stated absence.

## What the four stored values answer, and where there is no host oracle

Built through the header's own factories, read back through the members:

    ~VALUES auto-exposure bias after the factory        = 1.5
    ~VALUES manual-exposure ISO after the factory       = 400
    ~VALUES manual-exposure duration after the factory  = 0/1
    ~VALUES criteria preferredLanguages after the factory = (en)

All four are **port-only rows** (`~`), and the reason is not a missing measurement: the header's value
for a bracketed settings object is a *configuration*, not a measurement, and the host's factories are
unavailable on this build, so there is nothing to compare them against. `AVAssetResourceRenewalRequest`
has no value row at all, and that is the fact: the host declares no own method and no own property on
it and its instance size equals its superclass's, so it stores nothing.

## The two allowances, with the measurement each rests on

    ALLOWED AVMediaSelection RESPONDS selectedMediaOptions   host=[no] port=[yes]
    ALLOWED AVMediaSelection RESPONDS mediaSelectionGroups    host=[no] port=[yes]

The host's own `AVMediaSelection` method list, read with `class_copyMethodList`, carries
`-selectedMediaOptionInMediaSelectionGroup:` and not these two, and asking an instance answers no to
both. The 26.2 header declares all three. The port answers **more** than the host, which is the
direction the policy asks for and the same situation as the body-object members in the earlier slices.

## The harness, and what it can and cannot settle

One probe, linked twice, run **directly** rather than through `heavy.sh` — a handful of small compiles
is not what the lane is for.

- **No class here can be named as a type on this host.** `AVCaptureAutoExposure…`,
  `AVCaptureManualExposure…` and the criteria factory are all `API_UNAVAILABLE(macos)` — unavailable
  to *compile against*, not absent — so every class is reached by `NSClassFromString` and every member
  by selector. A probe that writes any of them as an expression does not compile, which is how the
  first version failed.
- **An instance is asked, and only an instance.** This host's `AVAssetResourceRenewalRequest` returns a
  forwarding object from `-init`; sending it `-respondsToSelector:` outside a `@try` kills the process,
  and asking the *class* instead says yes for a member the instance still cannot handle — so
  `class_respondsToSelector` on a class method is the wrong table (a class method lives on the
  **metaclass**) and instance-level access is behind its own `@try`, with printing contained in a
  second one.
- **Every key names its class.** Seven classes writing `PRESENT`/`SUPERCLASS`/`RESPONDS` into one table
  put the last class's answer under the first class's key, and the join then reported two *different
  classes* colliding.

| case | result |
| --- | --- |
| clean | 0 differing, 11 port-only, 2 allowed — ok |
| **mutant** | **ok — noticed, on 1 row: the ISO** |
| control | ok — the unmutated source through the identical path |
| plant-all / plant-one | red |
| build-failure control | `RUN FAILED` with the compiler's line, exit 1 |

The mutant is the load-bearing row: it goes red on **exactly one** row, and it is the row it aims at.
Its apply-guard checks both directions — the target was there, and afterwards it is gone with one
replacement — and it earned that twice: it first refused the mutation because `ISO:iso];` appears
**twice** in the source, which would have left the original in place, compiled, and changed nothing.
