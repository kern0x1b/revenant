# SFSafariViewController, iOS 9

Introduced in iOS 9: a view controller that shows a web page in Safari's own bars, in a process of its own, with the
owner's cookies, saved passwords and content blockers. iOS 11 added the configuration and the dismiss button style,
iOS 14 the delegate's word that the page is about to open in the browser, and iOS 15 the prewarming of connections and
the activity button of an extension.

Source: the newest header of the SDK for the interface, and the host's own SafariServices for what a controller answers
before it is shown. The `safariviewcontroller` group of `tests/backports/host/uikit2/run.sh` compiles the port with its
names changed and puts it beside the system's classes: which addresses are refused and with what words, what the
initializers do for no address or no configuration, the copying of a configuration, the state of a new controller, the
tokens, and the archiving of an activity button all answer alike (41 checks). `device/safariviewcontroller.m` shows the
controller in an application on an iPad 2 against a small server on the loopback address. The shared caches of iOS 6.0
and 7.0 have no SafariServices.

## What the port does as the system does

Only `http` and `https` addresses are accepted, in any case; any other, and no address, raises
`NSInvalidArgumentException` with the system's words. `-init`, `-new`, a nib and a coder raise `NSGenericException` with
the system's words. `-initWithURL:entersReaderIfAvailable:` and `-initWithURL:` take the configuration they imply, and a
configuration is copied when it is given, so a change to it afterwards is not seen; given none, the controller has none.
The controller is not loaded until it is shown, and nothing is asked of the delegate before then.

Once shown, it loads the address and tells the delegate that the initial load completed - once, with success, or with
failure when the page cannot be reached, in which case the page shows the error. A move to another address that nobody
asked for - a redirect of the server, or a script - is reported to `safariViewController:initialLoadDidRedirectToURL:`,
before the load completes when it is a redirect of the initial load and after it when the page moves later; a tap on a
link, a form, going back or forward, and a move to another fragment of the page are not. The dismiss button (Done, Close
or Cancel, by `dismissButtonStyle`) dismisses the controller and then tells the delegate it finished; dismissing it
from the application does not tell the delegate. The action button asks the delegate for the activities to add and for
the types to leave out, with the address and the title of the page, and shows the sheet of the release. The button that
opens the page in the browser tells the delegate first. `preferredBarTintColor` and `preferredControlTintColor` colour
the bars and their buttons. A link to another scheme - `tel:`, `mailto:`, an application's own - is handed to the
application when the release can open it.

## What it cannot do

The page is drawn by the `UIWebView` of the release, in bars of the application's own, in the process of the
application. It shares no cookies, passwords or autofill with Safari, has no content blockers, no Reader (the flag is
kept and nothing is shown), no bar collapsing, no lock in the address, no request for the desktop site, no bookmarks or
reading list, and no activity button of an extension (the button is kept and not shown), and pages that need what the
`UIWebView` of the release lacks are drawn as it draws them. Prewarming answers a token and prewarms nothing. The
address shown is the host name. The modal style is full screen on a phone and a form sheet on a pad; the system's
default on the host (a Mac) is not a phone's. The dismiss style is `Done` by default, as the header says; the host
answers `Close`, since a Mac has no Done. A controller pushed on a navigation controller is popped by the dismiss
button. The classes of iOS 17 (`SFSafariViewControllerDataStore`) and the authentication session (`SFAuthenticationSession`)
are not carried.
