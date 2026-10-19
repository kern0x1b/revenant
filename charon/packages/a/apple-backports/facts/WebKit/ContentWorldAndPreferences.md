# Content worlds and webpage preferences on a 2012 web engine

Source: the WebKit headers of SDK 16.4 for the declarations, and the armv7
shared cache of 6.1.3 for what the release's script engine has. The engine was
read by the strings of the cache, held against the same probes on the cache of
9.3.

## The script engine has no Promise, and that decides one API

`-[WKUserContentController addScriptMessageHandlerWithReply:contentWorld:name:]`
exists so that `window.webkit.messageHandlers.<name>.postMessage()` answers a
**JavaScript Promise** the page awaits. That is the whole of the API: without a
Promise there is nowhere for the reply to go.

The JavaScriptCore of 6.1.3 has none. The armv7 shared cache of the release
holds the string `Promise` exactly twice, and both are the Objective-C selector
`initWithDataPromise:` of a system class, unrelated to JavaScript. It holds
`JSPromise`, `PromiseConstructor` and `promiseCapability` not at all, and
`WeakMap` not at all; the same probes on the armv7 cache of 9.3, a release whose
engine does have promises, answer 657 and 44. `ArrayBuffer` and `Int32Array` are
there in 6.1.3, so the probe is finding the engine - it is the promises that are
missing, not the strings.

So the reply API is absent, and its delegate method with it. An application that
asks for it sees `respondsToSelector:` answer NO and can fall back to
`-addScriptMessageHandler:name:`, which this package carries and which needs no
Promise. A handler that could be registered but never replied to would be worse
than one that is not there.

## Content worlds are names, not separate contexts

`WKContentWorld` is carried, because an application that links it holds a strong
reference to the class symbol and a missing class is a launch that does not
happen rather than a call that fails.

What it carries is the identity: `+pageWorld` and `+defaultClientWorld` are each
one object for the process, `+worldWithName:` answers the same object for the
same name, and `-name` gives the name for a named world and `nil` for the two
standard ones. That is all measurable behaviour and all of it is here.

What a world *stands for* - a JavaScript context separate from the page's - the
release does not have. Its UIWebView runs one context per frame, so a script the
application injects and the page's own scripts share globals whichever world is
named. An application that uses worlds to keep its names from colliding with a
page's will collide; one that uses them only to address handlers will not
notice. `-removeScriptMessageHandlerForName:contentWorld:` therefore removes by
name and does not read the world, since the handlers are kept in one table.

## Webpage preferences are kept and change nothing

`WKWebpagePreferences` is carried and keeps its `preferredContentMode`, which
starts at `WKContentModeRecommended` as in the release. It changes nothing: this
release has one renderer, the UIWebView of 2012, which lays a page out as a
phone and has no desktop mode to switch to. The first mode set says so once in
the log.

`WKWebViewConfiguration.defaultWebpagePreferences` makes a preferences object on
first read and keeps it, and it can be replaced; setting `nil` gives a fresh
one, as the release does. It is held beside the configuration with an associated
object rather than inside it, because the configuration is an earlier release's
object of this package, so a copy of the configuration does not carry it.
