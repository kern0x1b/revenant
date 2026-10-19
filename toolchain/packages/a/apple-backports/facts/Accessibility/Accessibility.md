# Accessibility on a release that has the C library and not the classes

`libAccessibilityBackports.dylib` carries the first two groups of the Accessibility framework of SDK
26.2: the request and the feature-override session, the braille tables, and now the chart and data
classes of 15.0. Every registry entry of this framework points here.

## What the release has, measured

`tools/intents/measure-release-carries.lua` walks **every** library in a release's cache and prints a
control symbol, so "carries none" is a measurement and not a probe that could not look. Against the
**6.1.3 armv7** cache: 580 libraries, control symbol found.

```
the release carries 0 of 30, and does not carry 30
```

The same walk against 4.3 armv7 (398 libraries) and 3.0 armv6 (152 libraries) answers 0 of 30 on
both, with the control symbol found on both.

Zero, and yet the release has had Accessibility since iOS 3. What it has is the **C** library. Every
AX-prefixed export of every Accessibility library in the 6.1.3 cache, walked out of the cache's own
library list:

```
/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities  (190 AX symbols)
/System/Library/PrivateFrameworks/UIAccessibility.framework/UIAccessibility  (43 AX symbols)
/usr/lib/libAccessibility.dylib  (310 AX symbols)
total AX-prefixed exports across Accessibility libraries: 543
```

All 310 exports of `libAccessibility.dylib` are its `AXS*`/`kAXS*` preference surface - 310 of 310
match that prefix, and none does not - and **no** export is named as the public C API: zero of the 543
match `_AXUIElement`, `_AXIsProcessTrusted`, `_AXValue`, `_AXError`, `_AXObserver`, `_AXMessaging`,
`_AXNotification`, `_AXRuntime` or `_AXMakeProcessTrusted` at the start of a name. Two exports contain
the string `AXUIElement` inside a longer private name in `UIAccessibility`, and neither is that API.
The braille names that are there are VoiceOver's braille *display settings* - a table identifier
preference and its siblings - not the braille table API of 26.0.

So this framework is two things stacked: a preferences library the release already answers for, and
thirty Objective-C classes the SDK of 26.2 declares on top of it, of which this delivery carries
thirteen.

That is why no band needs a straggler here: nothing in either group is a class the release exports,
so every band builds the library whole and `tools/intents/measure-group.lua` - the check that found
the `INPaymentMethodResolutionResult` red - has nothing to name for Accessibility.

## The six headers 16.4 does not have, and what this tree declares

26.2 ships **thirteen** Accessibility headers and iPhoneOS 16.4 ships **seven**. The six that are new
to 16.4 are `AXRequest.h`, `AXMathExpression.h`, `AXBrailleTranslator.h`, `AXFeatureOverrideSessionManager.h`,
`AXSettings.h` and `AXTechnology.h`. Three of them are already transcribed in
`Accessibility/RevenantAccessibility.h`: the request, the feature-override session and the braille
classes, and with them `AXTechnology` - Apple's own `NSString *const` typedef, whose nine constants are
externs, spelled out because a backport writes the declaration itself. One spelling is worth recording
because it cost a compile and would cost the next person the same: an ivar of `AXTechnology` is a
*const pointer* and can never be assigned, so the class's storage is an `NSString *` and the property's
accessor answers it unchanged.

**The band a chart object lands in is measured, not read from the header.**
`tools/release-split.lua` over the built objects answers 16.0 for all fourteen class symbols of
`RevenantChartDescriptors.o`, while Apple's header and the corpus both say 15.0:

```
release-split: clean, every object file's symbols first-appear in one release (5 files, 26 symbols, 50 releases checked)
RevenantChartDescriptors.o	_OBJC_CLASS_$_AXChartDescriptor	16.0
RevenantChartDescriptors.o	_OBJC_METACLASS_$_AXChartDescriptor	16.0
```

The 16.0 is what the SDK the objects were compiled against can prove: its own interface file for the
16.0 Accessibility framework exports these names, and no earlier release on the held ladder is held with
a cache that does. That is the same rule the tool's own header describes - a header can name a later
release than the one that already exports the symbol - read the other way round. The consequence is the
one that matters and it is not a gap: `band()` keeps an object in every band whose release is older than
the object's own, so an object placed at 16.0 is carried on 6.1.3, 4.3 and 12.0 and is left out from
16.0 up, where the system has the class itself. The classes of 18.0 and 26.0 in the same library have
no export in that interface file at all and come out `none`, and are placed by the registry and the
header instead - which is why the two are named here and the 15.0 classes are not.

**`AXMathExpression.h` is transcribed, and the fifteen classes it declares are carried.**
`Accessibility/RevenantAXMathExpression.h` holds the declarations and
`Accessibility/RevenantAXMathExpression.m` the 39 rows. **The earlier note in this file, and the one in
`xmake.lua`'s `accessibility` description, said these classes are "an expression parser" and were not
carried because "an ivar per property would answer a parse that never happened". Both were wrong, and
the header is what says so**: `AXMathExpression.h` declares no method that takes a string, and no member
of any of the fifteen classes is anything but a value an initialiser was given - a leaf holds a string, a
container holds the expressions it was given. The tree an application builds is the tree an assistive
technology would be handed; turning it into speech or Braille is the system's half, and this release
has no assistive technology, so the container is the whole of the work. The registry rows said the same
thing and are now `implemented`.

**`AXCustomContent.h` is in 16.4 and needs no toolchain header**, so the class is declared by the SDK the
package compiles against - `Accessibility/RevenantAXCustomContent.m` is code only. The one member of
`AXCustomContentProvider` that 16.4's copy lacks, `accessibilityCustomContentBlock` of 17.0 (26.2's copy
adds six lines inside the protocol: a block-returning typedef, an `@optional` marker and the property),
is a different matter and is the one row of the two this group did not take. A protocol **category** in a
toolchain header would be the way to add it without a second declaration of the protocol, and the port does
not carry one: the member is unreachable on this release whatever the header says, because nothing on
this release implements it - `NSProtocolFromString(@"AXCustomContentProvider")` answers nil here and
answers nil on the host's own framework too, where the protocol is declared in a header and never
registered. A declaration of a member no object on this release could answer is a name with nothing
behind it, and the registry's own `implemented` check would refuse it. Both protocol rows are
therefore `absent`, and the reason each carries says which of the two walls it is.

This matters mechanically and not only for the compiler. A name no release exports and no implemented
registry row places is *unplaced*, and `modules/apple/backports.lua`'s `misplaced()` then refuses the
object that defines it with "no band can hold it". A class the SDK's own header declares is placed by
that header's availability annotation, read out of a clang AST dump of the source being compiled by
`introduced_version()`. Measured for the three headers above, compiling one file per name against the
16.4 SDK with `-Xclang -ast-dump -Xclang -ast-dump-filter`:

