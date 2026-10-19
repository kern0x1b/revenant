# The 15.0 rows of `registry/UIKit/ios15-16.json`: what each band end carries, and what was built

104 of the 105 rows of release **15.0** sat at `absent` with the SDK's own declaration as their
only `source`, which is an assertion and not a measurement. This page holds the measurement, the
commands that reproduce it, their output, and the four objects the band delivered off the back of
it. (The 105th, `UIButtonConfiguration`, was already `implemented` and measured by its own case;
it is not touched by this page.)

**Where the release landed: 12 `implemented`, 4 `inert`, 89 `absent`, and 0 rows still citing
only the SDK.** Four objects, four facts pages, one release.

**The claim, in one line:** no release the 15.0 band's registry check reads — the **deployment**,
6.1.3 — carries any of the 104 names, so `absent` is the correct verdict for all 104 and the gate's
`held` check cannot fire on them. All three ends were measured anyway, and **12.0 does carry six of
them**; that is recorded in full below rather than left out, because it is the one number that would
have changed this page's conclusion if it had not been read.

## Which releases are the band's ends, and why these

`modules/apple/backports.lua:2578` — "every band checks its imports against the caches of its first
and last release". A band point is a release some object's API arrived in (`band_plan`,
`backports.lua:2565`), and `band_ranges` (`:2518`) rounds it to the nearest pair of *catalog*
releases: the first catalog release at or after the point, and the last before the next point.

The catalog (`~/.revenant/firmware/catalog.json`, read by `firmware.versions`, `:201`) holds **no
armv7 or armv7s firmware between 12.0 and 15.0**:

```
$ python3 -c "<firmware.versions over the catalog, armv7+armv7s>"
armv7/armv7s catalog versions: 85
in [15.0,16.0): []            <- no armv7 firmware at all in the point's own range
lowest in [6.0,15.0): 6.0
```

So the 15.0 point's range on armv7 is empty, and the band that actually builds these objects runs
from the deployment release up to the newest release below the next point. Three caches matter and
all three are measured here, class-scoped, with the control in the same run:

- **6.1.3** — the deployment, and what the registry's `held` branch reads (`registry_step`,
  `backports.lua:1867`, hands the check `release_inventory(opt.cache)`).
- **4.3** — the oldest armv7 cache held, and the rung at which a placement defect is invisible from
  above: deleting rows that carry a `minimum` broke five objects on the 4.3 band while 6.1.3 stayed
  green, so the 4.3 log is read even when 6.1.3 is clean.
- **12.0** — the other held end, on arm64. It is a band end for the import check and
  `check_categories`, and it is where six of these rows turn out to be carried.

`first-rung.lua` over the 97 distinct names reads **16.0** for 88 of them and an earlier rung for 9.
That index answers *presence*, not ownership, so it cannot settle a row on its own; it is recorded
in "The early rungs are other classes' names" below and every one is explained.

## The measurement: class-scoped, all three ends, with the control in the same run

