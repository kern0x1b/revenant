# The three measurement formatters of iOS 8.0

`NSLengthFormatter`, `NSMassFormatter` and `NSEnergyFormatter`, one machine with three sets of
numbers: what they share is in `Foundation/CharonUnitFormat.{h,m}`, a `Charon`-prefixed helper, and
each class is in a file of its own.

Source: the 26.2 headers for the classes; the host's own Foundation for every rule, held against the
port by `tests/backports/host/unitformat`, which runs the two in one process over the same inputs and
compares two answers for one input; the armv7 caches under `$HOME/.charon/dyld/<release>/` for
whether the release could have answered anything itself.

**device-unverified.** The wording of every answer, every threshold and every name is measured on
the host. What is **not** verified on a device is the part a host differential cannot see: the number
is written through the **release's** own `NSNumberFormatter` and the system of units is read from the
**release's** own locale, so the digits, the grouping, the decimal mark and which of the three
systems a value is written in are the device's. `tests/backports/device/unitfmt.m` calls every
implemented method of the three classes on the release it runs on, in all three unit styles, over
each class's own units and flags, and holds that every one of them answers and that the documented
parse returns NO with both out-parameters untouched. **Its run is pending**: it is wired into
`tests/backports/device/below6/xmake.lua` and has not been on a device, so no claim is made here
about what the device answers, only about what the port asks it.

## Why the names are carried and the rest is asked of the release

The three classes arrived in iOS 8.0 and no release the port carries has them. The question is
whether the release can be asked for the *names* of the units, and it cannot:

| what | iOS 6.1.3 | iOS 10.0.1 |
| --- | --- | --- |
| `icudt*_dat` the image links | `icudt49_dat` (ICU 49, CLDR 24) | `icudt57_dat` (ICU 57, CLDR 31) |
| `ures_open` and the rest of the resource API | 41 exports | 44 exports |
| `uameasfmt_*`, the measurement formatting API | none | 10 exports |
| the CLDR keys `length-meter`, `mass-kilogram`, `energy-kilojoule`, `celsius`, `square-meter` | **absent** | present |

So the resource API is there and the table the names come from is not: searching every cache on the
ladder for those keys finds them in **iOS 8.0 and every release above it, and in no release below**
(3.1.3, 3.2, 4.0, 4.3, 4.3.5, 5.0, 5.1.1, 6.0, 6.0.2, 6.1, 6.1.3, 6.1.4, 6.1.6, 7.0, 7.0.1, 7.0.6,
7.1, 7.1.1, 7.1.2 — 0 of 4; 8.0 through 9.3.6 — 4 of 4). The names are therefore carried, in English,
which is the limit `NSRelativeDateTimeFormatter` already works under.

What the port *does* ask of the release is real and is the reason the numbers are right in every
locale:

- the number is written through **the release's own `NSNumberFormatter`**, so the digits, the
  grouping, the decimal mark, the sign and the spelled-out words are the locale's;
- the system of units is read from **the release's own locale** under `NSLocaleMeasurementSystem`,
  which answers `"U.S."`, `"U.K."` or `"Metric"` and has done since before iOS 5. `NSLocale`'s own
  `usesMetricSystem` is iOS 10 and is not used. The key is the right one to read and not a region
  list: `en_CA` answers `Metric`, where a list of the imperial regions would get it wrong.

## The figures are the system's own, and they are not the units' exact factors

A U.S. yard is written in 1.0936 of a metre, a foot in 3.28084, a mile in 0.00062137, an inch in
39.3701, a pound in 2.2046226218 and an ounce in 35.2739619; the metric figures are exact, and a
calorie and a kilocalorie are 1/4.184 and 1/4184. Each was pinned twice: by bisecting the value the
system changes its answer at, to the last bit, and by the value it writes at six fraction digits.

The thresholds follow from them and are not written out as numbers of their own, because they are
where the two bisections disagree and the *switch* is the authority:

- a **U.S. table switches at its threshold** and a **metric one strictly above it** — 0.3048 m is
  written "1 foot", where 0.01 m is "10 mm" and 1 kg is "1,000 g". The metric thresholds are stored
  one double past the value the system switches at for that reason;
- the U.S. kilocalorie is the one U.S. threshold above its value: 4184 J is exactly one kilocalorie
  and the system still writes "1,000 cal".

## The rules, all measured

- **The plural is decided on the number that is written, not on the value.** 0.3048 m is
  1.000000032 feet and the system writes "1 foot"; 0.0254 m is 1.000001 inches and it writes
  "1.000001 inches". A negative one is the singular as well.
- **The short style joins without a space and the other two with one** — "1km", "1 km", "1 kilometer".
- **A stone is written in two units** — the whole stones and the pounds over fourteen, "0st 7#",
  "0 st, 7 lb", "0 stones, 7 pounds" — and the U.K. and the metric write it as the U.S. does. Below
  zero it is written in stones alone.
