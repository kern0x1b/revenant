# UIContentUnavailable, the empty-state API of iOS 17.0

What the host's own UIKit answers was measured first, on the host's UIKit under Mac Catalyst, and
every number and answer below is the case's, not a reading of the header. The case is
`tests/backports/host/uikit2/contentunavailable_test.m`, run by the `contentunavailable` group in
`tests/backports/host/uikit2/run.sh`, and the port is
`packages/a/apple-backports/UIKit/UIContentUnavailableProperties.m`.

## M1. The three property bags and the state object are plain holders, with three measured defaults

`UIContentUnavailableTextProperties`, `UIContentUnavailableImageProperties` and
`UIContentUnavailableButtonProperties` each hold only what their properties say. The port's three are
the same holders, and the case sets every property on the port's copy and on the system's and reads
both back: 45 checks, 0 failures.

The header states **no** default for the text bag's font, colour or line break mode, so the port's
values are not read out of it. They are what the case measured, and the case's first run is what found
them wrong — the port held zeros where the host holds three things:

```
FAIL a fresh text bag holds the same line break mode: port 0 != system 4
FAIL a fresh text bag holds a font on both sides: port (null) system ".SFNS-Regular 17.00 pt. …"
FAIL a fresh text bag holds the same default colour: port nil != system <UIDynamicCatalogSystemColor: … name = labelColor>
```

So, measured: a fresh text bag breaks its **last** line, which is `NSLineBreakByTruncatingTail` and is
**4**; it holds the **system font at 17.0 points**; and it holds a **labelled colour**.

The two colour names are the host's, and they are the two the port cannot share, so the facts carry
them and the case compares the *role*:

| side | name |
|---|---|
| the host's fresh bag | a dynamic catalog entry, `labelColor` — `UIColor.labelColor`, iOS 13.0 |
| the port's fresh bag | `[UIColor darkTextColor]` — the release's own label text colour, 6.1.3 |

Neither name exists on the other side's release, and holding the names equal would ask the port to
answer a colour it has no way to build. The case therefore asks that both sides answer a colour that
is there and is not `UIColor.clearColor`, which is what a label colour is for. The font is the same
case: the host answers `.SFNS-Regular 17.00 pt.` and `.AppleSystemUIFont` for the family, the port asks
for the system font by size, and the case compares the size and whether either side answered a font at
all.

A button bag's `enabled` is a fresh `YES` in the port and the case reads the system's fresh bag; the
two agree, and that is the case saying so rather than this file. An image bag's fresh zeros — nil
symbol configuration, nil tint, zero radius, zero maximum size, `NO` — match the host's, read the same
way.

## M1a. The bags are archivable and the archive is read back

Each bag keeps `NSSecureCoding` and answers `+supportsSecureCoding YES`, so each writes its properties
out and reads them back. The first version answered `[self init]` from `initWithCoder:` and wrote
nothing, and the review's round trip is what that cost: a button bag archived with `enabled = NO` and
`role = UIButtonRoleDestructive` came back `enabled` and plain, because nothing was read. The state
class already had the right shape in the same file; all three bags now match it.

## M2. A state over no trait collection is refused

The host raises on `initWithTraitCollection:` with a nil collection:

```
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException',
    reason: 'Invalid parameter not satisfying: traitCollection != nil'
```

The port raises the same exception with the same message, so the refusal the host has is not missing
here. Both initialisers are `NS_DESIGNATED_INITIALIZER` in the header, which is why the port's
`init` is not offered.

## M3. The two classes that are not carried

`UIContentUnavailableConfiguration` has a `button` and a `secondaryButton` of type
`UIButtonConfiguration`, which this library does not carry, and `UIContentUnavailableView` is built
over the configuration. Both rows are `absent` on that, and both land when `UIButtonConfiguration`
does.

**Corrected 2026-10-03: the paragraph above is stale.** `UIButtonConfiguration` is carried
(`UIKit/UIButtonConfiguration.m`, class row `implemented` in `registry/UIKit/ios15-16.json`), and so is
`UIContentConfiguration`, the protocol the configuration conforms to (`registry/UIKit/ios13rest.json`).
Neither class is blocked on substrate. What the configuration still waits for is seven host defaults
nobody has measured - `imageToTextPadding`, `textToSecondaryTextPadding`, `textToButtonPadding`,
`buttonToSecondaryButtonPadding`, `alignment`, `axesPreservingSuperviewLayoutMargins` and
`directionalLayoutMargins` (`coordination/api-queue.md`, owed since 2026-09-30) - and the view waits for
the configuration. Both rows' `reason` now say this; `UIKit17Absence.md`, "A stale blocker in M3,
corrected", is the same correction from the absence side.

