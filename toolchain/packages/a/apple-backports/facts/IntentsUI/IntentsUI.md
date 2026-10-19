# IntentsUI on a release with no Siri, no Shortcuts and no extension host

`libIntentsUIBackports.dylib` carries the three classes of the IntentsUI surface an application
reaches: the button that shows what a shortcut would do, and the two view controllers that take a
person through adding or editing one. Every registry entry of this framework points here.

## The wall, and what is on this side of it

What these three classes are for is **the system's own flow**: Siri's screens, taken through
adding a shortcut to a phrase, and written into the system's shortcut database. This release has

* no Siri,
* no Shortcuts database — the framework is iOS 12 and the database arrived with it,
* no extension host — `NSExtensionContext`, which the header's `NSExtensionContext` category is
  declared on, arrived with iOS 8 and is not here at all,
* and `INVoiceShortcut` **declares no initialiser at all** — only `init NS_UNAVAILABLE` and
  `+new NS_UNAVAILABLE` — because a voice shortcut is the system's own object. That is Apple's
  own header, and it is the measurement that decides what the two controllers can honestly do.

So the classes are real, the views are real, the state is real — and the flow ends where the
system's begins:

* `INUIAddVoiceShortcutViewController`'s **Add** calls
  `addVoiceShortcutViewController:didFinishWithVoiceShortcut:error:` with a **nil shortcut and an
  error**, which is the answer its own documentation names ("with either the successfully-added
  voice shortcut, or an error"). Inventing a voice shortcut would be a value that looks like the
  system's and is not.
* `INUIEditVoiceShortcutViewController`'s **Save** calls
  `editVoiceShortcutViewController:didUpdateVoiceShortcut:error:` the same way: the phrase of a
  voice shortcut is `readonly` in the SDK's own header and there is no database behind it here.
* Its **Delete** calls `editVoiceShortcutViewController:didDeleteVoiceShortcutWithIdentifier:`
  with the voice shortcut's own `identifier`, which is a `NSUUID` — the class can only be reached
  by an application that already holds one, and on this release nothing can make one.

The button's **press** asks its delegate for the *add* controller, which is the only of the two it
can build: making an edit controller needs a voice shortcut, and there is none. Both delegate
methods are the SDK's own declaration and are answered by the application's class, which is the
same treatment the 77 Intents protocols get.

## What the button answers

`INUIAddVoiceShortcutButton` is a `UIButton` that draws itself, because the six styles the header
names are a background, a border and a title colour:

* the two light styles take dark ink, the two dark ones take light, and the two outlines take a
  one-point border;
* **Automatic** and **AutomaticOutline** (iOS 13) follow the interface style, and the interface
  style is the one UIKit's own trait collection reports, so the style is applied again when that
  changes;
* `cornerRadius` is capped at half the button's height — the header's own rule, and the cap is
  applied again in `layoutSubviews`, where the height is known.

The button is titled with what the shortcut would say: the intent's
`suggestedInvocationPhrase`, or the user activity's title.

## The two view controllers

Both are laid out by hand in `viewDidLayoutSubviews` — a label, a field or a button, and two
buttons — because the screens are those few pieces and this release's UIKit has no auto layout
chain worth relying on for a view nobody loaded a nib for. The two buttons are the header's own
answers, and they call the three delegate methods the header declares.

## The hosted view, and why it is implementable here

`INUIHostedViewControlling` looked like it needed a system host, and it does not: **the `context`
argument is an enumeration** (`INUIHostedViewContextSiriSnippet`, `INUIHostedViewContextMapsCard`),
not an `NSExtensionContext`, and the parameters come out of the interaction — which the port
carries, donation and all. So both of the protocol's methods are implemented in full by
`RevenantIntentsUIHostedViewController` (`RevenantIntentsUIHostedView.m`):

* the interaction's parameters — its intent's own properties, by the key path an `INParameter`
  names, which is exactly what `-[INInteraction parameterValueForParameter:]` reads — become the
  view's content, one label each, and a parameter the interaction carries nothing for is **left
  out of the configured set** rather than shown empty;
* the interactive behaviour becomes the button the header describes for that case, and the four
  cases are four different things: `None` shows nothing at all (it is the header's own first
  case), `NextView` a navigation chevron, `Launch` a button to leave the context, and
  `GenericAction` a large tap target in a bigger font;
* the completions are answered with the size the content needs, and with the set of parameters
  that were really configured.

The class is named as **Revenant's own**, because the SDK declares the *protocol* and the class that
conforms to it is the application's: this is the port's, so an application has a conforming class
to build on, and the name keeps it clear of any class Apple may add.

## INImage's bridge from images, measured

The category on `INImage` that IntentsUI declares is built in `IntentsUI/INImage+IntentsUI100.m`
(`+imageWithUIImage:`, `+imageWithCGImage:`, `+imageSizeForIntentResponse:`) and
`IntentsUI/INImage+IntentsUI110.m` (`-fetchUIImageWithCompletion:`, iOS 11). The image's bytes reach
them through two seams on `INImage` in `Intents/RevenantIntents100.m`: `-revenant_imageData` and
`+revenant_imageWithName:data:width:height:`, which keeps the bytes it is given, nil included.

Every behaviour below was asked of the Catalyst host's own IntentsUI, and the port answers the same
questions: `tests/backports/host/inimage-bridge/run.sh` builds one probe twice, against the system and
against the port's objects, and diffs the output (15 lines, the same on both), with a planted port
that must differ.

* `+imageWithUIImage:` stores `UIImagePNGRepresentation` of the image, the PNG the host stores. With
  nil it makes an image with no bytes, not a nil image.
* `+imageWithCGImage:` stores the CGImage's data-provider bytes unencoded: 1280 bytes for a 10 by 20
  image, rows of 64 bytes. It is not a PNG, and `UIImagePNGRepresentation` of it is not the same
  bytes. With nil it makes an image with no bytes.
* `+imageSizeForIntentResponse:` answers 60 by 60 points for every input the host was given: nil, an
  `NSObject`, a plain subclass and four response classes of the SDK. The constant is the host's answer,
  measured, not a value chosen for the port.
* `-fetchUIImageWithCompletion:` on an image with bytes calls the completion before the call returns,
  on the calling thread, with the UIImage decoded from them, or nil for bytes that are not an image
  (the raw bytes of a CGImage). On an image with no bytes it calls the completion later, on a
  background queue, with nil.

The one named divergence: a URL-backed image. The host keeps the URL and fetches it when asked, and a
file URL answers nil there; the port reads the URL's data when the image is made (`+imageWithURL:` was
already implemented that way), so a file-URL image is data-backed in the port and its fetch returns the
image. Fetches from a network URL were not measured in this round.

