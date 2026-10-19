# Cell, header and footer default background configuration, iOS 16.0

`-defaultBackgroundConfiguration` on `UICollectionViewCell`, `UITableViewCell` and
`UITableViewHeaderFooterView`. The header says what it is: "Returns a default background configuration
for the cell's style. This background configuration represents the default appearance that the cell
will use."

## What the release carries, measured

Neither band end answers the name at all, so before this object a caller got nothing:

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/12.0/dyld_shared_cache_arm64  > inv-12.0.tsv
awk -F'\t' '$2=="UICollectionViewCell" || $2=="UITableViewCell" || $2=="UITableViewHeaderFooterView" {print $2, $5}' inv-6.1.3.tsv
```

```
6.1.3  UICollectionViewCell          selectors=36  defaultBackgroundConfiguration=0  control=1
6.1.3  UITableViewCell               selectors=291 defaultBackgroundConfiguration=0  control=3
6.1.3  UITableViewHeaderFooterView   selectors=51  defaultBackgroundConfiguration=0  control=1
12.0   UICollectionViewCell          selectors=71  defaultBackgroundConfiguration=0  control=1
12.0   UITableViewCell               selectors=476 defaultBackgroundConfiguration=0  control=3
12.0   UITableViewHeaderFooterView   selectors=87  defaultBackgroundConfiguration=0  control=1
```

The three rows hold 36, 291 and 51 selectors at 6.1.3 and 71, 476 and 87 at 12.0, and none of the
three holds `defaultBackgroundConfiguration` in any spelling, while each holds the selectors those
classes are known for — `-initWithFrame:reuseIdentifier:`, `-contentView`, `-selectionStyle` — so the
zero is the release's and not the reader's. The census in `UIKit16Absence.md` covers the same 116
names and carries its own control.

`UITableView` is the one class here whose dump holds the name at both ends; it arrives from another
framework's category, not from UIKit's own `UITableView`, and no row of this file is about it.

## What the port does

The answer is a lookup, because the port already has everything the lookup reads:

- **The list a collection view cell is in.** `-charon_layoutListConfiguration`
  (`UICollectionViewCompositionalLayout.h`) walks the cell's superviews to the `UICollectionView`,
  reads its layout, and takes the list configuration of the section the cell's index path names,
  falling back to the layout's own. It is the same lookup `UICollectionViewListCell.m` already uses to
  decide whether the row draws a separator, so the configuration this object answers is the one the
  cell's own drawing is already styled from.
- **The table style.** `-style` on the enclosing `UITableView`, which both band ends carry (measured:
  present in the 6.1.3 and 12.0 inventories).
- **The styles themselves.** `UIBackgroundConfiguration`'s list styles, carried since iOS 14 and
  measured on the host in `UIBackgroundConfiguration.md`.

So `listPlainCellConfiguration` / `listGroupedCellConfiguration` / `listSidebarCellConfiguration` for a
collection view cell by the list's appearance, and `listPlainCellConfiguration` /
`listGroupedCellConfiguration` (or the header and footer pair) for a table cell by the table's style.

## What is reasoned and what is measured

Measured: what the two band ends carry, the list configuration lookup the port already performs, and
the background styles the host recorded. Reasoned: the mapping from a style to a configuration, which
is the header's own sentence ("for the cell's style") applied to the two kinds of style this port
knows — the list appearance and the table style. No host differential was run for this object, so no
number here is quoted as Apple's for these three methods; the differential the neighbouring iOS 14
object has is `tests/backports/host/uikit2`'s `listcell` group, and this object adds no measurement
of its own to it.

A cell or header/footer in no list and no table answers nil: there is no style to answer with, and
the header's "default appearance the cell will use" is nil when there is nothing that will use it.