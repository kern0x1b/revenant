# The attributed strings of iOS 15.0

Markdown, the attributed formatting of a format string, the language a table's text was found in, and the
inflection pass — one object for one release, six files and the rows they carry.

    sh tests/backports/host/attributed15/run.sh
    bytes 195712
    checks=376 failures=0

The port's selectors are prefixed (`tests/backports/host/prefix_selectors.py`, the mechanism `appgroup`
and `uikit2` use) and its Markdown class is renamed with a `-D` from its own object's symbols
(`tests/backports/host/uikit2/renames.sh`, the mechanism `presentationintent` uses), so the system's five
members and the port's five answer in one process and every case compares the two. The whole verdict is
376 checks and no failures: three constants, forty-five formatting cases, the bundle lookup, 309
inflection cases, ten Markdown cases, the task delegate's four, and four cases that ask the *release*
what it answers for the members of an abstract class.

Two things had to be measured before any of it could be written, and both are the kind of thing a header
does not say.

## The format is an attributed string, and the two families do not format numbers alike

`+[NSAttributedString localizedAttributedStringWithFormat:]` takes an `NSAttributedString`, not an
`NSString`, and a conversion can stand inside a run of its own attributes. Those attributes are what the
substituted text is drawn with:

| the format | the argument | the answer |
| --- | --- | --- |
| `pre %@ mid %@ post`, the colour over `%@ ` (4,3) | `ARG` bold, then `plain` | `ARG` coloured **and** bold, the space after it coloured, `mid ` and `plain` not |
| the same with `NSAttributedStringFormattingInsertArgumentAttributesWithoutMerging` | the same | `ARG` bold alone: the format's attributes are dropped |
| the same with `…ApplyReplacementIndexAttribute` | the same | both, and `NSReplacementIndexAttributeName` 1 and 2 on the two runs |
| `%d and %.2f` with de_DE, through the **variadic** initialiser | `1234`, `1234.5` | `1234 and 1234.50` — **canonical**, whatever locale it was handed |
| the same through the **va_list** initialiser, with de_DE, with fr_FR, with the current locale | the same | `1.234 and 1.234,50` — **localized**, whatever the numbers look like |
| the same through the va_list initialiser, with **nil** | the same | `1234 and 1234.50` — nil is the canonical one |
| `%d and %.2f` through `+localizedAttributedStringWithFormat:` | the same | `1.234 and 1.234,50` — the machine's `en_US@rg=plzzzz` |

So the two spellings of one initialiser disagree, and the two `localized` methods format with the
current locale. The port passes the caller's locale to the release's own formatter from the va_list
member, `nil` from the variadic one, and `[NSLocale currentLocale]` from the two class methods; that is
the whole of the difference and it is in `NSAttributedStringLocalizedFormat15.m`. The header's own
comment says the va_list member takes the canonical spelling for a nil locale and the localized one
otherwise, which is what it answers; it says nothing of the sort about the variadic member, which is
canonical whatever locale it is handed, and that is what it answers.

### Three rules of the format language the header does not describe

| the format | the arguments | the answer |
| --- | --- | --- |
| `%1$@ and %1$@ and %2$@` | `one`, `two` | `one and one and two` — one argument, substituted twice |
| `%2$@ then %1$@` | `one`, `two` | `two then one` |
| `%1$d apples and %1$d oranges` | `3` | `3 apples and 3 oranges` |
| `%3$@ %1$@ %2$@` | `one`, `two`, `three` | `three one two` |
| `%1$ld` | `(long)7` | `7` — the length modifier is read as part of the conversion |
| `%1$10d` | `3` | `       3` — an index and a width are two different things |
| `%1$@ and %@` | `one`, `two` | `one and one` — a positional conversion still takes the list with it |
| `[%*d]` of 6, 42 | | `[    42]` — a width written `*` is an argument of its own, read before the conversion's |
| `[%-*d]` of 6, 42 | | `[42    ]` |
| `[%.*f]` of 2, 3.14159 | | `[ 3,14]` |
| `[%*.*f]` of 8, 2, 1234.5 | | `[1.234,50]` — the width is padded onto the **localized** spelling |
| `[%*d]` of -6, 42 | | `[42]` localized, `[42    ]` canonical — see below |
| `[%.*f]` of -2, 3.14159 | | `[3,14159]` localized, `[3.141590]` canonical — see below |

