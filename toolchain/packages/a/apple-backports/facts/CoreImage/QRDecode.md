# QR decoder (RevenantQRDecode.c): what the host measures, and what stays open

The decoder is `Graphics/RevenantQRDecode.c` (ISO/IEC 18004, plain C, no CoreImage). It reads a grid of modules and returns
the message bytes and the mode. Its differential test is `tests/backports/host/ciqr/run.sh`: the host makes the codes with
CIQRCodeGenerator, the grid is read from the pixels, and the decoder's message is held to CIDetector's messageString.

## Measured on the host (macOS, CoreImage of this SDK)

- CIQRCodeGenerator at one pixel per module: the output extent is the module grid plus a one-module quiet zone on each
  side (version 1 gives 23 x 23). The symbol is the dark bounding box of the render: its outer ring is dark on all four
  sides, so the box is exactly the modules.
- CIDetector answers messageString for the generated image scaled 8x: one feature for every code the test makes.
- messageString for the byte payload is UTF-8 when the bytes are valid UTF-8, and ISO Latin-1 when they are not:
  `68 e9 6c 6c 6f` gives "h" "e-acute" "llo", `ff fe` gives the two Latin-1 characters, and `c3 28` gives "A-tilde (".
- A byte 0x01 in the payload is absent from messageString ("a" 0x01 "b" gives "ab"). The test corpus has no control
  characters, so this is not compared; it is a known difference.
- The generator chooses the numeric and alphanumeric modes from NSData content: the decoder reports mode 1 and 2 for the
  digit and character sets, and mode 4 for the rest.

## What the decoder reads

Numeric, alphanumeric and byte segments, any count of them in one symbol (the mode is then RevenantQRModeMixed). Versions
1 to 40, all four levels: 280 host cases (5 kinds x versions 1, 2, 7, 10, 25, 40 x four levels, with damage; and byte,
clean, versions 1 to 40 x four levels) decode to the host's text.

Damage (measured with a fixed seed): flipping ec/2 modules in the lower-right region (rows and columns 9 and up) still
decodes; flipping a quarter of the modules fails with an error and no text.

## Open

- Kanji, ECI, FNC1 and structured append: the decoder returns RevenantQRDecodeUnsupported. Not read.
- symbolDescriptor (CIQRCodeDescriptor): not carried out. Known difference 1 in Features.md stays.
- Six clean codes at level L (byte, versions 23, 27, 35, 36, 37, 38) decode to the host's text only through Reed-Solomon
  correction: every block has one or two codewords among the first stream codewords that disagree with the syndromes,
  and the correction restores the text. Measured on the first codewords of each block; the cause is not settled. Either
  the host's generator writes those codewords off the standard, or the decoder reads them from a module it should not.
  The flipped-correction control trips on exactly these six. Which of the two settles it: a second, independent encoder's
  codewords for version 23 level L against the grid.
- The detector hook (CIDetector to this decoder) is the next band's.
