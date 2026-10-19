# NSDiffableDataSourceSnapshot, iOS 13.0

Introduced in iOS 13.0: the state of a diffable data source - an ordered list of sections, each with an ordered list of items, both
named by identifiers - and the operations that build and edit it. iOS 6 has nothing like it. There is no `NSDiffableDataSourceSnapshotReference`
class on the host either: the Swift name of this class is a rename of the header, so none is carried.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), asked for every answer below and held against the port by two runs. The
`diffable` group of `tests/backports/host/uikit2` puts the port beside the system's class and compares random sequences of the 18
operations, with unknown, nil, repeated and existing identifiers, 50000 operations per run (340000 in the longest run made), none differing in outcome (the
exception, its reason and its user info), in the sections and items afterwards, in every lookup, in `-isEqual:` and in the copy.
`tests/backports/host/diffable` records 800 cases into `device/diffable-expectations.h`, and `device/diffable.m` holds the port to them on
the device.

## What the port does as the system does

- The snapshot holds sections and items in order. `deleteAllItems` removes the sections too, and deleting the items of a section leaves
  it empty. Section identifiers and item identifiers are two names of their own: a section may be called what an item is called.
- `appendItemsWithIdentifiers:` with no section appends to the last section, and raises when there is none; with a section named nil it
  does the same. **An item identifier that is already in the snapshot is moved**, not refused: appending or inserting it takes it out of
  where it was, into the section it is put in. A section identifier that is already there is refused.
- `insert...before/afterItemWithIdentifier:` puts the items in the destination's section, before or after it, and the destination may not
  be one of them. `moveItem...` is the same for one item. A section is inserted or moved in the same way; a nil destination puts inserted sections
  at the end, and an unknown destination raises.
- `deleteItems` and `deleteSections` ignore identifiers that are not there. `reloadItems` and `reloadSections` remember what was asked
  and raise for one that is not in the snapshot; `-reloadItemsWithIdentifiers:nil` does nothing.
- `-copy` is a snapshot with the same sections, items and reload marks. `-isEqual:` compares the sections and the items of each, in
  order, and nothing else - not the reload marks and not the identity of the object. `-hash` is not overridden, so two equal snapshots hash
  differently, as the system's do. There is no coding.
- `-sectionIdentifiers` and `-itemIdentifiers` are new arrays each time; `indexOfItemIdentifier:` counts across the sections.
- `-description` is `<NSDiffableDataSourceSnapshot 0x...: numberOfSections:3 numberOfItems:5; generation=UUID;
  sectionCounts=<_UIDataSourceSnapshotter: 0x...; 3 sections with item counts: [3, 2, 0] >` and then one line `[A: {a1 a2 a3}]` for each section,
  and `>`.

## Exceptions

Every one is an `NSInternalInconsistencyException` with `NSAssertFile` and `NSAssertLine` in the user info, as an assertion of the
system leaves them, and the reasons are the system's:

| when | reason |
| --- | --- |
| an unknown section named by `numberOfItemsInSection:` or `itemIdentifiersInSectionWithIdentifier:` | "Section identifier was not found. You can verify the section exists by calling the indexOfSectionIdentifier API (which has O(1) performance)" |
| a nil argument | "Invalid parameter not satisfying: identifiers" (or `itemIdentifiers`, `sectionIdentifiers`, `destinationIdentifier`, `toIdentifier`, `fromSectionIdentifier`, ...) with the name of the parameter |
| items appended and there is no section | "There are currently no sections in the data source. Please add a section first." |
| a repeated identifier in the argument | "Fatal: supplied item identifiers are not unique. Duplicate identifiers: {(...)}", in the order in which the repeats are found |
| a section that is there, appended or inserted | "Diffable data source detected an attempt to insert or append 2 section identifiers that already exist in the snapshot. Identifiers in a snapshot must be unique. Section identifiers that already exist: (...)", with one identifier written singular |
| an unknown destination | "Invalid parameter not satisfying: section != NSNotFound" (items), "insertIndex != NSNotFound" (sections), "fromIndex", "toIndex", "fromSection", "toSection != NSNotFound" (moves) |
| a destination among the identifiers inserted, or the same as the item or section moved | "Invalid update: destination for insertion operation [b1] is in the insertion identifier list for update: <_UIDiffableDataSourceUpdate 0x... - action: INS; ...>." and the three like it |
| a reload of something not in the snapshot | "Attempted to reload item identifier that does not exist in the snapshot: none" |

The order of the checks, and the line numbers of the user info, are the system's. `-moveItemWithIdentifier:` with a nil item raises
`NSInvalidArgumentException` from the array the system makes of it.

## Where the port departs

- Of the members of iOS 15, `reconfigureItemsWithIdentifiers:` and `reconfiguredItemIdentifiers` are not answered (their rows in
  `registry/UIKit/ios15-16.json` say why). `reloadedItemIdentifiers` and `reloadedSectionIdentifiers` are, below.
- A reload is remembered after the identifier is validated; the system remembers it first, so a snapshot in which one raised still holds
  the marks of what was asked. The data sources ignore an identifier that is not in the snapshot; `reloadedItemIdentifiers` and
  `reloadedSectionIdentifiers` of such a snapshot leave out what the port refused and the system would list.

## `reloadedItemIdentifiers` and `reloadedSectionIdentifiers`, iOS 15.0

`UIKit/UIDiffableDataSource+iOS15.m` answers the marks the snapshot already keeps for its data sources: every identifier passed to
`reloadItemsWithIdentifiers:` or `reloadSectionsWithIdentifiers:`, once each, in the order first asked; `-copy` keeps them, and the snapshot
a data source's `-snapshot` hands back has none, since the data source drops the marks when it applies one. The order and the
empty list after an apply follow the port's own bookkeeping and were not held against the system: no host oracle runs on this machine
(Catalyst is not installed), and the device run is the last section. `objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-diffable.log`
in the charon checkout the band used): the class is in neither the 6.1.3 nor the 12.0 cache, both getters are in 16.0 and 18.0; there is
no 13-15 cache, so `introduced` stays the header's 15.0.
- The generation UUID in `-description` is anew for a snapshot and copied by `-copy`; the port makes a new one when the sections change, and the
  rule of the system was not read. The host test does not compare it.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked `reloadedItemIdentifiers` (once each, in the order asked, kept by a copy, empty in a data source's snapshot) and `reloadedSectionIdentifiers`; all as described above.
