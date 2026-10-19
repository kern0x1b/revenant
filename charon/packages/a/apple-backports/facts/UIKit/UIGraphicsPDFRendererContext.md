# UIGraphicsPDFRendererContext

Introduced in iOS 10.0. The page being drawn, and the three primitives that write into the PDF.

Source: UIKit of the armv7s cache of iOS 10.3.4, read with `xmake firmware extract` and the method
addresses of `objc.code_map`, each body disassembled and annotated against the image's own
`__objc_selrefs` and indirect symbol table.

It keeps three members of its own, `objc.code_map`'s ivar list giving their names:
`_documentBounds`, `_pageBounds`, `_inPage`.

| member | address | what it does |
|---|---|---|
| `-pdfContextBounds` | `0x209856f1` | `-inPage` and then `-pageBounds`, or `-documentBounds`: the page is the document until the first `-beginPage`. |
| `-beginPage` | `0x209853bb` | `-beginPageWithBounds:` with the format's bounds (or `CGRectZero` when there is no format) and no page dictionary - it loads the nil object, `___NSDictionary0__` at `0x2098541e`. |
| `-beginPageWithBounds:pageInfo:` | `0x20985451` | see below. |
| `-setURL:forRect:` | `0x2098572f` | `CGPDFContextSetURLForRect(self.CGContext, url, rect)` and nothing else. |
| `-addDestinationWithName:atPoint:` | `0x20985783` | `CGPDFContextAddDestinationAtPoint(self.CGContext, name, point)`. |
| `-setDestinationWithName:forRect:` | `0x209857c7` | `CGPDFContextSetDestinationForRect(self.CGContext, name, rect)`. |

## Beginning a page

`0x20985451`, in this order:

1. `CGPDFContextEndPage(self.CGContext)` when `-inPage` is set.
2. the rectangle asked for, overridden by `format.documentInfo[kCGPDFContextMediaBox]` when that is
   an `NSData` - `-getBytes:length:0x10` into it - and replaced by the document's own bounds when what
   is left is empty (`CGRectIsEmpty`).
3. `-setPageBounds:` with that rectangle, `-setInPage:YES`.
4. `CGPDFContextBeginPage(self.CGContext, pageInfo)`. On iOS this call takes **no rectangle**: its
   declaration in `CGPDFContext.h` is `void CGPDFContextBeginPage(CGContextRef, CFDictionaryRef)`,
   and the rectangle travels inside the dictionary under `kCGPDFContextMediaBox`. That is why the
   release has the dictionary work in step 5 at all.
5. the media box is written into the page dictionary - as `[NSData dataWithBytes:&box length:16]` -
   but only when the page is **neither** the document's own rectangle **nor** US Letter, the two
   rectangles CoreGraphics already gives that box from the document it was made with. The write goes
   into a `-mutableCopy` of the caller's dictionary, which has an edge worth naming: a caller who
   passes no dictionary gets none, because `-[nil mutableCopy]` is nil and `-setObject:forKey:` on nil
   does nothing. That is the release's behaviour at `0x20985652`, and it is carried as it is.
6. the y axis is flipped once for the page, about the page's own height:
   `CGContextTranslateCTM(context, 0, box.size.height)` - at `0x20985684` the instruction loads the
   FOURTH float of the page rectangle into the second argument, which is its height and not a zero -
   then `CGContextScaleCTM(context, 1, -1)` and
   `CGContextSetBaseCTM(context, CGAffineTransformMakeScale(1, -1))`. The base matrix is what keeps
   that flip on the second and later pages of one document, and is the only private call in the family
   (first-rung 3.0, no header declares it).

   The height, not a zero, is what `tests/backports/host/pdf/run.sh` settled: a first version read
   that instruction as a zero and every page came out blank, because a flip about the origin puts the
   whole drawing below the paper. The test compares the rasterised pixels of every page against the
   host's own renderer, so it is not a reading of the listing that decides it.

There is no fourth step: the release calls a private `-updateAuxInfo:` after the flip, which
re-reads the page dictionary of the document, and nothing reaches it from any header.