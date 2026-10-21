# What works, and the Settings pane

The engine the phone ships with is WebKit 536 from 2012. It cannot render a page written this decade, and it cannot negotiate TLS with a current server. Each of those is fixed here, and the features are listed below, with the Settings pane.

## What works

- **Current WebKit**, built from source for armv7 with a 6.0 deployment target: current C++ compiled for a 2011 phone.
- **Real Mobile Safari on the new engine.** A MobileSubstrate tweak re-launches Safari with the engine forced
  underneath it; the user agent reports `AppleWebKit/605` instead of the stock `536`. UIKit's own gestures, scrolling
  and text selection are reused unchanged.
- **JavaScript with a JIT.** Upstream deleted the ARMv7 JIT; it is restored here, with the regressions that restoring it
  caused fixed as well ([the JIT](../../explanation/webkit/armv7-jit.md)).
- **TLS 1.2 and 1.3.** The system's TLS is from 2012 and current servers refuse its cipher suites. The port answers the
  system's TLS calls over OpenSSL, so the browser reaches sites the phone otherwise cannot open. Certificate
  verification is unchanged: the chain is evaluated by the system as a real `SecTrustRef`
  ([network](../../explanation/webkit/network.md)).
- **Web Crypto**, performed by WebKit's own OpenSSL backend rather than the Cocoa one, which works in CryptoKit and has no
  armv7 Swift: digests, HMAC, AES in GCM, CBC, CFB and CTR, AES key wrapping, HKDF, PBKDF2, ECDSA, ECDH, RSA-OAEP and
  RSASSA-PKCS1, all verified on the device.
