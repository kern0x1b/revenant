# UIWindowSceneGeometry and -[UIWindowScene effectiveGeometry], iOS 16.0

## What the header says, and what that leaves

`UIWindowSceneGeometry.h` on iOS carries exactly one value:

```objc
@property (nonatomic, readonly) CGRect systemFrame API_AVAILABLE(macCatalyst(16.0)) API_UNAVAILABLE(ios, watchos, tvos);
@property (nonatomic, readonly) UIInterfaceOrientation interfaceOrientation API_UNAVAILABLE(tvos);
```

`systemFrame` is unavailable on iOS, so on this platform the object is a readonly value over one
resolved `interfaceOrientation` — and the class's own comment says as much: "Geometry objects are
readonly and should only be created by the framework. To set a window scene's geometry, see
UIWindowSceneGeometryPreferences and -[UIWindowScene requestGeometryUpdateWithPreferences:]."
`-[UIWindowScene effectiveGeometry]` is "Provides the current resolved values for the window scene's
geometry in system space."

The row this object answers described the earlier draft of that class, which also carried a coordinate
space and size restrictions; on iOS 16 those are 13.0 members of `UIWindowScene` itself
(`coordinateSpace`, `sizeRestrictions`), not of this object, and the port answers both of those in
`UIWindowScene.m`. So this object is built from one of the three values the old row named, and the
other two were never part of it on iOS.

## What the release carries, measured

Neither band end has the class or the accessor, and neither has `UIWindowScene` at all — scenes
arrived in iOS 13 and the two band ends are older than that:

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/12.0/dyld_shared_cache_arm64 > inv-12.0.tsv
grep -c $'\tUIWindowScene\t' inv-12.0.tsv
```

```
6.1.3   classes 11378, of which UI* 705    UIWindowScene: absent, UIWindowSceneGeometry: absent
12.0    classes 63192, of which UI* 1741   UIWindowScene: absent, UIWindowSceneGeometry: absent
16.0    classes ...                        UIWindowScene: present, -effectiveGeometry present; UIWindowSceneGeometry present
```

The reader is certified by the same rows it reports on: `UIWindow`, `UIViewController` and
`UIPrintFormatter` are all in the 6.1.3 and 12.0 dumps (a run that found nothing at all would be
reported `CONTROL FAILED`, and `UIKit16Absence.md` carries that run with its own control of 2926 UI
names). The 16.0 line is the corroboration that these are 16.0 names and not port inventions.

## What the port does

`UIWindowSceneGeometry` is a real, allocable class of the port's own with one resolved orientation,
copied by `-copyWithZone:` and printed by `-description`. `-init` is unavailable exactly as the header
says it is, so the value is made through `-initCharonWithOrientation:`, the same shape
`UIWindowSceneGeometryPreferences.m` uses for its own unavailable `-init`.

`-[UIWindowScene effectiveGeometry]` returns a snapshot built from `-[UIWindowScene interfaceOrientation]`,
which `UIWindowScene.m` answers from `[UIApplication sharedApplication].statusBarOrientation`. A new
object per call, because the header says "the current resolved values" and the port's scene can change
orientation between two calls.

## What this object does not do

`-[UIWindowScene requestGeometryUpdateWithPreferences:errorHandler:]` is **not** carried, and its row
stays `absent`. This release rotates the device's own way — `supportedInterfaceOrientations` and
`+[UIViewController attemptRotationToDeviceOrientation]` — so honouring a requested orientation mask
means changing what the top view controller supports, and deciding what to do while the device is not
held that way is a decision about rotation the port has no release to take it from. Carrying a getter
that reports the resolved orientation and no way to ask for one is not a gap in this object; it is the
other half of the pair, and it is a separate row with its own reason.