# QUIC, the options and the metadata

`nw_quic_create_options` and its setters, `nw_parameters_create_quic`, and the metadata getters and
setters are the configuration and the description of a QUIC connection. The port has no QUIC transport,
so a connection of QUIC parameters is a connection over its transport with no QUIC layer on it; the
settings are kept and read back as the host's own Network answers them, and nothing pretends to speak
the protocol. Every answer, the defaults included, is in `NWObjects.md` and comes from
`tests/backports/host/network-objects`; the defaults that are worth writing down here are an idle
timeout of 30000 ms, a maximum UDP payload of 65535, and flow-control limits of `UINT64_MAX`, which is
"no limit of our own" - all three measured.

Two answers are the port's own: the default of `nw_quic_get_max_datagram_frame_size` is 0 because the
host's own is uninitialised memory (two runs, two numbers) and 0 is the documented way of saying that a
connection sends no datagram frames; and a message that is not QUIC's answers 0 for every one of these
getters and takes none of these setters, which is what the host does with them as well.

## Why this release has no TLS 1.3 of its own, and what that costs QUIC

Measured out of the iOS 6.1.3 cache, the TLS this port builds on is `SSLContextCreate` (the name from
iOS 7 on, `SSLCreateContext`, is **not** exported by that release), with `SSLSetIOFuncs`,
`SSLSetPeerDomainName`, `SSLSetCertificate`, `SSLSetSessionOption`, `SSLHandshake`, `SSLRead`,
`SSLWrite` and `SSLClose` all there, and **no** `SSLSetProtocolVersion`, no `SSLGetServerTrust` and no
`SSLGetNegotiatedProtocol`. So the release's SecureTransport stops at TLS 1.1, and a QUIC handshake -
which *is* a TLS 1.3 handshake, RFC 9001 section 4.2 - cannot be performed with it.

That is a statement about the release's TLS, not about QUIC being unreachable, and the way out is the
one the coordinator named: **picotls and quicly, from h2o, as packages of the port.** Both are MIT,
both are C99 with no dependency the port does not already have, and both have been built here to
measure the claim rather than assert it:

- fetched `h2o/picotls` at `d6c3da61b47cc3ccecaf9aa093c24e4aafebd52a` and `h2o/quicly` at
  `0a163c0e45e728a33f83261d8cf957ac0006935a` (quicly's own submodules, picotls at
  `3598470df01264da85157025ed10db0f7e103790`, klib and picotest, checked out at what its tree pins);
- **picotls-core (3 sources) and picotls-minicrypto (24 sources) compile for `armv7-apple-ios6.0`
  with the port's own clang, the 16.4 SDK and `-femulated-tls`: 27 of 27, no error.** The one thing
  that stops them without that flag is `picotls.h:1583`'s thread-local, and that flag is the port's
  own answer to exactly this release ("what an armv7 build below iOS 9 needs because that release's
  libSystem has no real `__thread`"), the same one `packages/m/matter` builds with;
- **quicly's 14 library sources compile for the same target the same way: 14 of 14, no error**, with
  its tracer header generated from its own `quicly-probes.d` by its own `misc/probe2trace.pl`;
- the undefined symbols the two leave are `__emutls_get_address` and `__emutls_v.*` (the port's own
  emulated-TLS runtime, which `-femulated-tls` links), `__assert_rtn`, `__error`, `__stack_chk_fail`
  and the `__fixdfdi` family (iOS 6's libSystem and the SDK's own `libgcc_s.1`, which is the file the
  SDK package exists to add). Nothing else.

So the two packages build for this release, and what is left before a connection of QUIC parameters
carries a QUIC layer is the transport itself: the two recipes, the quicly context in the connection's
engine (its handshake over the datagram socket, its streams in place of the byte stream, and the
metadata of a QUIC connection filled from quicly's own state rather than from 0), and the
certificate verification picotls-minicrypto deliberately does not do - a chain the port cannot
verify with minicrypto is a chain the port must either verify with its own evaluation or refuse, and
which of the two is right here is a question the emulator run has to answer, not this file.

The same two libraries are what a TLS 1.2 or 1.3 connection needs where the release's own
SecureTransport stops: `nw_tls_copy_sec_protocol_options` of a connection that negotiated above 1.1
would be a picotls options object rather than the release's, and the two sentinels of the port's
`CharonNWSecProtocol` are where a program would find out which of the two a connection got.
