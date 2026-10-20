# The Intents extern constants the port carries, and where each value came from

83 rows, 7 object files, and one value per name. What this page is for, and what it is not.

## The rows

Every one of the 83 is a `kind: "constant"` row in one of the five Intents registry files, status
`implemented`, minimum 6.0. The ledger's reason for all of them is one sentence, and it is the reason
this slice exists:

> declared extern in the lifted headers and there is no such symbol in the built libraries or the
> 6.1.3 cache — the port has to export it

So this is not a row the port declines: the header names the symbol, the release has no such symbol,
and a program that links against the port and reads the name finds NULL. Carrying it is the point.

The rows are read out of `coordination/corpus/ledger/Intents.tsv` with `csv.DictReader` and a tab, on
`kind == "constant"`, `status == "missing"` and `"code" in needs` — the header names the columns, so
no row is addressed by its number.

## The values, and this is the part that matters

**Every value was read out of the host's own Intents at runtime**, not spelled from a header:
`dlopen("/System/Library/Frameworks/Intents.framework/Intents", RTLD_LAZY)`, `dlsym` the name, and
the `NSString *const` dereferenced once. A value is what the system holds. The three names the
differential reports as an example:

```
INCancelWorkoutIntentIdentifier            INCancelWorkoutIntent
INCarChargingConnectorTypeCCS1            com.apple.intents.CarChargingConnectorType.CCS1
INIntentErrorDomain                        IntentsErrorDomain
INPersonHandleLabelMain                    com.apple.intents.PersonHandleLabel.Main
```

`tools/intents/emit-intents-constants.lua` writes the port's objects from that dump and refuses
rather than guesses: a name with no value in the dump, or a value with a quote or a newline in it,
stops the run and writes nothing for that name.

## The files, and why there are seven

One object per release rung, `IntentsConstants<NN>.m`, holding only the names that rung first
appeared in — 10.0 (26), 10.2 (38), 12.0 (3), 13.0 (3), 14.0 (9), 16.2 (2), 17.4 (2). The split is the
same one `AVFoundation/MetadataKeyspacesNN.m` uses and for the same reason: `backports.lua`'s `band()`
raises on an object mixing a name a band already exports with one it does not, and a single-band
6.1.3 gate cannot see that, so an object must not mix rungs.

## The differential, and what it does not check

`tests/backports/host/intents/constants.m` reads all 83 out of two builds in one process: the port's
objects, and the host's Intents for the same names. It compares **text**, and it compares the port's
value against the value the table records as well, so a table that drifts from the system is caught
separately from an object that drifts from its table.

**It asks which IMAGE answered, and that is not decoration.** `/System/Library/Frameworks/Intents
.framework` exports these names too, so a `dlsym` that took the framework's own would compare the
framework with itself and pass. That was not a theoretical worry — the first build of this check,
with the port's objects left out of the link, printed:

```
constants: 83 lines, 0 red  ->  PASS
```

and only `dladdr` on the answer, refusing one from `/System/Library/Frameworks/Intents.framework`,
turned it into what a check has to be:

```
the port's objects absent:   83 lines, 83 red  ->  FAIL
one object of the seven out: 83 lines,  2 red  ->  FAIL   (the 2 it held)
the plant:                   83 lines,  1 red  ->  FAIL   (INAnswerCallIntentIdentifier)
the port's objects present:  83 lines,  0 red  ->  PASS
```

Three ways red, one green, and the green is the one where all seven objects are linked.

## What is not proven here

The values are the system's, measured on the host's own framework. **Nothing runs the port's
constants**: they are armv7 iOS 6.1.3 objects and the differential links them beside the host's
framework in a host build, so what is compared is the emitted text against the system and the object's
symbol against the table. That the value survives into a linked 6.1.3 binary is the release-split and
link step's job, not this page's, and it is `gates: coordinator`.
