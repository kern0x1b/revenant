# The channel moves of vImage: permute, extract, overwrite - iOS 7.0, 8.0 and 16.0

Twelve functions in `Accelerate/vImageChannels7.m`, `vImageChannels8.m` and `vImageChannels16.m`, held
against the host's own vImage case by case by `tests/backports/host/vimagechannels`:

```
sh tests/backports/host/vimagechannels/run.sh
```

**The host is the oracle for this family and it is a good one.** Every one of these functions is a data
movement - a reorder, a copy of one run, a fill - so there is no rounding to disagree about and no value to
be within a tolerance of. A wrong channel order, a wrong mask bit, a wrong width, a wrong refusal or a write
one byte past the destination's own width is the whole space of possible mistakes, and the differential asks
for all five.

**Every expected destination in the differential is computed there, from Conversion.h's own statement,
before the host is asked**, by loops written in that file and not by calling the port's; then the host's
answer and the port's are each compared against it. The padding of every row is filled with a guard and
compared afterwards, so a destination written past its own width is a difference rather than an invisible
overrun. Two runs of the case suite: `889 checks, 0 failures`, and the same under AddressSanitizer,
`891 checks, 0 failures`.

## The refusal is in the object, and keeping it there took a measurement

**Every function of this family declares its buffers `VIMAGE_NON_NULL`, and clang assumes such a parameter
is non-null *inside* the function.** So the refusal the release makes - measured above, `kvImageNullPointerArgument`
for a NULL source, destination or map - is folded away at `-Os`. Not "could be": built for armv7-apple-ios6.0
at `-Os` with the package line, `vImagePermuteChannels_ARGB16F` contained **no compare against zero at
all**, and the map was dereferenced straight through (`ldrb r6, [r2, r3]`). The front end says so itself:
`warning: nonnull parameter 'permuteMap' will evaluate to 'true' on first encounter [-Wpointer-bool-conversion]`.

Four spellings of the same test were built at `-Os` and read in the disassembly:

| spelling | the compare |
| --- | --- |
| `if (!pointer)` on the parameter | gone |
| the same inside a `__attribute__((noinline))` helper | gone - LLVM infers nonnull from the call site |
| the same on a one-element array the parameter is stored into | gone |
| **the same on a `volatile` copy of the parameter** | **there** |

because the attribute is an assumption about a *value* and a volatile read is a memory access the optimizer
has to honour. That is what `RevenantChannelsIsNull` is, and every NULL test of the three files goes through
it. **No pragma is involved and none could be**: `-Wnonnull` and `-Wpointer-bool-conversion` are warnings, so
suppressing them would silence the diagnostic that names the folded test without bringing the test back.
The three files now carry no `#pragma` at all - `-Wunguarded-availability-new` was already off on the
package's own line, and the other two were hiding this.

`tests/backports/host/vimagechannels/run.sh` builds the port's objects **with the package line**, not with
clang's default optimisation, so every case runs against the arithmetic the bands link, and it prints the
diagnostics per object:

```
vImageChannels7.m      errors=0 warnings=0, with the package line
vImageChannels8.m      errors=0 warnings=0, with the package line
vImageChannels16.m     errors=0 warnings=0, with the package line
```

The red control is the same script with the NULL test removed from scratch copies of the three files, and
what it shows is worth stating exactly, because the red is not the shape one would guess: with the test
gone the port dereferences the pointer, so **the run ends on a signal** rather than printing a mismatch -
which is the release's own behaviour on three of these inputs, and what the test exists to prevent. The
script asserts its own target before planting it (a `str.replace` on a missing needle is a silent no-op) and
fails if the planted run is clean:

```
$ PLANT='if (RevenantChannelsIsNull(src) || RevenantChannelsIsNull(dest))
        return kvImageNullPointerArgument;' sh tests/backports/host/vimagechannels/run.sh
planted: removed 3 occurrence(s) of the NULL test
PLANT: the control holds - without the NULL test the run ends on a signal (exit 139),
```

and the same script unplanted is `889 checks, 0 failures`.

## The bit order, and which way round the mask is

Conversion.h's own pseudocode for the masked insert is

