# Buffers of vImage from images, iOS 7.0

iOS 7.0 gave vImage three functions that connect it to CoreGraphics: `vImageBuffer_Init`, which makes a buffer whose rows suit the
hardware, `vImageBuffer_InitWithCGImage`, which fills one with the pixels of an image in the format asked for, and
`vImageCreateCGImageFromBuffer`, which makes an image of one. An application that scales or filters an image with vImage
does its first and last steps with them.

Source: the host's own vImage, held against the port for every format the port makes, for the sizes 2x2, 5x4, 17x9 and 64x3, and for
three background colours, by `tests/backports/host/accelerate7/run.sh`; the answers of the host are recorded by
`host/accelerate7/refresh.sh` for `tests/backports/device/accelerate7.m`, which holds the port on the devices to them; the header of
iOS 16.4 for the documented contract. iOS 6 has the rest of vImage, and none of these three.

## What it is

The pixels are the image drawn into the format: the colours of the image are converted to the colour space of the format, an
alpha the format has not is flattened against the background colour (an array of the components of the colour space, zeros
when it is NULL), and a format that keeps alpha without premultiplying it is unpremultiplied, rounding to the nearest. The host makes a
format that skips a byte exactly as the same format with alpha: the byte holds the alpha. A row is a multiple of 16 bytes that holds
the pixels, and the data is aligned; the host's exact rowBytes depends on its processor and was not reproduced, and an application
is told to use the one it is given.

## What was measured, and where the documentation is not the host

The host answers `kvImageUnknownFlagsBit` to any flag but none, `kvImageNoAllocate` and `kvImagePrintDiagnosticsToConsole` for
`vImageBuffer_Init` and for `vImageBuffer_InitWithCGImage` (the header allows `kvImageDoNotTile` for the second, and the host refuses
it), and to any flag but those and `kvImageHighQualityResampling` and `kvImageDoNotTile` for `vImageCreateCGImageFromBuffer`. A
format version other than 0 answers `kvImageInvalidImageFormat`, a `bitsPerComponent` that is not in the list answers
`kvImageInvalidParameter`, a `bitsPerPixel` that does not fit the components answers `kvImageInvalidImageFormat`, and a
`bitmapInfo` with bits that mean nothing answers `kvImageInvalidParameter`. A non-NULL `decode` and a rendering intent that is none
are accepted. A buffer of no rows or no columns is made, with a data pointer that is not NULL. The port answers as the host does to each.

## Where iOS 6 differs

The release has no sRGB space, so a format whose colour space is NULL is made in the device RGB space. Only what CoreGraphics of
the release can draw into, in a colour space it converts as the host does, is made: the 8-bit RGB formats above. The formats of 16 bits and of
float components, gray and the other colour models answer `kvImageInvalidImageFormat`, which the host does not; an application that asks for
them has none of what it asked for, and the error tells it. Gray was tried and left out: the release's CoreGraphics converts an RGB image to gray
with weights of its own, and the pixels it makes differ from the host's by up to forty levels, where the RGB formats agree within one.
A row shorter than the pixels it holds answers `kvImageInvalidRowBytes` for the image, where the host makes an image that reads beyond it.
