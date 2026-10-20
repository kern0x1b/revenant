# WKWebExtensionTabConfiguration, WKWebExtensionWindowConfiguration and WKWebExtensionMessagePort (iOS 18.4)

The three objects the web-extension family **hands** an application, and why each member's answer is the
answer for the only one of them a program can have. Measured on this machine by asking the host's own
WebKit under Mac Catalyst, and held to the port by
`tests/backports/host/webkit/webextension-configuration_scenario.h`, 36 cases, asked of the system with
no port code in the process and then of the port with renames.sh's flags.

## Who builds one

Nothing in the 26.2 SDK returns any of the three. They are arguments and deliveries, not products:

| class | it arrives as | where |
| --- | --- | --- |
| `WKWebExtensionTabConfiguration` | the argument of the delegate method that asks for a tab | `WKWebExtensionControllerDelegate.h:97` |
| `WKWebExtensionWindowConfiguration` | the argument of the delegate method that asks for a window | `WKWebExtensionControllerDelegate.h:84` |
| `WKWebExtensionMessagePort` | the argument of the delegate method that hands over a connection | `WKWebExtensionControllerDelegate.h:203` |

So `+new` and `-init` are `NS_UNAVAILABLE` in the port's header as they are in the SDK's, and this port
defines neither. That is a measured statement about the SDK and not a guess: `grep -n "MessagePort\|TabConfiguration\|WindowConfiguration"`
over the 26.2 headers' WebKit directory finds those three headers, `WebKit.h`'s import of one of them,
and the three delegate methods -- and no factory of any kind.

They are declared in `WKWebExtensionController.m` rather than in a file of their own because that is
where they arrive, and because the object's release is already the 18.4 one they are.

## What the members answer

The release's answer for an object a program made. `-init` is asked for through the runtime, because
both headers mark it unavailable, and on the host that reaches NSObject's own `-init`: the release's
designated initialiser is private (`_init`), and `-init` is not among the fifteen methods the host's
message port declares.

```
  WKWebExtensionTabConfiguration, made by a program
    window nil   index 0   parentTab nil   url nil
    shouldBeActive 0  shouldAddToSelection 0  shouldBePinned 0  shouldBeMuted 0  shouldReaderModeBeActive 0

  WKWebExtensionWindowConfiguration, made by a program
    windowType 0   windowState 0
    frame x 0 y 0 w 0 h 0        tabURLs (null)   tabs (null)
    shouldBeFocused 0   shouldBePrivate 0

  WKWebExtensionMessagePort, made by a program
    applicationIdentifier (null)   messageHandler (null)   disconnectHandler (null)   isDisconnected 1
```

Two of those are worth stating because the headers say something else, and a port that followed the
header would be wrong:

- **A window's frame is `{0, 0, 0, 0}`, not NaN.** `WKWebExtensionWindowConfiguration.h:56` says
  "Individual components (e.g., `origin.x`, `size.width`) will be `NaN` if not specified", and the
  object a program made answers zeros in all four. The NaN belongs to a configuration WebKit built with
  some components unset, which this port never has.
- **`tabURLs` and `tabs` are nil, not empty arrays.** An application that sends `count` to either gets 0
  either way, which is why the differential asks `isNil` and `count` as two cases rather than one.

**`isDisconnected` is YES, always, and that is a fact about the port rather than a stored flag.** WebKit
builds a message port and connects it to the extension that opened it with
`browser.runtime.connectNative`; this port runs no extension, so there is nothing for a port here to be
connected to. The host agrees for the only port a program can make there (measured, 1).

## What is NOT carried, and why

`-sendMessage:completionHandler:`, `-disconnect` and `-disconnectWithError:` are `absent`, and the
measurement is a trap rather than a sentence: on the host, a port a program made has no extension
behind it, and all three raise

```
*** Terminating app due to ...   exit 133 (SIGTRAP)
```

`-[WKWebExtensionMessagePort sendMessage:completionHandler:]` on such a port, `-disconnect` on such a
port, and `-disconnectWithError:` on such a port each killed the probe before its completion handler was
called. A port does not define them either, and a caller that sends one gets
`doesNotRecognizeSelector:` rather than a trap -- which is the one answer here that is better than the
release's, and it is named here rather than left for a reader to find.

`WKWebExtensionMessagePortErrorDomain` **is** carried, with the host's own string, which is the symbol's
own name:

```
WKWebExtensionMessagePortErrorDomain   slot 0x1ebb780f0 value 0x1f5df2978 WKWebExtensionMessagePortErrorDomain
```

An application compiled against the SDK compares an error's domain against it, so the constant is
worth having even though this port raises nothing in it. Its three codes have **no** row: read on the
host, `WKWebExtensionMessagePortErrorUnknown`, `...NotConnected` and `...MessageInvalid` are all
`(no symbol)`, because an enumerator is a compile-time integer (`implemented` is a promise that
something of that name is built). They are carried as the `NS_ERROR_ENUM` in the port's own header, and
`facts/WebKit/WebExtension.md` has the same finding for the seven permission statuses.

The two enums a window's configuration is read through, `WKWebExtensionWindowType` and
`WKWebExtensionWindowState`, are transcribed into the port's header from the 26.2 SDK's
`WKWebExtensionWindow.h` and have no rows for the same reason. Their numbers are in the differential as
six cases (`enum.WindowTypeNormal` and the rest), so a wrong number in this port's header is caught
there.

## The red control

`run.sh` takes a copy of `WKWebExtensionController.m`, plants an index of 1 in `-index`, and the
comparison has to go red on it:

```
configuration red control: exit=1 with a planted index, and the case that moved is:
    port   case tab.index 1
    system case tab.index 0
```