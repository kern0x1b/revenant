# UIGraphicsPDFRendererFormat

Introduced in iOS 10.0. The document's metadata, and - privately - where the document is written.

Source: UIKit of the armv7s cache of iOS 10.3.4, read with `xmake firmware extract` and the method
addresses of `objc.code_map`.

| member | address | what it does |
|---|---|---|
| `-documentInfo`, `-setDocumentInfo:` | `0x2098530f`, `0x20985321` | one ivar, and a setter that copies: the release compiles both to `objc_getProperty` and `objc_setProperty` with the copy flag set. The property is `copy` in the header. |
| `-outputURL`, `-setOutputURL:` | `0x20985331`, `0x20985343` | private; where `-[UIGraphicsPDFRenderer writePDFToURL:withActions:error:]` writes. |
| `-pdfData`, `-setPdfData:` | `0x20985353`, `0x20985365` | private; the `NSMutableData` `-[UIGraphicsPDFRenderer PDFDataWithActions:]` draws into. |
| `-copyWithZone:` | `0x20985221` | `[super copyWithZone:]`, then **all three** onto the copy: `-documentInfo` copied a second time and handed to `-setDocumentInfo:`, then `-outputURL`, then `-pdfData`. |

`+defaultFormat` is not in the release's method list, so the base class's answers it:
`[[self alloc] init]`, which for this class is a format with no bounds, no document info and no
destination. `+[UIGraphicsPDFRendererFormat defaultFormat]` is therefore a fresh empty format, and the
document's page is whatever `-[UIGraphicsPDFRenderer initWithBounds:format:]` was given - US Letter
when that was nothing (see `UIGraphicsPDFRenderer.md`).

The two private members are the release's own names, and the ivar list in `objc.code_map` gives
them: `_documentInfo`, `_outputURL`, `_pdfData`. Nothing in any header declares the last two, and
nothing outside `UIGraphicsPDFRenderer.m` reads them, so a subclass cannot see where the release's
renderer is writing - which is why the facts pages name them rather than the port's own seam.