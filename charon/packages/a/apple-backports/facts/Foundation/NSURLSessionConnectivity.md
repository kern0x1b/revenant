# NSURLSession: waiting for connectivity and delayed requests, iOS 11

Source: the host's NSURLSession, asked for a background session's delayed requests, the date, the dispositions and
the properties (`tests/backports/host/session`, the `delayed` scenario, held to the port with the transcripts of the
system and the port equal); iOS 6.1.3 on an iPad 2 for what happens when the network goes and comes back
(`tests/backports/device/waitsconnectivity.m`).

## Delayed requests (`earliestBeginDate`, `willBeginDelayedRequest`)

A task of a **background** session begins no earlier than its `earliestBeginDate`; a date in the past, or none, begins it at
once. A task of a default or an ephemeral session ignores the date: its request goes out when the task is resumed. The
property is kept as set (the date itself, not a copy) and cleared with `nil`, and may be set after `resume`.

For every task of a background session, date or not, the delegate's `URLSession:task:willBeginDelayedRequest:completionHandler:`
is called on the delegate queue just before the request goes out, with the request. The disposition
`NSURLSessionDelayedRequestContinueLoading` sends it, `UseNewRequest` sends the request the handler gives (the task's
`currentRequest` becomes it), and `Cancel` ends the task with `NSURLErrorCancelled`. A delegate that does not implement the
method lets the task go on.

## Waiting for connectivity (`waitsForConnectivity`)

A task of a session whose configuration has it set, and every task of a background session, that begins when the network is
not there does not fail with `NSURLErrorNotConnectedToInternet`: it calls the delegate's
`URLSession:taskIsWaitingForConnectivity:` once and waits, and begins when the network is there. The reachability that
counts is that of the host of the request when it is an address (the loopback is always there), and of the network in
general when it is a name; a network that is only cellular does not count for a session or a request that does not allow
cellular access. While the task waits the timeout of the request does not run and the timeout of the resource does, so it
ends with `NSURLErrorTimedOut` when that passes, and cancelling it ends it with `NSURLErrorCancelled`.

A connection that fails while it is being made with not connected to the internet, international roaming off, a call
in progress or data not allowed is made again the same way, unless the network looks reachable, when it fails as it would
have; a task that has received a response, a download that has written to its file and a task whose body is a stream are not
made again. The two properties are kept by the configuration and copied with it; the default is off, for a background
session as well.

The system's behaviour while the network is down could not be asked of the host, which has no way to take its network away;
what is written above is the documented behaviour, held on the device, which is where the network can be taken away.

## The hints of the size of a transfer

`countOfBytesClientExpectsToSend` and `countOfBytesClientExpectsToReceive` start at -1
(`NSURLSessionTransferSizeUnknown`) and are kept as set, negative values included. The system uses them to schedule
discretionary background transfers; iOS 6 has no scheduler, so nothing reads them here.
