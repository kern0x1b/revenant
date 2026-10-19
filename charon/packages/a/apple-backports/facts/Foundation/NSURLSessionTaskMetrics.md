# NSURLSessionTaskMetrics and NSURLSessionTaskTransactionMetrics, iOS 10.0

What a session tells its delegate about the timing of a task, with `-URLSession:task:didFinishCollectingMetrics:`.

Source: the host's own Foundation, in the `metrics` scenario of `tests/backports/device/session-scenarios.m`, which
`tests/backports/host/session/run.sh` runs against the system's `NSURLSession` and against the port compiled for the host in one
process, over the same local server, and `tests/backports/device/session.m` on a device running 6.1.3, whose answers are held
to the same transcript. The engine is the port's own `NSURLSession`, over `NSURLConnection` (see `NSURLSession.md`).

## What the system does, and the port with it

- The delegate is sent `didFinishCollectingMetrics:` once for every task, **before** `didCompleteWithError:` and before a
  completion handler runs; a task made with a completion handler gets it too, if the session's delegate answers it.
- `transactionMetrics` holds one transaction for a request, and one more for every redirect that was followed: a 302 to
  another URL makes two, with the first transaction's response the 302, and `redirectCount` is the number of transactions
  less one. A load that fails makes one, without a response.
- A transaction keeps the request it was made for and the response it got. Its fetch, request and response dates are in
  order - fetch start, request start, request end, response start, response end - and a load that fails has the fetch start
  only.
- `resourceFetchType` is network load (1) for a load the network served; the protocol name of a response over HTTP is
  `http/1.1`, and nil for a failure.
- `taskInterval` runs from the creation of the task to the moment it completes, so it covers every transaction.
- The system, when its cache answers, makes an extra transaction of type local cache (3) before the network one, and it reuses
  connections; both depend on the state of the machine, so the scenario runs on an ephemeral configuration and does not
  compare the reused-connection flag.

## What the port cannot say

The engine sees a request go out and a response come back through `NSURLConnection`, and no more. So:

- the request start is the fetch start, and the request end is the moment the response began to arrive; the response start is
  that moment and the response end is when the last data was in;
- the dates of the name lookup, the connection and the secure connection are nil, the two flags for a proxy and a reused
  connection are NO, and the protocol name is `http/1.1` for an `http` or `https` load whatever the wire spoke;
- a load that the port's cache answers has the type local cache (3);
- the properties that came after iOS 10 - the byte counts, the addresses and ports, the TLS version and cipher, the network
  flags and the resolution protocol - are not carried, and the class does not answer them.
