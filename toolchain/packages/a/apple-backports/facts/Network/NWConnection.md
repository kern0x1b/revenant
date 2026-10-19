# The connection of Network, iOS 12

`nw_connection_t` is a real socket: the host is resolved with `getaddrinfo`, a datagram socket is opened, and it is
connected to the first address that answers. `nw_path_monitor_*`, `nw_path_*` and `nw_interface_*` are carried by the
Foundation library (`facts/Network/NWPathMonitor.md`), and this connection reports its path through them, so a
program that only asks "is that peer reachable from here" needs nothing of Network beyond this file.

The endpoint it is made of and the parameters it is given are the port's own objects of the families in
`NWObjects.md` (`nw12-core.m` and `nw12-parameters.m`), which is where the calls that make them now live: the
connection's own file holds the connection, and the two sentinels and the classes they were declared in moved to the
files that own them, so that nothing is defined twice.

This is the surface the Matter framework's device browser needs: `src/darwin/Framework/CHIP/MTRDeviceConnectivityMonitor.mm`
of connectedhomeip v1.6.1.0 calls `nw_endpoint_create_host`, `nw_parameters_create_secure_udp`,
`nw_connection_create`, `nw_connection_set_queue`, `nw_connection_set_path_changed_handler`,
`nw_connection_set_viability_changed_handler`, `nw_connection_start` and `nw_connection_cancel`, and nothing else of
Network.

## What it does

- `nw_endpoint_create_host` keeps the host and the port as they were given; the endpoint answers its type
  (`nw_endpoint_type_host`), its host and its port. A NULL or empty host is refused, as a NULL endpoint is.
- `nw_parameters_create_secure_udp` runs the caller's configure block exactly once, with the options it was handed,
  and gives back parameters for a datagram connection.
- `nw_connection_create` refuses a NULL endpoint or NULL parameters, as the header says it does.
- `nw_connection_set_queue` names the queue every handler of this connection is called on. A connection started
  without one does nothing, which is what the header says must not be done; a second `nw_connection_start` is not a
  new attempt.
- `nw_connection_start` opens and connects the socket on that queue, then starts a path monitor. The path-changed
  handler is called with the path when the connection starts and whenever the path changes. The viability-changed
  handler is called with `true` when the connection first becomes viable, and again on every change of it.
- `nw_connection_cancel` closes the socket, cancels the path monitor, and asks twice is the same as asking once; no
  handler is called after it.

## What viability means here, exactly

For a datagram socket `connect()` sends nothing: it binds the default peer, and the kernel returns `ENETUNREACH`
exactly when it has no route to give. So **viable means the kernel has a route to that address and the release's own
reachability says the path is satisfied**. It does not mean the peer answered, because nothing has been sent to it: a
UDP peer cannot be probed without sending it a packet, and a connectivity monitor must not send one.

## The two sentinel blocks

`parameters.h` declares `_nw_parameters_configure_protocol_default_configuration` and
`_nw_parameters_configure_protocol_disable` as `extern` blocks, and every factory that takes them compares them by
pointer. A release with no Network binds both as the null, and then the two would compare equal to each other and to a
caller who passed nothing. Each is defined here as the empty block it is documented to behave as, so the pointer a
caller passes is a real one and the comparison means what it says.

## Not carried, and why

- The stream parameters factories (`nw_parameters_create_secure_tcp`, `nw_parameters_create_tcp`, and the rest of
  `parameters.h`): there is no stream transport here, and a connection that only reported a path over a socket that
  cannot carry a stream would be a wall standing in for one.
- The connection's data calls: `nw_connection_send`, `nw_connection_receive`, `nw_connection_send_completion`, and the
  state, metadata, better-path and multipath handlers above them. A program that names one does not link, which is the
  honest answer for a call this file does not make real.
- Listeners, browsers, endpoints of a service or a Unix path, groups, the content and framer contexts, and every
  `nw_protocol_options` call: none of them is carried. Network has 1 649 rows in the SDK 26.2 surface; this file and
  the path monitor carry the 35 of them the port's own code reaches.

## The transport, measured against the host's own Network

`tests/backports/host/network-connection`, 24 checks, the port's `nw_connection_t` and the host's
`nw_connection_t` both connected to one loopback peer, which relays what one writes to the other. Every
byte the port sends is therefore read by Apple's own Network and every byte Apple's own Network sends
is read by the port, over a real socket on each side:

- a TCP connection of the port reaches `ready` over the loopback, as the host's does, and the two reach
  it through the same states;
- the port's `nw_connection_send` completion reports no error, the peer read the bytes, and the host's
  own Network read them **through the port's socket**;
- what the host's Network sends comes back through the port's `nw_connection_receive`, in the order it
  was written;
- the largest datagram the connection's path carries is the same number on both sides - 16344 over the
  loopback, where the port had to look at *this* connection's own interface rather than the device's
  first one (it said 1460 until it did, which is the general path's interface and not the connection's);
