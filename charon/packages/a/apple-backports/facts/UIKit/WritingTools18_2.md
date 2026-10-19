# The writing-tools surface of iOS 18.2, and why eight rows are absent

> **Superseded (2026-10-03).** Written while all eight rows were `absent`. `registry/UIKit/ios26.json`
> on main now carries `UIWritingToolsCoordinator`, `UIWritingToolsCoordinatorContext`,
> `UIWritingToolsCoordinatorAnimationParameters`, `UITextView.writingToolsCoordinator` and
> `UITextView.subclassForWritingToolsCoordinator` as `implemented`; `UIWritingToolsCoordinatorDelegate`,
> `-[UIResponderStandardEditActions showWritingTools:]` and `-[UIApplication defaultStatusForCategory:error:]`
> stay `absent`. The rows' own text is authoritative; the ladder measurement below still holds.

Eight rows arrived with iOS 18.2: `UITextView.writingToolsCoordinator`,
`UITextView.subclassForWritingToolsCoordinator`, `UIWritingToolsCoordinator`,
`UIWritingToolsCoordinatorContext`, `UIWritingToolsCoordinatorDelegate`,
`UIWritingToolsCoordinatorAnimationParameters`,
`-[UIResponderStandardEditActions showWritingTools:]` and
`-[UIApplication defaultStatusForCategory:error:]`. All eight are `absent`, and the fact that makes that
true is a measurement of this project's own release ladder rather than an argument about hardware.

**Where the rows live:** the eight are rows in `registry/UIKit/ios26.json`, which is where these names
already were; they are adjudicated in place there and not added to `ios17-18.json`, because the tree
keeps one row per name.

## The measurement

`tools/cache-index/first-rung.lua` answers, for one name, the first held rung that carries it — read from
the index, which is what makes it cheap enough to ask about every row. Asked about the eight:

| name | first held rung |
| --- | --- |
| `UIWritingToolsCoordinator` | NONE |
| `UIWritingToolsCoordinatorContext` | NONE |
| `UIWritingToolsCoordinatorDelegate` | NONE |
| `UIWritingToolsCoordinatorAnimationParameters` | NONE |
| `showWritingTools:` | NONE |
| `defaultStatusForCategory:error:` | NONE |
| `NSObject` (control) | 3.0 |
| `UIResponderStandardEditablesActions` → `UIResponderStandardEditActions` (control) | 10.0.1 |

The ladder's top held rung is 18.0 and the API arrived in 18.2, so NONE is the expected answer — and the two
controls are in the same table, answering 3.0 and 10.0.1, so the six NONEs are the index finding nothing
rather than the index finding nothing at all. A row whose claim rests on a probe that finds everything
missing is not evidence; these six rest on one that finds.

## Why this fact and not a device fact

The obvious argument for these rows was that Apple's Writing Tools run on-device and want a Neural Engine,
and that the iPhone 4S is an A5. That argument was refused, and correctly: **no facts page in this
repository records an A-series, CPU-generation or Neural Engine fact for either fleet device**, and the
device runs iOS 6.1.3, where the question cannot be asked of the device at all. An unsourceable claim of
absence decays into a false statement, so it is not used.

What replaces it is sourceable and answers the question these rows actually ask — "can the caller get
this on this release?" — from the tree: there is no rung of this ladder that carries the name, so there is
no implementation to write against and the caller sees `respondsToSelector:` answer honestly.

## What would move them

A rung above 18.0 in the ladder. When a cache for 18.2 or later is unpacked under `~/.charon/dyld/`,
`first-rung.lua` answers a real rung for these names and the question becomes a different one: whether the
coordinator is worth carrying over what the tree has. Until then there is nothing to read Apple's own
behaviour out of, and nothing to match it against.
