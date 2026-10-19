# UICollectionViewCell configuration and UICollectionView editing, iOS 14.0

`contentConfiguration`, `backgroundConfiguration`, their automatic update flags, `configurationState`, `setNeedsUpdateConfiguration`, `updateConfigurationUsingState:`, and `UICollectionView.editing` with `allowsSelectionDuringEditing` and `allowsMultipleSelectionDuringEditing`.

## What the port does as UIKit does
- The state is kept per view. `setSelected:`, `setHighlighted:` and the layout of the view request an update; the update runs at layout, so a subclass sees `updateConfigurationUsingState:` in the host's order.
- Turning editing on updates the visible cells. `allowsSelectionDuringEditing` is NO; multiple selection during editing forces it YES.
- `isPinned` is iOS 15 and is not answered. `configurationUpdateHandler`, also iOS 15, is: below.

## Differences
- The hooks are installed with the runtime when the library loads, in place of subclass overrides.

## What the host measures that a phone would not

The host is Catalyst, so its metrics are those of the Mac idiom: row margins {15,16,15,8}, a plain row estimate of 40.04 (44 x 0.91), a sidebar inset of 12.987 (10 / 0.77), a corner radius of 26 for grouped and sidebar lists, some Mac colours. The port follows the host's raw values, except the row estimate of a list layout, which is 44, the phone's. Nothing here was measured on an iPhone; `Dynamic Light Alpha` was 0.12 in light and 0.4 in dark, and the port carries 0.12, since this release has no dark mode.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured with random values and states side by side with the port in one process, and the header of SDK 16.4. The differential tests are `tests/backports/host/uikit2` (the `listvalues` group for values, the windowed `listcell` group for views); the device application is `tests/backports/device/lists.m`, held to the numbers the host recorded in `lists-expectations.h`.

## `configurationUpdateHandler`, iOS 15.0

Held by `UIKit/UIConfigurationUpdateHandler15.m` for `UICollectionViewCell`, `UITableViewCell` and `UITableViewHeaderFooterView` alike
(`UITableViewCellConfiguration.md` points here). The block is kept copied; setting one, nil included, sends the view
`setNeedsUpdateConfiguration`, as the header says. When the update runs at layout (`charon_layoutWillRun` in
`UIKit/CharonConfigurationHost.m`), the view is sent `updateConfigurationUsingState:` first and the handler is called after it with the
view and the same state object - the order the header gives ("called after `-updateConfigurationUsingState:`"). That the system hands
both the same state object is the port's reading of the header, not measured. No host oracle runs on this machine (Catalyst is not
installed), and the device run is the last section. Ladder by `objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-updatehandler.log`,
`setSelected:animated:` as the positive control and an invented selector as the negative one): getter and setter are on none of the
three classes in 6.1.3 or 12.0 and on all three in 16.0 and 18.0; no 13-15 cache, so `introduced` stays the header's 15.0.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked `configurationUpdateHandler` on a table cell: kept, run at the next layout after it is set with the cell and a cell state, run again with a selected state after selection, not called once cleared. The collection view cell and the header-footer view were not run.
