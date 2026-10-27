# 0015: NSURLComponents parses as macOS does, the lenient grammar

Status: accepted

## Context

`NSURLComponents` came with iOS 7, and the backport in `frameworks/Backports/src/Foundation/NSURLComponents*.m`
gives it to iOS 6. The first version was strict: it rejected a URL with a space, a brace, a quote or a lone `%` in a
component, where the modern class percent-encodes the character and returns the URL. The strict parser disagreed with
macOS's `NSURLComponents` on 18 of the 56 corpus URLs in `frameworks/Backports/tests/url_components_oracle_test.lua`.

Apple changed the parser in a release that is not the same for every app: an app is given the behaviour of the SDK it
was linked against, not of the system it runs on. Telegram is built against the 26.2 SDK, so on a modern device it gets
the lenient parser. The iOS 6 backport has to give the same answers, or a Telegram URL that the device accepts is refused
on the A5.

## Decision

The backport parses as macOS does, which is the oracle the test checks against:

- A component keeps its valid escapes and each character its set allows. Every other character, including a non-ASCII
  one, is written as the escapes of its UTF-8 bytes. A component with a `%` that starts no valid escape has each `%`
  written as `%25`. The sets are read from the oracle, one ASCII character at a time, in
  `frameworks/Backports/tests/url_components/corpus.txt`.
- A host label with a non-ASCII character is mapped (compatibility forms, lowercase) and written in punycode in the
  string. `percentEncodedHost` holds the Unicode form, escaped, so `xn--` labels read back as their Unicode.
- The port keeps the digits the URL spelled (`0080`), and an empty port keeps its colon in the string.
- A colon in the first segment of a relative path is written as `%3A` by the `path` setter, not by the composer, so a
  parsed `:x/y` keeps its colon.
- Setters keep the strict check and raise on an invalid value, as before. The oracle does not test the setters yet.

## Consequences

- The test compares all 705 corpus URLs with macOS and passes with an empty list of divergences.
- The punycode mapping is compatibility plus lowercase, not the full UTS #46 table. A label that depends on the table
  for its mapping is the first place a difference would show, and the corpus has none.
- The grammar is lenient on purpose. A test that expects a rejection of a URL macOS accepts is wrong for an app linked
  against the 26.2 SDK, and should be changed to the macOS answer.
- The backport does not select the parser by the app's SDK version. Apple's lenient parser is the one the modern class
  gives apps linked against the iOS 17 SDK or later; that is the owner's reading and was not re-measured on a device.
  Apps linked against an older SDK are not what this port is for, so no second grammar is kept.

## Check

`./xmakew l -P . frameworks/Backports/tests/url_components_oracle_test.lua` builds the dump twice (macOS alone, and the
backport's sources with `REVENANT_HOST_BUILD`), compares the rows, and then runs a negative control in which every URL
gets a path appended and the comparison must report it.
