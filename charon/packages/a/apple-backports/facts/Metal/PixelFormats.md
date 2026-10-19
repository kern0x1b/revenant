# The pixel formats the port holds, and the ones it refuses

Queued from MPS: the image filters and the convolutional kernels work in half and single floats, and
`formatFor` in `CharonMetalTexture.m` admitted only the four 8-bit formats. This is what the port holds
now, why, and what it answers for the rest.

## The nine formats

| Metal format | texel | channels × width | the extensions a device must list |
|---|---|---|---|
| `RGBA8Unorm` | 4 bytes | 4 × 1 | none beyond ES 2.0 |
| `BGRA8Unorm` | 4 bytes | 4 × 1 | none beyond ES 2.0 (`GL_EXT_texture_format_BGRA8888` for the read) |
| `R8Unorm` | 1 byte | 1 × 1 | `GL_EXT_texture_rg` |
| `RG8Unorm` | 2 bytes | 2 × 1 | `GL_EXT_texture_rg` |
| `RGBA16Float` | 8 bytes | 4 × 2 | `GL_OES_texture_half_float` |
| `R16Float` | 2 bytes | 1 × 2 | `GL_OES_texture_half_float` and `GL_EXT_texture_rg` |
| `RG16Float` | 4 bytes | 2 × 2 | `GL_OES_texture_half_float` and `GL_EXT_texture_rg` |
| `RGBA32Float` | 16 bytes | 4 × 4 | `GL_OES_texture_float` |
| `R32Float` | 4 bytes | 1 × 4 | `GL_OES_texture_float` and `GL_EXT_texture_rg` |

The internal format is unsized — `GL_RGBA`, `GL_RG`, `GL_RED` — with the type the extension names
(`GL_HALF_FLOAT`, `GL_FLOAT`), which is what OpenGL ES 2.0 with those extensions specifies; the sized
internal formats are ES 3.0. `GL_HALF_FLOAT` is not in ES 2.0's own headers, so it is defined in
`CharonMetalTexture.m` with the value `GL_OES_texture_half_float`'s header gives, and nothing else is
defined there.

**Where the extension list comes from.** The SGX 543 of an iPad 2 at 6.1.3
(`OpenGL ES 2.0 IMGSGX543-73.16.1`) lists 35 extensions, and `GL_OES_texture_half_float` and
`GL_OES_texture_half_float_linear` are among them: `tests/backports/device/gl-extensions.m` measured on
2026-09-24, and `facts/SceneKit/SCNView.md` "Textures" records the same list for the SceneKit renderer,
which is why a colour slot there is held in half floats. The port does not take that as a constant: it
reads `glGetString(GL_EXTENSIONS)` once, on the first texture that needs a decision, and compares whole
names — a name that is the prefix of another is not a match. A format whose extensions are not all in
that string is refused the way Metal refuses a pixel format the device does not support:
**`-[MTLDevice newTextureWithDescriptor:]` answers nil, and the log says which extension is missing**,
because "unsupported" on its own would not tell a caller what to do about it.

So the half-float formats are carried on a measured basis for the 8-bit-channel and 4-channel cases, and
the 32-bit floats and the red/green ones depend on extensions the recorded list does not name; they are
carried with the same code and a device without the extension answers nil for them, which is the honest
answer rather than a texture that holds something else.

## The readback, and why channels are not bytes

OpenGL ES 2.0 reads a colour attachment as four channels of the channel's own width, whatever the texture
holds, so a texture of fewer channels is the **leading** ones copied out of that row. `CharonFormat`
therefore carries the width of a whole texel, how many channels there are and how wide one channel is,
because before this they were one number and the two are not the same thing:

* two 8-bit channels are the first **two** bytes of each four;
* two 16-bit channels are the first **four** bytes of each eight;
* one 32-bit channel is the first **four** bytes of each sixteen.

A four-channel format keeps the fast path, where the read is taken in the texture's own format — which is
how a BGRA texture's readback keeps its byte order, as `tests/backports/host/metalblit/` measured against
macOS Metal — and everything else goes through the copy. For the four 8-bit formats the numbers are
unchanged: one texel, four channels, one byte each.

## Filtering, which is a separate question from holding

ES 2.0 filters the 8-bit formats with nothing extra. A **half float** is filtered only with
`GL_OES_texture_half_float_linear` and a **float** only with `GL_OES_texture_float_linear`, so each format
carries that extension beside the one that lets it exist, and `-charonCanFilter` asks the same extension
string the texture was made against.

**A format this device cannot filter, asked to be filtered, is what Metal answers with a validation
error.** So the render encoder refuses the filtering rather than performing it in the encoding: a
fragment texture whose sampler is linear and whose format this device cannot filter draws **nearest**,
and the log says so once per texture, naming the pixel format. Saying it once per texture rather than
once per draw is deliberate — a kernel in a loop would otherwise put a line out per invocation — and the
line names the texture and the format, so the caller can find which one.

The eight-bit formats are unaffected: `charonCanFilter` is YES for all four on every device, so the path
is only taken by a float format on a driver without its linear extension.

## What is not here
* **Write masks, sRGB, packed formats, depth and the 3-component formats** are unchanged: refused at
  `formatFor`, which is the same refusal as before for a format the port cannot hold.
* `MTLPixelFormat*Float` themselves are constants of the header and were already header-ok; what this
  file records is the behaviour behind them, which is the texture a descriptor of that format makes.
