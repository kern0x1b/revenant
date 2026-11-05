# How the engine gets underneath Safari

The phone's own Mobile Safari renders the modern web because the engine below it
is replaced at launch. Nothing of Safari's interface is reimplemented: every
gesture, scroll, text selection and keyboard behaviour is UIKit's, unchanged.

The proof it took is the user agent. iOS 6 reports `AppleWebKit/536`; with the
port loaded the same browser reports:

    Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X)
    AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148

## Why substitute rather than write a browser

A hand-written browser has to reimplement everything UIKit's `UIWebBrowserView`
already does, and then keep reimplementing it as new cases appear. Substituting
the engine underneath UIKit inherits all of that at once, and it is Apple's code
that keeps working.

## The three artifacts

The system engine lives in the dyld shared cache, not on disk, so there is no
file to replace — and replacing it system-wide would put a 2026 engine under
every process on the phone. Instead a loader is injected into the launching app,
points `DYLD_FRAMEWORK_PATH` / `DYLD_INSERT_LIBRARIES` at the port's build, and
re-execs. The second launch loads the new engine first.

| Artifact | On device | Built by | Role |
| --- | --- | --- | --- |
| Loader | `/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib` | `src/platform/safari/rev-safari-tweak.c`, the `RevSafari` target in the nested project `src/platform/safari/xmake.lua` | Reads the enabled-apps preference, re-execs an enabled app with the engine's `DYLD_*` set, skips SpringBoard |
| Engine | `/usr/lib/rev-fw/{JavaScriptCore,WebCore,WebKit}.framework` | the `webkit-engine` package, which lays it out under the system's names | The WebKit build itself |
| Compat | `/usr/lib/rev-safari-compat.dylib` | `src/platform/safari/safari-compat.mm`, the `rev-safari-compat` target in `xmake.lua` | The ABI iOS 6 predates, the bookmarks start page, WebAssembly, preference reads |

The table is the Safari substitution's. The WKWebView host loads a separate, prefixed build of the same engine, described in [The WKWebView host](#the-wkwebview-host).

### Framework names have to be the system's

UIKit asks for the frameworks by their system install names, so the build is laid
out under those names rather than its own:

| built as | installed as | install name |
|---|---|---|
| `WebKitLegacy.framework/WebKitLegacy` | `WebKit.framework/WebKit` | `/System/Library/PrivateFrameworks/WebKit.framework/WebKit` |
| `WebCore.framework/WebCore` | same | `/System/Library/PrivateFrameworks/WebCore.framework/WebCore` |
| `JavaScriptCore.framework/JavaScriptCore` | same | unchanged, already matches |

Cross-references between the three must use those same system paths, not
`@executable_path`, so that the substitution catches them too.

### Why the environment is set by the process itself

iOS 6's dyld ignores `LC_DYLD_ENVIRONMENT`, so the variables cannot be baked into
the executable, and SpringBoard passes no environment through. The loader sets
them and re-executes:

```c
if (!getenv("DYLD_FRAMEWORK_PATH")) {
    setenv("DYLD_FRAMEWORK_PATH", "/usr/lib/rev-fw", 1);
    execv(self, argv);
}
```

`execv` keeps the pid, so SpringBoard's launch handshake survives.

### Why the namespace is flat

iOS 6 exported the Objective-C DOM (`DOMElement` and 16 siblings) from WebCore;
2.54 moved those classes to WebKitLegacy. UIKit's undefined symbols record which
library is expected to supply each one, so under the normal two-level namespace
dyld looks for `DOMElement` in our WebCore and does not find it.
`DYLD_FORCE_FLAT_NAMESPACE=1` drops the library ordinal and lets any loaded image
satisfy the symbol.

## Two WebKits in one process

Before the substitution existed, the port ran as an ordinary app that also linked
UIKit — and UIKit pulls in the system WebKit for `UIWebView`. dyld loads
dependencies before the app's own frameworks, so iOS 6's classes registered first
and the port's lost:

```
objc[9248]: Class WebPreferences is implemented in both
  /System/Library/PrivateFrameworks/WebKit.framework/WebKit and
  .../Frameworks/WebKitLegacy.framework/WebKitLegacy.
  One of the two will be used. Which one is undefined.
```

221 classes collided: 88 `Web*` against the system `WebKit.framework`, and 133
more — the whole `DOM*` binding surface plus `WAK*`, `WebEvent`,
`WebScriptObject`, `WebLayer`, `WebAccessibilityObjectWrapper` — against the
system `WebCore.framework`. Every `[WebView …]` call then landed in a 2012
implementation while 2026 C++ expected a 2026 object layout, and the process died
with SIGBUS inside `WebKitInitialize()`.

The answer was a prefix: `src/compat/stubs/ios6_class_prefix.h` renames the colliding
classes, force-included into every compile. Four places look a class up by name
rather than by identifier, where a macro cannot reach inside a string literal, and
use `IOS6_CLASS_NAME(x)` instead:

