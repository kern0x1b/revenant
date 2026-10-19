# MPNowPlayingInfoLanguageOption and MPNowPlayingInfoLanguageOptionGroup, the 9.0 pair

Two classes neither release has, built over state the release really has. This page is the measurement
behind `registry/MediaPlayer/mpnowplayinginfolanguageoption.json`; the rows there say what a caller gets,
and this says how it is known and who checked the reader.

## The two reads, and their controls

Class-scoped, because a selector's presence somewhere in a release says nothing about the class that owns
it, and because a class's absence is a fact about the whole release rather than about one image. Both
reads ran through `coordination/heavy.sh`, in the slow lane, one per turn.

```
CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
  ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > .agent-work/runs/mp-absent/inventory-6.1.3.tsv
12549 lines: 11378 classes, 1171 protocols

CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
  ~/.charon/dyld/4.3/dyld_shared_cache_armv7 > .agent-work/runs/mp-absent/inventory-4.3.tsv
7751 lines: 7187 classes, 564 protocols
```

The 6.1.3 line count and both class/protocol totals match `WholeCacheRead.md` exactly, which is an
independent run of the same reader reaching the same numbers.

**Controls, and one of them discriminates.** In the same files, so no separate claim is needed for them:

| name | 6.1.3 | 4.3 |
| --- | --- | --- |
| `MPVolumeView` | PRESENT | PRESENT |
| `MPMediaPlaylist` | PRESENT | PRESENT |
| `MPMediaLibrary` | PRESENT | PRESENT |
| `MPNowPlayingInfoCenter` | **PRESENT** | **ABSENT** |
| `MPNowPlayingInfoLanguageOption` | ABSENT | ABSENT |
| `MPNowPlayingInfoLanguageOptionGroup` | ABSENT | ABSENT |
| `AVMediaSelectionOption` | PRESENT | ABSENT |
| `AVMediaSelectionGroup` | PRESENT | ABSENT |

`MPNowPlayingInfoCenter` is the control that makes this page's zeros mean something: the same reader,
the same two files, a YES at 6.1.3 and a NO at 4.3. A reader that answered NO to everything would have
produced this page's result for the wrong reason, and that is exactly the failure
`WholeCacheRead.md` records for its own first pass (a sign-prefixed selector column, where testing bare
names made `status` and `timedMetadata` read absent from `AVPlayerItem`).

The reader is not blind to the frameworks either: the 6.1.3 file holds 848 UIKit classes and 418
Foundation classes, and `NSBundle`, `NSUserDefaults` and `UIViewController` all read PRESENT in it.

## Why the whole-cache selector list could not decide any of this

`selectors_armv7.txt` is **113981 distinct names** - a list of names, not a count per class. `dealloc` is
on one line, not 433. A count of 0 there is absence from the release and is necessary; a count of 1 says
some class somewhere declares it and settles nothing about the owner. `WholeCacheRead.md:105` is the same
trap for `albumTrackNumber`. For a class row the selector list is the wrong instrument entirely: it holds
no class names.

## What makes these two carried rather than merely declared

A class no release has is new code and cannot shadow anything, so it could always be declared. What makes
it worth carrying is that the release holds the inputs it is built from, and that was read at CLASS level
in the same two runs:

- `AVMediaSelectionOption` at 6.1.3, **24 own instance methods**: `-locale`, `-mediaType`,
  `-hasMediaCharacteristic:`, `-displaysNonForcedSubtitles`, `-isPlayable`, `-commonMetadata`, `-group`,
  `-dictionary`, `-optionID`, `-_title`, ...
- `AVMediaSelectionGroup` at 6.1.3, **18 own instance methods**: `-options`, `-allowsEmptySelection`,
  `-_defaultOption`, `-asset`, `-_isAlternateTrackGroup`, `-_isKeyValueGroup`, `-_mediaType`, ...

Two of those readings changed what the object does, and both were checked rather than assumed:

- **`-title` is not on 6.1.3's option; `-_title` is.** A first draft of the object read a display name out
  of the option's title. There is no public title accessor on this release, so that value cannot be read
  without reaching into a private selector, and this object does not. It stores what the caller passes and
  reads nothing private.
- **`-mediaType` is the real legible/audible discriminator.** Apple's factory decides an option's type
  from the AV media type, and 6.1.3's option carries it.

## The one constant that is named by the SDK and declared by nothing

