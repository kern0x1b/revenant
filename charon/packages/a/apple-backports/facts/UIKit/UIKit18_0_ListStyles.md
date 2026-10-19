# The 18.0 list-style class methods: four doors the port already had the rooms for

**Five rows, four of them `absent` → `implemented`.** They are the same family as
`UIKit18_0_ListContentAlpha.md`, found by the same sweep: every owner of an 18.0 row that **the port
implements itself** rather than reaching through a category onto a release-owned class. The seven other
owners in this slice (`NSObject`, `UIColor`, `UITabBarController`, `UITextView`, `UITableView`,
`UIViewController`, `UIActivityViewController`) are release-owned and were left alone.

The port-implemented owners in this slice: `UIListContentConfiguration`,
`UIBackgroundConfiguration`, `UIListContentImageProperties`, `UICollectionLayoutListConfiguration`,
`UITraitCollection`, `UIAccessibilityCustomAction`.

## The 18.0 names are new, not renames — measured against the build SDK

This is the question that decides whether a row is a new member or a spelling the port already answers.
The build SDK is 16.4, so:

| the 18.0 row | 16.4 SDK's own class methods | verdict |
|---|---|---|
| `+[UIBackgroundConfiguration listCellConfiguration]` | `listPlainCellConfiguration` … but **not** `listCellConfiguration` | new name |
| `+[UIBackgroundConfiguration listHeaderConfiguration]` | `listPlainHeaderFooterConfiguration` … but **not** `listHeaderConfiguration` | new name |
| `+[UIBackgroundConfiguration listFooterConfiguration]` | `listPlainHeaderFooterConfiguration` … but **not** `listFooterConfiguration` | new name, **and nothing to name** |
| `+[UIListContentConfiguration headerConfiguration]` | `plainHeaderConfiguration`, `groupedHeaderConfiguration` … but **not** `headerConfiguration` | new name |
| `+[UIListContentConfiguration footerConfiguration]` | `plainFooterConfiguration`, `groupedFooterConfiguration` … but **not** `footerConfiguration` | new name |

Command, over whichever 16.4 SDK is in the store:

```sh
grep -nE '^\+ \(instancetype\)' \
  ~/.xmake/packages/i/iphoneos-sdk/16.4/*/iPhoneOS16.4.sdk/System/Library/Frameworks/UIKit.framework/Headers/UIBackgroundConfiguration.h
grep -nE '^\+ \(instancetype\)' \
  ~/.xmake/packages/i/iphoneos-sdk/16.4/*/iPhoneOS16.4.sdk/System/Library/Frameworks/UIKit.framework/Headers/UIListContentConfiguration.h
```

## What each method returns, and why that is not a new behaviour

**`+[UIBackgroundConfiguration listCellConfiguration]` → `CharonBackgroundStyleListCell`.** This style
already exists and is already in use; only the door was missing:

- in the port's own style enum, `CharonLists.h:30`
- given the same systemBackground colour as `ListPlainCell` in `-initCharonWithStyle:`,
  `UIBackgroundConfiguration.m:144-145`
- returned by `-charon_styleColor:`, `:366-367`
- counted as plain by `-updatedConfigurationForState:`, `:382`
- **already built** by `UICollectionViewListCell.m:40` and `:52`

So the method returns the identical configuration the port's own list cell uses today. Nothing about the
drawing changes.

**`+[UIListContentConfiguration headerConfiguration]` → `CharonListStyleHeader`, and
`+footerConfiguration` → `CharonListStyleFooter`.** Both styles are carried, and the footer is *not* the
header relabelled — the initialiser gives them different margins, which is the whole of the difference
between a header and a footer here:

| style | margins (top, leading, bottom, trailing) | where |
|---|---|---|
| `CharonListStyleHeader` | `10, 8, 10, 8` | `UIListContentConfiguration.m:176-179` |
| `CharonListStyleFooter` | `8, 8, 6, 8` | `UIListContentConfiguration.m:180-184` |

Both are answered as header-footer styles by `-charon_isHeaderFooterStyle:` (`:294-297`), which is what
the drawing path asks.

## `+[UIBackgroundConfiguration listFooterConfiguration]` stays `absent`, and why

The port's background styles name headers and **no footer at all**. The full enum, `CharonLists.h:21-31`:

```
Custom, ListPlainCell, ListPlainHeaderFooter, ListGroupedCell, ListGroupedHeaderFooter,
ListSidebarHeader, ListSidebarCell, ListAccompaniedSidebarCell, ListCell
```

`listHeaderConfiguration` is therefore carryable — a style exists to name, `ListPlainHeaderFooter` — and
its row says plainly that the style it names is the *combined* one, so a header does not get colours of
its own. `listFooterConfiguration` has no such style: a method would have to return a header's colours
under a footer's name, which is a wrong answer rather than a missing one. Its row keeps `absent` and now
names the combined style a caller gets instead.

This asymmetry is the honest shape of the port's own capability, and it is recorded in both rows rather
than papered over by inventing a `ListFooter` style with guessed colours.

## The definitions are in the objects

```sh
clang -Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability -fobjc-arc \
      -target armv7-apple-ios6.1.3 -isysroot <16.4 SDK> -I packages/a/apple-backports/UIKit \
      -c packages/a/apple-backports/UIKit/UIBackgroundConfiguration.m   -o UIBackgroundConfiguration.o
clang … -c packages/a/apple-backports/UIKit/UIListContentConfiguration.m -o UIListContentConfiguration.o
otool -v -s __TEXT __objc_methname UIBackgroundConfiguration.o
otool -v -s __TEXT __objc_methname UIListContentConfiguration.o
```

```
UIBackgroundConfiguration.o    000019a3  listCellConfiguration
                               000019b9  listHeaderConfiguration
UIListContentConfiguration.o   00001cbb  headerConfiguration
                               00001ccf  footerConfiguration
```

Both objects compile with no new warning. The two that `UIListContentConfiguration.o` reports are
pre-existing and unrelated — `-Wincomplete-implementation` for
`+prominentInsetGroupedHeaderConfiguration` and `+extraProminentInsetGroupedHeaderConfiguration`, which
the 16.4 header declares and this file has never defined.

## What a caller gets

Each of the four returns the port's own configuration object for a style the port already draws, already
encodes (the coder carries `_style`), already copies and already compares for equality. A caller who sets
one and hands it to `UICollectionViewCell` or `UITableViewCell` gets the same drawing as before, reached
by the name 18.0 introduced.

The limits are stated in the rows rather than left for a reader to find:

- no list cell, header or footer on this port differs in colour from the style it was named after, except
  where the port already had a distinct style (the content-configuration header and footer do);
- nothing on 6.1.3 reads these back — the release carries neither class — so this is forward
  compatibility for an application written against 18.0, not behaviour the ladder exercises.