All of these need the argument list read **once**, into the argument each conversion stands for, and every
conversion then reading its own slot out of it: that is what makes one argument be substituted twice, and
what lets a width be an argument rather than digits. `RevenantScan` walks the format first and says which
argument each conversion stands for, `RevenantRead` takes them off the list with the type C promotes them
to, and the walk that substitutes reads the slots. The count the list is read by is the largest number
any conversion asked for: a `n$` reads the argument it names and leaves the list at least there, and a
conversion that names none takes the next one.

**The replacement index is the argument, not the run.** With
`NSAttributedStringFormattingApplyReplacementIndexAttribute`, `NSReplacementIndexAttributeName` is the
number of the argument the conversion stands for, so `%1$@ and %1$@ and %2$@` is numbered 1, 1, 2 and
`%3$@ %1$@ %2$@` is numbered 3, 1, 2 — and a width off the list pushes the conversion's own number along,
because the width is an argument: `[%*.*f]` of 8, 2 and 3.14159 puts **3** on the eight characters the
value occupies. The number covers the padding too.

Two shapes of a negative `*` are the two families disagreeing with each other, and both are measured:

* **A negative width.** The canonical family takes the magnitude with the `-` flag (C's rule) and the
  localized family takes no width at all, for every width from -1 to -12. The port answers each of them
  as measured, which is why `RevenantApplyStars` reads the locale.
* **A negative precision.** The canonical family answers the default six, which is C's "no precision",
  and the localized family answers the value's own digits — the shortest decimal that reads back as the
  same double. That one is **not carried**: it is a search over the precisions rather than a rule, and
  the differential prints both answers beside each other as a note instead of comparing them, so the
  difference is on the output and not folded into a pass.

A `%` that opens no conversion is consumed and what it read is text again: `a % b` answers `a  b` and
`a %1 b` answers `a 1 b`, while `x %q y` answers `x q y`; a format that is nothing but such a specifier
answers nothing, so `%q`, `%0` and `%-` are empty, and so is the `%q` at the end of `100%% %@ %q`. A
`%@` given nil is `(null)`, a number and an array are their own `-description`, and an attributed argument
contributes its own text.

**A format whose conversion has no argument behind it is not compared**, because it is not a question with
an answer: `50% off` answers `505ff` on one run of the system and `500ff` on the next, both from a
variadic slot nobody passed. It is left out of the differential and named here instead.

Two things about the va_list are the port's own and not the release's, and both were measured:

* A list cannot be handed to the release's formatter twice. The second call reads the floating-point
  register area as spent and answers `0.00` where the first answered `1234.50`, so each argument is taken
  out of the list with the type C promotes it to and formatted on its own (`RevenantApply`).
* A variadic member cannot be reached through a non-variadic `objc_msgSend` prototype: the call is a
  misread, and a member given `Bob 7` answers `Ann 3`. `tests/backports/host/attributed15/ported.h`
  declares the prefixed members the way the SDK declares them, with the variadics, and `run.sh` checks
  every selector in it against the declarations header the tool writes, so the two cannot drift.

## The Markdown answer is a tree of intents, numbered in document order

Apple's own source for this does not exist and no public source implements it; the semantics come from
the release's own answers above, and `swiftlang/swift-corelibs-foundation` has neither the Markdown nor
the presentation intents (`Sources/Foundation/NSAttributedString.swift` carries neither). What a
document answers, measured on the system and reproduced by `NSAttributedStringMarkdown15.m`:

* a heading is a header intent with its level, a paragraph a paragraph intent, a fenced or an indented
  code block a code block intent with the info string as its language hint, `***` a thematic break whose
  text is the two-em dash U+2E3B, `> ` a block quote with a paragraph inside it, a list a list intent
  with an item intent per entry carrying its ordinal from 1 and a paragraph inside the item;
* the identities are numbered from 1 in document order, a container before what it holds: in
  `> quote` / a code block / a paragraph / a table / a table, the system answers 1…12 and so does the
  port, run for run;
* a link carries `NSLinkAttributeName` with its URL resolved against the `baseURL`, an image
  `NSImageURLAttributeName` likewise;
* a table is a table intent with its column count and the alignments of its header, a header row intent,
  a row intent per body row from 1 and a cell intent per cell with its column from 0; the cells of a row
  follow one another with nothing between them;
* the inline spans are `NSInlinePresentationIntent`: emphasized 1, strongly 2, code 4, strikethrough 32,
  a soft break 64 and a hard break 128, and the extended syntax is interpreted with the *default* options
  even though `allowsExtendedAttributes` answers NO;
* a soft break is one separator space and not the newline: `one\ntwo` answers `one two` with a run of one
  space carrying 64. `NSAttributedStringMarkdownInterpretedSyntaxInlineOnlyPreservingWhitespace` is the
  one option that keeps the source's own spacing;
* a document that cannot be read or decoded is the release's own refusal: `nil` and an `NSError` under
  `NSCocoaErrorDomain` / `NSFileReadUnknownError`.

`NSAttributedStringMarkdownParsingOptions` is a class the release 6.1.3 does not have at all: five
properties, a copy of the five and a keyed archive under the SDK's own property names. Its defaults are
measured and are the allocation's own — `allowsExtendedAttributes` NO, `interpretedSyntax` full,
`failurePolicy` return the error, `languageCode` nil, `appliesSourcePositionAttributes` NO.

### The link's key: the name is the release's, the value is `NSLink`, and the Foundation library can reach neither

`NSLinkAttributeName` is declared in **UIKit's** copy of `NSAttributedString.h`
(`UIKIT_EXTERN NSAttributedStringKey const NSLinkAttributeName API_AVAILABLE(macos(10.0), ios(7.0))`)
and in no Foundation header of the SDK this port builds against (`iPhoneOS16.4.sdk`). The 16.4 SDK
exports `_NSLinkAttributeName` from `UIKit.tbd` and from no other `.tbd`; `Foundation.tbd` does not
carry it. `FoundationBackports` links `Foundation`, `CoreFoundation` and `SystemConfiguration` and
`icucore` (`modules/apple/backports.lua`), so nothing on that link line offers the name, and the
reference failed at the 6.1.3 band link with

    Undefined symbols for architecture armv7:
      "_NSLinkAttributeName", referenced from:
          -[RevenantMarkdownParser parseInlines:from:to:intent:] in NSAttributedStringMarkdown15.o
    ld: symbol(s) not found for architecture armv7

The **device** does carry the name, and where it lives is measured from the armv7 dyld cache of 6.1.3
itself (`~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7`, 574 images, every image's external defined
symbol table read — the same order `modules/apple/dyld.lua`'s `library_of()` reads them in, export trie
first and symbol table otherwise, and no image of that cache carries an export trie):

| release | image that exports `_NSLinkAttributeName` |
| --- | --- |
| 6.0, 6.0.2, 6.1, **6.1.3**, 6.1.6, 7.0, 7.1, 8.0, 9.3 | `/System/Library/PrivateFrameworks/UIFoundation.framework/UIFoundation` |

So the name belongs to the release from 6.0 on and the port must not define it: a second definition of a
data symbol the device already exports is a collision in a flat namespace, and at a band point of 6.0 or
later `band()` (`modules/apple/backports.lua:787`) would refuse an object that defined it beside the
15.0 keys of `NSAttributedStringKeys15.m`, whose seven symbols the same release does not export.

The **value** is what an attributed string holds and what a caller reads back, and it is not the name.
It is `NSLink`, read out of the same image's own `__TEXT,__cstring` (`__cstring` at 0x36d760c8, size
0x942d, inside `__TEXT` vmaddr 0x36cef000), which holds the attribute-name family one string after the
other —

    NSFontName\0 NSFontSize\0 NSFontTrait\0 NSBaselineOffset\0 NSAttachment\0 NSLink\0 NSCharacterShape\0

