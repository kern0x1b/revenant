# Code points of a video colour description, iOS 11 and 12

CoreVideo 11.0 made public the six functions that turn the strings of a colour
description into the integer code points of ITU-T H.273 and back, and 11.0 and
12.0 added the constants below.

Source: CoreVideo of the arm64 shared cache of iOS 12.0 - the functions at
`0x18428d738` (primaries to string), `0x18428d5a4` (string to primaries),
`0x18428da58` and `0x18428d894` (transfer function), `0x18428d370` and
`0x18428d23c` (matrix), the helper that makes the strings of the code points
nothing names at `0x18428d514`, and the strings the constants hold, read from
their slots. An iPad 2 running 6.1.3 for what the release has. The host's
CoreVideo through `tests/backports/host/graphics11`.

## Code to string

The tables are the release's own. 0 and 2 (reserved and unspecified) answer `NULL`.

- Primaries: 1 `ITU_R_709_2`, 5 `EBU_3213`, 6 `SMPTE_C`, 9 `ITU_R_2020`,
  11 `DCI_P3`, 12 `P3_D65`, 22 `P22`.
- Transfer function: 1, 6, 14 and 15 `ITU_R_709_2`, 7 `SMPTE_240M_1995`, 8 `Linear`,
  13 `IEC_sRGB`, 16 `SMPTE_ST_2084_PQ`, 17 `SMPTE_ST_428_1`, 18 `ITU_R_2100_HLG`.
- Matrix: 1 `ITU_R_709_2`, 6 `ITU_R_601_4`, 7 `SMPTE_240M_1995`, 9 `ITU_R_2020`.

Any other code point, a negative one included, gets a string made from the name of
the table and the code, `ColorPrimaries#7`, `TransferFunction#5`, `YCbCrMatrix#-1`,
which the release makes once and keeps in a dictionary of its own; the same code
point gives the same object. The package does the same, with a lock around the
dictionary.

## String to code

The strings are compared for equality with the names above, and the answer is the
code point of the row: `ITU_R_709_2` 1, `UseGamma` 2 (transfer), `ITU_R_2020`
(transfer) 1, `EBU_3213` 5, and so on. A string that starts with the table's
prefix and `#` is read back: the rest of the string goes through
`CFStringGetIntValue`, so `ColorPrimaries#7` is 7, `ColorPrimaries#12abc` is 12,
`ColorPrimaries#x` and `ColorPrimaries#` are 0. Every other string, `NULL`, and
anything that is not a string answer 2.

## Where iOS 12 is narrower than the newest CoreVideo

The host's CoreVideo, which is far newer, names three matrix codes iOS 12 does
not: 14, 15 and 248. The package follows iOS 12: `YCbCrMatrix#14`,
`YCbCrMatrix#15` and `YCbCrMatrix#248`, and the newer names read back as 2. The
differential test leaves those three codes out of the comparison and checks what
iOS 12 answers instead.

## Constants

`kCVImageBufferTransferFunction_sRGB` is `IEC_sRGB`,
`kCVImageBufferTransferFunction_ITU_R_2100_HLG` is `ITU_R_2100_HLG`,
`kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ` is `SMPTE_ST_2084_PQ`,
`kCVImageBufferTransferFunction_Linear` (12.0) is `Linear`,
`kCVImageBufferContentLightLevelInfoKey` is `ContentLightLevelInfo`,
`kCVImageBufferMasteringDisplayColorVolumeKey` is `MasteringDisplayColorVolume`,
`kCVPixelFormatContainsGrayscale` (12.0) is `ContainsGrayscale`. None of these symbols is there on 6.1.3, which the build's own check of the
library against that release's exports shows for every one of them; the package
attaches nothing under the two keys and describes no pixel format with the last.

`kCVMetalTextureUsage` (11.0) belongs to a Metal texture cache and is not carried.
