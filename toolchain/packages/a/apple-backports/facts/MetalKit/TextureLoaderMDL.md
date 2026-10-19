# The two MDL loading methods and the 17.0 option key, MetalKit

Three rows, all of the loader: `MTKTextureLoaderOptionLoadAsArray` (17.0),
`-[MTKTextureLoader newTextureWithMDLTexture:options:error:]` and its completion-handler form (both
10.0). `facts/MetalKit/TextureLoader.md` is the rest of the loader; this is what the Model I/O half
does, and the refusals are the point of it.

## `MTKTextureLoaderOptionLoadAsArray`

The key's value is its own name, which is what every sibling key already in the tree does and what a
caller passing the NSString it read out of the header needs. It was **measured, not assumed**, out of
Apple's own framework:

```
sh tests/backports/host/metal-census/loaderoptions.sh
```

```
  ok   MTKTextureLoaderOptionLoadAsArray: the port and Apple's own framework both say MTKTextureLoaderOptionLoadAsArray
  ok   MTKTextureLoaderOptionSRGB -> MTKTextureLoaderOptionSRGB
  ... (seven more, one per key MetalKit exports)
loaderoptions: 10 check(s), 0 failure(s)
  red    MTKTextureLoaderOptionLoadAsArray: the port says MTKTextureLoaderOptionLoadAsArrayScharonMutant and Apple's own framework says MTKTextureLoaderOptionLoadAsArray
```