— and it is what this tree already records: `tests/backports/device/textkit7-expectations.h` carries
`"constant.NSLinkAttributeName":"NSLink"`, read on the iPad 2 and compared with the host's own UIKit
(`facts/UIKit/NSAttributedStringText.md`). The 6.0 cache holds the same family in the same order in
UIFoundation's `__TEXT,__cstring`, so the value has been `NSLink` for as long as the name has existed.

`NSAttributedStringMarkdown15.m` therefore writes the link under `RevenantMarkdownLinkKey`, a
file-scope `static NSString * const` holding that string, and defines nothing with Apple's name on it.
The shape is `NSBundleResourceRequest.m`'s `revenant_manifest_tags_key` — an Apple string under a name of
our own — and the reason is the one `NSLanguageIdentifierAttributeName` already has in
`NSAttributedStringKeys15.m`: for this key the name is not the value.

### What is not carried, named

* **`NSListItemDelimiterAttributeName`** is a 16.0 name and the SDK this port builds against
  (`iPhoneOS16.5.sdk`) does not declare it, so a list item's run carries its intent and not the
  delimiter. The differential leaves that one key out of the comparison and prints what the system put in
  it on every run — `"-" at 46` for the bullet list, `"." at 7` for the ordered one — so the difference is
  on the output and not folded into a pass.
