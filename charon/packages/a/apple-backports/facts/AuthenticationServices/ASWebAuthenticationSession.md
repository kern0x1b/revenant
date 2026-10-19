# Signing in through a web page, iOS 12.0

`ASWebAuthenticationSession` came in iOS 12.0 as the successor of the iOS 11
`SFAuthenticationSession`: an application hands it the address of a login page and
the scheme its own redirect uses, and gets the redirect back as a URL.

Source: AuthenticationServices of the arm64 shared cache of iOS 12.0 -
`-[ASWebAuthenticationSession initWithURL:callbackURLScheme:completionHandler:]`
at `0x1aa076000` and its block at `0x1aa076128`, `-start` at `0x1aa076200`,
`-cancel` at `0x1aa076218`, and the string of the error domain at `0x1aa07c65e`. An
iPad 2 running 6.1.3, with the page and the redirect served from the loopback
address by `tests/backports/device/aswebauth.m`.

## What it is

The class is a wrapper. It holds one `SFAuthenticationSession`, made from the same
URL and scheme with a handler of its own, and `-start` and `-cancel` call the
session's. The handler of the wrapper does one thing to what it is given: the URL
goes on as it is, and if there is an error, whatever its code, the application
gets a new error of `ASWebAuthenticationSessionErrorDomain`
(`com.apple.AuthenticationServices.WebAuthenticationSession`) with the code 1,
`ASWebAuthenticationSessionErrorCodeCanceledLogin`, and no user info. A `nil`
handler is not called.

This package has `SFAuthenticationSession` already, in `libSafariServicesBackports`,
over a page that the `UIWebView` of the release draws in bars of its own, so the
wrapper is the same few lines over it, and it is built with the
`authenticationservices` config, which brings that library.

## Where iOS 6 differs

- iOS 12 starts the session through `-startASWebAuthenticationSession`, a method of
  the wrapped class that this release does not have. `-start` of the session is
  used, the one iOS 11 has. What that method does differently in iOS 12 is not
  read here.
- The session shows the page over the top view controller of the key window, as
  `SFAuthenticationSession` does. There is no system sheet, no
  "wants to use ... to sign in" prompt and no shared login state with Safari, so
  cookies of the page are the application's own.

## Not carried

The credential provider extension and the credential identity store of iOS 12
(`ASCredentialIdentityStore` and its state, `ASCredentialProviderViewController`,
`ASCredentialProviderExtensionContext`, `ASCredentialServiceIdentifier`,
`ASPasswordCredential` and `ASPasswordCredentialIdentity`, with their error
domains) are absent: there is no AutoFill of the system to consult them, and a
password that looked stored would mislead.

## What iOS 13 added to the session

- `presentationContextProvider` is kept and read back, weakly, as the release holds it. `-start` sends it
  `presentationAnchorForWebAuthenticationSession:` when it responds to the selector, and, if the answer is
  non-nil, presents the page over that window instead of the key window - `SFAuthenticationSession`'s own
  `charon_presentationWindow` hook, already built for exactly this and unused until now. This was carried
  `inert` for a time on the theory that a single-window device makes the question pointless, which mistakes
  "the answer is almost always the key window" for "the question need not be asked": an application that
  keeps a second, non-key window around (a picture-in-picture overlay, a window it is mid-transition to)
  and names it through the provider gets that window, not a guess. iOS 13 also raises when a session is
  started without a provider at all; this port does not - a session with no provider, or one whose provider
  returns `nil`, still starts over the key window, since one window is always available to fall back to on
  this release.
- `canStart` answers `YES` until the session has been started or cancelled and `NO` after. It is read from
  the port's own state: `SFAuthenticationSession`, which this session wraps, has nothing to ask. `-start`
  and `-cancel` behave exactly as they did before, and only record that the session has been spent.
- `prefersEphemeralWebBrowserSession` is a real, settable `BOOL` and `-start` acts on it (below). It was
  carried absent for a time on the theory that "the release has no private browsing mode" was a wall; it
  is not one, only more work than the property's own getter/setter, and the coordinator's 2026-09-22
  ruling that difficulty is not a wall is what reopened it.

## The ephemeral session

This release has exactly one cookie jar per process and no store per web view: the selector table of
6.1.3 has `_cookieStorage`, `_cf2nsCookies:` and `_ns2cfCookies:`, the single CFNetwork-to-Foundation
bridge, and has no `websiteDataStore`, no `ephemeralDataStore` and no non-persistent web data store of any
kind - the only `nonPersistent` names in the release are about keychain credentials, not the web. A
`UIWebView` has nothing to read cookies from except that one jar, so isolating a sign-in flow means
emptying the jar for the flow's duration, not switching to a private store; the session is modal and the
phone runs one application at a time, so nothing else reads the jar meanwhile.

**The journal.** Save-the-jar-empty-it-put-it-back makes every cookie the application owns depend on the
process surviving the login; on a 282 MB jetsam ceiling being killed mid-flow is ordinary. `-start`, when
`prefersEphemeralWebBrowserSession` is set, first serializes `NSHTTPCookieStorage`'s cookies (their
`.properties`, a plist-safe dictionary each) to a binary plist under `NSApplicationSupportDirectory`,
empties the jar, then starts the wrapped session. The completion handler, `-cancel`, and a failed `-start`
all restore from that journal and delete it - whichever of the three ends the flow, the jar goes back to
what it held before, discarding whatever the sign-in page itself set. A `constructor` function runs at
image load, before any application code, and restores a leftover journal if one is found: a kill mid-flow
costs a restart, not the cookies.

**The URL cache.** `[NSURLCache sharedURLCache] removeAllCachedResponses]` is called once the flow ends,
alongside the cookie restore. It needs no journal of its own: losing a cached response only costs a
re-fetch, never a lost session, so what the flow cached (and, as a side effect, whatever else was cached at
the time) is discarded rather than snapshotted and put back.

**What is still not isolated, and is not claimed to be.** The property promises an ephemeral *browsing
session*, not ephemeral cookies: `localStorage` and WebSQL databases are part of what a sign-in leaves
behind, and `UIWebView` keeps those in its own directories, not the cookie jar or the URL cache. Isolating
them would mean snapshotting and restoring those directories too, which this does not do. A port built on
this must not describe the session as fully ephemeral without that caveat - only cookies and the URL cache
are isolated, exactly as this property backs onto for a `UIWebView`-drawn page.

**What was not measured.** The journal and the constructor's recovery path were written against the same
`NSHTTPCookieStorage`/`NSPropertyListSerialization`/`NSURLCache` API this file already used or that iOS 6
has carried since its first release; no device run exercised a real jetsam kill mid-flow to confirm the
constructor's recovery path fires correctly at the next launch. That is reasoned, not measured, and is
recorded here as exactly that.
