# CIColor's colour space and its named colours, carried for iOS 6

14 rows, `registry/CoreImage/colors10.json`.

iOS 6 has a `CIColor`. What it does not have is a way to name the colour space a colour was measured
in, nor any of the named colours — the release's CoreImage has neither `redColor` nor `clearColor`, and
the class properties and the colour-space initialisers arrived in iOS 10.

The components of a colour given in a space are that colour as the space sees it, so a colour named in
a space is built by matching it into the space the renderer works in, which is what CoreGraphics does
with a colour and a space. What comes back is the framework's own `CIColor`, so it is a real colour
object and every method `CIColor` already has works on it. The named colours are the primaries and
neutrals of the sRGB space, each built through the colour-space initialiser — so they are the colours
that initialiser makes rather than a second table of numbers — and each is made once and kept.

## What the pixel probe measured

`tests/backports/host/ciimage/pixel/`: forty colour cases, each asked through both colour-space
initialisers, both class methods and both no-alpha spellings, in sRGB and in the generic RGB space,
at two alphas, plus the ten named colours each asked twice so a cached one and a made one are the same
answer. For each, the number of components, the four numbers the colour holds, and the length and
checksum of the bytes an image of that colour renders to.

**`ciimage: 388 measurements, 388 the same, 0 different, 0 one side only`**, at a tolerance of 5e-4.
Every component and every rendered pixel matches, in both spaces and at both alphas.

**That was true when it was written and it is no longer, and the number below is the tree's.**
`tests/backports/host/modelio/compare.py` read only the first number of a line, so a line was the same
whatever followed it; it now reads the number and the whole rest of the line. Over the run the tree
makes today, the colour family has

    ciimage: 527 measurements, 479 the same, 40 different, 42 one side only (tolerance 0.0005)

and **no line of it is a colour any more**: the six that were differences were
`+[CIColor colorWithRed:green:blue:colorSpace:]` and its siblings in a space that is not sRGB, where
the port's accessors answered a converted component - a green the caller passed as 0.0000 came back
0.1491 - and `d63a8af20` fixed that by keeping the caller's components in the caller's space. All ten
named colours were byte-identical throughout, and the rendered pixels of the non-sRGB colours are
`0 811c9dc5` on both sides. The remaining forty belong to the other pages, and
`facts/CoreImage/Differences.md` groups all of them.

## What is not measured

- Nothing has run on a device or under `xmake emulate`.
- The `colorSpace` a `CIColor` answers is the one it was made with — the space the renderer works in —
  because the colour is a `CGColor` matched into it. A caller that names a space and reads it back gets
  the space the colour lives in, which is what the pixels are, rather than the name it gave. The header
  does not say which the framework answers; the probe did not ask, and this file says so rather than
  implying the question is settled.