## What is not carried, and why each

No row of this package is owed. The three `NSExtensionContext` members are answered by a class the port defines for the
release that has no extension host (the section "NSExtensionContext, for a release with no extension host" below). The
`-init`, `-initWithFrame:` and `-initWithNibName:bundle:` the header marks `NS_UNAVAILABLE` are answered by the runtime,
and the port answers them by inheritance (the section "The six NS_UNAVAILABLE initialisers" below).

## NSExtensionContext, for a release with no extension host

`NSExtensionContext` is iOS 8's class (`Foundation/NSExtensionContext.h`, `ios(8.0)`), so iOS 6 has none, and the three
members IntentsUI adds to it (`INUIHostedViewControlling.h`, iOS 10 and 11) have nothing to be sent to. The port defines
the class in `Foundation/NSExtensionContext.m` (the Foundation library, which every library that needs it links),
with its IntentsUI members in `IntentsUI/RevenantNSExtensionContext+IntentsUI.m`, and answers what an application's own
context answers.

Measured on Catalyst by `tests/backports/host/nsextension-context`, for a fresh context:

* `inputItems` is an empty mutable array (class `__NSArrayM`);
* `hostedViewMinimumAllowedSize` and `hostedViewMaximumAllowedSize` are `{0, 0}`;
* `interfaceParametersDescription` is nil.

The port answers those values, and the probe finds the port matches the host on every line except one.

**The one difference, by ruling.** On the host, `completeRequestReturningItems:completionHandler:` does not call its
completion, even after the run loop has turned for a second, because no extension host has started the context. The
ruling is that the context here answers as an application's own context does: the request is complete when the
application says so, so the completion is called once, with `expired` NO. The harness holds the port to that line, and
holds the host to its own. Nothing else in the class is a ruling; each value above is the host's.

`cancelRequestWithError:` and `openURL:completionHandler:` are declared by the header and are in no row of this package,
so they are not defined here.

## The six NS_UNAVAILABLE initialisers: the runtime answers, and the port inherits

The header marks `-init` on all three classes, `-initWithFrame:` on the button and `-initWithNibName:bundle:` on the two
view controllers `NS_UNAVAILABLE`, so a compiled call would not be the measurement. The probe in
`tests/backports/host/intentsui-init` calls each through its IMP on a fresh allocation, as the Intents `-init` rows do.

On Catalyst the host answers an instance of the named class for all six (`expected.txt`, six lines, each `isKind 1` and
`exact 1`). The port's classes declare none of the six themselves: `RevenantIntentsUI120.m` has `initWithStyle:`,
`initWithShortcut:` and `initWithVoiceShortcut:`, and the superclass's initialisers answer the rest. The port matches the
host line for line, and a planted category that answers nil for the button's `-init` makes the diff non-empty.

So the six rows are `implemented` by inheritance, with minimum 6.0. This is one measurement, on Catalyst: the device's
IntentsUI is not in the package, and nothing here measures the device.

The four enumerations and twelve constants of the surface get **no entries at all**: a case of an
enumeration and the type it belongs to are the header's own, and `registry/README.md` says so —
the compiler writes them into the application and the package carries nothing of them.

## What is not measured here

Nothing on this framework has been run: not on the device, not in the emulator, and not through
the generated call test, which has been run over the Intents registry only. Every entry here is
**device-unverified**, and the IntentsUI gate is still to come.