- the description has the shape Apple's own has, naming the connection, the peer and the transport;
- each side has the metadata of the transport it is carrying and none of a protocol it is not;
- a refused connection fails on both sides with the same domain of error and the same code (the POSIX
  one the kernel gave), and a datagram connection reaches `ready` where nothing is listening, on both
  sides.

Four scenarios are **not** compared there and are said so in the test: a data transfer report and its
collect, cancelling, the refused connection and the datagram one each need the port's own objects
through the port's own accessors - a report of the port read by the host's accessor reads Apple's layout
of a port object - so they are port-only checks, and they are what the emulator run at 6.1.3
(`tests/backports/device`) is for. The report's numbers are the connection's own counters and the
kernel's own `TCP_CONNECTION_INFO` (`charon_nw_tcp_round_trips`), which is what the accessors in
`NWObjects.md` read.

## What the release's own TLS is, and how the connection uses it

Measured out of the iOS 6.1.3 cache, the TLS this port builds on is `SSLContextCreate` (the name from
iOS 7 on, `SSLCreateContext`, is **not** exported by that release), with `SSLSetIOFuncs`,
`SSLSetPeerDomainName`, `SSLSetCertificate`, `SSLSetSessionOption`, `SSLHandshake`, `SSLRead`, `SSLWrite`
and `SSLClose` all there. The connection drives them from its own two dispatch sources, so the
handshake and the data travel over one engine, and the port declares `SSLContextCreate` itself because
the SDK it compiles against has only the newer name. There is no `SSLGetServerTrust` on this release,
so the evaluation of the server's chain is the system's own, and a program that wants a policy of its
own asks to break on server auth with `SSLSetSessionOption`, which is here.

**No TLS 1.2 and no TLS 1.3 on this release** - which is the whole of why there is no QUIC transport:
QUIC's handshake *is* a TLS 1.3 handshake (RFC 9001 §4.2), and this release has neither. That is the
concrete blocker on the 43 QUIC transport-dependent rows, and the QUIC options and metadata of
`NWQUIC.md` are the configuration of a protocol the release cannot speak at all.

## Two things this environment shows about the engine, measured

- **A write dispatch source over a socket does not fire on this host** (a two-line program: a socket
  connected and accepted, a `DISPATCH_SOURCE_TYPE_WRITE` source over it, no event - measured). The
  engine therefore does not wait for writability to connect: the one call that has to wait, the
  `connect`, runs on a queue of its own and the socket is blocking for exactly that call and
  non-blocking from then on. That is the native arrangement for a release with no writability signal
  worth having, and it keeps the connection's own queue - which carries every handler - free.
- **The host's own Network will not start a listener in this environment**: asked for one on a port of
  its choosing and on a port the test names, it answers `failed` with POSIX `EINVAL`, while its
  *connection* works and sends and receives normally (the same measurement). That is why the peer of
  this differential is a plain BSD listener in the test program, and why the port's own listener - which
  is `nw_listener_*`, not in this delivery - has to be measured on the emulator rather than here.

## The release's own TLS, with the names it actually has

Measured out of the 6.1.3 cache, and the names matter more than the conclusion:

- **The context call is `SSLCreateContext`**, and it *is* exported by Security.framework at 6.1.3.
  `SSLContextCreate` - the name a first reading of that cache suggested - is exported by no release
  of this machine, and the 16.4 SDK declares and its `Security.tbd` lists `SSLCreateContext` for
  `armv7-ios` and `armv7s-ios` as well as arm64. So a connection's TLS links **directly**, for every
  release whose cache exports the call, and no stub has to be taught anything.
- **The release speaks TLS 1.2.** `SSLSetProtocolVersionMin`, `SSLSetProtocolVersionMax`,
  `SSLGetNegotiatedProtocolVersion` and `SSLCopyPeerTrust` are all exported at 6.1.3, so the
  connection can ask for 1.2 and can take the peer trust with the call that exists on this release.
  What is *not* there is `SSLSetProtocolVersion` and `SSLGetServerTrust`, the spellings those two
  replaced, and TLS 1.3 is not in this stack at all.
- **TLS 1.3 comes from picotls**, which the port has as a package (`packages/p/picotls`, a TLS 1.3
  with a crypto backend of its own and no OpenSSL behind it, and a handshake proven on the host in
  `tests/backports/host/picotls-tls13`). It is needed twice over: a QUIC handshake cannot be made
  with a TLS 1.2 stack whatever the stack is, and a server that refuses 1.2 can only be answered with
  1.3 by a stack of picotls's. Which of the two a connection ends up with, and the ALPN it negotiates,
  is what `tests/backports/host/network-connection` is to measure against the host's own Network with
  one local server answering both.
- **4.3 has no SecureTransport context API at all** - `SSLCreateContext` is iOS 5.0 - so a connection
  on 4.3 has to reach the call by name at run time, the way `packages/a/apple-backports/Foundation`'s
  metrics reach SecureTransport, and 4.3 answers with what the release can: no TLS, a plain socket.
