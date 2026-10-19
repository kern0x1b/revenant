# Device checks

Numbers, on the phone, repeatable - because a screenshot is not a measurement
and one run is not evidence.

```sh
charon test --tier gate                      # every page, verdict per check
charon test --tier gate --test-port 8898     # if 8899 is busy
```

The device cannot be asked for its DOM, so each page reports itself: the runner
serves these pages over plain HTTP and reads the verdicts out of that server's
own request log. A page that reports nothing is a failure, not an absence.

Each page gets a fresh browser: asking a busy Safari to open another URL is
unreliable here, and that made a flaky runner look like a flaky engine.

| Page | What it pins down |
| --- | --- |
| `text-and-emoji.html` | joined emoji compose into one glyph, skin tones compose, ICU's grapheme rules agree, the system font and `sans-serif` both answer `font-weight` |
| `gradients-and-blends.html` | a gradient fading to transparent keeps its hue; every blend mode, including the four non-separable ones, is implemented by this CoreGraphics - measured through a canvas |
| `image-draw-cost.html` | what six hundred cropped draws of one decoded image cost, in milliseconds - the price of purgeable decoded images |
| `svg-image-filters.html` | a filter inside an SVG loaded through `<img>`: saturate in linear light, saturate in sRGB, and three exactness checks |
| `web-platform.html` | the APIs a page written this decade reaches for, including WebAssembly running a module and WebGL drawing a triangle - see below |
| `websocket.html` | a `ws://` and a `wss://` connection to this runner's own server fail cleanly instead of taking the browser down - opening one reaches CFNetwork calls this system may not have |

Composition can only be measured with a font that has the sequences to compose,
which the font iOS 6 shipped in 2013 does not: it predates skin tone modifiers
and every ZWJ sequence on the page. `emoji-font-covers-these-sequences` states
that dependency once - it measures the font, not the engine - so a device
without a newer emoji font fails it and the three composition checks together,
and the page says why. Grapheme rules and `font-weight` need nothing from the
font.

Today: **57 pass, 0 fail**.

Memory is measured separately, over repeated cold runs, by the harness in the
session notes rather than from here: dirty pages are a property of a process's
whole life, not of one page.

## Known limitations, as of 2026-09-09

`mix-blend-mode: hue | saturation | color | luminosity` on an **element** is
drawn unblended. A page cannot read it, so it was measured from a screenshot: a
multiply and a hue over the same orange, `/usr/bin/shot` for the screen, and the
two halves read off the PNG.

The result is the discriminator this had been missing:

- **multiply reads 56,80,24 - exact.** So the element blend path works, and the
  engine reaches CoreGraphics with the mode.
- **hue reads 64,128,192** - the source colour, no blending at all.

Everything else has been eliminated, each by measurement:

- **The platform implements the four modes.** Orange filled, `kCGBlendModeHue`
  set, a transparency layer begun, blue filled and the layer ended, in a
  device-RGB bitmap and again through a `CGLayer`: 105,180,255 both times. (There is no `kCGColorSpaceSRGB` by name on this release.)
- **The box is not composited.** Its layer and its parent's both report no
  backing at the moment the transparency layer is begun, so this is not a layer
  blending against an empty backdrop, and not the missing CoreAnimation filter
  types either - the layer path never runs.
- **The engine asks for the right mode on the right context.** The same
  `GraphicsContext` that paints the box is told mode Hue immediately before the
  transparency layer begins.
- **Re-applying the mode before `CGContextEndTransparencyLayer` changes
  nothing**, so it is not about when CG captures the mode.
- Reading the state inside `beginTransparencyLayer` shows Normal, but that
  proves nothing: `GraphicsContextState::repurpose` resets the composite mode on
  CG by design, because `CGContextBeginTransparencyLayer` starts the layer's
  contents fresh. The CGContext itself still carries Hue at that point.

