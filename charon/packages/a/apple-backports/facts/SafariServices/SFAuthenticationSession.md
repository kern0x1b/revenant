# SFAuthenticationSession, iOS 11

Introduced in iOS 11 and deprecated in 12 for `ASWebAuthenticationSession`: a way to sign the owner in to a web service. The
application gives the address of the login page and the scheme of the address the service will send the owner on to;
the system shows the page, and when the page goes to the callback scheme it hands that address to the completion handler.

Source: the newest header of the SDK, and the host's own SafariServices. The `safariviewcontroller` group of
`tests/backports/host/uikit2/run.sh` holds what a session answers when it is made, started and started twice, and the
words of the error, against the port (the system draws nothing on the host, so what it does with a page is not there to
read). `device/safariviewcontroller.m` shows the sessions on an iPad 2 against a small server on the loopback address.

## What the port does as the system does

Nothing is checked when the session is made, `-init` makes one that has nothing to load, `-start` answers YES once and NO while the session
runs, `-cancel` before it starts does nothing, and the error is `com.apple.SafariServices.Authentication` code 1
(`SFAuthenticationErrorCanceledLogin`) with no user info. Starting a session ends the one that was showing, with that
error. The page is shown over the top view controller of the key window, as an `SFSafariViewController` with a Cancel
button; when the page - or a redirect of the server, or a script - goes to the callback scheme, in any case, the page is
dismissed and the handler is given the address as the web view has it (its scheme in lower case), with no error. A redirect to a scheme nobody handles fails the load, and the failing address is taken as the callback. Cancel, and `-cancel` from the application, dismiss
the page and give the canceled-login error, after the dismissal. Without a callback scheme the schemes the application
declares in `CFBundleURLTypes` are taken. An address that is not a web address, or no window to show the page over, ends the
session at once with the canceled-login error. A session that has ended can be started again.

## What it cannot do

The page is the `UIWebView` of the release, so the owner's logins in Safari are not shared, and there is no request
for consent to share them; the owner signs in again in every session, and what the service remembers is what the
application's own cookie storage remembers. The callback is taken from the navigation of the page, not from a
launch of the application by the address, so a service that sends the owner to Safari to finish, or to an application
that is not this one, cannot end a session. What the system does when it has no window is not read: the host has no
place to show a page.