* **The styling is not carried.** A heading's font, a link's colour and a code span's monospaced face
  are the system's own private choices; no API fixes them, and the port does not invent sizes. What the
  release's own documentation says an attributed string from Markdown is *for* — an application that lays
  the text out by hand reading the intents instead of parsing the Markdown — is answered in full.
* **A negative precision on a localized value.** Named and measured above, under the three rules: the
  system answers the value's own digits and the port answers the default six, which is what the canonical
  family answers for the same format. The differential prints the two answers as a note.
* **An HTML block and an entity reference are the source's own text.** The system marks them
  (`NSInlinePresentationIntentBlockHTML`, 512) and the port keeps the characters without the mark.

## Inflection: the rule travels in the string, and English is what is followed

`-[NSAttributedString attributedStringByInflectingString]` is not a function on the text: its own header
says it inflects the portions tagged with `NSInflectionRuleAttributeName` by the rule in the attribute.
The tag is dropped from every run the pass answered, so a string of three runs comes back as **one run
with no attribute on it**, and the neighbours that answer alike are written as one run — both measured.

### The gates, one measurement each

The rule is `NSInflectionRuleExplicit` and not the automatic one, and the three settings the SDK declares
are read through the SDK's own accessors. Every row below was measured one value at a time, by the case
named in the third column.

| the gate | the values, and what each answers | the cases |
| --- | --- | --- |
| `number` | Plural, PluralFew and PluralMany inflect; NotSet, Singular, Zero and PluralTwo leave the text as it stood | `inflect.number.*` |
| `partOfSpeech` | Letter, Verb, Numeral and Preposition leave it as it stood; the other eleven inflect | `inflect.partOfSpeech.*` |
| the language | none, `en`, `en-GB`, `en-US` and `EN` inflect; `de`, `fr`, `ru`, `ar`, `ja` and `und` do not | `inflect.language.*` |
| the range | it must END where a word ends, and it is the whole word ending there that is inflected | `inflect.partial.*` |
| the word | letters, at least two of them | `inflect.plural.*` |

The range rule is the one that is not obvious. `-addAttribute:value:range:` does not widen the range it
is given to the run it lands in, so the tagged range is read back with `-attribute:atIndex:effectiveRange:`
rather than taken from the enumeration, and then:

* `the house and the dog` tagged (4,4) — "hous" — answers the text as it stood;
* `the house and the dog` tagged (4,3) — "hou" — answers the text as it stood;
* `the house` tagged (4,3) answers the text as it stood;
* `1 house` tagged (4,3) — which ends at the end of the string — answers **`1 houses`**, which is the
  word "house" made plural and not the three characters "use".

So the range has to end where a word ends, and the word that ends there is what changes. The word itself
has to be letters and at least two of them: `child's`, `house's`, `house-s`, `house s`, `house3`, `3`,
`two houses` and every word of one letter all answer the text as they stood, measured.

Two more shapes the header names:

* **A range carrying its own answer** under `NSInflectionAlternativeAttributeName` takes it verbatim:
  `the mouse` with `mice` under the alternative is `the mice`.
* **A range that still holds a `%`** is left as it stood **and its tag stays on it** — `"%d house"` comes
  back as `"%d house"` with the rule still on the run. The header's "that have no format specifiers" is
  the system declining to answer, and a tag it did not follow is still a tag.

### The English rules