```
AXLiveAudioGraph   |-AvailabilityAttr <col:43, col:84> ios 15.0 0 0 "" "" 0
AXChartDescriptor  |-AvailabilityAttr <col:43, col:84> ios 15.0 0 0 "" "" 0
AXCustomContent    |-AvailabilityAttr <col:43, col:84> ios 14.0 0 0 "" "" 0
AXBrailleMap       |-AvailabilityAttr <col:43, col:84> ios 15.2 0 0 "" "" 0
```

The annotation has to be on the `@interface`, not on the `@implementation`: the same annotation above an
`@implementation` produces no `AvailabilityAttr` on the implementation node, which was measured with
the same dump. This is also how the 27 `inert` class rows elsewhere in this registry are placed, so an
`inert` class the release lacks is not a special case.

## The three walls, and what each answers

**A request is the system's.** `+[AXRequest currentRequest]` is the request the system's assistive
technology is serving, and `technology` is the one serving it. No assistive-technology service holds a
request on this release, so `+currentRequest` is **nil** and the class is the container an application
keeps its own request in: `-revenant_withTechnology:` builds one, the coding and the copy carry it, and
`+currentRequest` says there is none.

**A feature override is a service.** `beginOverrideSessionEnablingOptions:disablingOptions:error:` is
how an application asks the system to turn grayscale on, or Voice Control on, for a while. The system
that does it is not on this release, so the manager answers **nil with
`AXFeatureOverrideSessionErrorUndefined`** - the header's own name for a session that could not be
begun for no more specific reason, and there is no more specific one: there is no service, so there is
nothing to be entitled to, nothing already active and nothing registered under a UUID.
`endOverrideSession:` answers NO for the same reason, and a session that cannot exist is not invented so
that the call has something to end.

**A braille table is Apple's data.** `AXBrailleTable` is a provider's dot patterns, and
`AXBrailleTranslator` maps print text onto the table it is given. The table the system installs is not
on this release, so `+supportedLocales` is an **empty set**, the two other sets are empty, and
`+defaultTableForLocale:` is nil - which is what makes the translator's answer honest rather than
invented: a translation of nothing is the input with **no cells**, and the location map is empty
because no cell was produced. Both directions answer that way, the second without guessing print text
out of dot patterns. A table an *application* builds is real and is kept, coded and copied.

## Does the release carry any of these names? Measured, and no

`tools/cache-index/first-rung.lua` answers for the oldest held release carrying a name, which is exactly
the question "is a whole-class `@implementation` the right direction here, or a category":

```
$ printf '%s\n' AXMathExpression AXMathExpressionNumber AXMathExpressionFenced AXMathExpressionRow \
      AXCustomContent AXCustomContentProvider NSObject | xmake l tools/cache-index/first-rung.lua
AXMathExpression	NONE
AXMathExpressionNumber	NONE
AXMathExpressionFenced	NONE
AXMathExpressionRow	NONE
AXCustomContent	16.0
AXCustomContentProvider	16.0
NSObject	3.0
```

`NSObject` at 3.0 is the positive control in the same run, so the four `NONE`s are answers and not a
tool that found nothing. **All fifteen AXMathExpression names read `NONE`**: no held release carries
the class, so implementing it whole is the right direction. `AXCustomContent` reads **16.0**, the same
reading `AXChartDescriptor` of 15.0 gets and the same rule written down above - `band()` keeps an object
in every band whose release is older than the object's own, so an object placed at 16.0 is carried on
6.1.3, 4.3 and 12.0 and left out from 16.0 up, where the system has the class itself.
`tools/release-split.lua` reads the same 16.0 for that object, and `minimum: 6.0` is what carries it
below. The 16.0 is "after 12.0 and by 16.0" and not a measured first release - no release is held
between 12.0 and 16.0 - and what the reading settles is the one it was asked: **6.1.3 and 4.3 carry
neither group.**

`AXCustomContentProvider` reads 16.0 too, and that is a *name* in the cache, not a protocol object.
`NSProtocolFromString(@"AXCustomContentProvider")` answers **nil** - in a process with nothing of this
library in it, and in the host's own framework, where the protocol is declared in a header and never
registered. A name in the cache and a protocol with no object are the same fact seen two ways, and they
are what the two `absent` rows rest on.

The same reading for six classes this repository already ships is what says a `minimum` of 6.0 does not
mean "the release has this class":

| class | registry `minimum` | first held rung carrying it | whole-class `@implementation` |
| --- | --- | --- | --- |
| `HKSource` | 6.0 | 8.0 | yes |
| `AXRequest` | 6.0 | 18.0 | yes |
| `AXBrailleTable` | 6.0 | `NONE` | yes |
| `AXFeatureOverrideSessionManager` | 6.0 | `NONE` | yes |
| `AXChartDescriptor` | (none) | 16.0 | yes |
| **`AXCustomContent`** (this band) | 6.0 | 16.0 | yes |
| **`AXMathExpression`** (this band) | 6.0 | `NONE` | yes |

## The two groups that had no object behind them: AXCustomContent of 14.0, AXMathExpression of 18.2

45 of the 47 rows of these two groups are now `implemented` and 2 stay `absent`. The two groups were
`absent` for a stated reason, and **the stated reason for the 39 AXMathExpression rows was wrong**: it
said the classes "are a parser and an evaluator for the mathematics grammar ... and an ivar per property
would answer a parse that never happened". `AXMathExpression.h` declares no parser. It declares fifteen
containers, each of which has an initialiser that takes a value and properties that read that value
back, and there is not one method in the file that takes a string. An ivar per property **is** the class.
The registry rows, and `xmake.lua`'s `accessibility` description, repeated the claim; both are corrected
above.

Every rule below was measured against the host's own `Accessibility.framework` (macOS 27.0, whose SDK's
`AXMathExpression.h` is byte-identical to iPhoneOS 26.2's apart from two copyright lines, so the header
under test is the one the corpus was built from) by `tests/backports/host/accessibilitymath/run.sh`,
which builds the same cases against the system's classes and against the port's - compiled under names
the system does not use, so neither can answer for the other - and compares the two outputs line by
line:

```
=== the two answers: 137 cases a side (135 behaviour, 2 declaration), 7 declared to differ
cases read: 137 a side; declared differences: 7; undeclared or moved: 0
identical on all 135 behaviour cases except the 7 declared above: the system and the port answer the same
declaration cases: 2, which check a header and not the port's code; compared above, 2 of 2 the same
```

`tests/backports/host/accessibilitymath/mutants.sh` is what says the case can fail: thirteen mutants, one
per rule, each changing one line of the port's own source in a copy of it, and **13 killed by the
comparison, 0 did not die in the required way, 0 survived.** Four of the thirteen were wrong on the first
attempt, and each was wrong in a way worth recording because a surviving mutant is a check that
examines nothing:

* copying an immutable `NSArray` hands back **the same** array, so "answers the very array it was given"
  is invisible unless the caller gave a mutable one. The case was strengthened
  (`mx.fenced.mutable.is.same.array` and the caller-appends case), not the mutant weakened.
* a copy of a content whose importance was never raised cannot be seen to have dropped it. The case was
  strengthened (`cc.copy.of.urgent.importance`).
* a fifth argument added to a four-specifier format is **ignored** by `stringWithFormat`, so the first
  spelling of M13 changed nothing at all and the case passed with the rule broken.
* and the case file found a real defect the mutants never would have: `-description` written with `%@`
  on `self` **calls itself**, and the case that reads it died on a segfault. The class and the address
  are now spelled out the way `NSObject` spells them, and the port's `AXCustomContent` prints what the
  host's does - `<AXCustomContent: 0x...>: label: Orientation, value: Portrait`, with **no importance in
  it**, because the host's description does not print one either (both measured).

**The three numbers in this group, and where each came from.** None of them was chosen:

| number | what it is | where it comes from |
| --- | --- | --- |
| `AXCustomContentImportanceDefault` = 0, `AXCustomContentImportanceHigh` = 1 | the two cases of the enumeration | the header, `AXCustomContent.h` of 16.4: it is an `NS_ENUM` and `Default` is its first case. Confirmed on the host: a fresh content answers 0 and one set to `High` answers 1 |
| the four `AXCustomContent` properties are four spellings of two values | the storage model | measured on the host: `customContentWithLabel:value:` gives an `attributedLabel` whose `.string` is the string passed in, and `customContentWithAttributedLabel:attributedValue:` gives a `label` that **is** `attributedLabel.string` (identity, not equality) |
| 18.2, and `visionos(2.2)` left off | what places the object | the `API_AVAILABLE` on each `@interface` in `RevenantAXMathExpression.h`, which is what `introduced_version()` reads. The `visionos` argument is in Apple's copy of every one of those lines and is dropped because the SDK of 16.4 has no such platform and writing it does not compile (measured: 16 `expected ','` errors) |

**The seven declared differences, and why the port does not follow the host on them.**
`AXMathExpressionRow.expressions` and `AXMathExpressionTable.expressions` answer **nil** on the host,
whatever array the initialiser was given - nil for one element, for three, for a mixed array, and nil
again for an empty array, six cases, nil in every one. The three other classes declaring the same member
- `AXMathExpressionFenced`, `AXMathExpressionTableRow`, `AXMathExpressionTableCell` - answer the very
array they were given. The port answers the array for all five, because the header declares the property
`nonnull` and the initialiser takes it: the value is the caller's own, and a port that reproduced the
drop would break every caller that compiled against the header on a release where the caller can get
nothing better. The seventh case is the same difference seen from further down a whole tree. This is the
only place in the two groups where the port does not follow the host.

**The one property whose header disagrees with itself.** `AXMathExpressionSubSuperscript`'s initialiser
takes `baseExpression` as an **array** and its property is declared a **single** `AXMathExpression *`; the
two cannot both be right. The host answers the array, unflattened and identity-preserved (measured:
`__NSArrayI` holding the two elements the initialiser was given, and the very array it was given). The
port does the same, and `RevenantAXMathExpression.m` says why in a comment at the cast: the initialiser is
the only source of the value and the property the only way to read it back, so answering one of the
elements would throw away what the caller put in, and nothing in the header says which element that would
be. The declaration is transcribed as Apple writes it and **not** corrected - a backport that fixed the
type would stop being the thing an application compiles against - and a caller that wants one expression
takes `firstObject` itself. `denimonatorExpression` is Apple's own misspelling, in the initialiser and in
the property, and it is the name the corpus row and every caller use, so it is the name the port carries.

**The two rows that stay `absent`, and what the protocol is on this release.**
`AXCustomContentProvider.accessibilityCustomContent` and `.accessibilityCustomContentBlock` are members
of a **protocol**, and the protocol has no object behind it here or on the host:
`NSProtocolFromString(@"AXCustomContentProvider")` answers **nil** in a process with nothing of this
library in it, and nil in the host's own framework, where the protocol is declared in a header and never
registered. An application that adopts the protocol is one of the port's own classes and implements the
accessor itself, which is where the value lives. The second of the two is a further step: 16.4's
`AXCustomContentProvider` does not declare it at all, so the port cannot name it either. `implemented`
would be refused by the registry's own check, which asks what is built and finds nothing under a protocol
name, and a protocol category declaring a member no object on this release could answer would be a name
with nothing behind it.

## The chart and data classes of 15.0

The group is seven classes and the two protocols that declare an axis, of which the class
`AXLiveAudioGraph` is the one that asks for something; the other six are containers. An application
fills a container in and an assistive technology reads it back, and neither half has to reach anything
on this release, so the value each one keeps is the value it was given. Every rule below was measured against the host's own `Accessibility.framework` by
`tests/backports/host/accessibilitychart/run.sh`, which builds the same 206 questions against the
system's classes and against the port's - compiled under names the system does not use, so neither can
answer for the other - and compares the two outputs line by line. **193 of them are behaviour cases and
all 193 answer the same; 13 check a declaration** (the two protocols and their members, which come from
whichever header each side compiled against and are counted apart for that reason) **and there is no
declared difference left.** The case's own `expected-differences.tsv` is empty and says why, and the
summary line `run.sh` prints says which of the two kinds each case is:

```
=== the two answers: 206 cases a side (193 behaviour, 13 declaration), 0 declared to differ
cases read: 206 a side; declared differences: 0; undeclared or moved: 0
identical on all 193 behaviour cases: the system and the port answer the same
declaration cases: 13, which check a header and not the port's code
```

**A name and an attributed name are one value.** The header declares `title` and `attributedTitle` (and
`label`/`attributedLabel`, and `name`/`attributedName`) as two readwrite properties each. On the host,
setting either face leaves the other holding the same characters, and setting one to nil leaves the
other nil - measured on a chart, a data point, a series and both axis classes. The port keeps two
storage slots and its two setters write both, which is the smallest thing that keeps them in step.

**A data point value's two faces are independent, and are not the same rule.** The factory for a number
leaves the category **nil**; the factory for a category leaves the number **0**, not NaN and not a
raise. A write to one afterwards does not move the other: a number value given a category keeps 1.5, a
category value given a number keeps "cat".

**A nullable argument stays what it was given.** A data point built with the two-argument initialiser
answers nil for its y value, its additional values, its label and its attributed label. A chart given
an empty series answers an empty array, and the same chart given nil answers nil. A numeric axis given
nil gridline positions answers nil, and answers nil again after a set to nil.