## Not measured

- `supportsSecureCoding` on the port's copies answers yes, which is what the port has always answered for
  a value holder; the host's answer is not read by the case.
- Whether the host's empty/loading/search configurations differ in any property a fresh one holds: the
  configuration is not carried, so there is nothing to read them on.

## The red control for this group, and the 14.0 rows that are not this object's

### THE CONTROL, and why this group needed one more than the others

    $ sh tests/backports/host/uikit2/red-control.sh
    == the unplanted group, which must be green
       contentunavailable: exit=0
    == planting a line count nothing keyed asked for, in a scratch copy
    == the planted group, which must be RED and must NAME the key
       contentunavailable: exit=1
         FAIL a fresh text bag holds the same line count: port 99 != system 0
       the planted run names the line-count key, so the disagreement is attributable
    RED CONTROL OK: green before, red after, naming the key, tree untouched

The group is built for arm64-apple-ios15.0-macabi, where the four iOS 17.0 classes do NOT exist in the
system UIKit.  There is still a system side - the test holds the four classes under their own names and
the port's objects sit beside them with prefixed selectors - but the class EXISTENCE comes from the
test's own @interface declarations rather than out of a framework.  That is a weaker position than a
group whose other side the SDK supplies, and the review is right that a check which has only ever seen
its own clean output has not been shown to fail.

The plant is a VALUE, not a deletion: `_numberOfLines = 0` becomes 99 in the copy, so the group still
builds and still links.  A plant that broke the build would prove the compiler works, not that the
comparison works.  It is made in a scratch copy reached through UIKIT2_SOURCES - the runner already read
its source directory from that variable - and the control asserts the repository's own file is byte
identical afterwards, so a control that forgot to copy could not pass by editing the tree.

TWO THINGS THIS COST TO GET RIGHT, both caught by the control itself rather than by a reading:

  the first anchor was `return 0`, and numberOfLines is a synthesised PROPERTY over an ivar - there is
  no getter to edit, so the plant changed NOTHING and the run stayed green.  The file-unchanged
  assertion caught it.  A control that cannot tell a no-op plant from a real one will one day report a
  green run as a green plant.

  the suite is over ten minutes and contentunavailable is the LAST group in the file, so the control
  could never reach the group it controls.  UIKIT2_ONLY narrows the run to named groups, empty by
  default so an ordinary invocation is unchanged, and it is honoured by all THREE dispatchers - `group`,
  `windowed` and `prefixed_group`.  Filtering only one of them is what the first run showed: it built
  foundation14networkaccess and printed a listmenus compile FAIL from a group that never ran.

The control reads only ITS OWN group's failures, for that last reason: a shared build directory means a
skipped group can still leave a line in the log, and reading the whole log would credit this control with
a failure it did not cause.

### WHY THESE ARE 17.0 AND NOT 14.0, which is the question the review asks

The object adopts `<UIConfigurationState>` and implements `customStates`, `-initWithTraitCollection:`,
`-objectForKeyedSubscript:`, `-customStateForKey:` and `-setCustomState:forKey:`.  The registry dates
those same five members 14.0, in registry/UIKit/ios13rest.json:

    -[UIConfigurationState customStateForKey:]            introduced 14.0  implemented
    -[UIConfigurationState initWithTraitCollection:]      introduced 14.0  implemented
    -[UIConfigurationState objectForKeyedSubscript:]      introduced 14.0  implemented
    -[UIConfigurationState setCustomState:forKey:]        introduced 14.0  implemented

THE ANSWER: those rows name UIConfigurationState, and this object does not implement UIConfigurationState.
It implements UIContentUnavailableConfigurationState, a 17.0 class, and the five names above are the
PROTOCOL it adopts plus its own storage.  Concretely, and this is the distinction:

  A CONFORMANCE OBLIGATION.  `UIContentUnavailableConfigurationState : NSObject <UIConfigurationState>`
  declares the protocol, so the class MUST answer what the protocol declares or a caller holding it as a
  UIConfigurationState gets an unrecognised selector.  -initWithTraitCollection: and -objectForKeyedSubscript:
  are protocol members here; implementing them is conformance, not carrying 14.0 API.

  THE PORT'S OWN STORAGE.  `customStates`, `-customStateForKey:` and `-setCustomState:forKey:` are NOT on
  the protocol, and they are not in ios13rest.json at all.  They are this class's own dictionary-backed
  implementation of what the protocol's custom-state members mean for a state that carries a search
  field.  A 17.0 object implementing its own storage is not shipping a 14.0 release.