`MPNowPlayingInfoLanguageOption.h:68` says a languageTag "with the value of
`MPLangaugeOptionAutoLangaugeTag`" means the best language by system preference. A first draft of
`MPNowPlayingInfoLanguageOption90.m` declared `extern NSString *const MPLanguageOptionAutoLangaugeTag;`
and compared the tag against it.

**That would not have compiled, and the compile is the only reason it is written down here.** Measured
over the 26.2 MediaPlayer headers, that name occurs in that one comment and in no declaration anywhere in
the SDK:

```
$ grep -rn "AutoLangauge\|AutoLanguage\|MPLanguageOptionAuto" \
    .../iPhoneOS16.4.sdk/System/Library/Frameworks/MediaPlayer.framework/Headers/*.h
MPNowPlayingInfoLanguageOption.h:68:/// A languageTag with the value of MPLangaugeOptionAutoLangaugeTag represents
```

One hit, and it is a comment. An `extern` for a symbol no library exports is a link error on a device
build, and the stand-in build would have gone on reading a nil there and comparing it to nil, which is
true - so a host-side check would have passed while the device build failed. That is the shape of mistake
`facts/MediaPlayer/MediaPlayerConstants.md:8-12` records for the constant VALUES, and the reason the
`MPLanguageOptionCharacteristic*` rows there are `implemented` against values read out of the framework
rather than spelled from their names.

The shipped object answers **NO** to the two `isAutomatic...` accessors, and that is now measured rather
than argued. The header documents each as "a special case that is used to represent the best
legible/audible language option based on system preferences" (:56-63) and says at :57-59 that a tag
"with the value of MPLangaugeOptionAutoLangaugeTag" is that special case - a constant the SDK declares
nowhere, so its value cannot be written down from the headers. **What Apple's own class answers was
therefore asked directly**, by building every option its designated initialiser can build:

    $ sh tests/backports/host/mp-language-option/run.sh

`tests/backports/host/mp-language-option/probe.m`, linked against this Mac's own MediaPlayer. It is a
read of Apple's behaviour, not a check of the port: the port's own check is
`tests/backports/host/mediaplayeritem/languageoption90.m`, which compiles the port's source against
`MPMediaItemStandin.h` so that what is measured is the port.

**Two controls, because a table of NOs is what a broken probe also prints.** The probe exits non-zero
and `run.sh` fails if either is missing:

| control | answer | what it rules out |
| --- | --- | --- |
| the class declares `initWithType:languageTag:characteristics:displayName:identifier:` | yes | a framework without it would answer through an inherited `-init`, and every row below would be about nothing |
| the **type round-trips**: given 0 reads back 0, given 1 reads back 1 | yes | an initialiser that dropped the type would answer NO on every row, and that is indistinguishable from a refutation of the type rule unless the round-trip is shown first |

**The run.** 34 options built, **0** answering YES:

| what varies | rows | `automatic` |
| --- | --- | --- |
| 13 `languageTag` values (`en`, `""`, `auto`, `und`, `mul`, `zxx`, `-auto-`, `x-auto`, `*`, the literal `MPLangaugeOptionAutoLangaugeTag`, `auto-langauge`, `system`) x both types | 26 | 0 |
| the **nil** tag, which :57-58 says disables the option, x both types | 2 | 0 |
| `characteristics`, `displayName` and `identifier` as nil, as empty and as filled, x both types | 6 | 0 |
| the same option installed as a group's `defaultLanguageOption` | 2 | 0 |

So the discriminator is **none** of the five arguments the initialiser takes, and in particular it is not
the type. An earlier version of this file answered from the stored type, on the reading that "the
automatic option is the automatic option *for a type*"; this table is what refutes it, and the port now
answers what Apple answers.

What is **not** established, and is not claimed: what tag the system's own special option carries. The
option that means "choose for me" is inserted by `-selectMediaOptionAutomaticallyInMediaSelectionGroup:`
and is not one a caller can build, so neither Apple's class nor this port can be asked about it. The
misspelled constant appears in Apple's own binary only twice in this machine's arm64e shared cache, and
neither occurrence is that name - measured with `strings -a` over the cache's subcaches, which is why
the sentinel's value could not be read out and is not written down here.

## The exclusivity the group does not enforce