**The two values no initialiser takes start where the host's start.** A chart's `contentFrame` is a zero
rectangle and its `contentDirection` is the zero case of its own enumeration, and both are set and read
back when a caller sets them.

**`-copy` is shallow, and which objects it shares was measured one field at a time.** The case asks
every copy whether it answers the very object its original does, and prints shared-or-copied for each -
the addresses stay out of the output and the question is the same on both sides. Measured on the host:
a copy of a chart, a series, a categorical axis, a numeric axis and a value shares its arrays, its axes,
its block and both faces of its name pair, and a copy of a data point shares the plain label and answers
a **new** attributed string. So four of the five copies hand their storage over, and the point's copy is
built through its own pair's setter, which is what makes the attributed string a new one.

That last rule was found by the identity probe and not by reading: the first version of this file said
the copies share, the case could not see whether they did, and when the probe went in it turned up four
copies in this port that rebuilt the attributed face through an initialiser where the system shares it.
All four are fixed, and a mutant per class now holds each of them.

### The two protocols, and how a caller gets their metadata

`AXChart` and `AXDataAxisDescriptor` are rows of their own in the registry, and what the port carries for
them is the declaration and the metadata: `modules/apple/backports.lua`'s `protocol_sources()` reads the
two `implemented` protocol rows and writes `AccessibilityBackportsProtocols15.0.m`, which names each one
so clang emits its metadata into that object. `Accessibility/RevenantAccessibilityProtocols.h` is the
header that generated source imports, and it exists because without it the build stops on "file not
found" - the light guard says so by name.

The port implements **no member** of either protocol: they are declarations an adopter answers, and the
port has no class of its own that adopts them. What the case checks is that a caller can: it declares a
class that adopts both, gives it values, and asks it - `conformsToProtocol:` for each, its title, its
attributed title, the series count of the chart descriptor it was handed, and its own description. On the
port those answers come from the port's own protocol metadata, and on the host from the framework's.

The adopter is in **both** halves of the case, and that is the whole fix for a hole the first version of
this case had: the system's Accessibility image does not list `AXChart` in its protocol list, so with no
adopting class the name resolved on one side and not the other and four of the cases were comparing the
case's own file with itself. `AXDataAxisDescriptor` never had the problem - the system's own image names
it - and the case now has the adopter for both so the two halves are asked the same question. The port
half is also given the generated protocols object, because that object is part of what the port ships and
its absence would be a real defect; the host half is not, because the host's equivalent is the framework
it links.

The thirteen cases labelled `declaration.` are the ones that do not test the port's code: their members
come from whichever header each side compiled against, so a change to Apple's header moves them and
nothing under `packages/` can. They are counted apart from the behaviour cases in the summary line above,
so "193 answer the same" is a claim about the port and not about a header.

### The three fields the port's copies drop, because the system's do

The host's own `-copyWithZone:` drops three fields, and the port drops the same three. Measured twice on
the host: a chart set to direction 5 and frame (1, 2, 3, 4) and a numeric axis set to scale case 2, and
of the copies of those objects the host answers the zero case, the zero rectangle and the zero case
again, while every object-typed field of the same copies is carried - the title, the summary, the shared
series array, both axes, the additional axes, the gridline positions, the caller's own description
block. The three fields it loses are the three value-typed ones, and it loses the same three in both
runs.

**The policy of this framework is the system's behaviour, so a copy here answers the same.** A copy that
kept them would be a port that is better than the system, and that is a thing to decide on purpose and
record, not to arrive at by writing a careful copyWithZone:. What a copy that kept them would be good
for is written down in the ledger the coordinator keeps
(`.agent-work/handoffs/better-than-system-accessibility.md`): a port application that sets a chart's
content frame, copies the descriptor and reads the copy's frame would get the frame back here and a
zero rectangle on the device, which is a difference a port should not have introduced quietly.

What pins the parity is three mutants, one per field, each of which puts the field back into the copy
and has to turn that one case red. The three rows of `expected-differences.tsv` that used to declare
these differences are gone and the file says in its own lines why it is empty: a declaration could not
have held this, because a port that quietly started *agreeing* with the host would have passed a
"the two must not agree" check and told nobody anything about the parity the policy asks for.

### AXLiveAudioGraph, the one member of the group that asks for something

A live audio graph is drawn by an assistive technology, and this release runs none: the whole
Accessibility surface it holds is the preferences library above, and no publisher of a graph is in it.
The class is carried and `inert`, and so are its three class methods, each of which writes one line to
the log the first time it is used - the package's own say-once, so a second call is silent.

The class holds **no state**, and that is measured rather than assumed: the host's instance has no ivar
at all (`class_copyIvarList` over `AXLiveAudioGraph` returns none, and its instance size is 8, which is
the isa pointer and nothing else), and all three of its methods are class methods
(`class_getClassMethod` for each). No value is refused and no call raises, because the host does not:
it takes a value below the unit range, a value above it and a call after `+stop`, without complaint.
What the case compares for this class is the shape both sides can answer - the three class methods, the
instance size, the ivar count, that the calls survive - and the sound itself, which a program cannot
read, is not compared and is not claimed.

**The once-only part of the `inert` contract is held by a count, not by a comparison.** "Declared, does
nothing, and says so once in the log the first time it is used" is most of what the four `inert` rows
here claim, and a log line is not a value: the host writes none, because the system's three methods
publish sound. So the case calls each of the three members several times and prints how many times, and
`run.sh` counts the port's own log lines against exactly those numbers and fails if any member wrote
more than one:

```
say-once: +[AXLiveAudioGraph start] called 3 times, 1 line in the port's log
say-once: +[AXLiveAudioGraph updateValue] called 5 times, 1 line in the port's log
say-once: +[AXLiveAudioGraph stop] called 2 times, 1 line in the port's log
```

A mutant that takes the guard out of `RevenantSayOnce.h` writes a line per call, and the run fails with
"the port wrote 3 lines for +[AXLiveAudioGraph start], and the case called it 3 times". That is what the
`inert` status now rests on rather than on a sentence.

## AXBrailleMap, 15.2: the pin state of a display that is not there

A braille map is the state of a connected two-dimensional braille display: a grid of pins, each raised
to a height or lowered, and a size. The release has neither the class nor the protocol
(0 of the framework's 30 classes on 6.1.3 armv7, on 4.3 armv7 and on 3.0 armv6, control symbol found on
all three), and it needs no toolchain header: `AXBrailleMap.h` is in the SDK the package compiles against
and is byte-identical to 26.2's copy.

