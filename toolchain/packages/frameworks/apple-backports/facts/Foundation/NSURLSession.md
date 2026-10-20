# NSURLSession

Source: the host's own Foundation, through the differential run of
`tests/backports/host/session/run.sh`, which puts the system's session and the backport side by side on
the same server and holds both to the same transcript. The host's Foundation is newer than any cache we
hold, so it is the source for behaviour a test can observe; a cache is read where a test cannot see the
answer.

## Following a redirect

`Authorization` is taken off the request the session follows with, whatever the redirect leads to: the
same origin loses it as surely as another one. Everything else the application set travels on, including
`Cookie` set by hand and any header of its own, and the cookie storage adds its cookies to the new request
as it would to any other. The backport did the opposite at first - it kept the header inside one origin and
stripped a set of them when the origin changed - and the differential run named both mistakes.

A session follows at most 20 redirects; the 21st fails with `NSURLErrorHTTPTooManyRedirects` and the failing
URL of the last hop.

## What the release cannot do

`TLSMinimumSupportedProtocol` and `TLSMaximumSupportedProtocol` reach CFNetwork on a modern release and bound
the handshake. iOS 6 hands its requests to NSURLConnection, which takes no such bound, so the backport has
no setters for them - `respondsToSelector:` answers no, and a call raises rather than storing a value that
changes nothing - and the getters answer with the bounds the platform really has, SSLv3 to TLS 1.2. An
application that only reads them runs as it does on a newer release; one that asks before it narrows them
learns that it cannot, and one that narrows them without asking stops at the call.

## The key a background session would have answered under

`+backgroundSessionConfigurationWithIdentifier:` is the name iOS 8 gave the factory iOS 7 shipped as
`+backgroundSessionConfiguration:`, with nothing else changed, so the port answers it with the older one: an
application written against either name gets the same configuration, and the identifier it is given is the
identifier the configuration holds. What the configuration cannot do is below - the transfers run in the process,
since the release has no daemon to hand them to.

`NSURLErrorBackgroundTaskCancelledReasonKey` carries its own name as its value, read from the host's own
Foundation. It is the key an error's `userInfo` holds when the system cancels a background transfer, and
nothing in this release cancels one, because the backport's background configuration runs in the process
like any other session and the daemon that would have reported a reason is not there. The constant is
carried so that an application that reads the key out of an error, or names it in a comparison, builds and
runs; it is never the key of an error the backport makes.

## The constants and a task's priority

Measured against the host's own Foundation, and held by the differential transcripts of
`tests/backports/host/session` and by the device test:

- `NSURLSessionTaskPriorityLow`, `Default` and `High` are 0.25, 0.5 and 0.75, and a new task's priority is
  0.5.
- `-setPriority:` keeps a value from 0 to 1 and ignores anything outside it, leaving the priority it had:
  0.3 followed by -0.1, 1.0001, 2, -5 or infinity still reads 0.3. The test is `priority < 0 || priority >
  1`, so NaN is not outside it and is kept.
- `NSURLSessionTransferSizeUnknown` is -1, and it is what `countOfBytesExpectedToReceive` answers once a
  response has come without a length; before any response it answers 0.
- `NSURLSessionDownloadTaskResumeData` is its own name, and it is the key under which a cancelled download's
  error carries the data to resume from.
- `prefersIncrementalDelivery` of iOS 14.5 is kept on the task and read back, and starts as `YES`, which is
  the release's default. It changes nothing: this port's loader has one path, which hands each part of a
  body to `URLSession:dataTask:didReceiveData:` as it arrives, and the release's CFNetwork has no switch
  that would hold a response back and deliver it whole. `YES` is therefore the behaviour the property asks
  for; `NO` is a preference the port does not take, which the name of the property allows and which a
  release itself answers on a transfer it cannot coalesce.

## Three task-delegate members the port never sends, and why that is `absent`

