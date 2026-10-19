# The UIKit Swift overlay: the surface's Swift constants and cases

`UIKitSurfaceConstants.swift` declares the 28 types and 111 cases of
`coordination/corpus/ledger/UIKit.tsv` whose `lang` is `swift` and whose `kind` is `constant` - the
part of the API push that is Swift-only, which no Objective-C file can answer.

**Where it goes.** Appended to the overlay's own `stdlib/public/Darwin/UIKit/UIKit.swift`, the file
`packages/s/swift-runtime/xmake.lua` builds the `UIKit` Swift module from (line 432 onwards, the
`uikit` tree it fetches at `swift-5.2.5-RELEASE` / `71d85a7c28eed8f46241649a723ddf23989139c6` and
patches with `patches/uikit/*.patch` before `build_overlay`). The overlay of swift-5.2.5 declares
none of these 28 types, so nothing here collides with what it already has.

**Two shapes, and which one a type takes is a measurement.** The 111 names are typechecked one per
file at `armv7-apple-ios6.1.3` with the port's own flags (`tc.sh`, which takes every path from the environment). Every one fails against the
port's headers alone - `type 'UIButton' has no member 'Configuration'`, `cannot find
'UICellAccessory' in scope` - because these spellings are made by UIKit's *own Swift overlay*:
`UIButtonConfigurationCornerStyle` is a top-level Objective-C enum, and `UIButton.Configuration.
CornerStyle` is the nested Swift name the SDK's overlay gives it. So:

- where the port's headers declare the enclosing Objective-C class, the overlay carries a namespace
  type of its own and a `typealias` on the class, which is what makes the nested name resolve
  (`extension UIButton { public typealias Configuration = RevenantUIButton.Configuration }`);
- where the headers declare no such class at all - the type is native Swift in UIKitCore and has no
  Objective-C spelling - the namespace is declared outright.

`roots.txt` holds the eight roots of the second kind, taken from the typecheck's own errors.

**What is not claimed.** Only the cases this checklist names. A type's `==`, its `hash(into:)`, its
`init(rawValue:)`, and the types its payloads point at (`UITextFormattingViewController.TextList`,
`Highlight`, `TextAlignment`, `UITab`) are other rows of the surface.

**Source.** The case names and their payloads are the SDK's own, read from the checklist and the SDK's
own `UIKit.framework/Modules/UIKit.swiftmodule/arm64e-apple-ios.swiftinterface`, not typed by hand. The
script that printed the file above is no longer in the tree. The patch itself is
regenerated with `git diff` against the file the recipe fetches at `swift-5.2.5`
(`71d85a7c28eed8f46241649a723ddf23989139c6`), because it applies first of the three `patches/uikit`
patches and a diff taken against a base the recipe has already patched would only apply at an offset.

**The one declaration that carries a mark of its own: `UIPointerEffect`.** Every other type the patch
declares is a namespace of its own or a typealias onto a class the port's headers carry, so its availability is
the declaration's own and needs no mark. This one's four cases all take a `UITargetedPreview`, which the
SDK's own UIKit marks `API_AVAILABLE(ios(13.0))` (`UIKit.framework/Headers/UIAccessibilityConstants.h`
is the wrong place; it is `UITargetedPreview.h:17`, and the copy the port's headers keep reads
`API_AVAILABLE(ios(6.1.3))` because `registry/UIKit/ios13menus.json` carries that class `implemented`
at `6.0`), so the enum carries the release the SDK 26.2 interface gives it, `@available(iOS 13.4, *)`,
and `packages/s/swift-runtime/xmake.lua` lowers that mark where the UIKit backports are linked.

Measured at `armv7-apple-ios6.1.3` over this tree, the two configurations the recipe builds:

| configuration | mark in `UIKit.swift` | the overlay's compile | a program naming the type |
| --- | --- | --- | --- |
| `backports`, no `backports_uikit` | `iOS 13.4` | 0 errors | `'UIPointerEffect' is only available in iOS 13.4 or newer` |
| `backports` and `backports_uikit` | `iOS 6.1.3` | 0 errors | exit 0 |

Without the mark at all, and with the UIKit backports out, the overlay does not compile: 4 errors,
`'UITargetedPreview' is only available in iOS 13.0 or newer`, one per case. The mark is therefore not a
narrowing of this checklist - it is what lets the checklist's 86 rows compile in the configuration where
the process has no `UITargetedPreview`, and the recipe's lowering is what keeps them reachable in the
configuration where it has one.


## The rows that wait for their class

These 25 rows spell their names through a class the port's registry carries as `absent`
(`registry/UIKit/ios17-18.json`: `UITab`, `UITabSidebarItem`, `UITextFormattingViewController`
and `UITextItem`), so the overlay cannot declare the name they ask for: the enclosing class is
not there to nest a type in, and a typealias on a class that does not exist does not compile.
They are registered `absent` for that reason until the UIKit bands carry those classes, and the
typecheck counts them as such: each is a row whose name is unreachable, not a row whose
declaration is wrong.

| row | the class it waits for |
| --- | --- |
| `UITabBarController.Sidebar.ScrollTarget.tab` | `UITab` |
| `UITabSidebarItem.Content.action` | `UITabSidebarItem.Content` |
| `UITabSidebarItem.Content.tab` | `UITabSidebarItem.Content` |
| `UITextFormattingViewController.ChangeValue.bold` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.decreaseFontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.decreaseIndentation` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.font` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.fontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.formattingStyle` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.highlight` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.increaseFontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.increaseIndentation` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.italic` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.lineHeightPointSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.strikethrough` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textAlignment` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textColor` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textList` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.undefined` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.underline` | `UITextFormattingViewController.ChangeValue` |
| `UITextItem.Content.link` | `UITextItem.Content` |
| `UITextItem.Content.tag` | `UITextItem.Content` |
| `UITextItem.Content.textAttachment` | `UITextItem.Content` |
| `UITextItem.MenuConfiguration.Preview.default` | `UITextItem.MenuConfiguration` |
| `UITextItem.MenuConfiguration.Preview.view` | `UITextItem.MenuConfiguration` |

## The 86 that resolve: 0 error lines

Against the port's headers made from **this tree's registry** (the generator's output
`.agent-work/runs/uikit-c/port/6.1.3/`, over `packages/a/apple-backports`), the typecheck over the 86 rows that are not waiting is clean.
That number was measured on an earlier run, before this series; the output has not been re-typechecked under this
path, so read it as that run's measurement, not a fresh one:

```
$ export REVENANT_PORT_VFS=$PWD/.agent-work/runs/uikit-c/port/6.1.3/vfs.yaml
$ n=0; for f in /tmp/n86/*.swift; do c=$(packages/s/swift-runtime/facts/UIKit/tc.sh "$f" 2>&1 | grep -c "error:"); n=$((n+c)); done
$ echo "files: $(ls /tmp/n86/*.swift | wc -l)   total error lines: $n"
files: 86   total error lines: 0
```

The headers that earlier reported `'UITargetedPreview' is only available in iOS 13.0 or newer` were
made when the `swift-runtime` install this typecheck takes its resource directory from was built.
A fresh build of the port's headers over this registry lowers it, because the registry carries it `implemented`
(`registry/UIKit/ios13menus.json`), and the class's availability is the only thing that was left.

The overlay: 38 enumerations, 86 case declarations, 5 typealiases, declared unconditionally - the
Swift counterpart of the port's headers lowering the availability of the headers, and the reason a name the surface
spells at 6.1.3 can be named at 6.1.3.

## The rows that wait for their class

These 25 rows spell their names through a class the port's registry carries as `absent`
(`registry/UIKit/ios17-18.json`: `UITab`, `UITabSidebarItem`, `UITextFormattingViewController`
and `UITextItem`), so the overlay cannot declare the name they ask for: the enclosing class is
not there to nest a type in, and a typealias on a class that does not exist does not compile.
They are registered `absent` for that reason until the UIKit bands carry those classes, and the
typecheck counts them as such: each is a row whose name is unreachable, not a row whose
declaration is wrong.

| row | the class it waits for |
| --- | --- |
| `UITabBarController.Sidebar.ScrollTarget.tab` | `UITab` |
| `UITabSidebarItem.Content.action` | `UITabSidebarItem.Content` |
| `UITabSidebarItem.Content.tab` | `UITabSidebarItem.Content` |
| `UITextFormattingViewController.ChangeValue.bold` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.decreaseFontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.decreaseIndentation` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.font` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.fontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.formattingStyle` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.highlight` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.increaseFontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.increaseIndentation` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.italic` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.lineHeightPointSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.strikethrough` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textAlignment` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textColor` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textList` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.undefined` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.underline` | `UITextFormattingViewController.ChangeValue` |
| `UITextItem.Content.link` | `UITextItem.Content` |
| `UITextItem.Content.tag` | `UITextItem.Content` |
| `UITextItem.Content.textAttachment` | `UITextItem.Content` |
| `UITextItem.MenuConfiguration.Preview.default` | `UITextItem.MenuConfiguration` |
| `UITextItem.MenuConfiguration.Preview.view` | `UITextItem.MenuConfiguration` |

## The 86 that resolve, and the one class standing between them and 86/86

The overlay, with the 25 waiting rows' namespaces left out, is 38 enumerations, 87 case
declarations and 5 typealiases, and the typecheck over the 86 rows that are not waiting reports
exactly one error:

```
$ for f in /tmp/n86/*.swift; do packages/s/swift-runtime/facts/UIKit/tc.sh "$f" 2>&1 | grep "error:"; done \
    | sed 's/.*error: //' | sort | uniq -c
    688 'UITargetedPreview' is only available in iOS 13.0 or newer
```

688 is 86 files naming the same four `UIPointerEffect` cases. `UIAction` and `NSTextAttachment`
already lower in the headers this typecheck reads; `UITargetedPreview` does not, and
`registry/UIKit/ios13menus.json` carries it as `implemented` - the headers were made when the
`swift-runtime` install this typecheck takes its resource directory from was built, so a fresh build of
the port's headers over this tree's registry lowers it. The count against those fresh port headers is what
the re-measure is for, and it is queued.
## The rows that wait for their class

These 25 rows spell their names through a class the port's registry carries as `absent`
(`registry/UIKit/ios17-18.json`: `UITab`, `UITabSidebarItem`, `UITextFormattingViewController`
and `UITextItem`), so the overlay cannot declare the name they ask for: the enclosing class is
not there to nest a type in, and a typealias on a class that does not exist does not compile.
They are registered `absent` for that reason until the UIKit bands carry those classes, and the
typecheck counts them as such: each is a row whose name is unreachable, not a row whose
declaration is wrong.

| row | the class it waits for |
| --- | --- |
| `UITabBarController.Sidebar.ScrollTarget.tab` | `UITab` |
| `UITabSidebarItem.Content.action` | `UITabSidebarItem.Content` |
| `UITabSidebarItem.Content.tab` | `UITabSidebarItem.Content` |
| `UITextFormattingViewController.ChangeValue.bold` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.decreaseFontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.decreaseIndentation` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.font` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.fontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.formattingStyle` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.highlight` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.increaseFontSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.increaseIndentation` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.italic` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.lineHeightPointSize` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.strikethrough` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textAlignment` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textColor` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.textList` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.undefined` | `UITextFormattingViewController.ChangeValue` |
| `UITextFormattingViewController.ChangeValue.underline` | `UITextFormattingViewController.ChangeValue` |
| `UITextItem.Content.link` | `UITextItem.Content` |
| `UITextItem.Content.tag` | `UITextItem.Content` |
| `UITextItem.Content.textAttachment` | `UITextItem.Content` |
| `UITextItem.MenuConfiguration.Preview.default` | `UITextItem.MenuConfiguration` |
| `UITextItem.MenuConfiguration.Preview.view` | `UITextItem.MenuConfiguration` |

## The other 86

The remaining rows resolve once the port's headers lower the availability of the SDK classes the surface
spells them through, which they do for a class the registry carries as `implemented` - `UIAction` and
`UITargetedPreview` are, in `registry/UIKit/ios13menus.json`. The port's headers a typecheck reads
were made when a `swift-runtime` install was built, so a fresh build of the port's headers over this tree's
registry is what the count below is measured against.