The rule that makes a selector's rung useless here: **a selector's rung says nothing about its
owner** (`fileSystemRepresentation` reads 3.0 — another class's — while `-[NSURL
fileSystemRepresentation]` is 7.0). So the question is never "does this name exist", it is "does
*this class* carry *this selector*", and that is `carried_by_release()` at `backports.lua:1631-1645`
reading the release's own inventory. The reader below is that function, line for line: a class row
is the class's presence; a method row is the owner class's instance/class selector column; a
property row is the getter **or** the setter.

```
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/4.3/dyld_shared_cache_armv7   > inv-4.3.tsv
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/12.0/dyld_shared_cache_arm64  > inv-12.0.tsv
```

One TSV line per class: `class <name> <superclass> <image> <instance selectors> <class selectors>
<protocols>`. Selector keys carry a `-` prefix in both columns, which is what `carried_by_release`
expects (`carried[sign == "-" and "instance" or "class"]["-" .. selector]`), so the dump is directly
comparable to the check.

```
6.1.3  classes 11378, of which UI* 705      protocols 1171
4.3    classes  7187, of which UI* 597      protocols  564
12.0   classes 63192, of which UI* 1741     protocols 11426
```

**Result: 0 of the 105 names are carried by 6.1.3, and 0 by 4.3. Six are carried by 12.0**, and
that is the most important number on this page — see "Six rows 12.0 does carry" below.

### The controls, and the two the controls caught

A census printing zero is ambiguous — the name may be absent, or the reader may be looking at the
wrong thing. Three controls, run through the same reader:

**Eight selector controls, 8/8 present on 6.1.3**: `UIView -setFrame:`, `UITableView -reloadData`,
`UIBarButtonItem -tintColor`, `UINavigationItem -title`, `UIImage -imageNamed:` (class column),
`UIView -isHidden`, `UICollectionView -dequeueReusableCellWithReuseIdentifier:forIndexPath:`,
`UISearchBar -text`.

**A positive control through the property path itself, 18/18 found, 0 missed**: 18 property
spellings were taken out of 6.1.3's own selector columns (`UIView`, `UIButton`, `UITableView`,
`UICollectionView`, `UITextField`, `UIWindow`, `UIControl`, `UIViewController`, `UIDatePicker`,
`UIColor`, `NSParagraphStyle`, `NSTextContainer`, `UIResponder`, `UIBarButtonItem`,
`UIActivityViewController`, `UIPrintInteractionController`) and pushed back through the getter /
`is`-getter / setter test. This is the control that matters for the property rows, because it
exercises the exact spelling decision the 50 property rows turn on.

**4.3 reads 6/8 on the same eight**, and both misses are the release's own, not the reader's:
`UICollectionView` does not exist at 4.3 as a *class* the reader can find, and `-tintColor` on
`UIBarButtonItem` is 7.0. A reader that found nothing at all would have missed the six it did find.

**12.0 reads 8/8, and 20/20 on the same positive control.**

- **The `is`-form.** The 6.1.3 era spells the `hidden` property's getter `-isHidden`, not `-hidden`.
  A property check that looked only for `-<name>` would have reported a false clean. All 50 property
  rows were run against the getter, the `is`-getter and the setter; still 0 carried.
- **Categories are merged.** `UIImage`'s class column holds `-mapkit_imageNamed:` — a MapKit category
  on a UIKit class — so the dump already counts what categories add, which is what the registry
  check counts.

### 46 of the 82 method and property rows were real questions, not formalities

A row whose owner class the release does not carry at all cannot fire `held`, so measuring it
proves nothing. **46 of the 82** method and property rows name an owner class 6.1.3 *does* carry —
`UIButton` (9 rows), `UIView` (6), `NSTextAttachment` (5), `UITableView` (5), `UICollectionView`
(3), `UIViewController` (3), `UIControl` (2), `UIResponder`, `UIColor`, `UIDatePicker`,
`UITextField`, `UITextView`, `UIWindow`, `UIBarButtonItem`, `NSTextContainer`, `NSTextStorage`,
`NSParagraphStyle`, `NSMutableParagraphStyle`, `UIPrintInteractionController`,
`UIActivityViewController`. For those the selector check was the whole question, and each was read
on its own class. All 46 read absent at both ends.

## Six rows 12.0 does carry, and why `absent` is still the right verdict

This is the one place where measuring a second end changed the answer, and it is recorded rather
than smoothed over. **Six rows are carried by the 12.0 cache**, all of them TextKit 2:

| row | kind | selectors 12.0 carries | image |
|---|---|---|---|
| `NSTextAttachmentViewProvider` | class | the class itself | `UIFoundation` |
| `NSTextLayoutFragment` | class | the class itself | `UIFoundation` |
| `NSTextLineFragment` | class | the class itself | `UIFoundation` |
| `NSTextAttachment.allowsTextAttachmentView` | property | `-allowsTextAttachmentView`, `-setAllowsTextAttachmentView:` | `UIFoundation` |
| `NSTextAttachment.lineLayoutPadding` | property | `-lineLayoutPadding`, `-setLineLayoutPadding:` | `UIFoundation` |
| `NSTextAttachment.usesTextAttachmentView` | property | `-usesTextAttachmentView` (getter only) | `UIFoundation` |

`first-rung.lua --rungs` says the same thing independently, and names the releases: these three
classes read **`11.0,12.0,16.0,18.0`**, which is the only non-16.0 answer among the 23 class and
protocol rows. `NSTextLayoutManager` and `NSTextViewportLayoutController` read `16.0,18.0` even
though they are the other half of TextKit 2 — so the split inside one framework is real and is the
reader's, not the release's.

**Why the rows stay `absent`.** The claim `absent` makes is about the release, and the branch that
tests it is `held` at `backports.lua:1901-1907`:

```lua
local natively = deployment and entry.introduced and dyld.compare_versions(deployment, entry.introduced) >= 0
if (entry.status == "absent" or entry.status == "owed") and in_range(entry, deployment)
   and not natively and carried_by_release(entry, inventory) then
    table.insert(held, name)
