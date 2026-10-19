# UICollectionLayoutListConfiguration and the list layout, iOS 14.0

`UICollectionLayoutListConfiguration`, `+[NSCollectionLayoutSection sectionWithListConfiguration:layoutEnvironment:]` and `+[UICollectionViewCompositionalLayout layoutWithListConfiguration:]`.

## What the port does as UIKit does
- The section is a horizontal group of one item, with the host's content insets per appearance (the sidebar's 12.987012987012987 sides), a pinned 28 point header for plain lists and an unpinned 17.5 one for the others, boundary supplementary items, z index 200 and extended boundary. Thirty combinations of appearance, header and footer mode are compared for structure.
- `layoutWithListConfiguration:` draws the row separators of a layout of one configuration.

## Differences
- The row estimate is 44 for every appearance where the host measured 40.04 for plain, because this release has no self sizing cells: a row is 44 high and does not grow to its text.
- The swipe action providers are asked when a row is dragged, see `UICollectionViewListSwipe.md`. The background decoration item is not carried.

## The separator configuration, the item separator handler and the header padding

`separatorConfiguration` (iOS 14.5), `itemSeparatorHandler` (iOS 14.5) and `headerTopPadding` (iOS 15) are stored, and the layout does not read them.
The separators the port's lists draw are unchanged by any of the three.

- `separatorConfiguration` is unset until given: each read then builds a configuration for the appearance, which is a new object each time, as the host's
  read does. Once set, the list holds a **copy** of the configuration given, so a change to the one given afterwards does not reach it. Nil raises
  `NSInvalidArgumentException` ("Setting a nil separatorConfiguration is not supported"), as the host does, and keeps what it held. A copy of the list
  holds a copy of the configuration, a different object.
- `itemSeparatorHandler` is nil by default and copied on set; nil clears it.
- `headerTopPadding` is the largest `CGFloat` by default (the host answers 1.79769e+308 on the 64-bit host, which is the largest double; the port uses
  `CGFLOAT_MAX`, which is the same value on the host and the largest float on the 32-bit release). It keeps the value set, zero included.

Measured by `tests/backports/host/list-config` (20 checks; the port's list and the host's print the same values, and the four controls fail). The
default separator configuration's colours were not compared: the host's default colours for each appearance are not in the check.

## What the host measures that a phone would not

The host is Catalyst, so its metrics are those of the Mac idiom: row margins {15,16,15,8}, a plain row estimate of 40.04 (44 x 0.91), a sidebar inset of 12.987 (10 / 0.77), a corner radius of 26 for grouped and sidebar lists, some Mac colours. The port follows the host's raw values, except the row estimate of a list layout, which is 44, the phone's. Nothing here was measured on an iPhone; `Dynamic Light Alpha` was 0.12 in light and 0.4 in dark, and the port carries 0.12, since this release has no dark mode.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured with random values and states side by side with the port in one process, and the header of SDK 16.4. The differential tests are `tests/backports/host/uikit2` (the `listvalues` group for values, the windowed `listcell` group for views); the device application is `tests/backports/device/lists.m`, held to the numbers the host recorded in `lists-expectations.h`.