Three need no table: a word ending in s, x, z, ch or sh takes `-es`; a word ending in a consonant and `y`
changes it to `-ies` and one ending in a vowel and `y` takes `-s`; every other word takes `-s`. Those get
`index` and `matrix` right on their own (`indexes`, `matrixes`) and `house` and `sieve` right by not
applying at all (`houses`, `sieves`).

Six closed sets are beside them, and every entry is the system's own answer for the word:

* the nouns whose two numbers are not the regular rule's — mouse/mice, foot/feet, tooth/teeth,
  goose/geese, ox/oxen, person/people, child/children, man/men, woman/women, datum/data,
  criterion/criteria, phenomenon/phenomena, and sheep, deer, fish, moose and buffalo, which do not change,
  and `the`, which does not either;
* the Latin plurals that change back — cacti/cactus, foci/focus, nuclei/nucleus, and `data`, which the
  system refuses to change twice;
* the `-f` and `-fe` nouns that become `-ves` — knife/knives, leaf/leaves, life/lives, wife/wives,
  half/halves, loaf/loaves, self/selves, thief/thieves, wolf/wolves, shelf/shelves, calf/calves,
  elf/elves, scarf/scarves. The regular rule would make `roof` into `rooves` and the system answers
  `roofs`, so the set is closed. `leaves` is the one row whose two ends are not reverses: the system
  answers **`leave`**, and that is what the object answers;
* the `-o` nouns that take `-es` — echo, veto, torpedo, volcano, mosquito, embargo, tornado, hero, potato,
  tomato — where `photo`, `piano` and `zero` take `-s` and nothing about the letter tells the two apart;
* six plurals whose singular keeps a final `e` — houses, shoes, canoes, safes, sieves, axes — where
  `echoes`, `vetoes` and `potatoes` drop the whole `-es`;
* the words that end in `-as`, `-us` or `-is` and are their own singular — bus, status, virus, cactus,
  focus, fungus, nucleus, octopus, alias, axis, crisis, analysis, hypothesis, thesis.

Four more endings are named rather than derived, each measured: `-ises`, `-yses` and `-eses` are a
singular in `-is` with an `-es` on it (`crises` → `crisis`, `analyses` → `analysis`, `hypotheses` →
`hypothesis`, `theses` → `thesis`), `-zzes` is a singular with a doubled z (`quizzes` → `quiz`), a final
`z` after a vowel doubles (`quiz` → `quizzes`, where a final `s` after the same vowel does not: `bus` →
`buses`), and the capitalisation of the word is kept (`KNIFE` → `KNIVES`, `Knife` → `Knives`, `Wolf` →
`Wolves`).

### What is not carried

**The system's English table is a lexicon and this object carries a rule set.** A word outside the sets
above gets the regular rule's answer here, where the system has its own: `thes` for `the` is the shape of
it, and `the` is in a table only because it was measured. One measured divergence is named as well: the
system inflects a range carrying the Spanish tag `es` the English way and this object does not, because
the tag is not English and the rules here are English.

The 309 inflection cases are the evidence: every word of every table both ways, all seven numbers, all
fifteen parts of speech, ten language tags, four partial ranges, the alternative, the format specifier,
two tagged runs and an untagged one. The system is asked first and the port second in every one.

## The bundle's answer carries the language it was found in

`-[NSBundle localizedAttributedStringForKey:value:table:]` is the release's own
`-localizedStringForKey:value:table:` with one thing added: the text comes back with
`NSLanguageIdentifierAttributeName` on it, holding the bundle's own current localisation. A key the table
does not carry answers the `value` the caller passed, tagged the same way. The lookup itself is 6.1.3's
and reads the same `.strings` and `.stringsdict`; a second reader of the tables would answer differently
from the release's on every rule the format has.

## The three attribute names, and the one whose name is not its value

`NSAlternateDescriptionAttributeName` is `NSAlternateDescription`,
`NSImageURLAttributeName` is `NSImageURL` and `NSInlinePresentationIntentAttributeName` is
`NSInlinePresentationIntent` — each read with `dlsym` out of the system's own image and compared in
`constant.*`. `NSLanguageIdentifierAttributeName` is **`NSLanguage`**, and the system exports no symbol for
it on either of its images, so the value is measured by `bundle.missingKey`, which prints the attribute
name the system itself put on the answer. All four are in `NSAttributedStringKeys15.m`, which is the
release's own object for the attribute names of 15.0.

