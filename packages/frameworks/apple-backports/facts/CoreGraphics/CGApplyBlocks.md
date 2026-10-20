# Block walks over paths and PDF objects, and two masks of an image, iOS 11 and 12

Source: CoreGraphics of the arm64 shared cache of iOS 12.0 -
`_CGPathApplyWithBlock` at `0x182d20840` with its block at `0x182d208f4`,
`_CGPDFArrayApplyBlock` at `0x182b43f74`, `_CGPDFDictionaryApplyBlock` at
`0x182cebb00`, `_CGImageGetByteOrderInfo` at `0x182b15310`,
`_CGImageGetPixelFormatInfo` at `0x182b15320`. The host's CoreGraphics through
`tests/backports/host/graphics11` for what comes out.

## CGPathApplyWithBlock, 11.0

Calls the block once for each element of the path, in the order of the path, with
a `CGPathElement` and its points. A `NULL` path or a `NULL` block calls nothing.
The release's own `CGPathApply` walks the same elements, so the package hands
each of them to the block.

## CGPDFArrayApplyBlock, 12.0

Walks the array by index. For each index it asks for the object; if the object is
there it calls the block with the index, the object and the caller's info pointer,
and stops when the block answers false; if the object cannot be read it goes on
to the next index without calling. A `NULL` array or block calls nothing.

## CGPDFDictionaryApplyBlock, 12.0

Walks the entries of the dictionary in the order the release keeps them. An entry
that is an indirect reference is resolved first, so the block is given the object
the reference names. The block is called with the key, the object and the
caller's info pointer, and the walk stops when it answers false. A `NULL`
dictionary or block calls nothing.

The release's own `CGPDFDictionaryApplyFunction` walks in the same order and
resolves in the same way, and it cannot be stopped. The package stops calling the
block after the first false and lets the walk finish unseen. What the block sees
is the same as on iOS 12; a block that does something slow on each entry is not
saved the walk.

## CGImageGetByteOrderInfo and CGImageGetPixelFormatInfo, 12.0

The first is the bitmap info of the image masked with `0x7000` (the byte order
bits), the second the bitmap info masked with `0xF0000` (the pixel format bits).
Both answer 0 for a `NULL` image. The test makes images of every pixel format the
host accepts (the 16 bit formats and the 10 bit one) with each byte order.
