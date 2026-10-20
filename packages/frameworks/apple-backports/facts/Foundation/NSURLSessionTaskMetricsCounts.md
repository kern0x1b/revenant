# The transaction metrics' own numbers, iOS 13.0

The counts and the flags a `NSURLSessionTaskTransactionMetrics` carries, on top of the dates and the
request `NSURLSessionTaskMetrics.m` already keeps.

## The shape is corelibs', and only the shape

`swift-corelibs-foundation`'s `URLSessionTaskTransactionMetrics` (Apache-2.0, read at
`Sources/FoundationNetworking/URLSession/URLSessionTaskMetrics.swift`) is a **plain data holder**, and
what it says about the fields is what the port follows:

- every count is an `Int64` that starts at **zero**;
- every flag is a `Bool` that starts **false**;
- `resourceFetchType` and `domainResolutionProtocol` start at their own **unknown**;
- the addresses and the two negotiated TLS values start at **nil**;
- and the two body-byte fields are two fields, not one: `countOfRequestBodyBytesBeforeEncoding` is what
  the caller handed over, `countOfRequestBodyBytesSent` is what went on the wire.

What fills them is the load, and that is the whole difference between the two implementations.

## The port's load knows eleven of the nineteen

| the field | where the number comes from |
| --- | --- |
| `countOfRequestBodyBytesSent`, `…BeforeEncoding` | the loader's own two counters, which are exactly those two things |
| `countOfResponseBodyBytesReceived`, `…AfterDecoding` | the loader's received counter; the port applies no content encoding, so the decoded count is the received one |
| `isReusedConnection` | the session's per-host connection table, which knows whether a connection was already open |
| `isCellular`, `isExpensive`, `isConstrained` | SystemConfiguration, which the session already asks |
| `isProxyConnection` | whether the release's own connection was the one that ran it |
| `isMultipath` | false: 6.1.3 has no multipath, and a system without the feature answers the default |
| `domainResolutionProtocol` | its own `unknown`: the release's connection resolves and connects with whatever it uses and says nothing about which |

## The eight it cannot reach, and the wall

The release's `NSURLConnection` takes a request and hands back a response, and **nothing in between is
the port's**: the two header byte counts, the two addresses, the two ports, and the two negotiated TLS
values are all properties of the socket and of the TLS session that the release's connection makes and
keeps to itself. Those eight are `absent`, with that reason, rather than answering nil or zero for a
number the API says is real.

A port that negotiates its own TLS does reach them, and the port has one: `NSURLSessionStreamTask`
runs over the release's own `CFStream` pair and can read
`kCFStreamPropertySocketNativeHandle` for the addresses and `kCFStreamPropertySSLContext` for the
negotiated version and cipher. Wiring the transaction metrics to *that* path is the change that closes
the eight, and it is a change to the loader's data path rather than to this family.