## The per-task delegate

`NSURLSessionTask`'s `delegate` is `@dynamic` in `NSURLSession.m` with no accessor behind it, so a task
answered the accessor with `doesNotRecognizeSelector:`. `NSURLSessionTask+Delegate15.m` adds the two
accessors as a category with the value in an associated object, `OBJC_ASSOCIATION_RETAIN_NONATOMIC`
because the SDK's own declaration of the property is `(nullable, retain)`; the four `task.*` cases in the
differential read a fresh task (nil beside the system's nil), a delegate set and read back, and the
system's own doing the same.

### The routing is per SELECTOR, and that was measured before it was written

The header states three things about this property beyond its accessors, at SDK 16.4
`NSURLSession.h:296-304`, and `revenant_task_delegate()` in `NSURLSession.m` was answering only the first
of them:

    Sets a task-specific delegate. Methods not implemented on this delegate will
    still be forwarded to the session delegate.
    Cannot be modified after task resumes. Not supported on background session.
    Delegate is strongly referenced until the task completes, after which it is
    reset to `nil`.

It returned the task's delegate **whole**, which answers the first sentence per OBJECT: a caller that
set a delegate implementing nothing of the protocol heard nothing at all, because every guard asked the
task's delegate and every send went to it. The header says per SELECTOR.

`tests/backports/host/tasksession/` is the harness that measured it, asking the system's own
`NSURLSession` and not the port — the port's objects are armv7 iOS 6.1.3 that no macOS process can
load. Its control runs first and fails if the reader cannot see the property, the protocol or a live
task, because a reader that could not would report every rule as "does not happen". Nothing leaves the
machine: every task is `http://127.0.0.1:1/`, which the loopback stack refuses at once. On macOS 27.0
build 26A428 arm64:

    $ sh tests/backports/host/tasksession/run.sh
    forwarding: the task's delegate implements nothing
      the task's delegate was set and reads back: yes
      setDelegate: after resume: NSGenericException: Cannot set task delegate after resumption
      the session delegate heard didCompleteWithError: 1 time(s)
      delegate after completion: (nil)
    partial: the task's delegate implements didCompleteWithError:
      the task's delegate heard it: 1 time(s)
      the session delegate heard it: 0 time(s)
      setDelegate: after resume: NSGenericException: Cannot set task delegate after resumption
      delegate after completion: (nil)
    tasksession: 10 checks, 0 failures

Three answers, and each one is a different piece of code:

- **Per selector.** A delegate implementing nothing left the session delegate hearing
  `URLSession:task:didCompleteWithError:` once; a delegate implementing exactly that selector heard it
  once and the session delegate heard it **zero** times. So `revenant_task_delegate()` takes the selector
  being sent and falls through to the session's delegate when the task's own does not answer it. All
  seventeen call sites pass their own selector, which is what makes the `-respondsToSelector:` guards
  and the sends read the same answer — a guard and its send still cannot disagree about who was asked,
  and now they are also asking the question the header asks.
- **Refused after `-resume`, not accepted.** `NSGenericException`, reason
  `"Cannot set task delegate after resumption"`. The port raises the same name with the same reason:
  the header's "cannot be modified" is that sentence, and a caller that catches the system's exception
  catches the port's. The gate on it is `state != NSURLSessionTaskStateSuspended`, which is the state a
  task created but not yet resumed is in — the case the header leaves open — so a task that has run in
  any way is refused.
- **Reset to nil once the task has completed**, in both runs. The reset cannot go through
  `-setDelegate:`, which now refuses a task that has resumed and a task being completed has resumed, so
  it clears the association directly through `-revenant_resetTaskDelegate` — the same shape as
  `RevenantURLSessionMetrics.h`'s note calls: a method the loader itself calls, declared in
  `RevenantTaskDelegate15.h` so the call and the definition cannot disagree about its name. The
  association was already `RETAIN_NONATOMIC`, so "strongly referenced until the task completes" was
  true of the port before this and still is; what was missing was the nil afterwards.

What is **not** measured here, and is not claimed: any of this running on the port's own objects. The
routing needs a process where the port's `NSURLSession` is the only one — `tests/backports/device/
ios1516.m` is where that runs, and the canon build is what measures it.

## What the host's `-[NSPresentationIntent init]` answers, and why it is not the paragraph intent

A blocked band (`gb09-foundation1516-r15`) measured this and reported that the host's `+new` and
`-init` "answer a paragraph intent of identity zero, equal to what `+paragraphIntentWithIdentity:0
nestedInsideIntent:nil` gives", and that this contradicted the row above. It does contradict the row's
wording, and the measurement says which side is right. Read through the IMP, because
`NS_UNAVAILABLE` forbids the compile-time call — which is the same constraint
`tests/backports/host/intents-init/` reads its own answers around. On macOS 27.0 build 26A428 arm64:

    NSPresentationIntentKindParagraph = 0
    a nonsense selector answers the forwarding trampoline: yes      <- the reader's control
    -init IMP is NSObject's -init IMP
    -init   kind=0 identity=0 isEqual(paragraph 0)=1 isEqual(paragraph 5)=0
    +new    kind=0 identity=0 isEqual(paragraph 0)=1
    factory kind=0 identity=0

Three facts, and together they settle it.

- **`-init` is NSObject's `-init`**, at NSObject's own IMP. The port already does exactly this:
  `revenant_intent()` in `NSPresentationIntent15.m` runs `[NSObject class]`'s `-init` through
  `objc_msgSendSuper` rather than its own. So the port and the host agree on WHICH `-init` runs.
- **`NSPresentationIntentKindParagraph` is 0**, the first enumerator of the enum at
  `NSAttributedString.h:297-298`. So a zeroed `intentKind` field reads as Paragraph. That is the whole
  of the "paragraph intent" reading: the object is zeroed, and zero is Paragraph.
- **The identity is uninitialised, so the equality is not a property of the answer.** On this run it
  read 0 and the object compared equal to the identity-0 factory; the `attributed15` differential on
  the same host recorded the same field reading a pointer-shaped number on another run, and on that run
  the comparison would answer NO. So `isEqual: 1` here is a fact about a run, and the row above's
  "the release's own answer is uninitialised state" is the claim that survives it.

The blocked band's finding therefore stands on the one thing it measured — the host answers an object,
not nothing, which is what makes the row `inert` and not `absent` — and does not stand on the equality,
which is zeroed memory rather than the system's own intent. Nothing is changed in the port for it, and
the two rows keep the wording they have.

## The release answers the initialisers of an abstract class, and nothing can be held to the answer

Three rows of this slice are `inert` and not `absent`, and the difference is the whole of their reason.
`+[NSPresentationIntent new]`, `-[NSPresentationIntent init]` and `-[NSInflectionRule init]` are all
`NS_UNAVAILABLE` in the SDK's own headers, and the port's classes carry those selectors by inheritance
from `NSObject` while sending them nowhere. A claim that "the release has nothing" would be false, and
the release's own answer is what makes the row `inert` rather than `implemented` — measured in the
`release.*` cases:

    +new answers <NSPresentationIntent 0x…>: Paragraph (id 0), an instance of NSPresentationIntent,
    intentKind 0, identity 0
    -init answers an instance of NSPresentationIntent, intentKind 0, identity 0
    -[NSInflectionRule init] answers an instance of NSInflectionRule

The identity is **not initialised**: it reads 0 on one run and the pointer-shaped number
-6510171893482810916 on another, both measured. So the release does answer, and there is no value any
implementation could be held to — which is what `inert` says and what `absent` would deny.

## The release's own ladder

`xmake l tools/cache-index/first-rung.lua` from the repository root answers which held release carries each
name, and for this object's members it answers **16.0** for all of them — the four attribute names
(`_NSAlternateDescriptionAttributeName`, `_NSImageURLAttributeName`,
`_NSInlinePresentationIntentAttributeName`, `_NSLanguageIdentifierAttributeName`) and the ten selectors.
The held set is dense to 12.0 and then has no 13.0, 14.0 or 15.0, so 16.0 is an upper bound and never a
measured 15.x. `NSAttributedStringMarkdownParsingOptions` and `NSPresentationIntent` read `NONE` for
their class names and 16.0 for the members, which is why the objects that define them are placed by
their minimum. Two names read 3.0 and say nothing about their owner: `delegate` is another class's
selector and `-attributedStringByInflectingString` is 15.0, so the class-scoped reading is the one above
and not the bare selector's.
