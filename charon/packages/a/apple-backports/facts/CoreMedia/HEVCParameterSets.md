# The HEVC parameter sets of iOS 11 on a release that has no reader for them

iOS 6 stores the `hvcC` record the way any HEVC stream does and exports the description that holds it;
what it does not have is the function that walks that record. This is the iOS 11 reader, and its oracle
is a real one: the `hvcC` of an `ffmpeg`/`libx265` stream, kept at
`.agent-work/plan-and-analysis/coremedia-avf/hvcC-x265.bin` - 2428 bytes, `numOfArrays` 4, level idc 30,
and the arrays are a 23-byte VPS (NAL type 32, starting `40 01 0c 01 ff ff`), a 43-byte SPS, an 8-byte PPS
and x265's 2307-byte prefix SEI. The NAL units carry **no** length prefix, which is what this function
returns.

## The record, as measured

`numOfArrays` is byte 22, after a 23-byte fixed part. Each array is a type byte
(array_completeness, reserved, `NAL_unit_type`) and a 16-bit count of NAL units; each NAL unit is a 16-bit
length and that many bytes. `NALUnitHeaderLength` is `(byte 21 & 3) + 1`, which is 4 for the x265 record.

## The answers, all measured against the host's own reader

`tests/backports/host/coremedia7/hevcreader.m` asks both readers the same question over the real record,
**every one of its 2428 truncations**, 64 single-byte flips of it, a flip of byte 0 and of byte 12, a null
description and a JPEG one: **7544 answers, none different.** It is built with AddressSanitizer, because
a reader that walks off the end of a record is the bug this test exists for.

Four things the header does not say, each of which the differential found:

- **A call that asks for neither the pointer nor the size is answered 0 whatever index it is given.** The
  x265 record has four NAL units, and index 7 with only the count asked for is `0` with the count 4. The
  same rule the H.264 reader in `CMVideoFormatDescription7.m` already carries.
- **The `-12710` path writes no out-parameter at all** - not a null pointer, not a zero size, nothing.
  A caller that passed a pointer and a size and got `kCMFormatDescriptionError_InvalidParameter` has both
  still as it left them.
- **A record the walk cannot finish is refused even when the index asked for was already reached.** A
  record cut after the first NAL unit answers `-12712` with that unit's 23-byte size filled in and the
  pointer handed back, which is the one case where the host both answers and refuses.
- **A record whose `configurationVersion` is not 1 is refused**, and so is one shorter than the whole
  23-byte fixed part - for which the host reports no `NALUnitHeaderLength` either, though it does report
  the header for a record long enough to hold the fixed part and cut later.

A record that walks reports the number of NAL units its **array headers** declare, not the number it
walked: the x265 record declares 4 and walks 4, and a record cut after the first unit declares 1, walks 1
and reports 0.

## Where the SIGSEGV was

Not the version check, and not a 0-byte record: it was in the differential. It initialised the two
out-pointers to the sentinel `(const uint8_t *)0x1`, which is fine while a reader always writes them -
and the `-12710` path does not, by the rule above, so the test's own `memcmp` read from address 1. The
sentinel is now `NULL` and the byte comparison only runs when the reader returned 0 and really wrote a
pointer.

## Reuse

Searched: none, and the search is named so it can be repeated. The 2026-09-28 rule's upstream table has
no CoreMedia row and Apple's CoreMedia is not open-sourced, so there is no reference reader to take.
The one external thing this family touched is a **byte record**, `hvcC-x265.bin`: the `hvcC` box of a
stream `ffmpeg` encoded with `libx265`, from the three-frame `testsrc` pattern. That is a data record
from a media file, not libx265's code, so the GPL "read only" rule is not in play; ffmpeg and libx265
were run, not read. Every behaviour in the two HEVC functions is measured against the host's own
CoreMedia, 7544 answers, none different.