- `WebCore/bridge/objc/objc_runtime.mm` — `WebScriptObject`, `WebUndefined`
- `WebCore/accessibility/ios/WebAccessibilityObjectWrapperIOS.mm` — `WebView`
- `WebCore/testing/Internals.mm` — `WebCoreBundleFinder`

Under substitution the system engine is never loaded, so there is nothing to
collide with and UIKit needs the classes under their real names — it links
`_OBJC_CLASS_$_WebView`, not the prefixed spelling. That is why the shipped build
is configured without the prefix; the prefix header remains for any build that has
to share a process with the system engine.

The prefix renames classes, not the selectors of categories, and one category
matters. iOS 6's UIKit measures and draws strings through methods the system
WebKit adds to `NSString` (the `_web_draw…` and `_web_size…` family), and a
category loaded from the port's WebKitLegacy replaces those methods
process-wide: with both engines in one process every UIKit label, text field
and the status bar draw nothing, while web text is fine. So
`WebNSStringExtrasIOS6.mm` renames its eight drawing and measuring selectors to
`Rev…` when `IOS6_CLASS_PREFIX_H` is defined; under substitution the real names
stay, because there they are meant to replace the system's. A new category
method on a system class in the prefixed build needs the same treatment.

## The WKWebView host

Apps that use `WKWebView` do not go through the Safari substitution. The backport's
`WKWebView` runs its own host on the same engine: a prefixed (`Rev*`) WebKit1 build
that the `org.revenant.webkit-engine` package installs under
`/usr/lib/revenant/webkit-engine/`. `RevenantWebEngine` opens each framework with
`dlopen`, resolves the C symbols with `dlsym` and looks classes up by name, so the
backport links no engine symbol. `REVENANT_WEBKIT_ENGINE` names another folder. When
the engine is missing, the host raises an error that names the folder it expected.

`RevenantEngineHost` owns the engine's view and window, and a scroll view that
scrolls the page. The host connects to the engine in four places:

- **Screen.** `RevenantUIKitDelegate` is the engine's UIKit delegate. The engine calls it on its web thread, and the root layer and content size reach the host on the main thread. The other callbacks are declared and do nothing.
- **Scrolling.** The scroll view's offset becomes the window's exposed rect, set on the web thread. The document's height sets the scroll content size. Once the page has grown past the viewport, its tallest height is kept, so a page that shrinks while it loads does not jump back.
- **Touch.** `RevenantContentScrollView` passes each touch phase to the host after UIKit has seen it. The host sends a touch event to the engine's window on the web thread. A touch the page does not handle becomes a mouse click.
- **Keyboard.** The host is the engine's form delegate. A focused field raises the keyboard through `RevenantKeyInputView`, a view that is never shown and takes the keyboard's input. Typing sets the field's value and fires `input`, and return fires `change`, both on the web thread, so the page's own handlers run.

**Threads.** The engine runs the page on its web thread. The navigation policy and frame-load delegate calls are made from WebCore on that thread: `WebFrameLoaderClient.mm` calls the policy forwarder (lines 874 to 938) and the frame-load callbacks (lines 676 to 780) directly, with no hop to the main thread. The web thread holds the engine's recursive lock (`webLock`, `WebCoreThread.mm`) while it runs them. The host takes the same lock on the main thread, through `RevenantWithWebLock`, around each synchronous engine call and around the state a navigation changes. On the main thread the take is released at the end of the run loop turn (`MainRunLoopAutoUnlock`, `WebCoreThread.mm`), so `WebThreadUnlock` does nothing. The navigation delegate's decisions that the app makes synchronously run under the lock, as WebKit's own delegate calls do, so a decision that waits on the web thread would deadlock. The thread of each callback is read from the pinned source (c70a794), not measured on a device.

These paths compile and link into `libWebKitBackports.dylib` for armv7. They have not
yet run against a built engine on a device.

## What UIKit actually needs from an engine

Measured from the shared cache rather than guessed: across the 18 system libraries
that import from WebKit, WebCore and JavaScriptCore, 147 symbols are imported in
total, and UIKit itself uses 80. `xmake firmware extract` and `xmake firmware classes`
of the toolchain read the cache and the classes it holds, which is where these counts come from.

One thing is not a symbol: UIKit gets its `WKWindowRef` by sending
`-[WAKWindow _windowRef]`, an accessor 2.54 dropped along with the C window layer.
Restoring it was the last step before the first successful load.

## Related

- [compatibility.md](../../reference/webkit/compatibility.md) — the API this OS does not have, how each gap is answered, and the rule every shim answers to
- [memory-and-caches.md](memory-and-caches.md) — what 512 MB forces
- [core-update.md](core-update.md) — moving the port to a newer engine branch
- [network.md](network.md) — the TLS and HTTP layers this port brings with it