```
uint8_t mask = 0x8;
for (int i = 0; i < 4; i++) { result[i] = srcPixel[permuteMap[i]]; if (mask & copyMask) result[i] = backgroundColor[i]; mask = mask >> 1; }
```

so the mask is tested from the top bit down and **a set bit copies the given pixel in**. Measured over all
sixteen masks on three widths, the host answers that and not the other way round; the first version of
`RevenantChannels.h` had the sense the other way up and the run said so at every mask.

The overwrite with a pixel is written differently, and its prose points the other way:

```
// Set up a uint32_t mask - 0xFFFF where the pixels should be conserved
destRow[x] = (srcRow[x] & mask) | the_pixel;
```

Read as a word, that puts the overwrite on the opposite sense from the masked insert. **It is not what the
host does.** Measured:

```
     vImageOverwriteChannelsWithPixel_ARGB16U, copyMask 0x0: the host conserves every run of the source
     vImageOverwriteChannelsWithPixel_ARGB16U, copyMask 0x8: the host writes the pixel's alpha, conserves the rest
     vImageOverwriteChannelsWithPixel_ARGB16U, copyMask 0xF: the host writes all four runs of the pixel
```

which is the masked insert's own sense - the parameter is commented "Copy plane into 0x8 -- alpha" in both -
so the two functions of the family agree and the sentence about "0xFFFF where the pixels should be
conserved" is read as prose about a word, not as the rule. The port does a run at a time rather than a word
at a time, because a channel taken from the source and a channel taken from the pixel never share a word.

## A copyMask has no range, and the flag word differs per function

Both are measured over the whole input rather than taken from a neighbour, and both are cases the tree's
other vImage files would have answered differently.

**The copyMask.** Conversion.h names `kvImageInvalidParameter` for a mask above `0x0F`, in both the masked
insert and the overwrite. Asked of the host over twelve values - `0x00 0x01 0x08 0x0F 0x10 0x11 0x1F 0x20
0x40 0x80 0xF0 0xFF` - it answers `kvImageNoError` for **every one of them** and writes the same bytes
above `0x0F` as for `0x0F`, so the bits outside the four channel bits are carried and ignored. The first
version of the port refused a mask above `0x0F` on the strength of the header sentence and was wrong; the
differential's mask survey prints all twelve values with both codes and compares the bytes for each.

**The flag word**, asked one bit at a time over all thirty-two, for every function of the family. The
accepted sets are not one set:

| function | bits the host accepts |
| --- | --- |
| `vImagePermuteChannels_ARGB16U`, `_ARGB16F`, `WithMaskedInsert_ARGB16U`, `_ARGB8888`, `_ARGBFFFF` | `0x10` `kvImageDoNotTile`, `0x80` `kvImageGetTempBufferSize` |
| `vImagePermuteChannels_RGB888` | the same two |
| `vImageExtractChannel_ARGB16U`, `_ARGBFFFF` | the same two **and** `0x100` `kvImagePrintDiagnosticsToConsole` |
| `vImageOverwriteChannelsWithPixel_ARGB16U`, `OverwriteChannelsWithScalar_Planar16U`, `_16S`, `_16F` | **every one of the thirty-two bits** |

Everything else is `kvImageUnknownFlagsBit`. So the shared check in each file takes the measured set as a
parameter and each group passes its own: one constant for the file was wrong for six of the twelve
functions. The two fills and the pixel overwrite having no flag refusal at all is worth naming, because
their headers list two or three flags and `kvImageUnknownFlagsBit` for anything else.

## Three places the release dies on an input and the port refuses

Each of these is asked of the host **in a child process**, because a host that ends on a signal would
otherwise take the differential down with it and the measurement would be worth nothing:

```
     vImagePermuteChannels_RGB888 with a NULL map: the host's own process ended on a signal
     vImageOverwriteChannelsWithPixel_ARGB16U, a NULL destination: the host died on a signal, and the port answers -21772
     vImageOverwriteChannelsWithScalar_Planar16U, a NULL destination: the host died on a signal, and the port answers -21772
     vImageOverwriteChannelsWithScalar_Planar16F, a NULL destination: the host died on a signal, and the port answers -21772
```

