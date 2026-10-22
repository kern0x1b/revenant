# The large members still open for Telegram

What the demand map (`docs/guides/backports/demand.md`) still reports as missing, after the UniformTypeIdentifiers,
CryptoKit, QuartzCore protocol, UserNotifications and NaturalLanguage groups. Each entry says what exists now, what
the member needs, and what has to be decided before anyone starts. Nothing here is implemented.

## Metal

Missing for Telegram: `MTLDevice` (37 files), `MTLTexture` (31), `MTLLibrary` (21), `MTLRenderPipelineState` (21),
`MTLCommandBuffer` (16), `MTLBuffer` (11), `MTLComputePipelineState` (11), `MTLCommandQueue` (10),
`MTLRenderCommandEncoder` (7), `MTLDrawable` (4).

What exists: `frameworks/Backports/src/Metal` has 84 files, mostly the iOS 9 to 26 classes (`CAMetalLayer` extensions,
the `MTL4*` family, `MTLArgumentBinding`) and a Metal-specific `RevenantMetal26Types.h`. None of the protocols above
is declared for iOS 6, so a `MTLDevice` reference fails at the point where it is used.

Design, to decide before building:

- The device has OpenGL ES 2.0 and no Metal. The WebKit port already runs a GL ES 2 backend over EAGL for WebGL
  (`docs/explanation/webkit/webgl.md`), so the Metal backport should reuse the same `EAGLContext` path rather than add
  a second one. A `MTLRenderPipelineState` becomes a GL program; `MTLBuffer` and `MTLTexture` become GL objects.
- Shaders are the hard part. Telegram's shader source is Metal Shading Language, which the device cannot compile. The
  repository has the air2cpu route (`frameworks/Backports/src/air2cpu-abi.h`, the `air2cpu` option): AIR from the
  Metal compiler becomes a C kernel table that runs on the CPU. That covers compute kernels. Render shaders need an
  MSL to GLSL ES 1.00 translation, and no translator is in the tree. This is the first decision: translate offline
  (a new tool), or give render pipelines a loud stub and keep compute on the CPU path.
- `MTLCommandBuffer` and `MTLCommandQueue` can be emulated over a GL context's command order, but completion handlers
  and `waitUntilCompleted` then mean `glFinish`, which costs a frame on this GPU. The backport must say so in its docs.

## WebKit (`WK*`)

Missing for Telegram: `WKNavigationDelegate` (8 files), `WKScriptMessageHandler` (7), `WKUIDelegate` (4),
`WKSecurityOrigin` (4), `WKWindowFeatures` (4), `WKDownload` (3), `WKSnapshotConfiguration` (3), `WKDownloadDelegate` (2).

What exists: `frameworks/Backports/src/WebKit` has 17 files: `WKNavigation`, `WKBackForwardList`,
`WKUserContentController`, `WKContentRuleList`, `WKContentWorld` and the `WKWebExtension*` family. `WKWebView` itself
is not among them.

Why the demand map cannot see the engine: `packages/w/webkit/xmake.lua` declares the package
`set_kind("library", {headeronly = true})` and its description says "its sources only". That is deliberate: the package
checks out and patches the WebKit tree, and `frameworks/WebKit` builds the engine from it with CMake. So the
installed `webkit` package has no libraries because it was never meant to carry any. This is not a packaging error in
the recipe, but it leaves the demand map blind to the engine: nothing in the package's install tells the tool which
`WK*` members the engine provides. The fix is to give the engine build an install that the demand tool can read, which
is a decision about the WebKit build's outputs, not a change to the recipe.

Design, to decide before building:

- `WKNavigationDelegate`, `WKScriptMessageHandler`, `WKUIDelegate` and `WKDownloadDelegate` are protocols. Declaring
  them is the same work as the QuartzCore protocols (`frameworks/Backports/src/QuartzCore/QuartzCoreProtocols10.m`), but
  a conforming class can only be called if a `WKWebView` exists to call it. So the protocols wait on `WKWebView`.
- `WKWebView` needs an engine. On iOS 6 the system engine is `UIWebView`; the revenant engine is WebKit. The choice
  is between a `WKWebView` over `UIWebView` (what iOS 6 can do natively, with no `WKNavigation` callbacks for the
  navigation-policy and download paths) and a `WKWebView` over the revenant engine (complete, but it needs the engine
  installed on the device).

## AuthenticationServices

Missing for Telegram: `ASAuthorizationController` (5 files, a class), `ASAuthorizationControllerDelegate` (5),
`ASAuthorizationControllerPresentationContextProviding` (5), `ASAuthorizationAppleIDButton` (2),
`ASAuthorizationPlatformPublicKeyCredentialProvider` (2), `ASAuthorizationCredential` (1).

What exists: `frameworks/Backports/src/AuthenticationServices` has 24 files: the request and credential classes
(`ASAuthorizationAppleIDProvider`, `ASAuthorizationAppleIDRequest`, `ASAuthorizationOpenIDRequest`) and their constants.
The controller that presents them is the missing part.

Design, to decide before building:

- Sign in with Apple is a web flow with a server-side token. On iOS 6 the controller can present that flow in a web view
  and return the authorization it gets back, but the identity token is only checked by Apple's server, so the backport
  can deliver a token and cannot verify it on the device. That limit goes in the docs.
- The web view is the same choice as `WKWebView` above. `RevenantCKWebAuth` (`frameworks/Backports/src/CloudKit/webauth`)
  already runs a web authentication for CloudKit, and it is the candidate to reuse.
- Passkeys (`ASAuthorizationPlatformPublicKeyCredentialProvider`) need a platform authenticator that iOS 6 does not
  have. That member gets a loud stub, named in the open gaps of `frameworks/Backports/README.md`, and no fake credential.
