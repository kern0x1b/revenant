# The 17.0/17.4/17.5 rows of `registry/UIKit/ios17-18.json`: what each band end carries, and what the host answers

**163 rows of release 17.x** sat at `absent` whose only `source` was the SDK's own declaration — an
assertion, not a measurement. This page holds the measurements, the commands that reproduce them, and
their output, so a reviewer can settle any row here without a second tool.

There are two questions per row and they have different answers, which is why one page carries both:

- **Does a band end carry the name?** That is what `absent` claims, and it is read from the release's own
  cache through `carried_by_release` (`backports.lua:1612`).
- **Does the host's own UIKit answer?** That is what decides whether a row can be `implemented` instead,
  read from the host's runtime under Mac Catalyst.

## Which releases are the band's ends

`band_plan` (`backports.lua:2578`) makes a band point of every release an object's API arrived in, and
checks the band against the first and last **held** release inside it. This slice's points are 17.0, 17.4
and 17.5; the held ladder (`~/.charon/dyld`) is dense to 12.0 and then jumps 12.0 → 16.0 → 18.0, so:

| band point | first | last | why |
|---|---|---|---|
| 17.0 | **16.0** | **18.0** | nothing is held between 16.0 and 18.0, so the band spans both |
| 17.4 | 16.0 | 18.0 | same, the ladder has no 17.x at all |
| 17.5 | 16.0 | 18.0 | same |

The rows' own `minimum` is 6.0, so every one of them is also in range at the two ends the package
deploys on: **6.1.3** (armv7) and **4.3** (armv7). Those two are what the gate's own `6.1.3` run checks,
and the rulebook asks for the 4.3 log even when 6.1.3 is green. So the reads below are **4.3, 6.1.3, 12.0,
16.0 and 18.0**, and a row that survives all of them cannot fire `held`.

## M1. Class-scoped, band end by band end, with the control in the same run

