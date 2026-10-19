# CoreImage's barcode descriptors: what the host answers, and what this family needs

`CIBarcodeDescriptor` and its four subclasses (`CIQRCodeDescriptor`, `CIAztecCodeDescriptor`,
`CIPDF417CodeDescriptor`, `CIDataMatrixCodeDescriptor`) are 25 of CoreImage's `missing` rows - 5 classes,
8 initializers and factories, 16 properties, of which the base class carries none because
`CIBarcodeDescriptor.h:26` declares it with no member - and they are carried in
`Graphics/CIBarcodeDescriptor11.m`. The twenty-sixth row of the family,
`+[CIQRCodeFeature symbolDescriptor]`, is a member of a feature class the port does not have and belongs to
the detector family, not here.

`tests/backports/host/cibarcode/` is the differential, and what it took to write one is on this page twice:
the host's own answers and the way this port's classes can be compared with them at all.

    RENAMED: 5 names the port defines, in this build only
    COMPARED: 90 records against the host's own answers
    HOST CRASH: 2 of the 13 groups end the host with a trap, and 0 records are ones the host never reached
    BINDING: the port's renamed class answered every case above, and the host build has no port object in it
    cibarcode: 90 records compared against the host's own answers, mutation RED

## What a descriptor is: the caller's bytes, and no Reed-Solomon

The header calls the initializer's argument `errorCorrectedPayload`, gives the property the same name, and
says what those bytes are (CIBarcodeDescriptor.h:75): "During decode, error correction is applied and if
successful, the message is re-ordered to the state immediately following 'Bitstream to codeword coversion.'
The errorCorrectedPayload corresponds to this sequence of 8-bit codewords."

**So the payload is the codeword sequence, and a descriptor holds it as it is.** Measured: a descriptor made
from "abcdefgh" hands exactly those eight bytes back, in all four subclasses, through the property and through
an `NSKeyedArchiver` round trip whose keys are the header's own property names
(`dataCodewordCount, errorCorrectedPayload, isCompact, layerCount` for Aztec and so on).

This retires the premise the family was queued with. zxing-cpp (Apache-2.0) is the right reuse for a
*barcode encoder*, and this row set is not one: there is no Reed-Solomon here, no mask to choose and no
codeword to lay down, so there is nothing in zxing-cpp these 26 rows would call. What the rows do is check
their own header's ranges and keep the bytes, and the encoding is the generator filter's work -
`CIBarcodeGenerator`, which no release this port deploys has. Carrying these classes therefore does **not**
make `+[CIFilter barcodeGeneratorFilter]` render: that constructor row is already `implemented` (it hands back
the filter object by name), and what is missing is the filter's own behaviour, which is a different row set
and the one that would need zxing-cpp.

## Every range, swept whole rather than sampled

| class | the header's range | the host answers |
| --- | --- | --- |
| `CIQRCodeDescriptor` | symbolVersion 1-40, maskPattern 0-7, L/M/Q/H | **1280 of 1280** |
| `CIAztecCodeDescriptor` | layerCount 1-32, dataCodewordCount 1-2048 | **131072 of 131072** |
| `CIPDF417CodeDescriptor` | rowCount 3-90, columnCount 1-30 | **5280 of 5280**, and rows 1 and 2 answer `nil` |
| `CIDataMatrixCodeDescriptor` | no range stated | **6400 of 6400**, 1x1 and 1x40 among them |

The floors and ceilings are the header's own sentences, and the host agrees with each of them at the edge:
`pdf417 rows 1` and `pdf417 rows 2` answer `nil` while `rows 3` does not, `qr version 0` answers `nil`, and
`aztec layers 0` answers `nil`. The Data Matrix header states no range and the host has none either, so a
range check there would refuse inputs the host accepts.

## What the host does not survive, and what that turned out to be

**The host's crashes here were this harness's bug, not ImageIO's.** An earlier reading of this page said every
boundary group ends in a trap and that the host's own `CIPDF417CodeDescriptor` dies in its own dealloc. Both
were `cases.m` printing a `class_getName()` result - a `const char *` - with `%@`, which sends
`-respondsToSelector:` to a stack address where the ObjC runtime traps. With the format fixed, **twelve of the
thirteen groups survive**, and the only two that still do not are `copy` and `copy-no-pdf417`, which answer
their seven records and then abort (exit 134) inside the host's own archiving. Nothing in that last one is
compared beyond the records that were printed, and the run says so.

It is the third time this wave a probe's own format string produced a crash that read as the framework's
behaviour (the ImageIO property table's `%@` with a C string, and the `CFStringGetCStringPtr` NULL), so the
rule that came out of it is in the harness itself: a case prints with `%s` for anything that is not an
object, and a trap in a probe is the probe's answer to check before it is the framework's.

## Why the port's own object cannot be compared with the host here

The five classes carry the same names on the host and in the port, and **on macOS every process that uses
Foundation has CoreImage loaded**: `DYLD_PRINT_LIBRARIES=1` on a program that links Foundation alone prints
CoreImage arriving through `DataDetection.framework` and `AppleNeuralEngine.framework`. A port build in such
a process is a duplicate class, and the runtime's answer to a duplicate is whichever class registered first.

Taking CoreImage out of the *link* is not enough, because it is *loaded* rather than linked. What that costs
is the whole point, and it was measured rather than assumed:

- An earlier version of this harness compiled `cases.m` twice, once with the port's object and once without,
  and **both builds printed identical answers for all 140338 combinations** - because only one of them was
  running the code under test. The `dladdr` binding record in `cases.m` is what caught it.
- With CoreImage out of the link, the binding record says `port` for `-[CIPDF417CodeDescriptor rowCount]` and
  the port build still dies exactly where the host dies, which is what a selector resolved to the host's class
  looks like. One passing method is not one class answering.

So the port's object is **not** in the tree and the 26 rows stay `missing`: code that cannot be shown to
answer is worse than no code, and a registry row that claims `implemented` needs the check.

## What this family needs, which is a decision and not a measurement

1. **A way to run the port's five classes beside the host's.** The tree's own answer for a class the port
   defines and the host also has is the `Charon` prefix (`registry/Metal/ios80classes.json`'s
   `CharonMetalBuffer` and its siblings, `CharonIntentsUIHostedViewController`), which needs a decision about
   whether a renamed class is acceptable for an SDK-named class on a release that has none.
2. **Or the comparison moves off macOS.** The port's bands are the ones with no such classes, so there is no
   host there; the device route (`xmake emulate`, 6.1.3) checks the port's answers but has no oracle, which
   makes the recorded table above the oracle - which is what `host-answers.tsv` already is.
3. **Or the harness compares values instead of objects**: read the port's answers out of a process where the
   five classes are the only ones, by loading the port's object *before* Foundation (a constructor that forces
   the load), which is measurable and cheap to try.

The three are ordered by how much they cost to be wrong. Option 3 is a measurement; option 1 is a naming
decision; option 2 is a schedule.