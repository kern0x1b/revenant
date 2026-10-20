# CMVideoFormatDescriptionGetH264ParameterSetAtIndex and CMVideoFormatDescriptionCreateFromH264ParameterSets

## CMVideoFormatDescriptionGetH264ParameterSetAtIndex

Introduced in iOS 7.0. iOS 6 has CMVideoFormatDescription and the `avcC` sample description atom, so the function reads the parameter sets from the atom of the description.

- A description that is NULL, is not video, is not `avc1` or has no `avcC` atom answers -12710 and leaves every output as it was.
- Otherwise every output is zeroed first; a record shorter than 6 bytes or of a version other than 1 answers -12712.
- The NAL unit header length is `(byte 4 & 3) + 1`, and is all that is read when it is the only output asked for.
- The sets are the SPS group, the PPS group and, for profiles 100, 110, 122 and 144 when bytes remain, the extension group, numbered in that order.
- The pointer and size are set when the index is met and the call ends there when no count is asked for; the count is set only when the whole record parsed; an index not below the count answers -12712.

The behaviour was found by putting generated descriptions, records cut at every length and records with trailing bytes to the host's CoreMedia, over six indexes and all sixteen combinations of outputs, and holding the port to it: tests/backports/host/coremedia.

## CMVideoFormatDescriptionCreateFromH264ParameterSets

Introduced in iOS 7.0: the armv7 cache ladder first exports it at 7.0, and 6.1.3 exports
`CMVideoFormatDescriptionCreate` and every key and chroma location value the description holds.
The function builds the `avcC` record and the extensions and hands them to
`CMVideoFormatDescriptionCreate` with the dimensions.

Checks, in this order, the first failure answering:

- No output pointer: -12710. Fewer than two sets, no pointer or size array, or a NAL unit header
  length other than 1, 2 or 4: -12712.
- Each set in the order given: an empty or null set, the forbidden bit set, `nal_ref_idc` 0, or a
  type other than 7 (SPS), 8 (PPS) and 13 (SPS extension): -12712. The first field it cannot read
  (`profile_idc`, the constraint flags, `level_idc` and `seq_parameter_set_id` of an SPS, and for
  profiles 100, 110, 122 and 144 `chroma_format_idc` and both bit depths; the identifier of a PPS
  or an extension): -12714. An SPS of those four profiles whose chroma format or bit depths differ
  from the first such SPS: -12712.
- No SPS or no PPS: -12712.
- Every SPS is then parsed whole. An `ue(v)` code of more than 12 leading zeros (a value above
  8190, and for an `se(v)` one outside -4095 to 4095) fails the parse, except the bit rate and buffer
  size values of the HRD. This holds for the three offsets of `pic_order_cnt_type` 1 as well, although
  H.264 7.4.2.1.1 gives them -2^31+1 to 2^31-1: the host takes 4095 and -4095 and refuses 4096, -4096,
  8190, 100000 and 2^31-1 in each of the three (`host/coremedia/create.m`), and a reader that took 31
  zeros there differed from the host in all 30 such cases. The last SPS in the
  order given that fails: -12710; an earlier one that fails is left out. The SPSs that parse must
  have the same dimensions: otherwise -12710. A dimension of exactly 0 fails; a crop larger than the
  picture gives a negative dimension, which the host passes on and so does the port.

The record:

- Profile the largest `profile_idc`, compatibility the AND of the constraint bytes, level the
  largest `level_idc`, the length size, then the SPSs and the PPSs, each sorted by its identifier
  with the order given kept between equal ones, byte for byte as given.
- For profiles 100, 110, 122 and 144 the chroma format, both bit depths and the extensions follow;
  for any other profile the extensions go into the SPS list, sorted with the SPSs.

The extensions come from the first entry of the record's SPS list, parsed again; when it does not
parse, only the two chroma locations remain, both `Left`:

- `CVFieldCount` 1 when `frame_mbs_only_flag` is set, absent otherwise.
- Chroma locations from `chroma_sample_loc_type` 0 to 5 as `Left`, `Center`, `TopLeft`, `Top`,
  `BottomLeft`, `Bottom`, absent from 6 up, `Left` for both without VUI chroma location; top and
  bottom both 2 answer `Center` for both.
- With VUI: `FullRangeVideo` from the video signal type, false without it; `CVPixelAspectRatio`
  for `aspect_ratio_idc` 1 to 16 from the table of the standard, for 255 from the two values when
  neither is 0, not reduced; colour primaries, transfer function and matrix through
  `CV*GetStringForIntegerCodePoint` of GraphicsBackports (code points 0 and 2 give nothing).
- Width `16 * mbs - unit * (left + right)`, height `16 * units * (2 - frame_mbs_only) - unit *
  (top + bottom)`, the units 2 and 2 for 4:2:0, 2 and 1 for 4:2:2, 1 and 1 for 4:4:4, the vertical
  one doubled for fields, and no crop at all for monochrome. Profile 144 is parsed as having no
  chroma format syntax, the way the host parses it, though its `avcC` tail is written.

Measured by `tests/backports/host/coremedia`, which holds the port against the host's CoreMedia on
16245 cases, 0 different: the parameter sets the host's H.264 encoder writes for three profiles,
eight sizes and both ranges, in their own and the reversed order; every colour code point, aspect
ratio code and chroma location pair; generated SPSs over the whole syntax, each also cut short and
with one bit flipped; and generated sets of up to three SPSs, three PPSs and an extension.

Where the port and the host differ, both named:

- Matrix code points 14, 15 and 248 give `ITU_R_2100_ICtCp`, `IPT_C2` and `IPT` on the host and
  `YCbCrMatrix#14`, `#15`, `#248` in the port, whose code point tables are iOS 12's
  (`facts/CoreVideo/CVCodePoints.md`); the test fails if that ever stops being so.
- A set whose SPS that is not the last one fails to parse partway: the host's answer then depends
  on where the parse stopped in a way this port does not reproduce. Other seeds of the same
  generator find up to three such sets in 16149 cases, all of this kind; no encoder writes them.
- The host is a current macOS. The code point strings for 9, 11, 12, 16 to 18 and the `#` strings
  are later than iOS 7, whose own function this port stands in for; the port answers as a current
  system does.
