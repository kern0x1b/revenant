# CVMetalTexture and CVMetalTextureCache, iOS 8

Introduced in iOS 8.0: `CVMetalTextureCacheCreate`, `CVMetalTextureCacheCreateTextureFromImage`,
`CVMetalTextureCacheFlush`, `CVMetalTextureCacheGetTypeID`, `CVMetalTextureGetCleanTexCoords`,
`CVMetalTextureGetTexture`, `CVMetalTextureGetTypeID` and `CVMetalTextureIsFlipped`.

Source: the header of iOS 16.4 for the contract; CoreVideo of the armv7 shared cache of iOS 6.1.3,
which exports none of the CVMetalTexture names; Metal is not in the device.

The functions live in `libGraphicsBackports.dylib`, built with the `graphics` config, because CoreVideo
is one of its frameworks.

## What the device has

An iPhone 4S and an iPad 2 on iOS 6.1.3 have no Metal hardware. Metal arrived in iOS 8 with the A7,
and these devices predate it. `MTLCreateSystemDefaultDevice` answers nil, and so does the backport's
`MTLCreateSystemDefaultDevice` in `libMetalBackports.dylib`.

## What the port does

Three applications in the corpus (session, telegram, yattee) hard-link `_CVMetalTextureCacheCreate`,
`_CVMetalTextureCacheCreateTextureFromImage` and `_CVMetalTextureGetTexture`. A hard-linked C symbol
that is absent kills the application at launch — dyld fails to bind the non-weak import — which is worse
than a crash on use. The port carries all eight CVMetalTexture functions so the import resolves and the
application launches. The functions answer honestly that Metal is not there, the way a device without
the hardware does:

- `CVMetalTextureCacheCreate` answers `kCVReturnInvalidArgument` and writes `NULL` to the cache out,
  because the Metal device the caller gives is nil on a device with no Metal.
- `CVMetalTextureCacheCreateTextureFromImage` answers `kCVReturnInvalidArgument` and writes `NULL` to
  the texture out, because no cache was made and no Metal device is there.
- `CVMetalTextureCacheFlush` does nothing, because there is no cache to flush.
- `CVMetalTextureGetTexture` answers nil, because there is no Metal texture to give.
- `CVMetalTextureCacheGetTypeID` and `CVMetalTextureGetTypeID` answer 0, because no object of either
  type was ever made.
- `CVMetalTextureIsFlipped` answers false, because there is no texture to be flipped.
- `CVMetalTextureGetCleanTexCoords` writes 0.0 to each of the four coordinate pairs, because there is
  no texture to read coordinates from.

## What differs from the release

The release's functions make a texture from a CoreVideo image buffer through a Metal device. The port's
functions never make one, because the device has no Metal. An application that checks the return of
`CVMetalTextureCacheCreate` or the texture of `CVMetalTextureGetTexture` sees the failure and takes its
non-Metal path, as it does on a device whose GPU does not support Metal.
