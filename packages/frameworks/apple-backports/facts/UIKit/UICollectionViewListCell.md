# UICollectionViewListCell, iOS 14.0

A cell that lays its content out beside its accessories.

## What the port does as UIKit does
- Accessories inset by the cell's layout margins (8 in a flow layout, 16 under a list layout), indentation of `indentationLevel * indentationWidth`, `indentsAccessories`, editing-only accessories hidden when not editing, `separatorLayoutGuide` from the text's leading edge, a row separator, the default background of the List Cell style.
- Two accessories of one system type raise NSInternalInconsistencyException, as the host does.

## What the host measures that a phone would not

The host is Catalyst, so its metrics are those of the Mac idiom: row margins {15,16,15,8}, a plain row estimate of 40.04 (44 x 0.91), a sidebar inset of 12.987 (10 / 0.77), a corner radius of 26 for grouped and sidebar lists, some Mac colours. The port follows the host's raw values, except the row estimate of a list layout, which is 44, the phone's. Nothing here was measured on an iPhone; `Dynamic Light Alpha` was 0.12 in light and 0.4 in dark, and the port carries 0.12, since this release has no dark mode.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured with random values and states side by side with the port in one process, and the header of SDK 16.4. The differential tests are `tests/backports/host/uikit2` (the `listvalues` group for values, the windowed `listcell` group for views); the device application is `tests/backports/device/lists.m`, held to the numbers the host recorded in `lists-expectations.h`.
