# UITextSearchOptions, iOS 16.0

Introduced in iOS 16.0: the options of a text search, the match method (contains, starts with, full word) and the string compare options.
The options are handed to a search (`UITextSearching`'s `performTextSearchWithQueryString:usingOptions:resultAggregator:`); the find session
that runs the search is not in the port (`registry/UIKit/ios15-16.json`, `UIFindSession` and its family), so the port makes the options only
as the release's defaults.

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=16.0` on the class).
The header declares `wordMatchMethod` and `stringCompareOptions` readonly; `-init` is not marked unavailable.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/search-options`, which compiles the port
source beside the host's class in one process and prints the same checks for both.

## As UIKit does

- The runtime `-init` answers options with match method 0 (`UITextSearchMatchMethodContains`) and compare options 0.
- Equality is by value. Two options with the same match method and compare options are equal (`isEqual:` answers YES); an option is not
  equal to nil, to a string, or to a different kind of object; an option is equal to itself.

## What the port does

- `UIKit/UITextSearchOptions.m`: the two values are the ivars, read through the readonly getters. Nothing sets them: the port has no find
  session to make options with other values. `-init` is the zero state, which is the release's default.
- `-isEqual:` compares the two values, and `-hash` follows them, so equal options hash alike.

## A named divergence, asserted, not a gap

- **The host's class has setters the header does not declare.** `setWordMatchMethod:` and `setStringCompareOptions:` store what they are given:
  the host reads back 2 after a set to 2, and 1 after a set to 1. The header declares both properties readonly, and the port has no setters, as
  the header says. `tests/backports/host/search-options/run.sh` asserts both answers.
- **The host's hash is per object.** Two equal options (both defaults) hash differently on the host, although `isEqual:` answers YES. The port's
  hash follows the value, so equal options hash alike. The port keeps the contract (equal objects hash alike), the host does not; the run
  asserts the host's NO and the port's YES.

## What is not carried

- The host has a class method `+defaultSearchOptions` that answers an options object with the defaults. It is not declared in any public header,
  so no documented call reaches it; the port does not carry it. The defaults it answers are the ones the port's `-init` gives.

## What is not compared

- **Options with values other than the defaults.** The differential compares the defaults only, since the port has no setter and no find session
  to make other values. A host-only measurement (in this band's probe, not a committed test) shows the host's `isEqual:` answers NO between an
  options object whose match method was set to 2 and the defaults, so value equality does depend on the stored values. The port's value
  comparison for non-default values is not checked against the host by this differential.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The class is plain Objective-C state, so the host run is its
  oracle for the defaults and the equality of defaults.