What is left is the destination: the tile Safari paints into is not a bitmap
context - `CGContextGetType` says 0 and it has no bitmap colour space - and this
CoreGraphics honours the separable modes there and drops the others. That is
consistent with how the two kinds differ: a separable mode is per-channel
arithmetic, while hue, saturation, colour and luminosity need a colour space to
decompose the pixels into, and this context has none that CG will name.

Which is why this stops here rather than continuing. Making it work means not
using CG for the composite at all: rendering the group into an offscreen bitmap,
reading the backdrop back, blending in software and writing the result - which is
what the ports without colour management do, and which costs a read-back per
blended element on a phone where a full-screen read-back is already expensive.
For a CSS feature this rare on this hardware, that is not a trade worth making
without someone asking for it.

One attempt is recorded so it is not repeated: skipping the transparency layer
and blending the fill directly crashes the browser, because the paint that ends
the layer is elsewhere and the counts stop matching. If anyone tries it, both
halves have to move together.

## The filter brightness, and how it was closed

An SVG filter that reads pixels used to come out one gamma encode too bright
through `<img>`: `192,64,64` read back as `225,137,137`, and `64/255` encoded as
sRGB is `137.6`. The engine already had the answer under `USE(CAIRO)`: where the
graphics library cannot convert while painting, the filter's source buffer is
made in sRGB and the engine converts it into the operating space itself. This
CoreGraphics matches colour spaces by primaries and ignores transfer functions,
so linearRGB and sRGB are the same `CGColorSpace` here and it belongs on that
path. It now takes it, and the three checks read 109, 92 and 192,64,64 exactly.

What has been ruled out, so nobody pays for it twice:

- **The linear-light conversion.** Compiled out, both symptoms were unchanged -
  which was true and misleading: the conversion was not wrong, it was never
  reached, because the source buffer was already tagged with the space it was
  being asked to convert to.
- **Colour space tags.** Beaconed at the effect: source, result and buffer are
  all linearRGB, and no conversion runs anywhere in between.
- **CoreGraphics matching.** linearRGB and sRGB resolve to the same
  `CGColorSpace` on this port, so CG has nothing to convert between.
- **Filters in general.** A plain `<svg>` rect through `<img>` reads
  192,64,64 exactly, and so does one carrying `feOffset`. Only the effects that
  read and write pixels - `feColorMatrix` and its kin - come out bright.
- **Two repair attempts that crashed**: copying the borrowed source buffer with
  the filter's allocator (wrong resolution scale) and with `ImageBuffer::clone()`.
  Restoring the source buffer's colour space after the filter chain changed no
  measured number.

What is left to look at: the one gamma encode that happens between the buffer an
SVG image is rasterised into and the canvas it is drawn onto, on the pixel-reading
effect path only.

## web-platform.html — what a page written this decade can ask for

Twenty-nine checks over the APIs a modern site reaches for, run by `run.py` like
the rest. It exists because of the failure that wrote it: `window.WebAssembly`
was installed by a swizzle that won its race only sometimes, and when it lost,
every site behind an AWS WAF challenge rendered one sentence about attempts
exceeded. Nothing in the suite was false, no console error was printed, and the
page simply did not appear. A missing global is now a failing check.

Two of them are not presence checks. `wasm-runs-a-module` instantiates a
two-parameter module and adds 40 and 2, because a `WebAssembly` object that
cannot run anything is the same failure with a different shape.
`backdrop-filter-bar-is-opaque` asserts the rule this port applies in place of a
filter it cannot honour.

`crypto-subtle` passes when the page is not a secure context, which is what the
runner serves: the specification exposes it to secure contexts only, and the
check says so rather than reporting a hole that is not there.

## gl-present.py — the canvas the GPU drew, on the screen

Every WebGL check in `web-platform.html` passes by reading pixels back out of
the context, and all of them passed while the canvas on screen was a white
rectangle: reading back and presenting are different paths, and only one of them
was working. This loads a canvas cleared to red and looks at the screen.

