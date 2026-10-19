# UIButtonConfiguration, the button configuration of iOS 15.0

What the host's own UIKit answers was measured first, on the host's UIKit under Mac Catalyst, and
every number below is the case's: `tests/backports/host/uikit2/buttonconfig_test.m`, run by the
`buttonconfig` group in `tests/backports/host/uikit2/run.sh`. The port is
`packages/a/apple-backports/UIKit/UIButtonConfiguration.m`. 55 checks, 0 failures.

## M1. The class is the SDK's own, and the port implements it

The build SDK declares `UIButtonConfiguration.h`, so nothing is redeclared here: the port is an
`@implementation` of the SDK's class, the shape `UIAction.m` uses for `UIAction`. That is also why the
differential can ask both sides the same question — the two are two classes with the same API, one the
host framework's and one the port's, renamed apart by `renames()`.

Every property name in the port is the SDK's own. One was invented and the compiler caught it: the
property is `preferredSymbolConfigurationForImage`, and an earlier version of this file wrote
`synthesize preferredSymbolConfiguration:`.

## M2. What a fresh configuration holds, and the six defaults the header states none of

The 16.4 header states no default for any property, and the first run of the case is what found that
the port's zeros were wrong in six places. Measured on the host:

| property | a fresh configuration holds |
|---|---|
| `background` | there, and its `cornerRadius` is **17** |
| `contentInsets` | **7** top, **12** leading, **7** bottom, **12** trailing |
| `imagePlacement` | **2** |
| `titlePadding` | **1** |
| `automaticallyUpdateForSelection` | **1** |
| `setDefaultContentInsets` | the same insets, **7 12 7 12** |

The port's background is a fresh instance of its own `UIBackgroundConfiguration`: its style is 0, and
0 is `CharonBackgroundStyleCustom` (`CharonLists.h:22`), which is the base style the host prints, with
the measured corner radius on it. The case holds the **radius** and nothing else about the background:
the two sides' `-description` are two implementations with two sets of fields and a pointer in each and
could never be character-equal, and the base style is not a property the host's class has at all - it
appears only inside that description - so there is no property here for a two-sided comparison to hold
on. The port exposes its own as `-charon_style`, which the host has no counterpart for.

## M3. The eight constructors are not aliases

Measured on the host, one property tells them apart — `automaticallyUpdateForSelection` is **0** for
`filledButtonConfiguration` and `borderedProminentButtonConfiguration` and **1** for the other six. The
port's `-init` answers 1, so the two that answer 0 set it. The case holds all four pairs it can
distinguish: filled, borderedProminent, plain and gray.

## M4. The one behaviour the port does not have

`-updatedConfigurationForButton:` is where the two sides part. Measured on the host: the answer is a
**new** configuration, a different object from the receiver, and its background differs from the fresh
one's; the answer's base style is plain whatever button it was asked about, and it does not carry the
button's own configuration. The port returns the receiver, so its answer is a configuration and the
host's is another one.

What a button contributes to that answer is not pinned down yet - it needs the measurement over several
button types the review asks for, and until it is made the case holds only that the port answers a
configuration. The divergence is here rather than in the row, and nothing in the file claims the port
is right about it.

## M5. What the class does not carry

The four **glass** constructors of 26.0 — `glassButtonConfiguration`,
`prominentGlassButtonConfiguration`, `clearGlassButtonConfiguration`,
`prominentClearGlassButtonConfiguration` — are not implemented, and no registry row names them. That is
the only thing `-Wincomplete-implementation` is off for in the port's file, and the reason is on the
pragma line. Everything the 16.4 header declares is implemented, including the three an earlier version
left out: `showsActivityIndicator` and `activityIndicatorColorTransformer` (both 15.0) and
`macIdiomStyle`.

## M6. The archive carries twelve of the twenty-five

`NSSecureCoding` is answered, and the archive carries the twelve properties a configuration is made of
that a coder can hold as a value — the two enums, the two strings, the two line break modes, the two
paddings, the image placement, the title alignment, the content insets and the selection flag. The
colours, the images, the background and the three block transformers are carried by `-copy`, which the
case holds. The case round-trips a configuration through a keyed archiver on both sides and compares
what comes back.