The first is the sharpest one, because **this header's own comment says the opposite**:

> permuteMap[3] = {0, 1, 2} **or NULL** will produce the same dest pixels as the src

The host dereferences the map. So the port answers `kvImageNullPointerArgument` for a NULL map here, as it
does for the four-channel forms: a caller passing NULL has a bug either way, and a refusal is the answer
that is the same on both sides. The other two are the same shape - the port answers
`kvImageNullPointerArgument` where the release has no answer to give. This is a named divergence, not a
silent improvement: the port survives three inputs the release does not.

## The refusals the release does answer, all measured

```
     vImagePermuteChannels_ARGB16U, a NULL source:            host -21772, port -21772   (kvImageNullPointerArgument)
     vImagePermuteChannels_ARGB16U, a NULL destination:       host -21772, port -21772
     vImagePermuteChannels_ARGB16U, a NULL map:               host -21772, port -21772
     vImagePermuteChannels_ARGB16U, a map value of 4:         host -21773, port -21773   (kvImageInvalidParameter)
     vImagePermuteChannels_ARGB16U, a map value of 255:       host -21773, port -21773
     vImagePermuteChannels_ARGB16U, a destination wider:      host -21766, port -21766   (kvImageRoiLargerThanInputBuffer)
     vImagePermuteChannels_RGB888, a map value of 3:          host -21773, port -21773
     vImageExtractChannel_ARGB16U, a channel index of -1:     host -21773, port -21773
     vImageExtractChannel_ARGB16U, a channel index of 4:      host -21773, port -21773
     vImageExtractChannel_ARGB16U, a destination wider:       host -21766, port -21766
     vImagePermuteChannelsWithMaskedInsert_ARGB16U, a map value of 4: host -21773, port -21773
```

The channel index is a `long` and is tested on the value, so -1 is a refusal and not a wrapped 3.

## In place, and what each case proves

Every one of these functions is documented to work with `src->data == dest->data`, so the differential runs
the whole permute case a second time with one buffer on both sides, over the same five maps - the identity,
`3,2,1,0` (ARGB to BGRA, the one the header names), two pair swaps, and a map that takes every run from
channel 0. The engine reads a whole source pixel into local storage before it writes any of it; writing run
0 before reading run 1 would be correct only for a map that leaves run 0 alone, and `3,2,1,0` is in the
corpus.

The maps are chosen so that a **transposed slot table cannot pass**: `1,0,3,2` and `2,3,0,1` move channels
across halves, and `0,0,0,0` makes every destination run the same source run, so a port that read the wrong
slot for any channel differs at the first pixel of the first row.

## The release ladder

`minimum: 4.3` on every row, the convention every implemented Accelerate row follows, and `introduced` as
the corpus measured it from the held caches' export trie: five names at 7.0, five at 8.0, two at 16.0 -
which is why the family is three object files and not one. Nothing here needs a declaration the port's headers add: the
16.4 SDK's own `Conversion.h` declares all twelve, and the two pixel types the 26.2 header spells
`Pixel_8888` and `Pixel_FFFF` are the 16.4 header's names for the same shapes (`vImage_Types.h:274` and
`:281`). The first version of the port spelled them `Pixel_ARGB_8888` and `Pixel_ARGB_FFFF`, which are
**not** types in either SDK - it did not compile, and the compile line is what said so.

## Half-precision needs no arithmetic here, and that is the argument

`vImagePermuteChannels_ARGB16F` and `vImageOverwriteChannelsWithScalar_Planar16F` would want
`RevenantVImageFixed.h`, the header this library uses where a half is computed and has to be rounded. Neither
of these computes one: a permute moves sixteen bits and a fill copies sixteen bits, and a half that is
copied is the same half it was. So the sixteen bits move as sixteen bits, the differential compares them as
bits, and the fill case uses the value `0x1234` - a half NaN - which a port that converted it to a float and
back would not reproduce.

## How to run this

```
sh tests/backports/host/vimagechannels/run.sh
```

The renames the port's translation units are built with come from the three registry files, read out of the
rows themselves, so a name added to the library is renamed too.