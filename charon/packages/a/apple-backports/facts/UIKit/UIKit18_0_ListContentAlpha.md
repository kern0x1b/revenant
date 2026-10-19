# `UIListContentConfiguration.alpha`: the value the port already stored, and 18.0 published

**The row moved `absent` → `implemented`.** The other 101 rows of the 18.0 family keep the status a
second reader confirmed; this one did not survive being read against the port's own sources, because the
port implements `UIListContentConfiguration` itself and had been holding this exact value the whole time.

## The reason is about the release, and it was true while being misleading

The row's reason read:

> the class is absent from both band ends, so there is no content configuration whose alpha a caller
> could set

Every clause of that is true — `UIListContentConfiguration` is genuinely in neither the 4.3 nor the 6.1.3
cache (read class-scoped; see `UIKit18_0_NSHitTest.md` for the reader and its three defects). What it
misses is that `absent` is a claim about the RELEASE, and the port does not depend on the release for
this class: it implements it. `UIListContentConfiguration.m:41` is the port's own
`@implementation`, added because the release has no such class.

## What the port already had, before this commit

`alpha` was not merely storable in the port's configuration — it was stored, defaulted, encoded, copied,
compared, described and **applied to the drawing**:

| what | where |
|---|---|
| the ivar `CGFloat _alpha` | `UIListContentConfiguration.m:58` |
| the default: `0` for a bare configuration, `1` otherwise | `UIListContentConfiguration.m:151` |
| decoded from the coder under the key `alpha` | `UIListContentConfiguration.m:232` |
| encoded under the same key | `UIListContentConfiguration.m:258` |
| carried by `-copyWithZone:` | `UIListContentConfiguration.m:285` |
| compared by `-isEqual:` | `UIListContentConfiguration.m:525` |
| printed by `-description` | `UIListContentConfiguration.m:544` |
| read and applied to three views' `alpha` | `UIListContentView.m:187-190` |

`UIListContentView.m:187` is the load-bearing line: the drawing path sets `_textLabel.alpha`,
`_secondaryLabel.alpha` and `_imageView.alpha` from `[config charon_alpha]`. So a caller who sets the
new public property changes what the port draws, because the setter writes the same ivar the drawing path
reads — there is no second store and no translation step.

## The property's NAME is not always its selector, so the spelling was measured

The rulebook's warning applies here, and the answer is the plain one. Three independent reads:

1. **The build SDK declares the class but not the property.**
   `~/.xmake/packages/i/iphoneos-sdk/16.4/*/iPhoneOS16.4.sdk/System/Library/Frameworks/UIKit.framework/Headers/UIListContentConfiguration.h`
   declares `UIListContentConfiguration` and 18 `@property` lines, and the string `alpha` occurs
   **zero** times in it (`grep -c alpha` → `0`). So the port has to supply the accessor, and `alpha`
   being absent from 16.4 is consistent with the row's `introduced: 18.0`.
2. **Every property in that header uses the plain spelling** — `@property (nonatomic) CGFloat
   imageToTextPadding;`, `@property (nonatomic) BOOL prefersSideBySideTextAndSecondaryText;` — with no
   `getter=` override anywhere, so the selector is the property's own name.
3. **The registry's own source agrees**, and names the release:
   `coordination/corpus/sdk-26.2-surface.tsv:123512` reads
   `UIKit	property	objc	UIListContentConfiguration.alpha	18.0	…	own	absent`.

So the selectors are `alpha` and `setAlpha:`. Had the SDK spelled it `isAlpha`, the exported symbol
would have been the wrong name and the row would have been a defect that reads as correct.

## The definition is in the object, not only in the source

Compiled the way the tree builds it, for the deployment band:

```sh
clang -Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability -fobjc-arc \
      -target armv7-apple-ios6.1.3 -isysroot <16.4 SDK> -I packages/a/apple-backports/UIKit \
      -c packages/a/apple-backports/UIKit/UIListContentConfiguration.m -o UIListContentConfiguration.o
otool -v -s __TEXT __objc_methname UIListContentConfiguration.o
```

The selector table lists, among the class's own:

```
00001fa2  charon_alpha
00001faf  alpha
00001fb5  setAlpha:
```

`nm -gU` lists `_OBJC_CLASS_$_UIListContentConfiguration` and
`_OBJC_IVAR_$_UIListContentConfiguration._alpha`. The compile emits two warnings, both pre-existing and
unrelated: `-Wincomplete-implementation` for `+prominentInsetGroupedHeaderConfiguration` and
`+extraProminentInsetGroupedHeaderConfiguration`, which the 16.4 header declares and this file has
never defined.

## Why the accessor is written as it is, and why `-charon_alpha` stays

The two accessors are written in the same shape as the public accessors this file already defines
(`-image`/`-setImage:`, `-textProperties`, and the rest): a getter returning the ivar and a setter
assigning it, on the `@implementation` itself, with no `@interface` — the file declares no interface for
the class, so the accessors are reachable by selector and by the compile, which is what the registry
check counts.

`-charon_alpha` is deliberately **kept**, not folded into `-alpha`. `UIListContentView.m:187` reads it,
and folding the two would mean touching the drawing path for no gain. Two names for one value is a
small, stated duplication rather than a second mechanism: both return the same ivar, and there is
nothing to keep in step.

## What a caller gets

- An application that names `alpha` links; `respondsToSelector:@selector(alpha)` is YES.
- A value set through the public accessor is what the port draws, and it survives `-copyWithZone:`,
  the coder and `-isEqual:` because it is the ivar those already handled.
- A configuration built by `+cellConfiguration` and its siblings reads back the alpha its own style gave
  it — `1`, or `0` for the bare style — so a caller who never touches the property sees no change, and
  one who does is not fighting an initialiser.
- Nothing on 6.1.3 reads the accessor back: the release has no list configuration of its own, so this is
  forward compatibility for an application written against 18.0 and run on 6.1.3 through this port, not
  a behaviour any release on this port's ladder exercises.