The header calls `MPNowPlayingInfoLanguageOptionGroup` "a mutually exclusive group of language options"
where "only one language option within a given group may be active at a time" (:86-87). The object does
not enforce that, and the reason is written into the file: it holds the set the caller built and the one
option the caller marked active. Enforcing exclusivity would mean silently dropping options the caller
passed in, which answers a different question from the one Apple declares and loses data the caller can
see. Apple's own group is enforced by the system's media-selection machinery, which is not present on
this release - `AVMediaSelectionGroup` exists at 6.1.3 but the selection UI that would enforce it is
`AVPlayerItem`'s, and none of this port's code drives it.

## Copies, and why they are copies — and the copy assertion that was removed

`initWithLanguageOptions:` and `initWithType:...characteristics:` both take an `NSArray` or `NSString`
the caller owns and the object holds it past the call. All seven are copied. A caller that mutates its
own array afterwards must not silently change what the option reads, and the header's accessors are
`readonly`, so there is no setter for a copy to fall out of step with. The four `NSString` fields are
copied for the same reason - `[NSString copy]` on an immutable string is a retain, and it is spelled
`copy` so the intent survives a future mutable subclass.

`tests/backports/host/mediaplayeritem/languageoption90.m` asserts the array copy, and **the languageTag
copy is deliberately not asserted, because that assertion cannot fail.** Measured: mutating the object to
`_languageTag = languageTag;` and rerunning the check prints

```
langcheck: OK (0 failures)
```

which is the check being wrong rather than the code. `NSString` is immutable, so `[languageTag copy]`
and `languageTag` are the same retain, and a test that passed on both spellings certifies nothing. An
`NSMutableString` caller is the only case where the difference is observable, and the header types the
parameter `NSString *` under `NS_ASSUME_NONNULL`, so that caller is not one the contract admits. The
array is the case where copy and retain differ visibly - the check mutates the caller's `NSMutableArray`
after construction and reads `count == 2` - so that is the one asserted.

Three mutants of the object, each shown to turn the check RED rather than assuming it would:

| mutation | verdict |
| --- | --- |
| retain the characteristics array instead of copying it | `RED characteristics were copied, not retained: 2` |
| `isAutomaticAudibleLanguageOption` answers YES | `RED neither 'automatic' accessor fires on an ordinary option: NO for both types` |
| drop the caller's `allowEmptySelection` flag | `RED allowEmptySelection reads back: YES` |
| retain the languageTag instead of copying it | **`OK (0 failures)` — the check is blind here, and is not asserted** |

The second row used to be "`isAutomaticLegibleLanguageOption` answers YES without reading the type", and
it was a real mutant while the accessors read the type. They hold no state now, so there is nothing left
to perturb in that direction and the row names the only mutation left for them: an accessor that starts
answering YES. The expectation it is compared against is Apple's, from the table above - not the port's
own output, which is what makes the check worth having.

## The stand-in header is the only place these two classes are declared

`MPMediaItemStandin.h` already declared `MPNowPlayingInfoLanguageOption` as a bare `NSObject` with one
accessor, because `MPChangeLanguageOptionCommandEvent90.m` needs a type for its `languageOption` property
to compile against and the framework has no such class on this release.

A first draft of `MPNowPlayingInfoLanguageOption90.m` restated the full contract under
`#if defined(CHARON_MEDIAPLAYER_STANDIN)`, which is the idiom `MPMediaPlaylist93.m` uses for
`MPMediaPlaylist`. **It does not compile**, and the reason is specific:

```
error: duplicate interface definition for class 'MPNowPlayingInfoLanguageOption'
note: previous definition is here
MPMediaItemStandin.h:47:12: @interface MPNowPlayingInfoLanguageOption : NSObject
```

`MPMediaPlaylist93.m` gets away with its restatement because `MPMediaItemStandin.h` declares no
`MPMediaPlaylist` at all - the stand-in has an item and no playlist, which that file's own comment says.
This pair is the opposite case: the header has one stub, so any second declaration collides. The fix was
to extend `MPMediaItemStandin.h` to the full contract and let the `.m` be the only `@implementation`, so
there is exactly one declaration of each class however a build is configured.

`MPMediaItemStandin.h` carries these two classes without nullability annotations while the SDK's header is
`NS_ASSUME_NONNULL`. That is deliberate and matches what the file already does for the rest of its
contents; clang's `-Wnullability-completeness` is a warning, not an error, in the stand-in build.

