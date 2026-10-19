# The person name components formatter, iOS 9.0 and 10.0

The class, the five styles, the annotated string, the parse, the phonetic option and the locale, and
the eight attribute names the annotated string is written with.

Source: the SDK 26.2 headers, and the host's own `NSPersonNameComponentsFormatter` over ten locales
and eleven component sets, through `tests/backports/host/personname` (the port's class compiled
under a name of its own, so the two answers sit side by side), with the readings kept in
`.agent-work/probe/order.m` and `batch.m`.

## The name order is six language codes, and the separator is one string

Both were read out of the host's own formatter over **every locale it knows — 1,072 of them**:

- the separator is a plain space in all 1,072, so it is one string and not a table;
- six languages write the family name first — **hu, ja, ko, vi, yue, zh** — and the other 1,040 write
  the given name first.

That is CLDR's `nameOrder`, one bit per language, and the port keeps the six. The
`ABRecordCopyCompositeName` route this file started with is *not* what is here: that call answers for
the **device's** language, which is right only while the formatter is left on the current locale and
wrong the moment an application sets another one — which the differential found, on `ja_JP` and
`zh_Hans_CN`, where the port wrote "John Appleseed" where the system writes "Appleseed John".

## The five styles, as the host answers them

| style | what it is | en_US "Dr. Johnathan Maple Appleseed Esq." | ja_JP, the same |
| --- | --- | --- | --- |
| long | prefix, given, middle, family, suffix, in the language's order | `Dr. Johnathan Maple Appleseed Esq.` | `Dr. Appleseed Johnathan Maple Esq.` |
| default, medium | given and family, in the language's order | `Johnathan Appleseed` | `Appleseed Johnathan` |
| short | the nickname, else the given name, else the family name | `Johnny` | `Johnathan` |
| abbreviated | the given and the family initial, in the language's order | `JA` | `AJ` |

Two of the header's own examples are not what the system answers, and the system is followed: the
header illustrates `short` with "C Darwin" (the host answers the nickname alone, or the given name
alone) and `abbreviated` with "CRD" (the host answers the two initials of the given and the family
name, and never a middle initial). Both are in the differential's cases.

Three smaller rules, all measured:

- **A nickname with nothing else** answers for `long` and `abbreviated` too, not only for `short`.
- **A middle name or a suffix alone** is a long name: the host answers "Maple" and "Esq.".
- **Nil components** raise `NSInternalInconsistencyException` on both sides.

## The annotated string

The default form, with one run per component and the *name of the component* under
`NSPersonNameComponentKey` — `givenName`, `familyName`, `middleName`, `namePrefix`, `nameSuffix`,
`nickname` — and one run for the separator whose value is `NSPersonNameComponentDelimiter`, which is
the constant's own string and not the separator's text (measured: the host's runs for a Japanese name
are family, delimiter, given, in that order). The eight names are defined in this file, beside the
code that writes them, so a formatter and the names it writes are one object and one release group.

## The parse

Fifteen strings, read on both sides. A comma reads as family-then-given ("Appleseed, John" gives the
given name John and the family name Appleseed). Otherwise the first word is the given name, a first
word ending in a full stop is a prefix, a last word ending in a full stop is a suffix, and everything
between them is the family name, so "Dr. John Maple Appleseed Esq." gives the prefix Dr., the given
name John, no middle name, the family name "Maple Appleseed" and the suffix Esq. A string with nothing
in it is not a name: `personNameComponentsFromString:` answers nil and
`-getObjectValue:forString:errorDescription:` answers NO with the error description "Person's name
could not be detected".

## The abbreviated style over a phonetic representation, and why the port raises too

When the abbreviated style is asked for a *phonetic* representation, both the host and the port
**raise** `NSUnknownKeyException`. The abbreviated template reads the given name and the family name
*through* the phonetic representation, by key path -- `phoneticRepresentation.givenName` -- and Apple's
own `NSPersonNameComponents` refuses a read of that path for a spelling that has not got the
component, with the reason `[<NSPersonNameComponents 0x…> valueForUndefinedKey:]: this class is not key
value coding-compliant for the key phoneticRepresentation.givenName` and `NSUnknownUserInfoKey` and
`NSTargetObjectUserInfoKey` set (measured on the host, ten locales, and reproducible from any caller
with `[components valueForKey:@"phoneticRepresentation.givenName"]`).

The port's own `NSPersonNameComponents` did **not** refuse it, so it answered the read, the port never
reached the release's behaviour, and the delivery answered two initials where every current system
throws -- a quietly-different answer, which is the most dangerous outcome there is. The refusal is now
there, in the release's own words, and the template reads the way the release's does. The fifteen
recorded divergences are gone: they are fifteen comparisons that agree, and the suite reads
`checks=872 failures=0 divergences=2` with only the parse shape left.

The exception is raised by **name as a string** rather than by a reference to
`NSUnknownKeyException`, because 6.1.3 does not export that symbol (measured with
`tools/corpus/cache-value.lua` over the 6.1.3 armv7 cache) and an exception's name is a string
anyway.

## The suite is green, and what it took

`tests/backports/host/personname` reads **857 checks, 0 failures, 17 named divergences**, and exits 0.
Two harness bugs were in the way and both are worth writing down, because neither was in the port's
code and both looked like one:

- **The attribute walk was a use-after-free in the test.** It described each run's value from inside
  `enumerateAttributesInRange:`, and the value the dictionary hands out is not guaranteed to be alive
  after the block returns, so `%@` trapped. ASan and UBSan were both silent, and lldb named the
  frames: `_DescriptionWithStringProxyFunc` under `__CFStringAppendFormatCore`. The walk now says
  *which of the eight names sits on which range* and sends nothing to a value: a dictionary lookup by
  a key that is one of the eight compares the value by pointer. It says the same thing and cannot walk
  off the end of an object.
- **The last section read a global variable through `objc_msgSend`.** The eight names are variables,
  not methods, and asking a class object for a selector it does not have throws a **C++** exception,
  which an `@catch (NSException *)` does not catch: the process terminated in `std::terminate`. The
  section reads the variables now, and a differential cannot test its own copy of them anyway --
  the object that defines the port's is not linked here, so both sides read the system's.

The suite covers **fifteen locales**, and five of them -- ja, zh, ko, hu, vi -- write the family
name first, so the order is decided here rather than on a device: dropping `ja` from the set gives
**`failures=16`, exit 1**.

## The seventeen divergences, and what each is

There are two of them now, and the other shape is the parse of one shape, and they are a *parser*, not a rule:
`"Appleseed John Dr. Esq."` gives the system the middle name `John` and the family name `Dr.`, where a
positional rule -- first remaining word the given name, last the family name, the rest in between --
gives the family name `"John Dr."`. The system's parser is a grammar and this one is positional, and
a dotted word in the family position is where they part company. Of fifteen measured strings this is
the only one, and both answers are in the log.