The harness compiles the port's object under `-DMTKTextureLoaderOptionLoadAsArray=
charonHost_MTKTextureLoaderOptionLoadAsArray`, so both spellings are in one binary and the two can be
compared; it also refuses a binary that does not define the renamed symbol, because a case that read
Apple's framework for the port's answer would agree with itself. The mutation is the value changed to
something else, and it is red.

**It is an object of its own, and not part of the 9.0 or 10.0.1 key objects**, because an object
carries the API of ONE release: `MTKTextureLoaderOptionLoadAsArray17.m` holds it alone.
`MTKTextureLoader.h:130` says what it is for - "loaded as an array texture **when possible**", an
NSNumber with a boolean value - and what is possible is what the device holds, which is the subject of
the next section.

## `newTextureWithMDLTexture:options:error:`

The header's words for it (MTKTextureLoader.h:332) are "create a Metal texture and load image data
from the given MDLTexture", and that is the whole of the work: an MDLTexture is a block of texels of
its own channel count and channel encoding, a Metal texture is a block of texels of a Metal pixel
format, and this maps the first onto the second.

**The format table** is the nine Metal pixel formats this port holds, which `facts/Metal/PixelFormats.md`
lists with the extension each one needs:

| MDLTexture channel encoding | channels | Metal pixel format |
|---|---|---|
| `UInt8` | 1 / 2 / 4 | `R8Unorm` / `RG8Unorm` / `RGBA8Unorm` |
| `Float16` | 1 / 2 / 4 | `R16Float` / `RG16Float` / `RGBA16Float` |
| `Float32` | 1 / 4 | `R32Float` / `RGBA32Float` |

The three channel counts and two encodings with no entry - three channels of anything, and
`Float16SR`, `UInt16`, `UInt24`, `UInt32` - are refused with the channel count and the encoding in the
message. Loading those bytes into a format that reads them as something else would hand back a texture
that is not the one the caller has, which is the failure `facts/Metal/PixelFormats.md` calls "a texture
that holds something else".

**The row order** is the rule `MTKTextureLoader9.m` already states, for the same reason: a Metal
texture's row 0 is its top row, this port's textures are OpenGL ES textures whose row 0 is the bottom
one, and `-replaceRegion:mipmapLevel:withBytes:bytesPerRow:` writes the bytes it is handed in the
driver's own order. A `CGImage` carries no origin metadata, so that path copies the rows; an
`MDLTexture` carries its own origin and exposes the two orders as two accessors, so here nothing is
copied - `MTKTextureLoaderOptionOrigin` picks the accessor, with `BottomLeft` and no option reading
`-texelDataWithBottomLeftOrigin` and `TopLeft` / `FlippedVertically` reading
`-texelDataWithTopLeftOrigin`. The bytes per row handed to the device is the MDLTexture's own
`rowStride`, because an MDLTexture may pad its rows.

## What is refused, and each refusal says why

* **An sRGB request.** `facts/Metal/PixelFormats.md`, "What is not here": sRGB is refused at the
  format table, so a texture loaded as sRGB would not be the texture the caller asked for.
* **`MTKTextureLoaderOptionCubeLayout`.** MTKTextureLoader.h:90 says the option cannot be used with
  MDLTextures, which support cube textures directly.
* **An MDLTexture that is a cube.** Six faces; this port's textures are 2D, so the texels are loaded
  as the single 2D texture they are, and the message says that.
* **`MTKTextureLoaderOptionLoadAsArray`.** Not read, and this is the one place where the 17.0 key is
  deliberately absent from a 10.0 object: the header asks for an array texture "when possible", and
  for a plain 2D MDLTexture what is possible is a 2D texture. An object that read a 17.0 key would
  carry a dependency on a release it is not placed in.
* **A channel count or encoding with no Metal format of that shape** (the table above), and an
  MDLTexture with no texels.
* **A device that cannot hold the format.** `facts/Metal/PixelFormats.md` puts that refusal in
  `-[MTLDevice newTextureWithDescriptor:]`, which reads `glGetString(GL_EXTENSIONS)` and names the
  missing extension; the loader repeats the format number in its own error so the caller has it
  without a second call.

## Where Apple accepts what this port refuses, measured

Three of the cases below are inputs Apple's own loader answers and this port does not. That is the
port's nine formats and not a claim about the input, and the differential prints Apple's answer beside
the port's on every run:

| input | Apple's own loader | this port |
|---|---|---|
| `MTKTextureLoaderOptionSRGB: @YES` | a texture | nil - the port holds no sRGB format |
| four channels of `UInt16` | a texture | nil - no 16-bit-integer Metal format is held |
| an MDLTexture that is a cube | (not exercised: an MDLTexture's `isCube` is set by its initializer and the case builds one that is not) | nil - six faces, and this port's textures are 2D |
| three channels of `UInt8` | nil, "Textures must have 1, 2, or 4 channels" | nil, naming the channel count |
| `UInt24` | nil, "Textures must use 8 or 16 bits per channel" | nil, naming the channel encoding |

Every one of these is an `NSError` in `MTKTextureLoaderErrorDomain` with the reason as its
`NSLocalizedDescriptionKey`, and the completion-handler form calls the handler with the same pair -
`(nil, error)` on a refusal and `(texture, nil)` on a texture. The header's `completionHandler` is
`nonnull`, so a caller that passes nil gets nothing called, which is what passing nil means.

## The differential, and what it does not reach

```
sh tests/backports/host/metal-census/mdltexture.sh
```

```
  ok   the control: MTLCreateSystemDefaultDevice() answers on this machine
  ok   four 8-bit channels, packed rows: pixel format, the port 70 and Apple's own 70
  ok   four 8-bit channels, packed rows: every byte of the texels, 48 of them
  ok   four 16-bit float channels: every byte of the texels, 96 of them
  ok   one 32-bit float channel: every byte of the texels, 80 of them
  ok   four 8-bit channels, rows padded to 40 bytes: every byte of the texels, 48 of them
  ok   four 8-bit channels, MTKTextureLoaderOptionOriginTopLeft: every byte of the texels, 48 of them
  ok   four 8-bit channels, MTKTextureLoaderOptionOriginBottomLeft: every byte of the texels, 48 of them
  ok   an sRGB request, which this port holds no format for: the port answers nil in MTKTextureLoaderErrorDomain
  ok   a texture: the handler is called once with the texture and no error
  mdltexture: 39 check(s), 0 failure(s)
  red  the two-channel entry of the format table:   two 8-bit channels: pixel format, the port 70 and Apple's own 30
  red  the origin option's choice of accessor:   four 8-bit channels, packed rows: every byte of the texels, 48 of them
  red  the sRGB refusal:   an sRGB request, which this port holds no format for: the port answers nil in MTKTextureLoaderErrorDomain
```

39 checks and three mutants, one per thing the loader decides. **The seam is one line**: the port's
loader is compiled under another class name together with the port's own `MTKTextureLoader9.m`, and
handed Apple's device through the port's own `-initWithDevice:`. The port's real device object is an
EAGL context over OpenGL ES 2.0 and cannot be built on a host; every other line under test - the format
table, the origin choice, the refusals, the completion handler - is the port's own. The `MDLTexture`
is Apple's and ONE of them, given to both sides, because it is the input and not the thing under test.

**What it does not reach**: the port's own `-replaceRegion:` on the port's own GL texture. The device
here is Apple's, so the bytes travel by Apple's path. What the port does with those bytes on a real
iPhone 4S at 6.1.3 is the device test's, and `facts/Metal/PixelFormats.md` is where the format
support of that device is measured.