So the object adds exactly four rows and all four are introduced 17.0.  It adds no 14.0 row, carries no
14.0 implementation, and does not change ios13rest.json.  IF this object were instead re-declaring
UIConfigurationState itself, that would be carrying 14.0 API and would belong in a 14.0 object - it is not,
and the row set is the evidence: four 17.0 rows and nothing else.

The test compares the pair that matters and it is a real system comparison, not a self-comparison: the
keyed-subscript round trip ("a state holds what was keyed into it", "a state holds nothing at a key
nobody keyed", "a state's copy keeps the keyed value") runs the port's object and the system's object side
by side over the same key.  That is what the red control plants against.

## M4. The configuration and its content view: every default measured on the host, 2026-10-03

M3's blocker is gone and the two classes are carried. `UIContentUnavailableConfiguration` and
`UIContentUnavailableView` are in `packages/a/apple-backports/UIKit/UIContentUnavailableConfiguration.m`,
declared in `UIContentUnavailableConfiguration.h`, transcribed from
`charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk/System/Library/Frameworks/UIKit.framework/Headers`, whose
`UIContentUnavailableConfiguration.h` and `UIContentUnavailableView.h` are byte for byte the Mac Catalyst
ones this was measured on (compared with `diff` after stripping the comments and the availability
macros: identical). The host is the Mac Catalyst UIKit, **build 26A428, iOS 27.0** - the newest side
available on this machine, and the one whose two headers still match the 26.2 surface this port
transcribes. Every number below was read out of the three factory objects with the probe in
`.agent-work/runs/cu17/`, and every one of them is asked of both sides by
`tests/backports/host/uikit2/contentunavailable_test.m`.

    $ UIKIT2_ONLY=contentunavailable sh tests/backports/host/uikit2/run.sh
    checks=229 failures=0
    contentunavailable: exit=0

229 checks, 0 failures; 45 of them are M1's four bags and the state, 184 are this section.

### The three factories, and the six values they do not share

| | `+emptyConfiguration` | `+loadingConfiguration` | `+searchConfiguration` |
|---|---|---|---|
| `image` | nil | nil | the `magnifyingglass` symbol at point size 48 |
| `text` | nil | `Loading` + U+2026 | `No Results` |
| `secondaryText` | nil | nil | `Check the spelling or try a new search.` |
| `textProperties.font` | **bold 22** | **regular 15** | **bold 22** |
| `textProperties.color` | label | secondary label | label |
| `imageProperties.preferredSymbolConfiguration` | point size 48 | point size 32 | point size 48 |
| `imageToTextPadding` | **15** | **8** | **15** |

and, the same on all three: `secondaryTextProperties` is the regular 15 point bag in the secondary label
colour, `lineBreakMode` 4 (`NSLineBreakByTruncatingTail`) with 0 lines, `numberOfLines` 0,
`alignment` 0 (`UIContentUnavailableAlignmentCenter`), `axesPreservingSuperviewLayoutMargins` **1**
(`UIAxisHorizontal`), `directionalLayoutMargins` **32 leading, 32 trailing, 16 top, 16 bottom**,
`textToSecondaryTextPadding` **3**, `textToButtonPadding` **20**,
`buttonToSecondaryButtonPadding` **15**, `imageProperties.tintColor` a secondary label colour,
`button`/`secondaryButton` a `UIButtonConfiguration` of base style `plain` with no title, and
`background` a `UIBackgroundConfiguration` whose own description reads `Base Style = Custom` - which is
what `+[UIBackgroundConfiguration clearConfiguration]` builds (CharonBackgrounds16.m's
`CharonBackgroundStyleCustom`).

The three strings are byte for byte: `Loading` + `e2 80 a6` (U+2026 HORIZONTAL ELLIPSIS, not three dots),
`No Results`, and `Check the spelling or try a new search.`. The port spells the first one
`@"Loading\u2026"`, because a `.m` in this package is ASCII only and the byte is in the string, not in
the source.

The three **point sizes** (48, 32, 48) are read out of the host's own `preferredSymbolConfiguration`
descriptions (`pointSize=48`, `pointSize=32`), and the port builds the same configurations with
`+[UIImageSymbolConfiguration configurationWithPointSize:]`, which is carried (13.0,
`UIImageSymbolConfiguration.m`) and which its own symbol table draws from - 333 glyphs in
`CharonSymbolGlyphs.h`, of which `magnifyingglass` is one. So the search configuration's image is the
port's own drawing of the symbol the host draws, at the point size the host names; it is not the host's
bitmap, and the row says so.

### The three values this port cannot share, and what it answers instead

| what | the host | the port on 6.1.3 / 4.3 | why |
|---|---|---|---|
| the primary text colour | the dynamic catalog entry `labelColor` (13.0) | `[UIColor darkTextColor]` | the name is 13.0 and does not exist on either release; `darkTextColor` is the release's own label text colour |
| the secondary text and image tint | the dynamic catalog entry `secondaryLabelColor` (13.0) | `[UIColor darkGrayColor]` | the same, for the same role - a dimmed label |
| the button configuration | `baseStyle=plain macStyle=bordered buttonSize=small titleAlignment=center cornerRadius=dynamic`, corner radius 14 | `+[UIButtonConfiguration plainButtonConfiguration]`, radius 17 | `+[UIButtonConfiguration init]` is `NS_UNAVAILABLE` in the SDK's own header and no factory names the small/bordered/centred variant, so the port takes the plain base style it can name |

The case compares the **role** for the two colours - a colour that is there and is not
`[UIColor clearColor]` - and the `baseStyle=plain` substring for the button, because a name or a radius
that exists on one side only is not a comparison. This is the same comparison M1 already makes for the
text bag's `labelColor`, and it is the reason those names are in this file rather than in the row.

### `+new` and `-init`: the one place the port does not copy the host

The header marks `+new` and `-init` `NS_UNAVAILABLE`, and the port cannot take `NSObject`'s away - the
class is over `NSObject`, so a caller that ignores the annotation gets an object rather than a link error.
Measured on the host: `+new` answers an object whose every scalar is the zero of its type and whose four
readonly property bags are **nil**.

The port answers every scalar at the same zero, and the four bags **present**. That is the one difference
and it is deliberate: the header declares the four bag properties nonnull, and a nil bag would turn every
write to it into a silent no-op on this release. So a caller that ignored the unavailability gets zeros,
as on the host, and an object whose bags it can use, which the host's does not offer.

### `UIContentUnavailableConfigurationState`'s own `+new` and `-init`: implemented, by inheritance from NSObject

The section above is about `UIContentUnavailableConfiguration`, whose object answers both. The **state**
class is the other half. Its two rows are `implemented` and both answers are NSObject's, which is what Apple's
own class metadata says (below): neither the port nor the release defines either selector on this class, so
what a call reaches is the same on both sides. The case that holds the rows to that is `check_state_new_and_init`
in `tests/backports/host/uikit2/contentunavailable_test.m`: both sides answer `respondsToSelector:` YES for
`+new` and `-init`, and each makes an instance of its own class.

Measured over `UIKitCore` of the arm64e shared cache of iOS 18.0, read with `modules/apple/objc.lua`'s
`inventory` (one pass, seven classes at once):

| read | result |
| --- | --- |
| `-init` in `UIContentUnavailableConfigurationState`'s own instance list | **no** (`no-own-init`) |
| a method named `new` in the own metaclass list of any class of that cache | yes, **665** of 190858 - see the correction below, this line first read 0 |
| control: `-init` in a class's own instance list | yes, 37248 of 190858, `NSObject` among them, and `ARConfiguration`, whose header marks `-init` `NS_UNAVAILABLE` all the same |
| control: `+new` in `NSObject`'s own metaclass list | **yes** - `NSObject` declares `+new` itself |

So Apple's class defines neither, and the port defines neither: `UIContentUnavailableProperties.m` carries
`initWithTraitCollection:`, `initWithCoder:` and the six `UIConfigurationState` members, and no `-init` or
`+new`. What a call reaches is `NSObject`'s, on this release and on Apple's alike.

### CORRECTION, 2026-10-03: the two `+new` lines above were a control that could not fail

This section first said `+new` is in the own metaclass list of **0 of 190858** classes, "because +new is
NSObject's and is inherited rather than redeclared", and listed `NSObject` not declaring it as the control
that made the zero believable.  **Both claims are wrong, and the number was never a measurement.**

`modules/apple/objc.lua`'s `method_list` stores every method name as `"-" .. name`, whichever list it read it
from (`objc.lua:91-93`).  There is no `+` anywhere in the reader, so asking whether a class's metaclass list
holds `"+new"` asks for a key that no read can ever produce: the count is 0 for every cache, always, and it
would have stayed 0 with the port's own `+new` definitions in front of it.  A control that comes out at zero
for something that cannot be zero is a defect in the control.

Asked the way the reader actually stores names - is there a method named `new` in the metaclass list - the same
one pass over the same cache answers:

    CENSUS  classes=190858  protocols=30845  own_init=37248  own_new=665

**665**, not 0, and `NSObject` is one of them: `NSObject` declares `+new` in its own metaclass list rather than
having callers inherit it.  (The iOS 18.0 reading is in `.agent-work/runs/initnew/own-18b.tsv` of the band that
corrected it; the shape question this file also rests on - which LIST a name is in - is unaffected, because
that is what the reader does distinguish, and `UIContentUnavailable26.md` now carries a case where the
distinction decides a row.)

**What this does and does not change.**  The eight rows this section decides keep their answer: all seven
classes read `no-own-init` and `no-own-new`, each measured per class in the list's own metaclass list, which
is the reading that was always sound; what was unsound was the sentence about the cache at large.  A claim
repeated in `coordination/wave-2026-10-03/v-spatial-report.md` - "`+new` is in the OWN class list of 0 of
143137 classes" of the iOS 16.0 cache - is the same measurement and is due the same correction.

The header half, measured so the row can say why no definition is needed.
`UIContentUnavailableConfigurationState.h:21-22` redeclares both `NS_UNAVAILABLE`, and an **`NS_UNAVAILABLE`
redeclaration forces nothing**: with `clang -fsyntax-only -fobjc-arc -Wall
-Werror=objc-missing-property-synthesis` at `armv7-apple-ios6.0` and `armv7-apple-ios4.3` against the 16.4
SDK, an `@interface` carrying `- (instancetype)init NS_UNAVAILABLE;` and
`+ (instancetype)new NS_UNAVAILABLE;` draws no `-Wincomplete-implementation`, while an `@interface` that
redeclares `+ (instancetype)new;` **available** draws `method definition for 'new' not found`. The 16.4
SDK does not carry this class at all (it is 17.0); the declaration read is the 26.2 one above.

That is the whole difference from the ARKit configurations, and it is what decides them too:
`ARWorldTrackingConfiguration` and its four siblings redeclare `+ (instancetype)new;` **available**, lifting
`ARConfiguration`'s `NS_UNAVAILABLE`, so the compiler requires a definition and the port carries one. Here
both redeclarations are `NS_UNAVAILABLE`, so requiring one would add a selector Apple's class does not have.

### `NSSecureCoding`: what the archive holds and what it does not

Measured: `+[UIContentUnavailableConfiguration supportsSecureCoding]` is `YES` on the host, a search
configuration archives (12416 bytes) and reads back with every public value intact. Archiving a
`UIContentUnavailableView` **fails**: `Class 'UIContentUnavailableView' does not adopt it`, so the view
does not claim `NSSecureCoding` here either and its `initWithCoder:` is the plain `UIView` one.

The keys the port writes are the host's own, read out of the host's archive plist:
`image`, `text`, `attributedText`, `secondaryText`, `secondaryAttributedText`, `imageProperties`,
`textProperties`, `secondaryTextProperties`, `buttonProperties`, `secondaryButtonProperties`,
`background`, `alignment`, `axesPreservingSuperviewLayoutMargins`, `directionalLayoutMargins`,
`imageToTextPadding`, `textToSecondaryTextPadding`, `textToButtonPadding`,
`buttonToSecondaryButtonPadding`.

What the port does **not** write is the host's own style bookkeeping, which the same plist shows:
`defaultStyle = 2`, `prefersButtonsJustified`, `prefersSideBySideButtonAndSecondaryButton` and eight
`hasCustomized-*` flags. Two reasons, both measured: the latter two properties are **in no 26.2 header**
(`grep` over the 26.2 SDK's `UIContentUnavailableConfiguration.h` finds neither; they are 27.0 runtime
members), and the flags describe a "has this been customised" model the port has no row for and no
reason to keep. An archive the port writes reads back through the port; an archive the host wrote reads
back here with every public value and without that private state.

### The content view, and what its layout is and is not compared against

`UIContentUnavailableView` is a `UIView` that holds a copy of its configuration and lays out and draws
what the configuration says, on the release's own `UIView`, `UILabel`, `UIImageView`, `UIButton` and -
only when `scrollEnabled` is `YES` - its own `UIScrollView` with the content as a child. The buttons are
wired with `-addAction:forControlEvents:` on `UIControlEventPrimaryActionTriggered`, the event
`UIControl+PerformPrimaryAction17.m` sends and the only one measured to fire a `UIAction`
(`facts/UIKit/UIKit17Absence.md`, M10, cases 1 and 4: a touch-up-inside action runs 0 times). The margins
the content is laid out in are the configuration's own, raised to the superview's inherited margins on
each axis `axesPreservingSuperviewLayoutMargins` preserves - which is what the 26.2 header says in as
many words: *"When preserving superview layout margins on one or both axes, these are just minimum
margins, as inherited margins may be larger."* The release's `-layoutMargins` is a `UIEdgeInsets` with
no `leading`/`trailing`, and the port maps its left/right to those and says so at the mapping.

What the case compares about the view is its accessors - the configuration it holds, the copy it hands
out, the scroll flag in both directions - and that both sides build one from `makeContentView`. The two
layouts are **not** compared numerically, and the reason is stated rather than assumed: the host's
content is private subviews inside `UIKitCore`, so a numeric comparison would mean reading a private
class, and reading what the port drew instead is what the port's own rows are about. The case asks that
each side produces a content taller than zero, and nothing about the host's frames.

### The red control, extended to this half of the group

`tests/backports/host/uikit2/red-control.sh` now plants twice: M1's line count in the text bag, and a
`textToSecondaryTextPadding` of 33 against the measured 3 in this file's `initCharonWithKind:`. Run:

    $ sh tests/backports/host/uikit2/red-control.sh
    == the unplanted group, which must be green
       contentunavailable: exit=0
    == planting a line count nothing keyed asked for and a padding no measured configuration has, in a scratch copy
    == the planted group, which must be RED and must NAME the key
       contentunavailable: exit=4
       the lines the planted group printed:
         FAIL a fresh text bag holds the same line count: port 99 != system 0
         FAIL the empty text-to-secondary-text padding: port 33 != system 3
         FAIL the loading text-to-secondary-text padding: port 33 != system 3
         FAIL the search text-to-secondary-text padding: port 33 != system 3
       the planted run names the line-count key, so the disagreement is attributable
       the planted run names the padding on all three factories, so the configuration half compares every factory
    RED CONTROL OK: green before, red after, naming the key, tree untouched

All three factories are required to report the planted padding: a group that went red on one and silent
about the other two would be a group that stops at the first disagreement, which is a different defect
from one that compares everything.

Two things the control had to be fixed for, both because the group grew a file that reaches headers the
old scratch copy did not have:

  `UIKIT2_SOURCES` overrides where the group reads its sources, and the control pointed it at a flat
  scratch directory of `UIKit/*.m` and `UIKit/*.h`. This file imports `CharonLists.h`, which imports
  `CharonMenus.h`, which spells `#import "../CharonSayOnce.h"` - and `..` out of the scratch directory is
  nothing, so every file that transitively includes `CharonMenus.h` stopped compiling. The control
  reported "the planted run produced no result line", which is the wrong answer to the wrong question: a
  control that cannot build the group it controls says nothing about whether the comparison responds. The
  package's own headers are now copied **beside** the scratch directory, which is what `../` resolves to.

  `charon_pixel_ceil`, `charon_pixel_round` and `charon_screen_scale` were functions in `CharonLists.m`,
  and this file is a class file that calls them - the exact shape AGENTS.md's "A C function shared between
  backport files" describes: the link works in the dylib and fails in a group that compiles the caller
  with its own sources, which is what `run.sh`'s `group` dispatcher does. They are now `static inline` in
  `CharonLists.h`, bodies unchanged, so every translation unit has its own copy and there is no
  cross-file C symbol to miss. `UIListContentView.m`, `UICellAccessory.m` and `UICollectionViewListCell.m`
  called all three and are unaffected.

## Not measured (this section)

- The host is 27.0 and the transcription is 26.2. Where the two differ, the port carries 26.2 - which is
  the surface the ledger's rows come from - and the difference is named above rather than carried.
- The host's `contentUnavailableConfiguration` machinery on `UIViewController` (17.0, still `absent`, two
  rows) is not touched by this section: it is the host-side hook, and this section carries the
  configuration and the view it would hold.
