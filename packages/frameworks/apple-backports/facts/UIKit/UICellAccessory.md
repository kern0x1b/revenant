# UICellAccessory and its eight subclasses, iOS 14.0

Accessories laid out at the edges of a UICollectionViewListCell.

## What the port does as UIKit does
- Regions are 24 wide, 14 for disclosure and outline, the width of the text for a label. Leading accessories are 16 apart, trailing ones 8; a reorder grip gets a one point vertical separator with a gap of 17 when it is not alone.
- Trailing, left to right: custom at its default position, label, checkmark, disclosure, reorder. Leading: delete, insert, multiselect, outline, custom.
- The position blocks of `UICellAccessoryPositionBeforeAccessoryOfClass` and `After...` place a custom view relative to the first or last accessory of a class, or at either end.
- Delete, insert, reorder and multiselect are displayed when editing by default. A hidden accessory takes no room. A label with nil text raises.

## Differences
- Two labels compare unequal where the host compares fonts by pointer and finds them equal.
- The drawing is the port's own; the geometry is the host's. The outline disclosure expands its item, see `UICollectionViewOutline.md`, and the reorder grip drags the row, see `UICollectionViewInteractiveMovement.md`.

## What the host measures that a phone would not

The host is Catalyst, so its metrics are those of the Mac idiom: row margins {15,16,15,8}, a plain row estimate of 40.04 (44 x 0.91), a sidebar inset of 12.987 (10 / 0.77), a corner radius of 26 for grouped and sidebar lists, some Mac colours. The port follows the host's raw values, except the row estimate of a list layout, which is 44, the phone's. Nothing here was measured on an iPhone; `Dynamic Light Alpha` was 0.12 in light and 0.4 in dark, and the port carries 0.12, since this release has no dark mode.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured with random values and states side by side with the port in one process, and the header of SDK 16.4. The differential tests are `tests/backports/host/uikit2` (the `listvalues` group for values, the windowed `listcell` group for views); the device application is `tests/backports/device/lists.m`, held to the numbers the host recorded in `lists-expectations.h`.
