# The exported constants of UIKit, and the ones that need no symbol

Of the 669 `constant` and `function` rows this framework declares between iOS 7.0 and 12.0, the
measured outcome at 6.1.3 is:

| | rows | what it means |
|---|---|---|
| header-ok | 439 | enum cases and macros: the port's headers carry them and there is no symbol to carry, because there is no code at run time |
| implemented | 180 | the built libraries or the release's own cache already have them |
| **missing** | **45** | real symbols, and the whole of this file |

The 439 were measured, not assumed: the ledger reads each row's AST node out of a
`clang -ast-dump=json` of `UIKit.h` against the port's headers, and an `EnumConstantDecl` has no
symbol to find while a `VarDecl` or a non-inline `FunctionDecl` does. So the family that looked like
490 rows of work is 45, and the other 439 need nothing done at all.

## Where each of the 45 values came from

Every value was read out of a real artifact. None was chosen, and none was typed by hand:
`UIKitExportedConstants.m` is generated from the table the two reads below produce.

- **A real dyld shared cache**, with `tools/corpus/cache-value.lua`, over `~/.charon/dyld/7.0` and
  `~/.charon/dyld/11.0`, image `/System/Library/Frameworks/UIKit.framework/UIKit`.
- **The host's own UIKit** under Mac Catalyst, read through `dlsym` and dereferenced, because these
  are data symbols and not functions.

**The two agree on every one both could give: 24 values, 24 agreements, no disagreement.** That is
what makes either source usable for the rest: the cache could not give 21 of them, and the host is
the oracle for those. Two things are worth recording about the cache read:

- `cache-value.lua` reads the 7.0 and 11.0 caches but **not** the 12.0 one. A control symbol known to be
  in 12.0's UIKit (`_UIApplicationLaunchOptionsURLKey`) is reported "not in the symbol table" there
  too, so this is the tool and that cache, not the symbol list. The 12.0 slide format is the
  difference; the tool's own comment describes the masking it does for the earlier ones.
- Most of the remaining names are in UIKit's **export table** but not in the local symbol table of
  that image, because the image that defines them is another one (`UIFoundation.framework` for the
  text storage notifications, `DocumentManager.framework` for the document browser error domain).
  `cache-value.lua` reads one image, so those need the defining image named.

`NSUserActivityDocumentURLKey` is worth a line of its own: its value is `NSUserActivityDocumentURL`,
not the constant's own name. Reading it is the only way to know that.

## What the values are

44 are strings — notification names, user-info keys, activity and pasteboard types, text list marker
formats like `{box}` — and one is not: `UISplitViewControllerAutomaticDimension` is a `CGFloat` whose
value is `-FLT_MAX`, the most negative a CGFloat can hold, which is what "no dimension" is. Reading
it beats guessing `-1`.

The two `UIAccessibilityCustomRotorDirection` cases are **not** in this file: they are cases of an
`NS_ENUM` in the port's header, so they are header-ok like the 439 and defining a variable of that
name would collide with the enum case.
