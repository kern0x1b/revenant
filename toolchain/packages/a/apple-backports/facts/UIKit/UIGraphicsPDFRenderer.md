# UIGraphicsPDFRenderer

Introduced in iOS 10.0. Writes a PDF document, either to a URL or into `NSData`.

Source: UIKit of the armv7s cache of iOS 10.3.4, read with `xmake firmware extract` and the
method addresses of `objc.code_map` (`modules/apple/objc.lua`), each body then disassembled and
annotated against the image's own `__objc_selrefs`, `__objc_classrefs` and indirect symbol table, so
every call below is the call the release makes and not a reading of its neighbours.

## Where the classes are, and where they are not

`REVENANT_ROOT=<worktree> xmake l tools/corpus/cache-census.lua UIGraphicsPDF 6.1.3 4.3 10.3.4`:

```
6.1.3  ... classes 11378, of which UIGraphicsPDF* 0
4.3    ... classes 7187,  of which UIGraphicsPDF* 0
10.3.4 ... classes 40727, of which UIGraphicsPDF* 3 (UIGraphicsPDFRenderer UIGraphicsPDFRendererContext UIGraphicsPDFRendererFormat)
control: 3 name(s) beginning UIGraphicsPDF found in this run, so a zero on another rung is the release's and not the reader's
```

## What this release carries that the family needs

Every symbol the three classes call is first-rung 3.0, which is below the 6.0 minimum its rows
carry, so no band that takes the object lacks one:

| symbol | first rung |
|---|---|
| `_CGPDFContextCreate`, `_CGPDFContextCreateWithURL`, `_CGPDFContextBeginPage`, `_CGPDFContextEndPage`, `_CGPDFContextClose` | 3.0 |
| `_CGPDFContextSetURLForRect`, `_CGPDFContextAddDestinationAtPoint`, `_CGPDFContextSetDestinationForRect` | 3.0 |
| `_CGDataConsumerCreateWithCFData`, `_CGDataConsumerRelease` | 3.0 |
| `_CGContextTranslateCTM`, `_CGContextScaleCTM`, `_CGAffineTransformMakeScale`, `_CGRectIsEmpty`, `_CGRectEqualToRect` | 3.0 |
| `_UIGraphicsPushContext`, `_UIGraphicsPopContext`, `_kCGPDFContextMediaBox` | 3.0 |
| `_CGContextSetBaseCTM` | 3.0, and declared in no header - not the 26.2 one either |

Read with `xmake l tools/cache-index/first-rung.lua <symbol>`, one name per run. The last one is the
family's only private call: it sets the matrix a context returns to when its CTM is reset, which is
what keeps the y flip across the pages of one document, and the three private functions beside it in
`RevenantGraphicsRenderer.h` are declared the same way for the same reason.

## The members, and where each body is

| member | address | what it does |
|---|---|---|
| `-init` | `0x20985bb1` | `-initWithBounds:` with `_CGRectZero` and `[UIGraphicsPDFRendererFormat defaultFormat]`. |
| `-initWithBounds:` | `0x20985c17` | `-initWithBounds:format:` with the PDF format's default. |
| `-initWithBounds:format:` | `0x20985c81` | `-setPdfData:nil` and `-setOutputURL:nil` on the format, then `[super initWithBounds:format:]` - the destination is cleared before the superclass copies the format, so a renderer built round one format writes nowhere until a member names a place. |
| `+rendererContextClass` | `0x209858f1` | `[UIGraphicsPDFRendererContext class]`. |
| `+contextWithFormat:` | `0x2098590d` | see below. |
| `+prepareCGContext:withRendererContext:` | `0x20985a41` | see below. |
| `-pushContext:` | `0x202e68ad` | fills a private record of the document's bounds, the page's bounds, whether a page is open and the context, and hands it to UIKit's own renderer stack - which is what makes the PDF context current for the block. |
| `-popContext:` | `0x202e6961` | `-inPage` then `CGPDFContextEndPage`, then the superclass's pop, then `CGPDFContextClose`, which is what finishes the document. |
| `-writePDFToURL:withActions:error:` | `0x20985d09` | `[self format]`, `-setOutputURL:` with the URL, then `-runDrawingActions:completionActions:format:error:` with that same format and the caller's `NSError **`. |
| `-PDFDataWithActions:` | `0x20985d91` | `[[NSMutableData alloc] init]`, `[self format]`, `-setPdfData:` with it, the four-argument run with a nil completion and a nil error, then `-copy` of the data when the run answered YES and `[[NSData alloc] init]` when it did not - an empty `NSData`, never nil, as the image renderer's three drawing members answer. |

`-allowsImageOutput` is not in the release's method list, so the base class answers NO: a PDF
renderer draws no image out of itself.

## Where the document goes

`+contextWithFormat:` asks the format twice over, and the answers are the release's own private
members: the URL, then the data. Either one present decides, and a nil rectangle is passed as no
rectangle at all, which is what lets the document's own media box decide:

| destination | the call |
|---|---|
| `outputURL` | `CGPDFContextCreateWithURL(url, CGRectIsEmpty(bounds) ? NULL : &bounds, documentInfo)` |
| `pdfData` | `CGDataConsumerCreateWithCFData(pdfData)`, and then `CGPDFContextCreate(consumer, the same media box, documentInfo)` with the consumer released |
| neither | `NULL` |

A `NULL` answer is the base class's empty case and nothing new: no drawing block runs,
`-runDrawingActions:completionActions:format:error:` answers NO with `NSCocoaErrorDomain` code 0 and
`Could not create CGContextRef`, and `-PDFDataWithActions:` answers an empty `NSData` in consequence.

## The document's page, and the default that is not a guess

`+prepareCGContext:withRendererContext:` gives the renderer context three pieces of state, in this
order: the format's bounds unless `documentInfo[kCGPDFContextMediaBox]` is an `NSData` of sixteen
bytes, which then replaces them; `CGRectZero` for the page bounds; and NO for whether a page is
open. So `-pdfContextBounds` answers the document's page until the first `-beginPage`.

When that rectangle is empty the release substitutes a page of US Letter at 72 dpi. The four floats
are at `0x20985ba0` of the same cache, read as `0, 0, 612, 792`, and the same two numbers are built
by immediate in `-beginPageWithBounds:pageInfo:`'s own comparison (`0x44190000` and `0x44460000`).
Two independent places in one image, which is what a constant looks like and what a value tuned
until a check passed does not.