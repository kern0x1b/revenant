# NSMorphology and the inflection rules, iOS 15.0 and 17.0

Five classes, each in a file of its own because `band()` reads a file as one object with one release
boundary: `NSMorphology.m` holds `NSMorphology`, the iOS 17.0 category and the side table they
share, and exports no API symbol of its own; `NSMorphologyCustomPronoun.m`,
`NSMorphologyPronoun.m`, `NSInflectionRule.m` and `NSInflectionRuleExplicit.m` are the other four.
`CharonMorphology.h` holds what the SDK does not.

Source: the 26.2 Foundation's `NSMorphology.h` and `NSInflectionRule.h`, read whole, and the host's
own five classes held against the port by `tests/backports/host/morphology` — **344 comparisons, none
differing**, over the 172 cases in `expected.txt`, built from scratch on every run so nothing stale is
ever measured, and behind two greps on the one file that holds the class, the description and the
side table.

**device-unverified.** The class asks the release's own `NSBundle` for a preferred localization and
the runtime for an object, and no device run exists.

## What the SDK has and what the port declares

`grep -c` on the 16.5 SDK's `NSMorphology.h`, one line per name, which is what the port's header is
built from:

```
NSGrammaticalGender 1   NSGrammaticalCase 0
NSGrammaticalPartOfSpeech 1   NSGrammaticalPerson 0
NSGrammaticalNumber 1   NSGrammaticalDetermination 0
NSGrammaticalPronounType 0   NSGrammaticalDefiniteness 0
NSMorphologyPronoun 0
```

So the SDK has three of the eight enums and not the class, while the macOS SDK the differential
builds against has all six — and a header that declared them unconditionally would be a
redeclaration on one of the two. `CharonMorphology.h` therefore declares the five 17.0 enums and
`NSMorphologyPronoun` under `CHARON_MORPHOLOGY_IOS17_ENUMS` and `CHARON_MORPHOLOGY_IOS17_PRONOUN`,
which the **package** defines, and the differential does not.

## The rules, all measured

- **The eight settings are plain storage.** A value outside the enumeration is written as given, with
  no refusal and no clamp — 40 through 43 into each of them, read back as written.
- **`-isUnspecified` reads only the three iOS 15.0 settings.** `grammaticalGender`, `partOfSpeech` or
  `number` at 1 or 2 answers NO; `grammaticalCase`, `determination`, `grammaticalPerson`,
  `pronounType` and `definiteness` at 1 or 2 leave it YES. Measured one property at a time, eight
  properties by three values, as 24 cases in the golden file.
- **A `-description` writes the enumeration's name**, and the name in **parentheses before the value**
  where the value is outside the enumeration: `Feminine`, `(NSGrammaticalGender)(-2)`,
  `(NSGrammaticalCase)(40)`. The eight tables are the 26.2 header's own orders and no other, which is
  the portability of the API: `NSGrammaticalNumber` is NotSet, Singular, **Zero**, Plural, PluralTwo,
  PluralFew, PluralMany, so a Plural printed where the host prints Zero until that table was the
  header's.
- **The field order is the host's and not the header's**: number before partOfSpeech, and
  definiteness before determination.
- **A custom pronoun is supported for en, en_US and en_GB** and for nothing else of the twenty-five
  languages measured, and its required keys are the five form names.
- **`-setCustomPronoun:forLanguage:error:` refuses with `NSCocoaErrorDomain` and code 1024**, and
  the wording names the **first required key that is missing**: `"self"` when the language is not one
  of the three, `"subjectForm"` when none of the five is set, `"objectForm"` when only a subject form
  is. `nil` clears a language and is accepted anywhere. The wording is `The value "<key>" is invalid.`
- **`+[NSInflectionRule canInflectLanguage:]` answers a real list**: en, en_US, en_GB, fr, fr_FR, de,
  es, pt, it, nl, ko and hi are 1; ru, ja, ar, zh, pl, tr, he, th, und, the empty string, xx_YY,
  klingon and 123 are 0.
