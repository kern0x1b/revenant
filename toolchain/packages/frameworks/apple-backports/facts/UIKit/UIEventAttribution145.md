# UIEventAttribution and UIEventAttributionView, iOS 14.5

Nine rows: two classes, two constructors and five readonly properties. What the host's own UIKit answers was
measured first, on the host's UIKit under Mac Catalyst **27.0, build 26A428**, through the probe in
`.agent-work/runs/b2/` and held to the port by
`tests/backports/host/uikit2/eventattribution_test.m`, run by the `eventattribution` group in
`tests/backports/host/uikit2/run.sh`. The port is
`packages/a/apple-backports/UIKit/UIEventAttribution145.m`.

Unlike the 17.0 empty-state family, this group's **system side comes out of a framework**: both classes are
in the 16.4 SDK this package compiles against, and both headers are byte for byte the 26.2 ones after the
comments and the availability macros are stripped, so nothing is redeclared here — exactly as
`UIButtonConfiguration.m` redeclares nothing for `UIButtonConfiguration`.

## M1. What the host answers

### The five values

`-[UIEventAttribution initWithSourceIdentifier:destinationURL:sourceDescription:purchaser:]` stores the four
values it was given, and `reportEndpoint` — `readonly` with **no** initialiser argument — is nil:

```
sourceIdentifier=7
destinationURL=https://example.invalid/a
sourceDescription=a source
purchaser=a purchaser
reportEndpoint=(nil)
```

The three object properties are `copy`, and the case asks for **identity** and not only equality, because
`-copyWithZone:` on an immutable `NSURL` or `NSString` is the same instance and that is what both sides
answer: "the destination URL is the URL it was given: same".

### `-copy` is the receiver, and that is measured twice over

```
copy is same: 1
copyWithZone: is same: 1
array copy holds same: 1
```

The third line is the control: an `NSMutableArray` holding the attribution, copied, holds the same instance.
So `UIEventAttribution` is an **immutable value object whose copy is itself**, on both `-copy` and
`-copyWithZone:`.

The first version of the port built a new object through the designated initialiser, the way a mutable value
object is copied. The case `a copy is not its receiver` is what caught it, and **the case was right**: a
value object that answers a second instance for a copy is not the class the release has. The port now
answers `self`.

### `-init` and `+new` do not refuse, and an earlier reading of this file said they did

Both are `NS_UNAVAILABLE` in the SDK's header — an attribution has no meaning without the URL it points at.
The port cannot remove `NSObject`'s two, and measured, the host's do not refuse either:

```
+[UIEventAttribution new] returned <UIEventAttribution: 0x75830881e0>
-init returned <UIEventAttribution: 0x7583088240>
-init object: id=0 url=(nil) desc=(nil) purchaser=(nil) endpoint=(nil)
```

**A first version of `UIEventAttribution145.m` had `+new` raise**, on the strength of a probe that sent
`new` to an **instance** — where no such instance method exists, so the `NSInvalidArgumentException` was the
probe talking to itself and not the host refusing. The corrected measurement is the three lines above. This
is recorded because it is the second time in this family that a probe answered the question to itself (the
first was `-initWithListAppearance:` sent to a class instead of an instance), and because the row now says
what the release does rather than what a mistaken reading of it did.

### The view

Measured on the host: `opaque YES`, `userInteractionEnabled NO`, background colour nil, no subviews, not an
accessibility element, alpha 1. So it is an inert, non-interactive rectangle as far as this release can
tell, and that is what the port is — the two answers that differ from `UIView`'s own defaults (`opaque` is
`NO` and `userInteractionEnabled` is `YES` by default) are written in both initialisers.

There is nothing more to measure and nothing more to draw: the only thing that ever put an attribution on
screen was a link preview, and a link preview is what SafariServices or a link-preview extension hands the
system. Neither exists on 6.1.3 or 4.3 and this library builds no SafariServices. The `UIEventAttribution`
rows are what a caller on this release can do — build one from four values, read them back, copy it — and
every row says that rather than claiming a preview flow this release has no path to.

## What is NOT carried, and why

- **`-setReportEndpoint:`** — the property is `readonly`, so a setter would answer a selector no Apple
  header declares, which is what `UIKit26_0.m`'s note on `UIDeferredMenuElement`'s identifier calls a worse
  answer than none. It is also unreachable: `reportEndpoint` has no initialiser argument and its only
  producer is the system opening a link preview. So the getter answers nil for every object a caller can
  build here, which is what the host answers for a caller-built one too.
- **`UIEventAttribution`'s producer.** Nothing in this port creates one. The rows are about the class, not
  about a flow.

## The red control for this group

`tests/backports/host/uikit2/red-control.sh` plants three values now, one per section, and each plant has to
be reported by name:

```
== the unplanted attribution group, which must be green
   eventattribution: exit=0
== planting an identifier no caller passed, in the same scratch copy
   eventattribution: exit=2
     FAIL the source identifier reads back: port 8 != system 7
   the planted attribution run names the source-identifier key
RED CONTROL OK: green before, red after, naming the key, tree untouched
```

The plant is `_sourceIdentifier = sourceIdentifier;` becoming `+ 1` — a **value** on a key the case asserts
on, so the group still builds and still links; a plant that broke the build would prove the compiler works,
not that the comparison works. It is made in the scratch copy reached through `UIKIT2_SOURCES` and the
control asserts the repository's own file is byte identical afterwards, so a control that forgot to copy
could not pass by editing the tree.

## Two defects this group found, both in the port and both by the case

1. **`-isEqual:` answered NO for two equal attributions.** Sending a message to a nil receiver answers NO,
   so `[_reportEndpoint isEqual:that->_reportEndpoint]` is NO whenever either side is nil — and
   `reportEndpoint` is nil on **every** object a caller can build, because it is `readonly` with no
   initialiser argument. So no two attributions ever compared equal. The fix is two `static` helpers written
   `a == b || [a isEqual:b]`, which is the only form that says two nils are equal. The case
   `two attributions with the same values are equal` is what caught it.
2. **`+new` sent `-init` to the class object.** The first version was `return [self init]`, and inside a
   class method `self` is the class, so the run died with `cannot init a class object`. Fixed to
   `[[self alloc] init]`. A case that exercises a row rather than reading it is what this is for.

Neither was found by reading the code; both were found by running the comparison.