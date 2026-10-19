# NSExtensionContext, iOS 8

Introduced in iOS 8.0: what an app extension is handed to find its input items and to hand the result back, and `UIViewController.extensionContext`, which answers it for the controllers of an extension.

Source: the host's own Foundation under Mac Catalyst (`host/tail2/run.sh`), asked about a context of an application and a controller: an `NSExtensionContext` made with `init` has an empty array of input items;
completing a request, cancelling it and opening a URL do nothing, and the two handlers are never called; a controller, and a child of it, have no extension context; the items and errors key is its own name.
`device/tail2.m` repeats them on iOS 6.

## What the port does

The release has no app extensions - `NSExtensionMain` here exits saying so - so no context is ever made for an extension: the class exists so that code shared between an application and its extensions loads and links,
answers what a context with no host answers, and `UIViewController.extensionContext` is nil, which is what it is in an application.

The class is defined once, in `Foundation/NSExtensionContext.m`. Its one difference from the host is the completion: the
port calls `completeRequestReturningItems:completionHandler:` back once with expired NO, where the host does not call
back on a context no extension host has started. That is the ruling, recorded in `facts/IntentsUI/IntentsUI.md`. The
IntentsUI and NotificationCenter members are categories in their own libraries, not a second definition of the class.
