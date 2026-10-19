# The UIButton configuration members of iOS 15.0: what is wired and what is only kept

Eight rows of release 15.0, one object: `packages/a/apple-backports/UIKit/UIButton+Configuration15.m`,
a category on the SDK's own `UIButton` — nothing is redeclared, which is why the file is an
`@implementation` of a category. Six are `implemented`, two are `inert`, and the difference is
the substance of this page rather than a detail in it.

## Why a button at all, when the cells already have this

The port has carried `configurationUpdateHandler` on `UICollectionViewCell`, `UITableViewCell` and
`UITableViewHeaderFooterView` since 15.0 landed — `UIConfigurationUpdateHandler15.m`, three
categories that call `charon_host_update_handler` and `charon_host_set_update_handler` from
`CharonConfigurationHost.m`. Those two functions take a **`UIView`**. They are not cell-specific;
they are view-specific, and a button is a view. Calling them from a button category is reuse, and
it is why this file defines **no C function of its own**: a C function defined in a file that
exports API is left out of the bands that already export that API, and the call is then
`Undefined symbols` in exactly those bands (`AGENTS.md`, "A C function shared between backport
files"). `charon_request_update` is the third seam, and it is the same one.

So the delivered work is the button's own half: the configuration value kept per button, the
update path, and the primary-action constructor. The value itself is not new — the port's
`UIButtonConfiguration.m` implements it, and `tests/backports/host/uikit2/buttonconfig_test.m`
holds its constructors and twenty-five properties against the host's.

## What the release has, measured

`6.1.3`'s own Objective-C metadata, read with the tree's reader
(`xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7`):

- `UIButton` carries **no selector mentioning `configuration` at all**;
- `UIButtonConfiguration` is **not a class the release declares**.

That is the whole shape of the problem, and it is why this file exists: the port can hold a
configuration, and the button can hold one, and the release's button has no way to be *given* one.
Wiring those two facts together is the backport. `4.3` and `12.0` carry neither the class nor the
selector either, and the rows' `source` records all three readings.

## The six implemented rows

| row | what it does |
|---|---|
| `UIButton.configuration` | keeps the configuration per button, **copied on set** so that mutating the caller's configuration afterwards does not reach back into the button; setting it asks for an update |
| `UIButton.configurationUpdateHandler` | keeps the handler per button, copied on set; **setting it asks for a configuration update** |
| `-[UIButton setNeedsUpdateConfiguration]` | asks for the update now |
| `-[UIButton updateConfiguration]` | runs the handler with the button and its configuration; does nothing when there is no handler |
| `UIButton.automaticallyUpdatesConfiguration` | **`YES` until something says otherwise**, and setting it `YES` asks for an update |
| `+[UIButton buttonWithConfiguration:primaryAction:]` | a system button holding the configuration, with the action delivered by `-addAction:forControlEvents:` |

Three of these are copied from a measurement rather than invented, and the sources are named so a
reader can check them:

- **`automaticallyUpdatesConfiguration` defaults to `YES`.** That is not a guess: the 14.0 row
  `-[UICollectionViewCell automaticallyUpdatesContentConfiguration]` was measured on the host under
  Mac Catalyst, and `UICollectionViewCell+Configuration.m` carries that default and the
  "setting it asks for an update" behaviour. The button's flag is the same flag on a different
  view, through the same seam.
- **The copy on set** is what the value's own `-copy` is for, and it is the same thing the 14.0
  cell rows do with their `contentConfiguration`.
- **The constructor reuses `+[UIButton buttonWithType:primaryAction:]`** from
  `UIButton+Actions14.m` rather than wiring the action a second way. That constructor sets the
  title and image from the action and calls `-addAction:forControlEvents:`, both of which the port
  already carries; a configured button draws its title and image from the configuration, so the
  configuration takes the place of the two `set…forState:` calls and everything else is the same
  code path. Writing a second wiring here would have been a second copy of a thing that exists.

## The two inert rows, and why they are not implemented

`UIButton.changesSelectionAsPrimaryAction` and `UIButton.subtitleLabel` are carried and read back
and **nothing applies them**:

- The flag says a selection on this button should be treated as its primary action. The release's
  button has no selection-primary-action behaviour for the flag to drive, so setting it changes
  nothing measurable.
- `subtitleLabel` **does** answer a real `UILabel`, created on first ask and kept, so a caller can
  set text on it. It is not laid out under the title, because the release's button has no
  two-line layout to lay out — that part is a layout feature, not a backport.

This is the landing `NSLayoutManager.usesDefaultHyphenation` took at 13.0 and
`UIParagraphStyle`'s half took at 15.0: **`inert` means the symbol loads and nothing applies it**,
which is exactly true here, and it is honest in a way `implemented` would not be. The row's
`effect` says it in those words so a caller who sets the flag and sees nothing can find the
sentence from the row.

## One release, one minimum

Both the object and the rows are single-release by construction: every one of the eight rows is
`introduced 15.0` with `minimum 6.0`, and the file defines no other API. `release-split` reads
band points, and a file mixing two releases passes it silently, so this was checked by reading
each row's `introduced` and `minimum` rather than by the tool — see
`.agent-work/runs/release-split.md` for why the tool itself had nothing to read on this machine.

## What was checked, and what was not

**This file compiles.** It was checked with the same flags `review-mechanical.sh` uses - `xcrun clang -target armv7-apple-ios6.1.3 -isysroot <iPhoneOS16.4.sdk> -fobjc-arc -Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability -Werror=objc-missing-property-synthesis -fsyntax-only` - and it builds with zero errors and zero warnings. What has **not** happened is a link into a band or a run on a device, and that is the gate's.

The first draft of this file was **refused by the armv7 compile** and the refusal is worth
recording: `-updateConfiguration` called the handler block with `(self, configuration)` and clang
said *"too many arguments to block call, expected 1, have 2"*. The SDK settles it —
`UIButton.h:46` reads `typedef void (^UIButtonConfigurationUpdateHandler)(__kindof UIButton *button)`
— so the handler takes the button alone, the configuration it needs is the one the button already
holds, and the call is `handler(self)`. The row's effect was corrected with it, and the facts page
for the reconfigure pass records the same lesson about Apple's headers being the authority.

Also checked, without a compiler being enough: every selector the file calls exists in the port or
the SDK (`+buttonWithType:primaryAction:` in `UIButton+Actions14.m`, `-addAction:forControlEvents:`
on `UIControl`, the three seams in `CharonConfigurationHost.m`); no other file in the tree defines
any of the eight selectors it defines, so nothing is shadowed; and the storage pattern is the one
`UIConfigurationUpdateHandler15.m` and `NSLayoutManager+Text13.m` already use.

The category was then compiled to an object and read back with the tree's own reader
(`modules/apple/objc.lua` `binary_inventory`), which reports **12 selectors on `UIButton`** — the
eight this file adds plus the four the rows do not name (`-copy`-side storage accessors and the
`-is`-form getters), every one attached to a class the 6.1.3 cache carries, which is what
`check_categories` (`backports.lua:1308`) requires for a category to attach at all.
