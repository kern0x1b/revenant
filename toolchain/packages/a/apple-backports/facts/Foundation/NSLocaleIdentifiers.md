# NSLocale's languageIdentifier and regionCode, iOS 17.0, and what each band end carries

The two accessors this object defines are 17.0 in the SDK 26.2 `NSLocale.h` and in
`sdk-26.2-surface.tsv`, and neither exists in any release the port builds. Both are
computed here from what the release does carry.

## The semantics are the header's, read there and not inferred

`SDK 26.2 .../Foundation.framework/Headers/NSLocale.h`:

```
/// Returns the identifier for the language part of the locale. For example, returns "en-US" for "en_US@rg=gbzzzz"  locale.
@property (readonly, copy) NSString *languageIdentifier API_AVAILABLE(macosx(14.0), ios(17.0), watchos(10.0), tvos(17.0));

/// Returns the region code of the locale.
/// If the `rg` subtag is present, the value of the subtag will be used. For example,  returns "GB" for "en_US@rg=gbzzzz" locale.
/// If the `localeIdentifier` doesn't contain a region, returns `nil`.
@property (nullable, readonly, copy) NSString *regionCode API_AVAILABLE(macosx(14.0), ios(17.0), watchos(10.0), tvos(17.0));
```

`rg` is a BCP-47 extension subtag. CoreFoundation on the 6.0 rung does not know it, so
neither accessor asks the dictionary for it: both read the `rg=` subtag out of
`-localeIdentifier` themselves. `regionCode` falls back to `NSLocaleCountryCode`, which
the release's own `-objectForKey:` answers.

## The ladder, and the control that certifies the zeros

`tools/release-split.lua` reads nm-visible exported symbols and finds **none** for an
Objective-C category, so a clean run of it says nothing about `NSLocale+Identifiers17.m`.
The measurement a category needs is the selector-string ladder, and it was run by hand.

**Is the name real, and in which held release** — presence, not introduction:

```
xmake l tools/cache-index/first-rung.lua languageIdentifier regionCode
  languageIdentifier   8.0
  regionCode           4.3
```

Neither answer is about `NSLocale`, which is the point the selector ladder cannot make on
its own. Class-scoped, with `python3` over the prepared per-release census:

```
python3 -c 'import json,os
for r in ("4.3","4.3.5","6.0","7.0"):
    c=json.load(open(os.path.expanduser("~/.revenant/dyld/"+r+"/classes_armv7.json")))["classes"]
    own=[n for n,e in c.items()
         if "languageIdentifier" in (e.get("instance") or {}) or "regionCode" in (e.get("instance") or {})]
    print(r, len(c), own)'
  4.3    7187 ['AADeviceInfo']
  4.3.5  7208 ['AADeviceInfo']
  6.0   11284 ['AADeviceInfo']
  7.0   14765 ['AADeviceInfo']
```

**The control is in that output**: 7187, 7208, 11284 and 14765 classes were read in the
four runs, and a class was matched in every one of them — the private AdSupport class
`-[AADeviceInfo regionCode]`, which is not `NSLocale`. So a zero for `NSLocale` is the
release's answer and not the reader's blindness. This is the owner trap the rulebook warns
about, measured: the selector string `regionCode` is in both the 6.1.3 and the 4.3 selector
dumps, and no `NSLocale` in either release owns it.

**What the release does have to answer them** — same census, 6.0:

```
  NSLocale instance: identifier, localeIdentifier, objectForKey:, displayNameForKey:value:,
                    initWithLocaleIdentifier:, canonicalLanguageIdentifierFromString: (class)
```

`-localeIdentifier` is the string both accessors parse and `-objectForKey:` is what
`regionCode` falls back to, so neither accessor needs anything iOS 6 lacks.

## The 6.1.3 rung itself, which is the band the gate links

The two censuses above are the prepared per-release ones. The band the 6.1.3 gate reads was
also read directly, through `modules/apple/objc.lua`'s own `inventory` — the rungs' reader, not
a re-implementation:

```
xmake l .agent-work/probe/inv.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 NSLocale NSFilePresenter
  control: 11378 classes, 188523 instance selectors, 15334 class selectors read in this run
  class NSLocale PRESENT  superclass=NSObject  image=/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation
    inst -localeIdentifier, -objectForKey:, -identifier, -displayNameForKey:value:,
         -initWithLocaleIdentifier:, -initWithCoder:, -hash, -isEqual:, -description
    cls  +componentsFromLocaleIdentifier:, +canonicalLanguageIdentifierFromString:,
         +localeIdentifierFromComponents:, +localeWithLocaleIdentifier:, +currentLocale, +systemLocale,
         +autoupdatingCurrentLocale, +availableLocaleIdentifiers, +ISOLanguageCodes, +ISOCountryCodes
```

**The control is that first line**: 11378 classes and 203857 selectors read in the one run,
and the reader then matched `NSLocale` and listed it. Neither `languageIdentifier` nor
`regionCode` is in either list, so at the rung this port's minimum is actually gated on, the
two accessors do not exist and the substrate they are built from does. `NSFilePresenter` came
back ABSENT in the same run.

## What this does not claim

`NSLocale+Identifiers17.m` defines release 17's two accessors and nothing else. The 15.0
accessors of the same family are other slices' rows and are untouched here.