```

`carried_by_release` is handed **one** inventory, and `registry_step` (`:1867`) builds it from
`release_inventory(opt.cache)` — the **deployment** cache, not a band end. For the armv7 build the
deployment is 6.1.3, where all 105 rows read 0, so `held` cannot fire on any of them. 12.0 is a band
end for the *import* check (`dyld.check`, `stage_bands`, `:2658`) and for `check_categories`, but
the registry's `held` branch never asks it. `absent` is therefore the correct verdict at the
deployment, and it is what the gate reads.

**What a caller actually gets, since the release carries the name on 12.0.** On a device running
12.0 or later these six are the system's own and the row is not consulted; a caller linking against
the port on such a device gets UIFoundation's, and the port is not built into that band. On the
armv7 devices the port targets, `NSClassFromString(@"NSTextLayoutFragment")` answers **nil** and the
three `NSTextAttachment` properties do not exist, because TextKit 2 arrived in 11.0 and the release
has TextKit 1 — measured present at 6.1.3: `NSTextStorage`, `NSTextContainer`, `NSLayoutManager`,
`NSTextAttachment`; measured absent: all three TextKit 2 classes and `NSTextAttachmentLayout`. The
port's own `UITextView` lays its text out in a WebKit body, so there is no layout manager to answer
for at any armv7 release. That is what the rows' `effect` fields already say, and this page is where
a reader can check it.

**And this is the second time the same trap has fired on this file.** The 16.0 page
(`UIKit16Absence.md`) closed 115 rows on 6.1.3 and 12.0 both reading 0. For release 15 the second
end is not 0, and had the batch measured only the armv7 ends — which is what the queue file's own
instruction to use "the 6.1.3 and 4.3 armv7 caches" points at — this page would have claimed a
clean 105/105 absence across the ladder and been wrong about six rows. The measurement that settled
it was reading the third end.

## The early rungs are other classes' names, measured

`first-rung.lua` over the 97 distinct names: 88 read 16.0, and 9 read earlier. Every one is
explained, and none of them rescues its row:

| name | rung | what the cache actually says |
|---|---|---|
| `NSTextAttachmentViewProvider`, `NSTextLayoutFragment`, `NSTextLineFragment` | 11.0 | TextKit **2**, and 12.0 **does** carry these three — see the section above. 6.1.3 carries TextKit **1** (`NSTextStorage`, `NSLayoutManager`, `NSTextContainer`, `NSTextAttachment` all present) and none of the three. |
| `UITrackingLayoutGuide`, `UIKeyboardLayoutGuide`, `UIButtonConfiguration`, `NSTextLayoutManager`, `UIToolTipConfiguration`, `UIPointerAccessory`, `UIBandSelectionInteraction`, `UIWindowSceneActivation*`, `UIFocusEffect`, `UIFocusHaloEffect`, `UIToolTipInteraction` | 16.0 | read `16.0,18.0` — the first held release carrying the name at all, and nothing between 6.1.3 and it. |

Per-release, for all 23 class and protocol rows (`first-rung.lua --rungs`, one name per run — the
multi-name form stops after the first answer):

```
NSTextAttachmentViewProvider            11.0,12.0,16.0,18.0
NSTextLayoutFragment                    11.0,12.0,16.0,18.0
NSTextLineFragment                      11.0,12.0,16.0,18.0
every other class and protocol row      16.0,18.0
```

This is the documented trap in its purest form: a class name belongs to exactly one class, so
first-rung is a *class-scoped* answer for a class row — and it still does not mean the release whose
cache the band checks carries it, because that check is the deployment's.

## What each family of rows is actually blocked on

The rows are not one queue. Grouped by the substrate that is missing, which is what a caller gets:

- **TextKit 2** — `NSTextLayoutManager`, `NSTextLayoutFragment`, `NSTextLineFragment`,
  `NSTextViewportLayoutController`, `NSTextLayoutManagerDelegate`,
  `NSTextViewportLayoutControllerDelegate`, `NSTextContainer.textLayoutManager`,
  `NSTextStorage.textStorageObserver`, and the `NSTextAttachmentLayout` /
  `NSTextAttachmentViewProvider` family. 6.1.3 has TextKit 1 and the port's own
  `UITextView` lays its text out in a WebKit body. There is no layout manager to answer for, and
  building one is a text engine, not a backport.
- **A focus engine** — `UIFocusEffect`, `UIFocusHaloEffect`, the `UIFocusItem` and `UIView` focus
  members, `allowsFocus`, `allowsFocusDuringEditing`, `selectionFollowsFocus…`,
  `UIWindowScene.focusSystem`, `UIFocusAnimationCoordinator`'s own 15.0 siblings. iOS 6 has no
  focus engine at all; the port never begins a focus update, so nothing delivers a focus context.
- **A scene** — `UIWindowScene` and the `UIWindowSceneActivation*` family, `UIScene.subtitle`,
  `UIWindowScene.activityItemsConfigurationSource`. iOS 6 has one window per process and no scene
  lifecycle, so there is no scene to configure.
- **A pointer** — `UIPointerStyle`, `UIPointerAccessory`, `systemPointerStyle`. iOS 6 has no
  indirect pointer device; the pointer interaction the style describes never begins.
- **Tooltips** — `UIToolTipConfiguration`, `UIToolTipInteraction`, `UIControl.toolTip`,
  `UIControl.toolTipInteraction`, `UIToolTipInteractionDelegate`. No pointer, no tooltip.
- **A camera text pipeline** — `captureTextFromCamera:`, `captureTextFromCameraActionForResponder:`.
  `UIAction` is the port's own class, but the action it would return performs live text recognition
  through a camera the release's capture pipeline does not do.
- **Content-size-category limits** — `minimumContentSizeCategory`,
  `maximumContentSizeCategory`, `appliedContentSizeCategoryLimitsDescription`. 6.1.3 has Dynamic
  Type and the port scales text for it; what it has not got is a *per-view clamp* on the category,
  which is a layout feature.
- **The rest** — the remaining rows are members of classes the release carries but whose 15.0
  behaviour has no counterpart there (button configuration on a button that has no configuration,
  `UITableView.fillerRowHeight`, `UIDatePicker.roundsToMinuteInterval`,
  `UIPrintInteractionController.showsPaperOrientation`, and the print/paste-and-go edit actions,
  which drive a print panel and a pasteboard menu the release has no UI for).

## Why this is not an audit that stopped short

The rulebook asks for an object when the rows are blocked on substrate **the port owns**, and for
the certified absence when they are blocked on substrate no band end carries. Both are true here
and the split is measurable, not a judgement call:

- **19 rows name an owner class the port itself defines** (its own `@implementation`, so the object
  exports a class symbol): `UIAction` (1), `UIImageSymbolConfiguration` (3),
  `UIListContentConfiguration` (2), `UIPointerStyle` (2), `NSDiffableDataSourceSnapshot` (2),
  `UIBackgroundConfiguration` (2), `UICollectionLayoutListConfiguration`,
  `UIMenu.selectedElements`, `UIMenuElement.subtitle`, `UIScene.subtitle`,
  `UIViewConfigurationState.pinned`, `UIWindowScene.activityItemsConfigurationSource`,
  `UIWindowScene.focusSystem`. `backports.lua:1673` (`entry_of`) says a class row answers for the
  members of a class the port defines wholly, so these are the rows where an object is the answer.
- **8 of the 19 turned out to be buildable, and are.** The first draft of this page concluded that
  every one of them was blocked on a missing capability. Reading the port's own objects showed
  otherwise for the eight that name a thing the release *can* do once something holds it:
  `UIButton.configuration`, `.configurationUpdateHandler`, `.automaticallyUpdatesConfiguration`,
  `-[UIButton setNeedsUpdateConfiguration]`, `-[UIButton updateConfiguration]`,
  `+[UIButton buttonWithConfiguration:primaryAction:]`, `-[NSDiffableDataSourceSnapshot
  reconfigureItemsWithIdentifiers:]` and `NSDiffableDataSourceSnapshot.reconfiguredItemIdentifiers`
  are delivered by `UIButton+Configuration15.m` and `UIDiffableDataSource+Reconfigure15.m`, and
  `UITableView.prefetchingEnabled` by `UITableView+PrefetchingEnabled15.m`. The test each one
  passed is the one the 14.0 cell rows passed: a behaviour the release can already perform,
  reached through a seam the tree already has. The lesson for the next band is the shape of the
  test, not the list — "the release cannot do this" and "the port has nowhere to put it" are
  different questions, and only the second one blocks a row.
- **11 of the 19 are still `absent`,** and each names the capability it waits on.
  `UIPointerStyle.accessories` and `UIPointerStyle.systemPointerStyle` need a pointer device;
  `UIWindowScene.focusSystem` needs a focus engine; the `UIScene` and `UIWindowScene` members need
  a scene lifecycle; `UIAction`'s camera action needs live text recognition;
  `UIImageSymbolConfiguration`'s three palette constructors need an SF Symbols renderer, and 6.1.3
  has none; `UIBackgroundConfiguration.image` needs storage the port's own class does not hold;
  `UIMenuElement.subtitle` and `UIMenu.selectedElements` are `@dynamic` and have no subtitle or
  selection on this release to report. `implemented` needs **a definition the band exports**
  (`backports.lua:1952`, `unbuilt`), and a property returning a fabricated pointer, focus system
  or scene is the stub §9 of the workspace contract forbids.
- The 14.0 rows on the same port-owned classes that were implemented
  (`UICollectionViewCell.configurationUpdateHandler` and its two siblings) are the precedent every
  one of the eight above followed, down to the mechanism: a category that calls a C seam
  (`UICollectionViewCell+Configuration.m` → `RevenantConfigurationHost.m`), so the effect is a
  configuration update that actually happens.

The landing state for the release is now **12 `implemented`, 4 `inert`, 89 `absent`**, and every
one of the 105 rows names a measurement rather than the SDK's declaration.

| state | rows | what it means here |
|---|---|---|
| `implemented` | 12 | a definition this band exports, through a seam the tree already had |
| `inert` | 4 | the accessor is carried and answers, and nothing applies it |
| `absent` | 89 | no cache this band's registry check reads carries the name |

**The four objects this band delivered**, each for release 15 only, each with its own facts page:

| object | rows | facts |
|---|---|---|
| `NSParagraphStyle+Text15.m` | 2 (`inert`) | `NSParagraphStyleDefaultHyphenation15.md` |
| `UIButton+Configuration15.m` | 8 (6 `implemented`, 2 `inert`) | `UIButtonConfiguration15Wiring.md` |
| `UIDiffableDataSource+Reconfigure15.m` | 4 (`implemented`) | `UIDiffableReconfigure15.md` |
| `UITableView+PrefetchingEnabled15.m` | 1 (`implemented`) | `UITableViewPrefetchingEnabled15.md` |

What they have in common is that each one reused something the tree already had rather than
adding a mechanism: the cells' `revenant_host_update_handler` seam for the button, the diffable data
sources' own reload for the reconfigure pass, the collection view's prefetch gate for the table's,
and the 13.0 layout manager's associated-object storage for the paragraph style's. None of the four
defines a C function, which is what keeps each of them safe in a band that does not keep its
sibling.

### One row the port's own object already answers, and it is not in this slice

`UIButtonConfiguration` is the 105th row of this release and is already `implemented`, measured by
`tests/backports/host/uikit2/buttonconfig_test.m` (55 checks). It is recorded here only so a reader
who counts 105 rows against 104 findings knows where the last one went; nothing in this page
changes it.
