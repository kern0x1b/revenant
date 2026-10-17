# Names of ImageIO that iOS 7 to 12 added

Constant strings of the framework: the keys of the property dictionaries of images, the dictionaries of the makers and formats (Apple, HEIF, HEICS, DNG and the rest), and the keys of the options of an image source and destination.

Source: ImageIO of the arm64 shared cache of iOS 12.0, where each constant is a string and its text was read; the header of iOS 16.4 for the type and the release that added each name;
an iPad 2 running 6.1.3 and the iOS 6.0 emulator, asked with `dlsym`, which export none of them.

## Where iOS 6 differs

iOS 6 exports none of these names, and an application that names one is not loaded at all. They are carried, each with the text the newer release gives it, so that an application
that names one loads, as it does on a release that has them. Nothing of iOS 6 produces, reads or posts the string under that name: a key is never found in a dictionary the release makes, a notification
is never posted, and a value an application hands to the release is treated as the release treats any string it does not know, which the release answers as its own code does. An application that
checks whether a feature exists before it uses it (a codec, a capture device type, a key algorithm, a metadata dictionary) gets the answer of the release for that feature, not for the name.

## The 46 names of iOS 10.0.1 to 26.0, and why each one is its own object's band

Added in this pass, in six objects of the same family: `ImageIONames1001.m` (4), `ImageIONames134.m` (2),
`ImageIONames160b.m` (1), `ImageIONames174.m` (2), `ImageIONames180.m` (25) and `ImageIONames260b.m` (12).

The band of a name is the release whose own caches first export **the symbol**, measured with
`tools/cache-index/first-rung.lua` over the 50 held rungs — an object carries API that arrived in one release,
and this family exports real `const CFStringRef` variables, so release-split and `check_releases` both see
this one and measure it themselves. Where no held rung carries the symbol — the ladder ends at 10.3.4, so
nothing above 10.3.4 is placed by measurement — the name's own `IMAGEIO_AVAILABLE_STARTING` annotation places
it, and the facts say so in the object.

Two of those placements are worth naming, because they are not the annotation:

- `kCGImagePropertyBCEncoder` and `kCGImagePropertyBCFormat` are annotated iOS 12.0 and their symbols first
  appear in a held rung at iOS **13.4**, so they are a 13.4-band object (`ImageIONames134.m`) and not a 12.0 one.
- `kCGImagePropertyASTCBlockSize`, `kCGImagePropertyASTCEncoder`, `kCGImagePropertyEncoder` and
  `kCGImagePropertyPVREncoder` are annotated iOS 10.0 and their symbols first appear at iOS **10.0.1**, which
  is why there is a `ImageIONames1001.m` and no `ImageIONames120.m` addition.

The values are the host's own, read with `dlsym` one process per symbol by
`tests/backports/host/imageio-names/probe.c`. Eleven of the forty-six are **not** their own name, which is why
no convention can produce this table:

| name | value |
| --- | --- |
| `kCGImagePropertyAVISDictionary` | `{AVIS}` |
| `kCGImagePropertyTIFFXPosition` | `XPosition` |
| `kCGImagePropertyTIFFYPosition` | `YPosition` |
| `kCGImagePropertyGroupMonoscopicImageLocation` | `GroupImageIndexMonoscopicImageLocation` |
| `kIIOMonoscopicImageLocation_Center` / `_Left` / `_Right` / `_Unspecified` | `Center` / `Left` / `Right` / `Unspecified` |
| `kIIOStereoAggressors_Severity` / `_SubTypeURI` / `_Type` | `Severity` / `SubTypeURI` / `Type` |

`kCGImagePropertyGroupMonoscopicImageLocation` is the sharpest of them: the name has no `Image` after
`Group` and the value has two words in a different order, so a rule that added or dropped a word would get
it wrong in a way no test of the other 45 would notice.

The harness compiles these five objects, links them into a pure C reader and reads **the port's own** values
through it, then runs one mutant per constant:

    GREEN (port vs host): 438 agree, 0 differ
    PLANT all 438 wrong: 0 agree, 438 differ
    PLANT one wrong (kCGComputeHDRStats): 437 agree, 1 differ
    imageio-names: 438 constants, 438 mutants run, 438 RED

The 438 is every name in the slice, the 392 that were already carried plus these 46. The mutants are the
part that makes the first line mean anything: each one changes one value and must be seen to change.
