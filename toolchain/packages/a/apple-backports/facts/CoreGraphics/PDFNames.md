# PDF names of CoreGraphics: outline, access, tags and linearized and PDF/A, iOS 11 to 16

Source: the macOS CoreGraphics of the host, read with a probe that prints each constant's string and each
`CGPDFTagTypeGetName` answer for the values 0 to 1000 (`tests/backports/host/cgpdf-names`), and the
SDK headers (`CGPDFContext.h`, `CGPDFDocument.h`, `CGBitmapContext.h`). The release's own strings for these
names on iOS 13 and later were not read: no such device runs here.

## Constants

Each constant is a `CFString` whose text the release gives it. An application that names one loads on iOS 6
and gets the text, as the names of `Names.md` are carried. Nothing in the port acts on them:

| Constant | Introduced | Text |
| --- | --- | --- |
| `kCGPDFOutlineChildren` | 11.0 | `Children` |
| `kCGPDFOutlineDestination` | 11.0 | `Destination` |
| `kCGPDFOutlineDestinationRect` | 11.0 | `DestinationRect` |
| `kCGPDFOutlineTitle` | 11.0 | `Title` |
| `kCGPDFContextAccessPermissions` | 11.0 | `kCGPDFContextAccessPermissions` |
| `kCGPDFTagPropertyActualText` | 12.0 | `CGPDFTagPropertyActualText` |
| `kCGPDFTagPropertyAlternativeText` | 12.0 | `CGPDFTagPropertyAlternativeText` |
| `kCGPDFTagPropertyLanguageText` | 12.0 | `CGPDFTagPropertyLanguageText` |
| `kCGPDFTagPropertyTitleText` | 12.0 | `CGPDFTagPropertyTitleText` |
| `kCGPDFContextCreateLinearizedPDF` | 16.0 | `CGPDFContextCreateLinearizedPDF` |
| `kCGPDFContextCreatePDFA` | 16.0 | `CGPDFContextCreatePDFA` |

`Introduced` is the first held release that exports the name, measured by `tools/release-split.lua` over the held
caches (11.0 to 18.0). The SDK 26.2 headers differ from the measurement in two places, and the port follows the
measurement, which is what the gate reads:

- the tag properties are `API_AVAILABLE(ios(13.0))`, and the name is absent on 11.0 and present on 12.0;
- `kCGPDFContextCreateLinearizedPDF` and `kCGPDFContextCreatePDFA` are `ios(14.0)`. Nothing is held between 13.4
  and 16.0, so the measurement says only "by 16.0": the 16.0 is an upper bound, not a measured first release.

The outline keys, the access permissions key and the two context options name what the PDF functions of the
release take; the port does not carry those functions (their rows stay `absent`), so the keys are never read.

## CGPDFTagTypeGetName, 12.0

The release's `CGPDFTagTypeGetName` answers the PDF role name of a tag type, with its slash, as a C string that
the release keeps; it answers NULL for a value that is not a tag type. The port answers the same for the 50 tag
types of the enumeration below iOS 27:

- 100 to 111: `/Document`, `/Part`, `/Art`, `/Sect`, `/Div`, `/BlockQuote`, `/Caption`, `/TOC`, `/TOCI`, `/Index`,
  `/NonStruct`, `/Private`;
- 200 to 207: `/P`, `/H`, `/H1` to `/H6`;
- 300 to 303: `/L`, `/LI`, `/Lbl`, `/LBody`;
- 400 to 406: `/Table`, `/TR`, `/TH`, `/TD`, `/THead`, `/TBody`, `/TFoot`;
- 500 to 507: `/Span`, `/Quote`, `/Note`, `/Reference`, `/BibEntry`, `/Code`, `/Link`, `/Annot`;
- 600 to 606: `/Ruby`, `/RB`, `/RT`, `/RP`, `/Warichu`, `/WT`, `/WP`;
- 700 to 702: `/Figure`, `/Formula`, `/Form`;
- 800: `/OBJR`.

`CGPDFTagTypeArtifact` (900, `/Artifact`) is declared `API_AVAILABLE(ios(27.0))` in the SDK, so it is not one of
the names of the 12.0 set: the port answers NULL for 900, and the host test checks that the host answers `/Artifact`.

`CGPDFContextBeginTag`, `CGPDFContextEndTag` and the marked content functions write structure into a PDF
context, which the port does not carry; their rows stay `absent` and are not answered here.

## Test

`tests/backports/host/cgpdf-names`: 1017 checks, 0 failures. The port's two source files are built with their
symbols renamed `revenant_host_*`; each constant's text is compared with the host's, and `CGPDFTagTypeGetName` is
compared for every value from 0 to 1000 (the host's NULLs included), with the 900 difference checked on both
sides.