- **WebAssembly** (via a bundled interpreter, since JSC's WASM is 64-bit only), **Web Notifications**, **getUserMedia**
  (camera and microphone), `<video>` MediaStream preview, and a wave of self-contained web APIs enabled by default.
- **WebGL.** `canvas.getContext("webgl")` returns a real context: shaders compile, and the GPU draws. Upstream's only GL
  backend goes through ANGLE's Metal renderer, which needs an A7, so this port carries an ANGLE backend on EAGL, the
  GLES API this hardware does have. WebGL 2.0 needs OpenGL ES 3.0 and this silicon is an ES 2.0 part; that is a ceiling,
  not a milestone ([WebGL](../../explanation/webkit/webgl.md)).
- **Web fonts and form controls.** Both were entirely absent rather than approximate: no `@font-face` had ever loaded a
  font in any format, and every button, field, checkbox and select was painted in a fully transparent colour. Sites now
  draw with their own typefaces and their controls can be read.
- **Scrolling inside a page.** Overflow blocks and frames are scrolled by the system's own `UIWebOverflowScrollView`, the
  way this release of iOS does it, which is what makes cookie dialogs and any other inner scroller usable.
- **The image formats the web actually serves.** WebP is decoded by WebKit's own decoder, since this ImageIO cannot. The
  formats that remain undecodable are no longer advertised to servers, which had been negotiating pictures the browser
  could not render.
- **Colour, measured rather than eyeballed.** Gradients interpolate premultiplied, every blend mode including the four
  non-separable ones is reached through CoreGraphics, and SVG filters interpolate in linear light and read back the
  numbers the specification asks for. This graphics library matches colour spaces by primaries and ignores transfer
  functions, so the engine performs those conversions itself, the way ports without colour management do.
- **Joined emoji shape as one glyph.** An astronaut, a family, a skin tone: one glyph each rather than their parts. What
  the device can *draw* is a question about the font it has, and the font stays where it is.
- **A native Settings pane** (`RevWebKit`), described below.

Correctness is checked by a numeric suite that runs on the device and reads pixels, glyph widths and the platform surface
rather than screenshots: `tests/device/run.lua`, currently **57 of 57**. Alongside it, `tests/device/sweep.lua` loads
real sites and reports whether each one survived, painted, and what it cost in memory. Both are described in
[the device suite](device-suite.md).

## How the features are carried

- **`navigator.share`** hands a title, a text and a URL to the system share sheet. The promise resolves when an activity
  ran, and rejects with `AbortError` when the sheet is cancelled. The sheet is presented on the main thread and the answer
  comes back on the web thread.
- **Clipboard.** `navigator.clipboard.writeText` writes an item dictionary through `-[UIPasteboard setItems:]`, with the
  types mapped to uniform type identifiers, so the copy is visible to the rest of the phone. Reading rejects with
  `NotAllowedError`, as the specification asks without a paste gesture.
- **`canPlayType()`** answers from AVFoundation's MIME types (`AVAssetMIMETypeCache`), not from a short list, so formats
  the framework plays are not refused.
- **Fonts.** `@font-face` loads through a data provider (`CGFontCreateWithDataProvider`), because the private CoreText
  parser that WebKit uses is not in iOS 6. The system parser does not read WOFF, so WebKit's own converter is compiled in
  for WOFF; WOFF2 uses the library built for armv7. Font features are translated to the numeric AAT pairs. A font with
  only OpenType tables does not get `font-variant-caps` small capitals, because this CoreText does not translate an AAT
  selector into a GSUB feature.
- **Favicons** are the page's own declared icons, not a third party's copy of them, so a start page does not disclose
  the hosts a user bookmarks.
- **Scrolling inside a page.** Overflow blocks and frames scroll with the finger: the embedder wraps each promoted layer
  in a `UIWebOverflowScrollView`, and frames are keyed by the element that owns them.
- **Web Crypto** performs ECDSA, ECDH, RSA-OAEP, RSASSA-PKCS1, PBKDF2 and AES-CBC, CFB and CTR, through WebKit's own
  OpenSSL backend, and AES-GCM, HMAC, HKDF and AES key wrapping on the same backend. Upstream routes all of them through
  CryptoKit, which has no armv7 target.
- **Console.** The Settings pane's Diagnostics switch sends what a page logs, uncaught errors included, to
  `/tmp/rev-safari-stderr.log` with file and line.
- **`requestIdleCallback`** is enabled; the engine implements it and this port had it off.
- **User agent.** The `Version` token is `18.7` (`Version/18.7 Mobile/15E148 Safari/604.1`), beside `AppleWebKit/605`.
  The 2012 token sent sites the workarounds written for the engine this one replaced, and the OS release it sits beside
  is frozen at 6.1.3.

## The jsc shell on the phone

`jsc` from trunk runs on the iPhone 4S, and it is a current engine, not a subset. A first probe printed:

```
private field: 5                                  // #x
optional chain: ok                                // ?. and ??
Object.groupBy: {"odd":[1,3],"even":[2,4]}        // ES2024
Array.fromAsync: function                          // ES2024
RegExp v flag: true                                // ES2024
Temporal: object                                   // ES2026
```

The first throughput numbers, with the JIT off (CLoop interpreter on the phone, JIT on the Mac). The comparison mixes
a 2011 CPU with the absence of a JIT, so it is an order of magnitude, not a JIT penalty:

| | iPhone 4S, CLoop | Mac, JIT |
|---|---|---|
| `fib(24)` | 97 ms | 3 ms |
| 2 M iteration loop | 2128 ms | 7 ms |

That is roughly a million simple JavaScript operations per second.

## The Settings pane

Installed as **`RevWebKit`** in the system Settings app, as a real PreferenceBundle. It writes the
`space.kern0x1b.rev` preferences domain that the engine reads:

- **Bookmarks start page.** A blank tab renders your Safari bookmarks as tiles. Turning it off collapses the rest.
- **Custom Home URL.** Open a fixed page on every new tab instead. A URL with no scheme is opened over `https`.
- **Per-App Injection.** A list of installed apps; the engine is injected only into the ones turned on (Safari by
  default). Injecting the engine into an arbitrary app is experimental and reversible: turn it off and respring.
- **Respring.** Restart SpringBoard from the pane.

<p align="center">
  <img src="screenshots/settings-revwebkit.png" alt="The RevWebKit settings pane" width="45%">
</p>