```sh
tests/device/gl-present.py
```

It prints how much of the page area is red and exits non-zero when the answer is
`absent`. The screenshot stays in `tests/device/sweep-shots/gl-present.png`.

## conformance.py — Khronos' suite, on the phone

The suite is not vendored here; it is a project of its own and is cloned
separately:

```sh
git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/KhronosGroup/WebGL.git webgl-conformance
cd webgl-conformance && git sparse-checkout set sdk/tests
```

Then name the tests to run; `WEBGL_TESTS` points at the checkout if it is not
in `~/Git/tools/webgl-conformance/sdk/tests`:

```sh
tests/device/conformance.py conformance/rendering/culling.html
```

Each test writes its own PASS and FAIL lines into its page, so
`conformance-runner.html` loads them one at a time in an iframe and reads those
lines back out. Two things about reading the result: a test's FAIL line states
the *expectation*, and the values actually read are on the line after it, which
the runner now includes. What has been run so far, and the two failures left,
are in [../../docs/webgl.md](../../docs/webgl.md).

## gl-frame-rate.py — a canvas that keeps drawing, and how fast

Everything else about WebGL here is measured on one frame, and one frame hid a
freeze: with no `CVOpenGLESTextureCacheFlush` the cache kept every IOSurface
alive, WebKit rebuilt the drawing buffer every frame, and the web thread stopped
answering after the first one - no crash and no log line.

```sh
tests/device/gl-frame-rate.py
```

It animates for four seconds at each of three canvas sizes and prints the rate,
exiting non-zero if the last size never reports - which is what a freeze looks
like. Today: **29, 30 and 28 frames a second** at 64x64, 320x240 and 320x480,
which says the cost is per frame rather than per pixel.

## share-sheet.py — navigator.share, which needs a finger and a secure page

Two things keep this out of `run.py`: the API is exposed to secure contexts only,
and calling it needs a user gesture. Both are solvable on this device. The page
is served through a reverse SSH tunnel so it arrives at `http://localhost`, which
is a secure context, and `revtouch` taps the button and then the sheet's Cancel.

```sh
tests/device/share-sheet.py
```

It prints what the page saw on load and after cancelling, and exits non-zero
unless the promise rejects with `AbortError`, which is what the specification
asks for when the sheet is dismissed. The screenshot of the open sheet stays in
`tests/device/sweep-shots/share-sheet.png`.

## sweep.py — the same engine against the web as it is served

`run.py` measures the engine against numbers it can check itself. Some failures
never appear that way: an anti-bot challenge that needs an API the port does not
have looks like a blank page and nothing else. `sweep.py` loads real sites, one
browser per site, and reports four things per page:

```
tests/device/sweep.py https://example.org/   # the sites you name
tests/device/sweep.py                        # or a list in sweep-sites.txt, which is yours and gitignored
```

It ships with no list of its own. Which sites a browser here is driven at from
an automated run is the operator's call and the operator's business with those
sites' terms, not something this repository decides. Everything `run.py` loads
is served out of this directory.

| Column | What it means |
| --- | --- |
| `ALIVE` | the browser survived the load — a `killall -0`, because this device has no `ps` |
| `CRASH` | how many times the crash handler fired during the load |
| `PAINTED` | how much of the page area the screenshot drew, `blank` under 1% |
| `DIRTY` | the process's dirty memory, which is what jetsam judges by |

Screenshots go to `tests/device/sweep-shots/` (gitignored), so a verdict that
looks wrong can be looked at.

**The device is not a Unix box.** It carries `sed`, `grep`, `xargs`, `cat`, `ls`,
`killall`, and the port's own tools — and nothing else. No `ps`, `head`, `tail`,
`wc`, `cut`, `awk` or `sort`. A pipeline through any of those quietly produces
nothing, which reads as "the process is gone" and has been mistaken for a crash
more than once.