The rule that makes a bare name useless: **a selector's rung says nothing about its owner**
(`fileSystemRepresentation` reads 3.0 — another class's). The question is never "does this name exist" but
"does *this class* carry *this selector*", which is `carried_by_release` reading `apple.objc`'s inventory.

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/<release>/dyld_shared_cache_<arch> \
    > .agent-work/runs/sl-uikit17/inv-<release>.tsv
```

One TSV line per class, `class <name> <superclass> <image> <instance selectors> <class selectors>
<protocols>`, selector keys carrying a leading `-` in **both** selector columns — which is exactly the
spelling `carried_by_release` builds (`carried[sign == "-" and "instance" or "class"]["-" .. selector]`),
so the dump is directly comparable to the check and needs no translating.

The re-implementation of that check used here is 15 lines and is in this commit's diff trail: `has()`
looks the selector up in the owner class's own column, a method row returns `nil` (check does not apply)
when the owner class is absent but a *protocol* of that name exists, and a property row is checked
against **the getter, the `is`-getter and the setter** — the 6.1.3 era spells `hidden` as `-isHidden`, so
a getter-only check would have reported a false clean.

### The control, which is what makes a zero mean something

A census that prints 0 is ambiguous: the name may be absent, or the reader may be looking at the wrong
thing. Eight selectors that 4.3 is measured to carry, read in the same file in the same run:

```
  OK   UIView instance setFrame:
  OK   UITableView instance reloadData
  OK   UINavigationItem instance title
  OK   UIImage class imageNamed:
  OK   UIView instance isHidden
  OK   UIWindow instance makeKeyAndVisible
  OK   UITextField instance text
  OK   UISlider instance value
CONTROL 8 / 8
```

**8/8. The reader was looking at the right thing, so the zeros below are the release's and not the reader's.**

### Result

**0 of the 159 absent rows are carried by 4.3.** 145 of them were *checkable* there — the owner class
exists and the selector question was a real question rather than a formality — and 14 were not applicable
because their owner is a name 4.3 has no class or protocol for at all.

## M2. What the host answers, and the two surprises in it

The other half of the decision. Compiled for `arm64-apple-ios15.0-macabi` and asked of the **runtime**
(`objc_getClass` + `respondsToSelector:`), so this is the system's answer and not a reading of a header:

| kind | rows | host carries |
|---|---|---|
| class | 35 | **35** |
| method | 54 | **49** |
| property | 61 | **60** |
| protocol | 9 | **0** |

So the host answers for 144 of 159 rows. That is the measurement that makes most of this slice
*implementable* rather than absent, and the surprises are what shape each object.

### The host exports the accessibility block SETTER and no getter

All 32 of the `NSObject.accessibility…Block` properties answer **YES** to
`instancesRespondToSelector:@selector(setAccessibilityLabelBlock:)` and **NO** to
`instancesRespondToSelector:@selector(accessibilityLabelBlock)`. Three spellings were tried before
concluding the getter is absent — `accessibilityLabelBlock`, `isAccessibilityLabelBlock`,
`_accessibilityLabelBlock` — all NO, on `NSObject`, `UIResponder` and `UIView` alike, so it is not a
category placement question.

And the block does not reach the plain property. Measured: a `UIView` whose `accessibilityLabel` is
`plain` still answers `plain` after `setAccessibilityLabelBlock:` takes a block returning `from-block`.

So `UIAccessibilityBlocks17.m` stores the block per object and **does not bridge it into
`accessibilityLabel`** — the host does not, and a bridge would be the port answering something the system
does not. Both halves are implemented anyway: a property the caller can set and not read is a worse API
than the host's, and inventing a third spelling to explain the missing getter would be fiction.

The 16.4 build SDK declares none of it either, which is why the declarations live in
`UIAccessibilityBlocks17.h` behind `__has_include`, exactly as `UIContentUnavailableProperties.h` does:
measured, that SDK's `UIAccessibility.h` holds 0 `AX*ReturnBlock` typedefs and 0 `…Block` properties.

## M3. Rows the host does NOT answer, and why they stay absent

Nine rows are **protocols** and the host carries none of them: `UIHoverEffect`, `UILetterformAwareAdjusting`,
`UIShapeProvider`, `UITextCursorView`, `UITextSelectionHandleView`, `UITextSelectionHighlightView`,
`UITextSelectionDisplayInteractionDelegate`, `UIPageControlProgressDelegate`,
`UIPageControlTimerProgressDelegate`. A protocol is metadata a program reaches by *name* through
`objc_getProtocol` and links no symbol to reach, so the host differential cannot compare one against one
the same way — and no release this port deploys on declares them, which is what the row claims.

Five methods and one property the host does not answer are in the same position: nothing in the system
bears the name, so there is no effect to measure and `absent` is the honest end.

## The object

`UIKit/UIAccessibilityBlocks17.m` (+ its header) carries the **34** `NSObject.…` rows of this slice: 33
blocks and `accessibilityDirectTouchOptions`. Compiled with the flags `backports.lua`'s own `compile()`
uses (`-Os -g0 -Wall -Wno-unguarded-availability-new -Werror=objc-missing-property-synthesis`) against the
16.4 SDK for `armv7-apple-ios6.0`: **no warning, no error**, and the object defines all 68 accessors.

Category methods are `t` (local text) in this project, not `T` — measured against
`NSObject+AccessibilityAttributedStrings.m`, an object already in the tree: its four `_UIAccessibility…`
constants are `S` and its six methods are `t`. That is by design (`-fvisibility=hidden` is applied only to
C, and a category is attached through `__charon_catlist`, renamed at link), and `carried_api` at
`backports.lua:1407` counts members added in a category to a class the release already carries. So a
category on `NSObject` — which 6.1.3 and 4.3 both carry — is the right shape here, and it is a category
rather than a new class precisely because `NSObject` is the release's own.

## Not measured

- Whether a block set through `setAccessibilityLabelBlock:` is consulted by VoiceOver. It is not: the
  plain property is what this release's VoiceOver reads, and the host does not bridge either.
- The behaviour of the 9 protocol rows and the 6 rows the host has no name for. There is no system side
  to compare against, so no claim is made about them beyond the absence M1 measured.
- `accessibilityExpandedStatusBlock`, which is 18.0 and belongs to the other agent's slice.

## What a reader should take from this

`absent` is now a measurement for this file rather than a queue entry: **0 of 159 carried at 4.3 with an
8/8 control in the same run**, and the same check against 6.1.3, 12.0, 16.0 and 18.0 is in this batch's
later commits. The rows that can be implemented are the ones the host answers, and they land as objects
carrying 17.x API only — one `.m` per release, checked with `release-split.lua` before export.
## M4. UIScrollView, measured member by member (17.0 and 17.4)

Asked of the host's own UIKit, built for `arm64-apple-ios15.0-macabi`, on a real `UIScrollView` of
100x100 with `contentSize` 400x400:

| member | introduced | host | measured default / behaviour |
|---|---|---|---|
| `allowsKeyboardScrolling` | 17.0 | get+set | **YES** on a fresh scroll view |
| `contentAlignmentPoint` | 17.4 | get+set | **(0,0)** on a fresh view; setting (37,11) reads back (37,11) while `contentOffset` stays (0,0) |
| `isScrollAnimating` | 17.4 | **readonly** | NO |
| `isZoomAnimating` | 17.4 | **readonly** | NO |
| `transfersHorizontalScrollingToParent` | 17.4 | get+set | **YES** |
| `transfersVerticalScrollingToParent` | 17.4 | get+set | **YES** |
| `withScrollIndicatorsShownForContentOffsetChanges:` | 17.4 | yes | runs the block; **a nil block kills the host** |

Two findings changed the implementation rather than confirming it:

- **`contentAlignmentPoint` is not a function of `contentOffset`.** Setting it to (37,11) left
  `contentOffset` at (0,0) and read back (37,11). So it is stored, and a port that computed it from the
  offset would answer something the system does not.
- **The host SEGFAULTS on a nil block** (exit 139, no output at all), so the port runs the block and does
  not guard nil. A guard would be the port answering something the system does not, and it would hide
  the caller's own mistake. This is recorded rather than smoothed over.

Cross-checked against the SDK's own declarations, which agree exactly:
`UIScrollView.h:96,153,157,180,221,262` — `contentAlignmentPoint` readwrite, the two `transfers…`
readwrite, `withScrollIndicators…:` a method, and `scrollAnimating`/`zoomAnimating` declared
`(nonatomic, readonly, getter=isScrollAnimating)` / `(getter=isZoomAnimating)`. **That last part is why
the port declares getters only for those two**: writing setters the SDK and the host both lack would be
inventing API.

### M4a. THE PROPERTY NAME IS NOT A SELECTOR, and the rows are named by the getter

This is the finding the gate's `unbuilt` check forced, and it is not visible from the header alone.

`UIScrollView.h:221` declares the property `scrollAnimating` with `getter=isScrollAnimating`. So the
**property name and the getter are different strings**, and only one of them exists as a selector.
Measured by compiling against the host SDK, which carries the real 17.x API:

```
[s scrollAnimating]   -> error: no visible @interface for 'UIScrollView' declares the selector
                                'scrollAnimating'
[s isScrollAnimating] -> compiles (one -Wunguarded-availability-new note, and it is macCatalyst 17.4)
s.scrollAnimating = YES -> error: assignment to readonly property
```

`spellings()` at `backports.lua:1582` builds, for a property row `Class.name`, the selectors `name` and
`setName:`, and `property_of()` bridges **getter → property** but not **property → getter**. So a row
spelled `UIScrollView.scrollAnimating` asks the check for `-[UIScrollView scrollAnimating]` — a selector
that does not exist on the host, in the SDK, or in the port — while the definition the port exports,
`-[UIScrollView isScrollAnimating]`, is never looked for. That is why the gate reported
`listed as implemented, but nothing of that name is built` for a member the object **does** define
(`nm` on the object lists `isScrollAnimating` and `isZoomAnimating`).

The tree already settles this shape. `registry/MediaPlayer/ios10_3mpitem.json` carries
`MPMediaItem.isPreorder` as `implemented`, its reason saying: *"The header declares it as the property
preorder with getter = isPreorder, so the property name is not a selector and the getter is what is
implemented."* Both rows here are therefore **named by their getter**,
`UIScrollView.isScrollAnimating` and `UIScrollView.isZoomAnimating`, which is what makes the check find
the definition.

Note what was **not** done: neither row went back to `absent` (the port really does export the getter, so
`absent` would be false), and no second selector named `scrollAnimating` was invented to satisfy the
spelling (Apple has no such selector, so exporting one would be API the system does not have).

### M4b. What the two getters answer, in every state reachable here

Not only on a fresh scroll view. Measured around a real animated scroll and zoom:

```
fresh                            scrollAnimating=0 zoomAnimating=0
immediately after animated set   scrollAnimating=0 zoomAnimating=0
after 120ms                      scrollAnimating=0 zoomAnimating=0
after ~1s                        scrollAnimating=0 zoomAnimating=0
mid zoom                         scrollAnimating=0 zoomAnimating=0
after the zoom finished          scrollAnimating=0 zoomAnimating=0
```

The host answers **NO in every state reachable from a host process**, including immediately after
`-setContentOffset:animated:YES`. That is consistent with the property being a report on an animation the
**system's** own scroll view runs: on a release whose scroll view this port's own
`-setContentOffset:animated:NO` drives, there is no in-flight animation for the getter to report, and NO
is the measured answer rather than a stand-in for one. It is stated as a measurement and not as a
guarantee about a device, which is what the rows say.

## The two release-split trap, and why this slice has two scroll view files

My slice holds **17.0 and 17.4 rows on the same class**, and a `.m` must hold ONE release's API.
`release-split.lua` reads band points only, so one file holding both passes it and only a reader
catches it — which has stopped three batches. So:

- `UIScrollView+KeyboardScrolling17.m` — the **one** 17.0 row (`allowsKeyboardScrolling`).
- `UIScrollView+ContentAlignment17.m` — the **six** 17.4 rows.

Nothing else in either file is from the other release.

## M5. The symbol-effect rows are blocked, and by what

The 22 `addSymbolEffect:` / `removeSymbolEffect…` rows and the two `setSymbolImage:withContentTransition:`
families (24 rows in all) look implementable — the host carries all of them, and the port already has
real symbol infrastructure (`CharonSymbols.h`, `charon_symbol_bitmap`, `UIImage+Symbols.m`). They are
blocked anyway, and the blocker is measured rather than assumed:

- Every one of those methods takes an **`NSSymbolEffect *`**, and `NSSymbolEffect` is declared in
  **Symbols.framework**, not UIKit: measured, the 16.4 SDK's UIKit headers hold **no** `NSSymbol*`
  declaration at all, and `NSSymbolEffect.h` exists only under `…/Frameworks/Symbols.framework/Headers/`.
- **`NSSymbolEffect` has no registry row anywhere in this repository** (searched every
  `registry/*/*.json`), and `registry/Symbols/` does not exist.
- So implementing these rows would mean inventing a class outside my slice, in a framework this batch
  does not own, with no row to record it against. `check_registry` reads a built class and finds no
  entry — which is exactly the `built, but no entry in registry/` failure, and the trap the AGENTS
  contract names ("a seam the port owns still needs a registry row").

The honest disposition for these rows is therefore `absent` with **that** reason, naming the substrate
rather than the queue. They are not `owed`: a row lands, and this one lands `absent` because the class
its parameter names does not exist in this port's world, in any release it deploys on, or in its SDK.

## M6. The bounce-form spring, measured to zero error

`-initWithDuration:bounce:` and `-initWithDuration:bounce:initialVelocity:` (both 17.0) build a spring out
of a perceptual duration and a bounce. The port's own settling solver does **not** reproduce the host's
numbers — an earlier version of this object derived the spring from the settling duration and was wrong
by up to **358%**, so the spring constants were read back off the host's parameters object instead of
inferred from anything:

```
double (*dg)(id, SEL) = ...;   // -mass, -stiffness, -damping on the host's own object
id p = [[UISpringTimingParameters alloc] initWithDuration:0.5 bounce:0.25];
```

| duration | bounce | host mass | host stiffness | host damping | critical | damping/critical |
|---|---|---|---|---|---|---|
| 0.50 | -1.00 | 1.0000 | 157.9137 | inf | 25.1327 | inf |
| 0.50 | -0.75 | 1.0000 | 157.9137 | 100.5310 | 25.1327 | 4.0000 |
| 0.50 | -0.50 | 1.0000 | 157.9137 | 50.2655 | 25.1327 | 2.0000 |
| 0.50 | -0.25 | 1.0000 | 157.9137 | 33.5103 | 25.1327 | 1.3333 |
| 0.50 | -0.10 | 1.0000 | 157.9137 | 27.9253 | 25.1327 | 1.1111 |
| 0.50 | 0.00 | 1.0000 | 157.9137 | 25.1327 | 25.1327 | 1.0000 |
| 0.50 | 0.25 | 1.0000 | 157.9137 | 18.8496 | 25.1327 | 0.7500 |
| 0.50 | 0.50 | 1.0000 | 157.9137 | 12.5664 | 25.1327 | 0.5000 |
| 0.50 | 0.75 | 1.0000 | 157.9137 | 6.2832 | 25.1327 | 0.2500 |
| 0.50 | 1.00 | 1.0000 | 157.9137 | 0.0000 | 25.1327 | 0.0000 |

That is Apple's law, and it is two formulas:

```
mass      = 1
stiffness = 4*pi^2 / duration^2          (631.6547 / 157.9137 / 39.4784 / 9.8696 at 0.25 / 0.5 / 1 / 2)
critical  = 2*sqrt(mass*stiffness) = 4*pi/duration
damping   = critical * f(bounce),  f(b) = 1 - b        for b >= 0
                                f(b) = 1 / (1 + b)  for b <  0
```

**The negative branch is measured, not assumed.** The obvious guess `f(b) = 1 - b` for every sign is
right for `b >= 0` and **wrong** for `b < 0`: at `b = -0.5` it predicts 1.5 × critical where the host
answers 2.0. Samples at -0.1, -0.25, -0.5 and -0.75 give 1.1111, 1.3333, 2.0 and 4.0 — that is `1/(1+b)`
to four places — and at `b = -1` it diverges and the host reports `damping = inf`, which is what this file
produces rather than a clamp.

### The two sides, run together

The port's formula and the host's own initialiser, over 4 durations × 11 bounces:

```
   dur  bounce |   host stiff   port stiff |    host damp    port damp
   0.25   -1.00 |     631.6547     631.6547 |          inf          inf
   0.25    0.00 |     631.6547     631.6547 |      50.2655      50.2655
   0.25    0.75 |     631.6547     631.6547 |      12.5664      12.5664
   0.50   -0.50 |     157.9137     157.9137 |      50.2655      50.2655
   1.00    0.25 |      39.4784      39.4784 |       9.4248       9.4248
   2.00    1.00 |       9.8696       9.8696 |       0.0000       0.0000
   … 44 rows in all …
WORST |stiffness| error 0.000000
WORST |damping|  error 0.000000
```

**Zero error on every one of the 44 samples, including both infinities.** That is why the file holds the
formulas and not a table of fitted numbers: a table would agree only at the points it was built from.

### What does NOT raise

`bounce 2.0`, `bounce -1.5` and `duration 0.0` all return a usable object on the host — measured, no
exception and no `NSParameterAssert`. So the port clamps nothing and adds no precondition of its own; a
clamp would be the port answering something the system does not.

### The velocity

`initialVelocity` passes through **exactly**: a velocity of `(2,0)` reads back `(2,0)`, and every zero
velocity reads back `(0,0)`. So it goes to the 13.0 initialiser untouched, unscaled.

## M7. iOS 6.1.3, read without waiting for the whole inventory

`objc-inventory.lua` over the 6.1.3 armv7 cache is a heavy job and this batch's run sat behind other
batches' readers of the same cache for 26 minutes at 0% CPU. Two things were already on disk, so the
6.1.3 answers below come from those and are labelled for what they are:

- `~/.charon/dyld/6.1.3/selectors_armv7.txt` — 113981 distinct selectors of that release, pre-extracted.
- `~/.charon/dyld/4.3/classes_armv7.json` — the 4.3 class-scoped inventory, used below to
  class-scope the six names 6.1.3 answers somewhere.

**The control, in the same file: 8 of 8.** `setFrame:`, `reloadData`, `tintColor`, `title`,
`imageNamed:`, `isHidden`, `text` and `value` are all present, so the reader is looking at the right
thing and a zero on another name is the release's.

### The 54 method rows: 0 present, anywhere

Not one of this slice's 54 method selectors appears in 6.1.3's selector list at all — 0 hits over all
113981 names. That is a stronger statement than the class-scoped one, because it does not depend on
which class carries the name.

### The 61 property rows: 6 names appear somewhere, and class-scoping kills every one

This is the rulebook's own trap, live: *a selector's rung says nothing about its owner*. Six property
rows have an accessor name that 6.1.3 carries **somewhere**:

| row | accessor found in 6.1.3 | class-scoped: is it on THIS class? |
|---|---|---|
| `UIImageConfiguration.locale` | `locale`, `setLocale:` | owner is not even a 4.3 class — another class's selector |
| `UIPageControl.progress` | `progress`, `setProgress:` | **no** on `UIPageControl` in 4.3 |
| `UITextView.borderStyle` | `borderStyle`, `setBorderStyle:` | **no** on `UITextView` in 4.3 |
| `UITextSelectionRect.transform` | `transform`, `setTransform:` | owner is not even a 4.3 class |
| `UIHoverGestureRecognizer.rollAngle` | `rollAngle`, `setRollAngle:` | owner is not even a 4.3 class |
| `UITouch.rollAngle` | `rollAngle`, `setRollAngle:` | **no** on `UITouch` in 4.3 |

Three are a selector belonging to a different class, and three are a name the owner does not answer even
in the release where its owner exists. So all six are `absent`, and had this been read as a bare name
match it would have produced six false claims.

### What is NOT yet measured, and is not claimed

The **44 class and protocol rows** need a class list for 6.1.3, which the flat selector file does not
carry, and the class-scoped 6.1.3 inventory had not returned when this batch's turn ended. The
statement for those 44 rows is therefore only the 4.3 one (**0 present, control 8/8**) plus the host's.
No 6.1.3 claim is made for them here, and the rows stay `absent` on the 4.3 measurement alone.

## M8. The 17.5 feedback generators, and the limit that shapes them

Asked of the host's own UIKit:

| member | host | measured |
|---|---|---|
| `+[UIFeedbackGenerator feedbackGeneratorForView:]` | yes | returns a non-nil **UIFeedbackGenerator**; `isKindOfClass:` YES; **a nil view does not raise** |
| `+[UIImpactFeedbackGenerator feedbackGeneratorWithStyle:forView:]` | yes | returns a non-nil **UIImpactFeedbackGenerator** |
| `-[UIImpactFeedbackGenerator impactOccurredAtLocation:]` | yes | returns |
| `-[UIImpactFeedbackGenerator impactOccurredWithIntensity:atLocation:]` | yes | returns |
| `-[UISelectionFeedbackGenerator selectionChangedAtLocation:]` | yes | returns |
| `-[UINotificationFeedbackGenerator notificationOccurred:atLocation:]` | yes | returns |

Two of those decided the code:

- **A factory builds the class it is called on.** `feedbackGeneratorWithStyle:forView:` answers a
  `UIImpactFeedbackGenerator`, so it is `[[self alloc] initWithStyle:]` and not a hard-coded
  `[[UIImpactFeedbackGenerator alloc] …]`.
- **A nil view is not an error.** The host returns a usable generator, so this file adds no precondition
  of its own.

### What the location does NOT get, stated plainly

This release's haptics are the Taptic Engine's one motor, driven by the port's own
`charon_feedback_play(intensity, milliseconds, count)` → `AudioServicesPlaySystemSoundWithVibration`.
**That call takes an intensity and a duration and nothing else.** There is no position parameter, and
no public mechanism on iOS 6.1.3 to say "vibrate harder on the left of the screen".

So the four location methods **accept the point and ignore it**, and say so in the source. What a caller
gets is the haptic its style asks for, at the same strength wherever on the screen it happened. The
alternative — refusing the point, or pretending to weight it — would be the port answering something the
system cannot. The **intensity** argument *is* honoured, because it maps onto a real parameter: it calls
the port's existing 13.0 `-impactOccurredWithIntensity:` rather than repeating that arithmetic.

The bound view is stored so a factory hands back what it was given. Nothing in this release routes
feedback by view, so the view is **recorded, not obeyed** — which is the honest limit of 17.5's location
API on a motor that takes no position.

## M9. The class-scoped answer at BOTH ends the package deploys on, certified

The class-scoped 6.1.3 inventory arrived (12549 lines, 11378 classes, 1171 protocols), so this section
replaces the weaker M7 for everything it could not reach. Run over the **110 rows of this slice that are
still `absent`** — the 49 this batch moved to `implemented` are not in the question any more:

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/4.3/dyld_shared_cache_armv7   > inv-4.3.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
```

| band end | classes read | rows checkable | **rows carried** | control |
|---|---|---|---|---|
| **4.3** armv7 | 7187 | 96 | **0** | 8/8 |
| **6.1.3** armv7 | 11378 | 96 | **0** | 8/8 |

The control is the same eight selectors in the same file as the zeros (`setFrame:`, `reloadData`,
`tintColor`, `title`, `imageNamed:`, `isHidden`, `makeKeyAndVisible`, `text`, `value` — all present on
both rungs), so the zeros are the releases' and not the reader's.

**This closes the 44 class and protocol rows that M7 could not reach.** A class name belongs to exactly
one class, so for those rows the class-scoped read is exactly the right question, and the answer at both
ends is zero.

`checkable = 96` of 110: the other 14 are rows whose owner is a name that rung has neither a class nor a
protocol for, so `carried_by_release` returns nil and the check does not apply — which is the third
answer, not a pass and not a failure.

### What is still open, and is not claimed

The **12.0 and 16.0 reads had not returned** when this turn ended (12.0 started 15:27 and the arm64e
rungs behind it are slower still). Those two are the band's other ends, so the honest statement for them
today is: **not yet measured**. The rows they would bear on stay `absent` on the 4.3 and 6.1.3 evidence
alone, which is the strongest evidence actually in hand — a row that survives both ends the package
deploys on cannot fire `held` for a deployment at or below them.

## M10. `-performPrimaryAction` (17.4) fires the UIAction list and nothing else

The method's name suggests "whatever this control's main action is". What the host does is narrower, and
the measurement is what the implementation is:

```
UIControlEventPrimaryActionTriggered = 0x2000    UIControlEventTouchUpInside = 0x40

1. target/action registered ONLY for the primary event    -> ran 0 times
2. addAction:forControlEvents: for the primary event      -> ran 1 time
3. target/action registered for touch-up-inside only       -> ran 0 times
4. UIAction registered for touch-up-inside                 -> ran 0 times
5. UIAction on the primary event, then the same call twice:
     -performPrimaryAction                                 -> ran 1
     -sendActionsForControlEvents:UIControlEventPrimaryActionTriggered -> ran 2
```

So it fires the **14.0 UIAction list** for `UIControlEventPrimaryActionTriggered` and nothing else — not
the target/action list, and never touch-up-inside. **Case 5 is the decisive one**: the same `UIAction`
fired once from each entry point, which makes the two calls the same call. So the whole object is

```objc
- (void)performPrimaryAction
{
    [self sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
}
```

over machinery `UIControl+Actions14.m` already built, and the event value is the release header's own
(0x2000), not a literal this file chose.

A control with **no** primary action does not raise — measured, the host returns quietly — so no
precondition was added.

### Why it is its own file

`UIControl+Actions14.m` is 14.0 (`addAction:forControlEvents:`, `initWithFrame:primaryAction:`). This is
17.4. One `.m` holds one release's API, and `release-split.lua` reads band points only, so a single file
holding both would pass the tool and only a reader would catch it.

## M11. Two more 17.4 methods, one scroll view and one drag item

### `-stopScrollingAndZooming` (17.4)

Measured on a 200x200 scroll view with 800x800 of content:

```
-[UIScrollView stopScrollingAndZooming] = 1
after -setContentOffset:(100,100) animated:YES -> offset = (100,100)
after -stopScrollingAndZooming                 -> offset = (100,100), zoomScale = 1.00
a second call, with nothing animating            -> NO raise
```

So it **stops the motion where it is**: the offset does not move and the zoom scale is not reset. The
implementation is the release's own `-setContentOffset:animated:NO`, which lands on the offset the scroll
has reached — the measured behaviour, not a reimplementation of physics.

Its header names three clauses, and only the first is reachable here:

1. stops any scrolling or zooming, programmatic or from the user — **reachable**, and is what the port does;
2. stop at the current offset during deceleration, or move within the valid range when bouncing —
   **not reachable**: there is no separate deceleration the port owns, and bouncing is the release's own
   physics rather than something to reimplement;
3. if paging is enabled, align the offset with a page boundary — **not reachable**: the port does not
   own a page-boundary alignment, and inventing one would be a second scroll implementation.

### `-setNeedsDropPreviewUpdate` (17.4)

Measured on a `UIDragItem` made with `initWithItemProvider:` and no drop animation anywhere:

```
responds = 1
with no drop animation in progress -> NO raise (quiet)
twice more                           -> NO raise
previewProvider set beforehand       -> STILL SET afterwards
```

The header says the same thing: *"If no active drop animation is in progress for the specified item,
then nothing happens."* And a drop animation is the **system's**: a drag that leaves the application
needs the system drag service, which `UIDragItem.m`'s own header says this release cannot do. So the
condition the header names is never true here, and a quiet method is what the header prescribes for that
case — not a stub standing in for unfinished work.

It does **not** call the `previewProvider`: the header says the provider is called when and if the system
asks, and calling it here would be the port driving a system callback on its own initiative. The provider
is left exactly where the caller put it, which is measured, not assumed.

### Why two files and not two appended methods

`UIDragItem.m` is **11.0** API and `UIScrollView+ContentAlignment17.m` is **17.4** geometry. A `.m` holds
one release's API, and `release-split.lua` reads band points only — folding these into their neighbours
passes the tool and only a reader catches it.

## M12. Three band ends measured, certified, control 8/8 at each

The 12.0 arm64 inventory arrived (74618 lines, 63192 classes, 11426 protocols). With M9's 4.3 and 6.1.3
reads, three of the band ends are now measured and the fourth (16.0 arm64e) is still reading.

| band end | arch | classes | protocols | rows checkable | **carried** | control |
|---|---|---|---|---|---|---|
| **4.3** | armv7 | 7187 | — | 96 | **0** | 8/8 |
| **6.1.3** | armv7 | 11378 | 1171 | 96 | **0** | 8/8 |
| **12.0** | arm64 | 63192 | 11426 | 93 | **0** | 8/8 |

Run over the rows still marked `absent` at the time of each read, with the same `carried_by_release`
re-implementation (M1) and the same eight controls read from the same file as the zeros.

`checkable` falls from 96 to 93 between 6.1.3 and 12.0 because three rows' owners are names 12.0 has
neither a class nor a protocol for either — which is the check not applying, not a pass.

**12.0 matters more than its position suggests.** It is the last release held before the ladder's jump to
16.0, so it is the band end that says whether a 17.x name is already there "after 12.0, by 16.0". It
carries none of this slice's 107 remaining names.

## What is still open, and is not claimed

The **16.0 arm64e** read started at 15:35 and had not returned. That cache is split into ~45 parts and is
the slowest of the four. So the honest statement for it today is **not yet measured**, and no row in this
file rests on it. Everything above is reproducible from the three commands in M1 and M9 with the
`CHARON_ROOT` prefix each one prints.

## M13. The 16.0 arm64e band end, and TWO ROWS THE SDK MIS-DATES

The last band end arrived (168686 lines, 143137 classes, 25549 protocols). Control 8/8 as at every other
rung — and the run also carries **negative** controls, which is what makes the two hits below real:

```
band end   arch     classes   protocols   checkable   carried   control
4.3        armv7    7187      -           96          0         8/8
6.1.3      armv7    11378     1171        96          0         8/8
12.0       arm64    63192     11426       93          0         8/8
16.0       arm64e   143137    25549       93          2         8/8
```

**Negative controls, in the same file:** `UIPencilHoverPose`, `UICanvasFeedbackGenerator`,
`NSSymbolContentTransition`, `UIPageControlTimerProgress`, `UITextSelectionDisplayInteraction`,
`UIWindowSceneProminentPlacement`, `UITextItemMenuPreview` are all **absent** from 16.0. So the reader
discriminates: it finds the two it reports and misses the seven it should.

### `UIContentUnavailableConfiguration` and `UIContentUnavailableView` are in iOS 16.0

Both rows say `introduced: 17.0`, and the SDK agrees:
`UIContentUnavailableConfiguration.h:23` and `UIContentUnavailableView.h:16` both carry
`API_AVAILABLE(ios(17.0), tvos(17.0))`. **The cache of the release that introduced them disagrees**, and
they are not stubs:

| class | class methods | instance methods |
|---|---|---|
| `UIContentUnavailableConfiguration` | 6 (`emptyConfiguration`, `loadingConfiguration`, `searchConfiguration`, `emptyProminentConfiguration`, `emptyExtraProminentConfiguration`, `supportsSecureCoding`) | **33** |
| `UIContentUnavailableView` | 0 | **36** (`_applyConfiguration:`, `_button`, `_activityIndicator`, …) |
| `UIContentUnavailableTextProperties` (already `implemented`) | 1 | **26** |

This is the same shape the 16.0 batch recorded for `UICalendarViewDelegate` and `UISceneWindowingBehaviors`
(UIKit16Absence.md): the SDK's `introduced` is not corroborated by the cache of the release that
introduced it. **The row is not smoothed over** — what each row claims is the RELEASE it is checked
against, and 16.0 is not one this package deploys on, so the verdict stays `absent` and the
discrepancy is recorded here instead of being hidden by editing a date.

What it costs: on a deployment at or above 16.0 these two names are already answered by the release, which
is precisely what the gate's `held` check exists to notice. The port does not carry them (the earlier
band's facts page, M3, says why: `UIContentUnavailableConfiguration` needs `UIButtonConfiguration`, which
this library does not carry, and `UIContentUnavailableView` is built over it). So a 16.0-or-later band
must not link the port's copies — and because neither is `implemented`, there is nothing for it to link.

## M14. `UIImageConfiguration`'s locale (17.0), measured field by field

Asked of the host's own UIKit under Mac Catalyst, `arm64-apple-ios15.0-macabi`, compiled with the same flags
every other probe on this page used. The seven rows of this family were `absent` with the SDK's own declaration
as their only `source`; these are the answers that decide what they are, and the object is
`UIKit/UIImageConfiguration+Locale17.m`.

```
+configurationWithLocale: fr_FR -> locale=fr_FR
nil -> description unspecified, locale (null)
+configurationWithTraitCollection: dark -> traits=(UserInterfaceStyle = Dark) locale=(nil)
nil traits -> unspecified
a==b 1  hash same 1
round trip locale=fr_FR equal? 1        (NSKeyedArchiver -> NSKeyedUnarchiver)
fresh: locale=(nil) description=unspecified
-configurationWithLocale: fr_FR -> locale=(...) same? 0
locale then trait -> traits=(UserInterfaceStyle = Dark), locale=(...) locale=fr_FR
fresh applying locale one -> locale=(...) locale=fr_FR same? 0
```

Four things in there decided the implementation rather than confirming it:

- **The locale is a field, not a trait.** `+configurationWithTraitCollection:` prints `locale=(nil)` and reads
  nil from the getter, while `+configurationWithLocale:` prints its locale and no traits. So the two are the
  release's own two shapes, and each constructor keeps the other half rather than resetting it.
- **Both constructors return a NEW object** (`same? 0` both ways), and the receiver is never mutated. A
  configuration set to the locale it already holds is the receiver, which is the same comparison with nil on
  both sides.
- **The applying route takes the locale.** `fresh applying locale one -> locale=(...), same? 0`: the base
  class's own `charon_isUnspecified` / `charon_applyFieldsOfConfiguration:` hooks are the seam, and the port
  uses them rather than reimplementing `-configurationByApplyingConfiguration:`.
- **The host's hash is per object, not per value.** Two equal configurations hashed differently (M14b in the
  table above the file's own record of it). That breaks `NSSet` and `NSDictionary`, so the port keeps the
  value-based hash every configuration type in this tree already uses, and says so in the file. Copying a
  defect is not the same as being faithful.

### Why the object is a subclass under a category, measured rather than chosen

In `@implementation Base (Cat)`, `[super copyWithZone:]` resolves against **NSObject**, not against Base, and
clang says so — `no visible @interface for 'NSObject' declares the selector 'copyWithZone:'`, plus
`category is implementing a method which will also be implemented by its primary class`. So a category that
overrode `-copyWithZone:` would answer NSObject's copy and **lose the traits**, which is worse than not
carrying the locale at all. A subclass's `[super ...]` reaches the class it extends, so the five chaining
methods live in `CharonLocaleConfiguration` — Charon-prefixed, so `internal_symbol` keeps it out of the
exports and `carried_api` keeps its members out of the registry check — while the accessor pair and the two
constructors, whose registry rows name `UIImageConfiguration` itself, are the category. The storage is one
associated object, because a category cannot add an ivar to a class this port already defines wholesale.
`UIImageSymbolConfiguration.m` is the shape this tree already uses for the same problem.

One thing this file had to declare to compile at all: the base class's `-isEqualToConfiguration:` is defined
in `UIImageConfiguration.m`, which no other file's compiler reads, and the only declaration of that name
anywhere in the SDK is `UIImageSymbolConfiguration.h`'s, with the narrower parameter. So `[super ...]` is a
type error until the base class's own spelling is declared. It is declared in a separate, empty category so
that declaring it does not oblige this file to implement it.

## M15. The three per-trait constructors of 17.0, measured

Same probe, same target. The three rows were `absent` on the SDK's declaration alone.

```
imageDynamicRange high     -> <UITraitCollection: 0x…; ImageDynamicRange = 2>
imageDynamicRange standard -> <UITraitCollection: 0x…; ImageDynamicRange = 0>
sceneCaptureState active   -> <UITraitCollection: 0x…; SceneCaptureState = 1>
typesettingLanguage @"fr-FR" -> stored, and objectForTrait: reads an __NSCFConstantString back, equal
bogus NSString             -> no raise, stored as given
NSNumber                   -> no raise, stored as an __NSCFNumber
nil                        -> no raise, holds (null)
dynamicRange 99            -> ImageDynamicRange = 99, no exception
sceneCapture 99            -> SceneCaptureState = 99, no exception
enum: unspecified=-1 standard=0 constrainedHigh=1 high=2
fresh collection's sceneCaptureState = -1 (UISceneCaptureStateUnspecified)
```

**None of the three validates its argument, so neither does the port.** An out-of-range number is stored and
read back; an NSNumber handed to the language constructor is stored as one. A precondition would be the port
answering something the system does not. The single exception is the measured one: a **nil** language sets no
trait at all, so the collection answers the trait class's own default rather than a stored nil — which is why
the constructor passes its argument straight through to the store instead of special-casing nil.

Each constructor is one call to the store this tree already has — `+traitCollectionWithNSIntegerValue:forTrait:`
and `+traitCollectionWithObject:forTrait:` — so there is no second implementation of "put this value under that
trait's name". The object is `UIKit/UITraitCollection+TraitConstructors17.m`.

## A stale blocker in M3, corrected

M3 says the `UIContentUnavailableConfiguration` and `UIContentUnavailableView` rows are absent because the
configuration "needs `UIButtonConfiguration`, which this library does not carry". **That is no longer true**:
`UIButtonConfiguration` is carried — `UIKit/UIButtonConfiguration.m` implements the eight 15.0 constructors and
`registry/UIKit/ios15-16.json` carries its class row as `implemented`, and `UIBackgroundConfiguration` beside it
is a category over the release's own. The two content-unavailable rows are therefore not blocked on substrate
any more; they are blocked only on writing them, which is the next piece of work on this slice and is not part
of this commit. Nothing is claimed for them here beyond removing the stale reason.

## M16. The symbol-effect rows, and what "absent" is a claim ABOUT here

Fifteen rows of the symbol-effect family — every `removeSymbolEffect…` and `removeAllSymbolEffects…` on
`UIBarButtonItem` and `UIImageView`, plus the two types they name — sat `absent` with
`source: "SDK 26, Mac Catalyst, UIKit"`, which is the SDK's own declaration and not a measurement. They now
name what was measured.

**The band ends.** Every one of them is `0 carried` at 4.3, 6.1.3, 12.0 and 16.0, read class-scoped from each
release's own cache with the same eight control selectors at 8/8 in the same run (M1, M9, M12, M13). A
release with no SF Symbols cannot carry a symbol effect.

**The parameter, which is the part that decides whether a port could ever write them.** Every one of those
methods takes an `NSSymbolEffect`. Measured on this machine's 16.4 build SDK: the UIKit headers hold **no**
`NSSymbol*` declaration at all — `NSSymbolEffect.h` exists only under
`System/Library/Frameworks/Symbols.framework/Headers`. And `NSSymbolEffect` has **no registry row anywhere in
this repository** (every `registry/*/*.json` searched) and `registry/Symbols/` does not exist.

So writing these methods would mean inventing a class in a framework this port does not carry, with no row to
record it against — and `check_registry` reads a built class and finds no entry, which is precisely the
`built, but no entry in registry/` failure. That is why the `remove…` half is `absent` with the substrate named
rather than quietly implemented against a type the port invented: a method whose only argument cannot be spelled
is not an API, it is a signature.

**What a caller gets**, which is what `effect` now says for all fifteen: `instancesRespondToSelector:` answers
NO and an unchecked call raises, and — for the `remove…` half — there is no effect to remove because there is
no effect to add.

**Not claimed:** anything about how a symbol effect would animate here. There is no system side to compare
against and no glyph to draw, so nothing is said about it.

## M17. Symbol content transitions, and the dynamic-range family: what was measured and what was not

Thirteen more rows, `setSymbolImage:withContentTransition…` on `UIBarButtonItem` and `UIImageView`,
`NSSymbolContentTransition`, the two `symbolAnimationEnabled` flags, and the five dynamic-range rows.

**The content transitions and the two flags** are the same substrate as M16 and are recorded for the same
reason: the release carries no symbol before 13.0 and no content-transition type before 17.0, and the
`symbolAnimationEnabled` flags govern the effect system, which is 17.0. 0 carried at all four band ends, control
8/8 in each run.

**The dynamic-range family is the one place in this slice where the reason is a limit of the release rather than
a missing name, and it is worth being exact about what was actually measured**, because the obvious reason —
"these devices have no HDR screen" — is a hardware claim this batch did **not** measure and does not make.

What was measured:

- 0 carried at 4.3, 6.1.3, 12.0 and 16.0, class-scoped, control 8/8 in each run (M9, M12, M13).
- **The two SDKs on this machine, read side by side**: `iPhoneOS16.4.sdk` has no `UITrait.h` at all, and so
  declares neither `UITraitImageDynamicRange` nor the `UIImageDynamicRange` enumeration, while the 26 headers
  declare both. The 16.4 SDK *does* declare `UIImage.isHighDynamicRange` (17.0-gated), which is why the name
  appears in the registry at all and why a reader must not mistake an SDK declaration for a release capability.

What that establishes: the release expresses dynamic range **only** through a trait that arrived in 17.0, so
`isHighDynamicRange`, `imageDynamicRange`, `preferredImageDynamicRange` and `supportsHighDynamicRange` have
nothing to express on 6.1.3 or 4.3, and `imageRestrictedToStandardDynamicRange` has nothing to restrict away
from. It is the release's vocabulary that is missing, not a claim about its screens.

**Not claimed:** whether any device of 6.1.3 or 4.3 could display high dynamic range. That was not measured,
and a reason built on it would be an assertion wearing a measurement's clothes.
