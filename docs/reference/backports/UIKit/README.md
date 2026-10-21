# The UIKit Swift overlay: the surface's Swift constants and cases

The UIKit overlay is the part of UIKit's API that exists only in Swift: constants and cases that no Objective-C file can
declare. It is a series of patches in `packages/s/swift-runtime/patches/uikit/`, applied to the overlay file that
`packages/s/swift-runtime/xmake.lua` builds the `UIKit` Swift module from.

**Where it goes.** The recipe fetches the `uikit` tree at `swift-5.2.5-RELEASE`, commit `71d85a7c28eed8f46241649a723ddf23989139c6`,
and applies `patches/uikit/*.patch` in order before `build_overlay`. The first patch,
`a-uikit-surface-constants-and-cases.patch`, appends the constants and cases to `stdlib/public/Darwin/UIKit/UIKit.swift`.
The overlay of swift-5.2.5 declares none of these types, so nothing collides with what it already has.

**Two shapes.** The SDK's overlay gives a nested Swift name to a type whose Objective-C spelling is a top-level enum: the
Objective-C enum `UIButtonConfigurationCornerStyle` is `UIButton.Configuration.CornerStyle` in Swift. The port's overlay follows
the same shape:

- where the port's headers declare the enclosing Objective-C class, the overlay carries a namespace type of its own and a
  typealias on the class, which is what makes the nested name resolve
  (`extension UIButton { public typealias Configuration = RevenantUIButton.Configuration }`);
- where the headers declare no such class at all (the type is native Swift in UIKitCore and has no Objective-C spelling),
  the namespace is declared outright.

A typealias on a class that the headers do not carry does not compile, so the overlay declares only the names whose
enclosing class the port's headers provide.

**What is not claimed.** Only the cases the patch names. A type's `==`, its `hash(into:)` and its `init(rawValue:)` are
not part of it, and neither are the types its payloads point at (`UITextFormattingViewController.TextList`, `Highlight`,
`TextAlignment`, `UITab`).

**Source.** The case names and their payloads are the SDK's own, read from the SDK's
`UIKit.framework/Modules/UIKit.swiftmodule/arm64e-apple-ios.swiftinterface`, not typed by hand. Each patch is generated with
`git diff` against the file the recipe fetches, because the series applies in order, and a diff taken against a base the
recipe has already patched would apply at an offset.

**The mark on `UIPointerEffect`.** Its four cases take a `UITargetedPreview`, which the SDK's UIKit marks
`API_AVAILABLE(ios(13.0))` (`UITargetedPreview.h`). The overlay declares the enum with the release the SDK 26.2 interface
gives it, `@available(iOS 13.4, *)`, and `packages/s/swift-runtime/xmake.lua` lowers that mark where the UIKit backports are
linked (its `gsub` on `public enum UIPointerEffect`, which asserts that the mark is there to lower). The release marks the other
declarations carry come from `the-overlay-of-uikit-says-which-release-its-types-came-with.patch`. Without the lowering, a program built for iOS 6
cannot name the type; with it, the names compile where the UIKit backports are linked.

**Not kept.** The earlier typecheck counts of the overlay (the number of rows that compiled, and the list of classes each
waiting row was missing) came from a checklist, a registry and a typecheck script that are no longer in the tree, so they
are not restated here.