`URLSession:didCreateTask:`, `URLSession:task:didReceiveInformationalResponse:` and
`URLSession:task:needNewBodyStreamFromOffset:completionHandler:` are all `absent`, and this is the
measurement behind that word for the first of them
(`registry/Foundation/ios15-16.json`; the other two rows live in `ios17-18.json` and carry the release
census of `Foundation17ReleaseAbsences.md` in their own `source`).

The claim is a claim about this package's own sources, and it is checkable by hand:

```
$ cd packages/frameworks/apple-backports
$ grep -rn "didCreateTask\|didReceiveInformationalResponse\|needNewBodyStreamFromOffset" --include="*.m" --include="*.h" --include="*.c" .
(no output; grep exits 1)
$ find . \( -name "*.m" -o -name "*.h" -o -name "*.c" \) | wc -l
2350
$ grep -rF "becomeCurrentWithPendingUnitCount:" --include="*.m" --include="*.h" --include="*.c" . | wc -l
8
```

**0 occurrences in 2,350 sources**, and the control comes back with 8 in the same run, so the zero is
the package's and not the search's. The zero form is a count over files, so a file that is not there
cannot be counted as empty: `grep -rc "didCreateTask" --include="*.m" --include="*.h" . | grep -v ":0$"`
prints nothing, and a run that searched nothing cannot be mistaken for a run that found nothing.

Each of the three is an event the port's loader does not produce, and each for its own reason rather
than by omission. **Only the first is in the 16.4 build SDK** - `didCreateTask:` is `API_AVAILABLE(...,
ios(16.0) ...)` at `NSURLSession.h:918-919`, while the other two are 17.0 and appear in no header this
machine has; their `source` quotes the SDK comment for each out of a 26.2 tree, so this page names them
by that record and not by a header it read.

- `didCreateTask:` is the system telling a delegate about a task *it* created - the SDK's own comment
  at `NSURLSession.h:912-913` reads "Notification that a task has been created. This method is the
  first message a task sends", invoked synchronously before the task creation method returns
  (`:915-916`). Every task in a port session is one the application asked the session for, so the
  application already holds the task the message would name.
- `didReceiveInformationalResponse:` is an informational (1xx) response other than 101. The port's
  loader has no such path: `grep -rln "informational\|100 Continue" --include="*.m" --include="*.h" .`
  over the package returns nothing, and the port drives the release's own `NSURLConnection`, whose
  callback is the one that carries a response.
- `needNewBodyStreamFromOffset:completionHandler:` is the system running out of a body it must resend.
  The port keeps the body it was handed - `RevenantTaskBody` in `Foundation/NSURLSession.m:28` is the
  enum for exactly those three (data, file, stream) - so it is never asked for one.

**`absent`, and not `ignored`.** `ignored` is this registry's word for an API the *release* carries and
the port chooses not to carry, so that the call reaches the system's own implementation. Neither band
this package carries has any NSURLSession to reach: `tools/cache-index/first-rung.lua` puts the first
held rung carrying `NSURLSession` or `NSURLSessionTaskDelegate` at **7.0**, above every rung a
`minimum` of 6.0 reaches, and the two rungs' own name indexes carry neither name nor any of these three
selectors - 0 of the 317,453 names at 4.3 and 0 of the 568,965 at 6.1.3, with `UIView`, `NSObject` and
`setObject:forKey:` present in both as the control. That is
`~/.revenant/cache-index/<release>.names.gz`, the index `tools/cache-index/build.lua` writes, read here by
`tools/cache-index/first-rung.lua`'s own `_names_of()` over the bytes it holds. `Foundation17ReleaseAbsences.md` closed the same
gap for 4.3 and 6.0 by class census, and found no class named `URLSession` in either.

An earlier commit in the sibling NSUserActivity family had its two rows as `ignored` and the 2026-09-28
review refused exactly that, for exactly this reason
(`facts/Foundation/NSUserActivity.md`, the last paragraph).