- **`-[NSInflectionRuleExplicit copyWithZone:]` raises on the host** —
  `*** -copyWithZone: cannot be sent to an abstract object of class NSInflectionRuleExplicit: Create a
  concrete instance!` — on a class that is concrete, and the port raises it in the base class where
  the host's does.
- The archive keys are the host's: the eight settings under their own names, a pronoun as `pronoun`
  plus the eight settings plus `morphology` and `dependentMorphology`.

## The side table, and two faults a compile could not see

The five 17.0 settings are a **category** on `NSMorphology`, and a category cannot add an ivar, so
their storage is one associated object per instance. Three things about that, each found by running
the differential and not by compiling:

- the box **must be an Objective-C object**. A `calloc`'d struct under
  `OBJC_ASSOCIATION_RETAIN_NONATOMIC` is retained by the runtime and faults on the first touch;
- it must be **mutable**. An `NSValue` hands back a copy of what it holds, so a getter that reads the
  box throws its write away and all five settings stay at zero. It is an `NSMutableData` of the
  struct's bytes, read and written in place;
- a **read of an object with no box is zero**, not a NULL to dereference. `-[NSMorphology
  copyWithZone:]` reads `grammaticalCase` on the copy it has just made, and the box is attached on
  the first write — lldb's backtrace named that frame and it faulted on the NULL.

Neither `class_createInstance` nor `objc_getAssociatedObject` is reached by name: `+automaticRule`
and the explicit rule's two initialisers use the class object of the receiver, because a lookup by
name finds the *other* class of the two when both exist — which is exactly what the differential's
`-D` rename does.

## What is not carried

- **The seven attribute constants are not in this file's registry**: `NSMorphologyAttributeName` and
  the six `NSInflection*` are already answered by `Foundation/ios15-16.json`, and the registry test
  refuses the duplicate. This file is **31 rows** — ten methods and twenty-one properties — and my
  first count of 38 was wrong for exactly that reason.
- `NSInflectionAgreementArgumentAttributeName`, `NSInflectionAgreementConceptAttributeName` and the
  rest of the 17.0 inflection vocabulary are not rows of this family.

## Owed

The port-target compile is clean of errors and of the one diagnostic the gate turns into an error,
`-Werror=objc-missing-property-synthesis`. The warnings it still reports are owed here rather than
fixed, each with the one that would be the fix:

- **four `-Wnullability-completeness` sites in `CharonMPSImage.h`** — a pointer parameter with no
  `_Nonnull`/`_Nullable`. The fix is the annotation; the port's own headers spell it everywhere else.
- **the four `+supportsSecureCoding` the NSSecureCoding adopters do not answer**
  (`CharonMorphology.m`, `NSInflectionRule.m`, `NSMorphologyCustomPronoun.m`,
  `NSMorphologyPronoun.m`) — `-Wobjc-property-implementation` and `-Wprotocol` on the class property
  the protocol declares. The fix is one `+ (BOOL)supportsSecureCoding` per class, after the ivar
  block rather than before it, which is where a first attempt put it and lost the compile.
- **three `-Wobjc-designated-initializers` in `NSInflectionRuleExplicit.m`** — its designated
  initialiser cannot call `[super init]` because the header marks `-init` `NS_UNAVAILABLE` on the
  abstract base, so it reaches NSObject through `class_createInstance`. That is the right behaviour
  and the wrong shape for the warning; the fix is a decision about how the port says so, not a cast.

Eleven of the branch's thirty-one member rows and three of the seven class rows are **absent** rather
than implemented, each with the reason naming what the differential does not measure — an
`NSInflectionRuleExplicit` it never constructs, the `NSMorphologyPronoun` initialisers it reaches only
through `customPronounForLanguage:`, the two `NSMorphology` properties that are not among the eight
settings it walks, and the two constant classes it never names.
