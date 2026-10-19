# BEAvailability, iOS 18.4

One class and one method: `+[BEAvailability isEligibleForContext:completionHandler:]` asks whether
this device may run a browser engine of its own inside a web browser, and hands the answer to a
handler. It arrived with iOS 18.4, the release in which the European Commission's decision let a
vendor of the operating system grant such an engine to a browser built with its own engine.

## What the devices this port runs on are

Eligibility is not a property of the hardware: it is the **system's** answer, reached from an
entitlement Apple grants to an application signed by a vendor that holds one, on a release whose
BrowserKit exists. iOS 6.1.3 predates all of it — the armv7 shared cache of that release has no
BrowserKit image and no such class — and no entitlement for it can exist on a release that has never
heard of it. So the answer is `NO` here, and it is `NO` for a reason that is not a guess: there is
nothing on this device that could be made eligible.

## What the port answers

- `+isEligibleForContext:completionHandler:` calls the handler once with `eligible` **NO** and a
  **nil** error, on the thread that asked, before the call returns. A nil handler is allowed. Every
  context is answered the same way: `BEEligibilityContextWebBrowser` is the only context there is,
  and a context the release has no meaning for is answered like one it has, because the release can
  make nothing eligible whatever the question.
- The error is nil, deliberately. The header says the handler is given the status and "if the call
  fails, the error is included" — and a device that is not eligible is an **answer**, not a failure:
  nothing went wrong, the answer is NO. A failure would be the case where the question itself could
  not be asked, and the port can always answer it.
- The class exists so that an application which names it loads. A strong reference to a class that is
  not there stops the application at launch, which is the one thing a backport must never leave.

## What was measured, and what was not

Measured: the state of the release (the 6.1.3 armv7 cache has no BrowserKit and no such class) and
the shape of the API (the header of `BrowserKit/BEAvailability.h` in the SDK 26.2, which the
coordinator pointed this band at because the SDK the port builds against — `charon@iphoneos-sdk` 16.4
— has no BrowserKit at all; the declaration is therefore written in the backport's own source).

Not measured: Apple's own `BEAvailability`, and the eligibility of a device that *could* be
eligible. BrowserKit is unavailable on macOS (its header is `API_UNAVAILABLE(macos)`), so the host
cannot be an oracle, and no release this port runs has the framework. The thread and the moment of
the completion handler follow the same rule the other carried seams of this package use — the answer
is known without a system call, so the handler is called on the thread that asked, before the call
returns — and that is written down here as a choice, not presented as a measurement. What *is*
measured is the `NO`, and it needs no oracle: nothing on iOS 6 can be eligible.