`tests/backports/host/accessibilitymap/run.sh` asks the system's class and the port's class the same
number of questions and compares the two outputs line by line. **On the branch this series was rebased
onto: 52 questions, 51 of them answering the same and one a declared difference** in the case's own `expected-differences.tsv`, and each of those three says in one column
what each side answers and in a third why.

**The pin store keeps whatever it is given.** Measured on the host: a height of 2.0 reads back 2.0, one
of -1.0 reads back -1.0, a fraction reads back exactly, a negative point takes one, and a point at
(1e9, 1e9) was never written and reads 0. There is no range check and no bounds check on the host and
there is none here: a check the system does not make is a port answering something a caller never
asked for, and three mutants hold that - a store that keeps nothing, a height clamped to the unit
range, and a negative point refused - each of which dies on its own line.

**The store is real before anything has sized it.** A map obtained by allocation answers a zero size and
still keeps its pins, measured, so the store is created when the first pin arrives and not by an
initialiser. Two maps do not share a grid, measured.

**The copy and the archive are real.** The header's protocol list is `NSCopying, NSSecureCoding`, so
both are members the port owes and both are measured: `+supportsSecureCoding` answers YES on the host,
a copy carries the size and the pins and is unaffected by a write to the original, and an
`NSKeyedArchiver` round trip brings the size and every pin back - over a map with pins and over an
empty one.

### The one line the two do not answer the same, and the cause of it

**The host's pin store is keyed by the first coordinate of the point alone.** This is established, not
guessed, and the numbers are these. Keying a 3x3 grid with a distinct height per point and reading a 5x5
neighbourhood of the map back:

```
grid	-1,-1	0	0      every point of column 0 answers 7, of column 1 answers 8, of column 2 answers 9,
grid	0,-1	7	7      and every point outside the three columns written answers 0 - on the original as
grid	1,-1	8	8      well as on the copy, so this is the store and not the copy
```

**Three narrower probes, and the third of the first version of them could not fail.** It read the same
expression twice - once, after both writes - so whatever the two models disagreed about, the two numbers
it printed were the same number. And its binary was wrong in a way that hid even that: it applied the
differential's alias to every file, so the system class was referenced by nobody, was never loaded, and
`NSClassFromString` could not find it - the probe was reading the port's own class twice, and printed
"the same" on every line, which is the signature of a probe that cannot fail. The measurement below is
the same sequence in a binary with the two classes distinctly named, the port's source compiled under
the alias and the probe compiled without it:

```
the two classes are distinct: system=AXBrailleMap port=RevenantPortAXBrailleMap
(2,0) after three writes in column 2	host=33	port=11	DIFFERENT, so this line can fail
(2,1) after three writes in column 2	host=33	port=22	DIFFERENT, so this line can fail
(2,9) after three writes in column 2	host=33	port=33	the same
(0,0), never written	host=0	port=0	the same
(4,0) after 5 then 0 in column 4	host=0	port=5	DIFFERENT, so this line can fail
```

Three writes down one column, at rows 0, 1 and 9, and the host answers the **last** of them at all three
rows while the port answers each at its own point. The five-then-zero line is the one that separates
them most sharply: a column-keyed store answers 0, a point-keyed one answers 5. And two lines *do*
agree - the last write, and a point never written - which is what a discriminating probe looks like
rather than a probe where everything differs or nothing does.

The host's answers alone, across four columns and three row sets, with no model in the file:

```
col=4 rows=0,1,2  ->  (4,0)=33  (4,1)=33  (4,2)=33
col=4 rows=0,1,9  ->  (4,0)=33  (4,1)=33  (4,9)=33
col=2 rows=0,1,2  ->  (2,0)=33  (2,1)=33  (2,2)=33
col=0 rows=0,1,2  ->  (0,0)=33  (0,1)=33  (0,2)=33
col=9 rows=0,1,2  ->  (9,0)=33  (9,1)=33  (9,2)=33
col=4 rows=0,1 hB=2  ->  (4,0)=2  (4,1)=2
col=4 rows=0,1 hB=0  ->  (4,0)=0  (4,1)=0
```