- **A person's height is two units in the U.S. alone**: feet and inches, the feet rounded towards
  minus infinity so a height below zero carries the sign there ("-4 ft, 8.63 in" and not
  "-3 ft, 3.37 in"). The U.K. writes centimetres as the metric does and still **answers the foot** to
  `-unitStringFromMeters:usedUnit:` and to the name beside it, at every style and every height.
- **The two `forXxxUse` flags change much less than their names suggest.** A person's mass and a
  food energy are written in the units any other mass and any other energy are, over ten decades in
  both directions; only the food kilocalorie's name and a person's height's form change.
- **Three names are not the symbol, and two of them differ between the two methods**:
  `-stringFromValue:unit:` writes a U.S. pound "# lb" where `-unitStringFromValue:unit:` answers
  "lb"; a kilocalorie of food energy is "C" as a name and "Cal" as a written value; a stone's name
  is always the singular where the written form takes a plural, and the U.S. writes that plural and
  the U.K. and the metric do not.
- **The four length units are spelled two ways**: a name on its own is the American spelling in every
  locale ("millimeters" in en_GB) and the written form is the locale's own ("0 millimetres" in en_GB,
  en_AU and en_001; "0 millimeters" in en_US). The symbol and the medium name are the same either way.
- **A value of exactly zero and a value below zero are the system's own answers**: zero is the
  largest unit of a mass and of an energy, the smallest of a metric length and the yard of a U.S. one;
  a value below zero is the largest unit of every table.

## The number formatter is not used as the caller set it

The one way the system does not take the caller's formatter is its **style**. It writes the value as
a plain decimal with the caller's own digits, grouping and sign, and puts the mark of the requested
style on that. Measured over 1234.5 m in en_US with the caller asking for five fraction digits and no
grouping:

| the caller's style | the formatter alone | through the formatter |
| --- | --- | --- |
| none, decimal | `1350.0492` | `1350.0492yd` |
| currency | `$1,350.05` | `¤1350.0492yd` |
| percent | `135004.92000%` | `1350.0492%yd` |
| scientific | `1.35005E3` | `1.35005E3yd` |
| spell out | `one thousand three hundred fifty point zero four nine two` | the same, spelled |
| ordinal | `1,350th` | `1,350thyd` |

So the percent style does not multiply by a hundred, the currency style writes the generic sign `¤`
and not the symbol the caller's code carries, and the scientific, spelled and ordinal forms are the
release's own transformations asked of a copy of the caller's formatter. The **ordinal is two
different numbers**: the number is the value rounded to the even one where it is a half (2.5 m is
"2nd m" and 1.5 is "2st m") and the suffix is the one of the value cut off at the point (1.64 feet is
"2st", 3.83 is "4rd", 1234.5 m is "1,350th", a million is "621st"), and it is grouped whatever the
caller asked for.

## What is not reproduced, named so it is not mistaken for agreement

- **The unit names in any language but English.** The port answers the English name, and in a locale
  that writes its own the digits, the unit chosen, the plural shape and the two-unit structure are
  the system's and are compared; the text of the name, and the space its unit pattern puts before it
  (German "0 mm" where English writes "0mm"), are that locale's data. Measured over the twelve locales
  `tests/backports/host/unitformat` runs, every one of which is green. `tests/backports/host/unitformat`
  says so in its own header and compares the two ways.
- **A `numberStyle` outside the seven the header names.** The system has a fallback table of its own
  for a value it does not know: style 9 writes "1,350.05 (unknown currency)", style 8 writes
  "XXX 1350.049" and style 7 writes a clock. None of the three is reproduced, and the differential
  sweeps the seven the header names.
- **A unit value outside its enumeration, in a locale that writes its own names.** A value outside
  the enumeration is a programming error and the system's own name lookup for it comes back
  unresolved, and the system writes the key of that lookup out rather than refusing. **That is now
  matched, not stated**: `(null)_NARROW_ONE_UNKNOWN` and its five siblings, one for each width and the
  plural, for the two name methods, and the name of the gram-force for a written value — "0Gs", "1G",
  "-1G" in the short style, "0 G" in the medium, "0 g-force" in the long. Two things are still the
  locale's own and are the limit above: the plural category in the key, which in Arabic is one of
  ZERO, ONE, TWO and OTHER and in Japanese is always OTHER, and the narrow form's plural suffix,
  which en_US and en_CA write and en_GB, en_AU, en_001 and de_DE do not — a fact that neither the
  system of units nor the language predicts, so the U.S. form is carried and the differential takes
  that one suffix off both sides everywhere else while holding the U.S. to it exactly.

## Not built yet

`NSMeasurementFormatter` (iOS 10.0) and `NSDateIntervalFormatter` and
`NSPersonNameComponentsFormatter` are the other three classes of this group and are not here.
`NSMeasurementFormatter` needs a name for every unit the port's own `NSUnit` carries, about 170 of
them, of which the short style is the symbol the release's own `NSUnit` already holds, so what is new
is the medium and the long names.