So the second coordinate is not part of the key, the last write to a column wins whatever its height,
and a copy is a frozen snapshot of that column-keyed store - which is why the copy answers the height
written at (5, 5) when asked about (5, 6): the two points are one key. The probe sources and their
output are in `.agent-work/runs/map5/` (`key-probe2.m` is the one with the port's answer beside the
system's, `key-probe3.m` the one with the system alone).

The port's store is keyed by the point, which is what the header's API says - a height at a point - and
**this one line is where the two differ**, and it is the only declared difference left. Everything else
about the copy is the same on both sides and is no longer declared: the size is carried, the pins are
carried, the copy is unaffected by a write to the original, and **a write to a copy raises on both
sides** - the parity decision of 2026-09-29, and the reason the copy's store is an immutable dictionary
handed over as it is, so that Foundation raises `NSInvalidArgumentException` out of its own frozen
dictionary, by the same class and with the same name as the system's, rather than a throw written here.
An application that wrote a pin to a copy crashes on iOS 26 too, so no working application depends on the
write landing; what a port that took the write would have given is in the coordinator's ledger at
`.agent-work/handoffs/better-than-system-accessibility.md`, which says so and which this port does not do.

### AXBrailleMapRenderer: the metadata is emitted and the name does not resolve

**This is the one thing in the group this series does not resolve, and it reverses a row the last one
claimed.** `nm` on the built library finds `__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_` and the two
property lists for the port's own `RevenantPortAXBrailleMapRenderer`, so the protocol's metadata is
emitted - by the generated protocols object that `modules/apple/backports.lua` writes from the registry
row, exactly as it is for the chart group's two protocols. And `objc_getProtocol` and
`NSProtocolFromString` both answer **nil** for that name in a program that links the port, while the
same call on the host answers the framework's own protocol. A class in the case adopting the protocol does
not change it, and neither does the generated object.

So the protocol row and its two property rows are **`absent`** again, with the two measurements as their
reason, and what a caller gets is the class and its pin grid, with the renderer protocol not reachable by
name. Establishing why an emitted protocol is not in its image's protocol list is the next piece of work
on this group, and nothing here guesses at it.

### The one way to make a map, and why it is the port's own

The header marks `-init` and `+new` unavailable and gives no other way to make a map, so on a real
device nothing but the braille display service ever holds one, and no release this port carries has
that service. A caller that wants a map has to be able to ask for one, so the port adds
`+revenant_mapWithDimensions:` in `Accessibility/RevenantBrailleMap.h` - Revenant's own spelling, the
arrangement `RevenantAccessibility.h` uses for the request's own methods for the same reason - and the
SDK's initialisers stay where they are. It gets a header of its own rather than a line in
`RevenantAccessibility.h`, because that file transcribes three braille classes and a program importing
both would have two declarations of each, which clang rejects by name.

That factory cannot be compared against the system, which cannot be asked to build a map at all, so
`factory-probe.m` checks it on its own and **asserts rather than prints**: seven checks over a 3x2 grid,
a copy of a sized map - which is the only place the copy's size is held by anything, since the two-sided
case can only ever copy a zero-sized one - and a zero-sized map that still takes a pin. The first
version of that probe printed and asserted nothing, and two mutants survived it: a copy that dropped
the size and a factory that answered the wrong size. It asserts now, and both die on it.

`presentImage:` is the one member of the group that asks for something this release does not have. It
is carried, it is `inert`, and it says once in the log that there is no display to show the image on -
counted by the run, which calls it once and fails if the port wrote a line per call.

## The settings of 17.0, 18.0 and 26.1, and the hearing functions of 15.0

Twelve rows, in four objects, one release a piece, and every answer in them comes from one measurement.
`RevenantAXSettings.h` declares the real names the port's applications write; `AXColorUtilities.h` and
`AXHearingUtilities.h` are in the SDK the package compiles against, so the hearing group needed no
header at all.

**The measurement**, `tests/backports/settings/axs-census.lua` over the 6.1.3 armv7 cache, 580 libraries:

```
the release's Accessibility libraries:
  AX-prefixed exports: 543
  of which its own AXS/kAXS preference names: 339
  of which anything else: 204

every library of the release, which is a different question:
  AX-prefixed exports: 1204, of which AXS-named: 362

CONTROL __AXSInvertColorsEnabled, a name that is in the surface: found
CONTROL __AXSRevenantPlanted, a name that is not:                nil
```

And the five subjects, by the words a preference about them would be named with, every match printed:
```
  Blink 0   Border 0   Slider 0   Horizontal 0
  Motion     1   _AXUTLEventIsMotion                            an event flag, not a preference
  Vertical   1   _kAXSVoiceOverTouchRotorItemVerticalNavigation  a VoiceOver rotor item
  Cursor     4   __AXSVoiceOverTouchCursorStyle and three       the shape of the VoiceOver cursor
  Image      7   __AXSVoiceOverTouchNavigateImages and six      VoiceOver's image navigation
```

**The Cursor ones are the near-miss, and they are why the names are printed.** They are VoiceOver's
*cursor style* - the shape of the selection cursor it draws - and not a preference about a text insertion
indicator blinking. So the release holds no accessibility preference about motion, a blinking or insertion
cursor, horizontal text layout, borders or a slider alternative, and each of those five functions answers
**NO**, the answer cannot change in the life of a process, and each of the five notifications is carried
so a caller can name the change and is **never posted** because there is nothing to announce. The check
proves the last part with an observer, not by the absence of a post in its own output.

**Three answers are "there is nothing to be on" rather than "off",** and two of them must never touch
the host:

  * `AXAssistiveAccessEnabled` answers NO for the same measurement, and its own header's contract - that
    the value cannot change in a process's lifetime - is what makes that a reading of the release and not
    a placeholder for work not done.
  * `AXMFiHearingDevicePairedUUIDs` answers an **empty array** and not nil: a caller that iterates it gets
    zero devices, and a nil would make it read the answer as a failure to ask.
    `AXMFiHearingDeviceStreamingEar` answers the enumeration's own no-device case at 0, which is what a
    caller checks before drawing a left/right indicator. Both declarations are `API_UNAVAILABLE(macos)` -
    the header's own statement that a Mac has no such device - and the answer would be the signed-in
    user's accessory list, so **the host is never called for these two**, or for the third,
    `AXSupportsBidirectionalAXMFiHearingDeviceStreaming`, which answers NO because there is no hearing
    device and so nothing that could stream in either direction.

    **What justifies the three is narrower than what the code first claimed, and the narrow claim is what
    the census prints.** The census's own last line, with its two numbers, is the one a claim about this
    surface has to be checked against:

    ```
      Hearing     28
      Pair        6
      TOTAL       47 (sum) / 43 distinct, across the 10 words
    ```

    Forty-seven is the sum over the ten per-word lists and 43 is the number of exports behind it: four
    exports contain two of the words each - the paired-UUIDs four, which carry Hearing and Pair - so the
    sum counts them twice. Two of the six in the Pair list are a class and its metaclass rather than
    preferences, and the list says so beside them.

    It first said the release's Accessibility surface held no hearing device, no
    pairing and no Bluetooth audio-device symbol in it at all. That is false: the census lists **28**
    hearing-named exports there, four of them about a paired-UUIDs preference
    (`__AXSHearingSetPairedUUIDs`, `__AXSHearingCopyPairedUUIDs`, `kAXSPairedHearingUUIDsPreference`,
    `kAXSPairedHearingUUIDsChangedNotification`). Every one of the 28 is a preference about a hearing-aid
    **feature** - compliance, ear independence, the live-listen alert, the stream selection, the two demo
    flags - in the VoiceOver preference surface, and **none of the 28 is an `AXMFiHearingDevice`
    symbol**. That is the claim the three answers rest on: they are about hearing devices made as phone
    accessories, and the release carries no API for one, in either direction, paired or streaming. The
    subject list that would have printed the counterexamples had no word for hearing or pairing in it, so
    the false sentence was checked by nothing; `axs-census.lua` prints both words now, and the three
    registry rows name this measurement rather than the settings one that cannot answer a hearing
    question.
  * `AXOpenSettingsFeature` calls its completion **once, synchronously, before returning**, with an error
    in the port's own domain naming **the section by its own name** and saying nothing was opened. The
    name rather than the number is a fix the check asked for: an assertion that the description names the
    section was first written to look for the number 5, and every description naming an OS version
    satisfied it; looking for the case name turned the check red, and the port was the thing that had to
    change. A feature outside the enumeration gets an error that says so rather than naming a section that
    does not exist. Calling it synchronously
    is a decision and it is forced: the API takes a completion and a caller that waits for one that does
    not come waits forever. A null completion is accepted and ignored; a feature outside the enumeration
    is still answered with an error rather than crashing. **The host is never called for this row**: the
    call opens the Settings app, which would put a window on somebody's screen.

### Owed

**`AXNameFromColor()` — a black-box fit, and not yet done.** The host answers a curated named-colour
vocabulary with a nearest-match rule, not the components of the colour: `(128,128,128)` and `(200,200,200)`
both answer `gray`, `(255,165,0)` answers `bright orange`, `(0,0,255)` answers `very dark blue`, and
`(128,0,128)` and `(255,0,255)` both answer `dark magenta`. Nineteen such answers are in
`.agent-work/runs/settings/colour-probe.txt` (sha256 `01cdefc918d5b94d930e94817661736abd14ca9e0220a7e690e1e62e366fb296`).
The work agreed for it: probe the host densely - a regular 17x17x17 sRGB grid, 20,000 random colours, the
named edge cases, and the neighbours of every grid point where the answer changes - identify the
vocabulary and the decision rule by fitting candidate spaces (sRGB, linear, Lab, OKLab) with per-name
prototypes and boundaries found by bisection, implement the port's own rule and the port's own prototype
table from those measurements, and report the agreement over a held-out sample of at least 200,000 colours
that were not in the fit set, with the disagreements counted and where they cluster. Nothing is read out
of the framework's binary or its resources; the names are facts of the answers the function returned.
**The registry has no row for it and there is no `absent` row pretending otherwise**: it is owed, and it
is owed to that series, `accessibility-color`.

**What that series has measured, and the two models it has ruled out.** The host's function is
`AXNameFromColor` in the system's Accessibility framework, and over a dense sample of 129,466 distinct
colours it answers **267 distinct names built from 28 words** - a modifier and a hue word, with the hue
words including the neighbouring pairs, so the vocabulary is a hue circle divided into named sectors.
Nearest prototype per hue word, the prototype being that word's mean, agrees on 0.3698 of the colours in
sRGB, 0.3414 in linear sRGB, 0.4018 in CIE Lab and 0.3305 in OKLab - so the hue word is not a
nearest-prototype rule in any of the four spaces the plan named. And it is not a partition of the hue
angle either: sorted by the OKLab hue angle, the 128,987 chromatic colours fall into 31,180 runs, not
28. The sample is 7,936,644 bytes, `sh tests/backports/colour/run.sh` prints all of those figures, and
that run also holds the host's answers to the 21 edge cases as a known-answer set with a control of its
own. The rule is not identified, so the row stays owed rather than `implemented`: a rule that agrees with
the host on two fifths of the colours is not this row's behaviour.

**The three hearing rows are held by less than the other twenty, and the run says so.** They are not run
here, and the reason is in two parts that are both about the machine and neither about the port:

  * their declarations are `API_UNAVAILABLE(macos)`, the header's own statement that a Mac has no such
    device, so **no macOS program can call them at all** - and the answer a host would give is the
    signed-in user's own accessory list, which is nobody's answer to what a phone whose surface carries
    no hearing-device API must say - the narrow claim the census now prints, and the one the code's own
    comment was reaching for past what it could measure;
  * there is no iOS runtime on this machine to run them on: `xcrun --show-sdk-path --sdk iphonesimulator`
    answers `SDK "iphonesimulator" cannot be located`, and the tree's device programs are run by the
    coordinator's gate, which a band does not invoke.

What holds the three rows is the compile of `tests/backports/settings/hearing-check.m` against the SDK's
own declarations, an **assertion** over `nm` of the built object - which the settings run makes and mutant
M9 turns red on - and the census the answers are readings of. The run prints `hearing: OWED` rather than
passing quietly over it.

**And the program that can run them now exists: `tests/backports/device/hearing.m`.** It is the tree's
own device-program shape, it compiles clean for `armv7-apple-ios6.0`, it resolves each of the three
names through `dlsym` and `dladdr` first so a reader can see which implementation it reached, and it
asks the port's three functions for the answers the census says they must give while printing the
release's own where the release has the functions at all. It is not run by anything in a band: the gate is what runs a device
program, and when it does, this one turns the three rows from held-by-three-measurements into
held-by-a-run. That is the whole of what could be done here, and it is a program rather than a promise.

### The Settings sections' availability, which is per case and was transcribed as if it were not

`AXSettingsFeature` arrived with 18.0 as a type, and its cases did not all arrive with it: the second
with **18.2** and the last three with **26.0**. The first version of `RevenantAXSettings.h` gave the type
its 18.0 and every case nothing, which is what its own preamble says it transcribes and what it did not
do - and the knowledge sat in a comment in `RevenantAXSettings18.m`, which is the one place a compiler
never reads. Given the type's annotation alone, a caller whose deployment target is 18.0 could use the
26.0 cases and hear nothing at all, where the same caller against the SDK is told to guard the use.
Measured on this tree, the same file, the same flags, before and after:

```
against the port's header, deployment 18.0, before:   0 diagnostics
against the SDK 26.2,     deployment 18.0, before:
warning: 'AXSettingsFeatureDwellControl' is only available on iOS 26.0 or newer [-Wunguarded-availability-new]
against the port's header, deployment 18.0, after:
warning: 'AXSettingsFeatureDwellControl' is only available on iOS 26.0 or newer [-Wunguarded-availability-new]
against the port's header, deployment 18.2, after:   the same warning
against the port's header, deployment 26.0, after:   clean
against the port's header, deployment 18.0, after, the 18.2 case:
warning: 'AXSettingsFeatureAllowAppsToAddAudioToCalls' is only available on iOS 18.2 or newer [-Wunguarded-availability-new]
```

The port now answers as the SDK does at every one of those deployments. Two things about the shape of
the declaration are worth writing down, because the obvious form of it does not compile and the
difference is not interchangeable: an annotated case carries **no explicit value** and numbers itself
from the one before, and the annotation goes **between the name and the comma**. Written the other way
round - the value first and the annotation after it - clang stops at the case with `expected '}' or ','`.

**There are no registry rows for the cases, and that is the convention rather than an omission.** The
whole registry is 2319 class rows, 358 protocol rows, 3835 constant rows, 4198 property rows, 4167 method
rows, one type row, 1224 function rows and 6 symbol rows, and **not one row of kind `case`**. An
enumeration is covered by the function that takes it - here `AXOpenSettingsFeature()` - and its cases are
names inside that function's declaration, so adding four rows for four case names would be four rows the
rest of the tree does not have.

### Where the four objects land, measured rather than read from the header

`tools/release-split.lua` over the nine objects of this library, built with the library flags for
`armv7-apple-ios6.0`, is **clean: every object file's symbols first appear in one release**, which is
the rule one-object-one-release exists to hold. What it measures is not always what the header says:

```
RevenantAXSettings17.o  _AXAnimatedImagesEnabled and three siblings   18.0
RevenantAXSettings18.o  _AXAssistiveAccessEnabled and five siblings   18.0
RevenantAXSettings26.o  _AXPrefersActionSliderAlternative and three  none
RevenantHearing15.o     the three hearing functions                   16.0
```

The 17.0 object measures at **18.0** and the hearing object at **16.0** because that is what the SDK
those objects were compiled against can prove: its interface files name the 18.0 and 16.0 frameworks and
export these symbols there. The registry rows keep 17.0 and 15.0, which are Apple's own releases and
what a corpus row and a Swift module need. The four 26.1 symbols measure `none`, because no held
release is new enough to export them, and are placed by the registry's `introduced` instead - the case
`releases_in()` describes for a name nothing can place. None of the three is a problem and none is a
mixed object; the numbers are here so the next band does not have to discover them again.

**And the same four objects were built and measured again on the branch this group was re-cut on** - the
map stack rebased onto `6fcdc631b` and this group cherry-picked onto its tip - because a number measured
on one branch and copied onto another is a number nobody measured on the branch it ships on. The
placements came out the same:

```
release-split: clean, every object file's symbols first-appear in one release (9 files, 43 symbols, 50 releases checked)
RevenantAXSettings17.o   the four 17.0 symbols       18.0
RevenantAXSettings18.o   the six 18.0 symbols       18.0
RevenantAXSettings26.o   the four 26.1 symbols       none
RevenantHearing15.o      the three hearing symbols  16.0
```

All nine sources of the library compile with the library flags for `armv7-apple-ios6.0` with no
diagnostics of their own, and the light guard is its nine suites with no failure on that branch.

### What the check is, and what it caught

`tests/backports/settings/check.m` is port-only, and the reason for each row is in its own header. It
runs **twenty-five** assertions - counted, not written down, and the number the program used to end with
was 23, so the summary line had been under-reporting its own coverage by two for as long as it was
there - and its first ten **failed while printing the same value on both sides**,
because an `@(0)` and a `@"0"` are not equal however they print: the check comparing a number with a
string is worth nothing until it can be seen to fail, and its sixth control was worse - it compared a
literal with itself. Eleven mutations now cover the assertions: ten killed, one control green, none
surviving, none run-failed. Three of the four things the harness found were real: a mutation that
posted from a function nothing called and so broke nothing, a check that printed three symbols and
asserted nothing about them, and a mutation that broke two behaviours at once so a crash hid the first.

## What the registry holds, and the rows it does not

**127 entries** are written, which is the file's own count read with `json.load` and not the number any
earlier version of this paragraph gave. Of them **120 are `implemented`, 5 `inert` and 2 `absent`**, and
the two `absent` rows are the two members of the `AXCustomContentProvider` protocol named above - the
only two this framework answers `absent` now, and both for the same measured reason. By kind: 30
classes, 75 properties, 10 functions, 5 constants, 3 protocols, 4 methods.

The count moved 45 rows on 2026-09-30, in the group above. What the earlier groups did, and what the two
rows that were removed rather than left `absent` were, still stands and is not restated here with a
number that has since moved:

* **`AXNumericDataAxisDescriptor.range`** and **`AttributeScopes.accessibility`** are both Swift-only
  spellings. Neither exports a symbol, so neither can be an `implemented` row, and an `absent` row
  would be the registry claiming an answer it has not got. `range` is the Swift face of the
  `lowerBound`/`upperBound` pair - the Swift initialiser takes a `range` and the Objective-C one takes
  the two bounds, and no header of either the port's SDK or 26.2's declares a `-range` selector: the
  host answers `respondsToSelector:range` = 0, and the only "range" in either header is inside a
  comment. `AttributeScopes.accessibility` is a nested member of a Foundation Swift type that no header
  in the port's SDK tree declares; its seven members are the `UIAccessibilitySpeech*Attribute` constants
  of the **UIKit** family, so the scope's content is already another family's answer. Both are owed to
  the Swift module build, which is where a Swift-only surface belongs, and until then they are owed
  work rather than a registry row of any status.
* The same rule takes **36 other Swift-only spellings** out of this framework's rows: the Swift face of
  an Objective-C initialiser (`AXDataPoint.init(x:y:additionalValues:label:)`), a Swift getter label
  (`AXBrailleTranslationResult.inputIndex(forResultIndex:)`), and the whole `AttributeScopes` and
  `AttributeDynamicLookup` surface. A property row is named by one spelling in this registry, and these
  are not it; the accessibility of an attribute is reached through the Objective-C half.
* **Four names the corpus gives twice** - a generic class's property once per instantiation
  (`AXChartDescriptor.additionalAxes`, `AXChartDescriptor.xAxis`, `AXNumericDataAxisDescriptor.gridlinePositions`,
  `AXBrailleTable.language`) - and two entries may not share a name, so one spelling is the row.

The **eleven Objective-C C functions** the corpus lists under this framework are not dismissed with a
sentence, because the rule that covers them is not the same rule twice. Eight of them are the framework's
own C surface that a backport has no reason to supply, and `registry/README.md` is right that a header's
own function is the header's own call. Three are the subject of the next groups and are named in the
plan for them: the two pairs of settings and the two constants, where the port **does** have to supply
the symbol, because a port application cannot call a function the release has no export of. The five
already answered are the two settings pairs of 17.0, the non-blinking pair of 18.0 and the two pairs of
26.1; the six still unanswered are `AXAssistiveAccessEnabled()`, `AXOpenSettingsFeature()`,
`AXNameFromColor()` and the three hearing-device functions, and each of them has a call written down for
it (D for the five that read a device or a service the release lacks, P for the one that is a pure
function of a colour).

## What the braille comparison measured, and the defect it found

`tests/backports/accessibility/braille-differential.sh` builds **two programs and diffs them**, because
one binary cannot hold both implementations: the system's three braille classes and the port's have the
same names, and renaming either renames the system's declaration. Two runs, the forward and the back,
per case.

The port's forward translation is the standard's, measured:

```
abcxyz        ⠁⠃⠉⠭⠽⠵
ABC           ⡀⠁⡀⡀⠃⠉
123           ⠼⠃⠉⠙
0123456789    ⠼⠁⠃⠉⠙⠑⠋⠛⠓⠊⠚
,;:.-!?       ⠂⠆⠒⠲⠤⠖⠦
Hello, World! 42.  ⡀⠓⠑⠇⠇⠕⠂⠀⡀⠺⠕⠗⠇⠙⠖⠀⠼⠑⠉⠲
```

The capital sign is doubled for the run after the first capital, and the number sign is written once
for a run of digits, which is the standard's own rule for both.

**The host answers nil for every case.** Its `AXBrailleTranslator` returns nil when it is given a table
built through `-[AXBrailleTable initWithIdentifier:]`, because a table's dot patterns are a provider's
data and this host has none installed for one. So on this host **the system is not an oracle for a
hand-built table**: the comparison's finding is that the oracle is unavailable here, not that the two
implementations agree. A host with an installed braille provider is where that finishes.

**One defect the comparison found, and this delivery does not fix:** the back-translation's number sign
does not keep its scope across a run of digits, so `123` comes back `2cd` where the standard says `123`.
The forward translation of the same input is right.

## What is not measured here

Not run for the chart group: not on the device, not in the emulator, not through the generated call test.
The host differential and its eight mutants are what the group is held to here - each mutant changes one
line of the port's own source and has to be caught by the comparison, and each was shown to be caught,
with the line that caught it. The braille table group is at the same state: device-unverified, and the
package build that checks every band is what the delivery report quotes.
