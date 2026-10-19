# The objects of Network's C API, iOS 12 to 26

Every `nw_*` call that hands back an object or holds a setting, for a release that has no Network at
all. There is no release below iOS 9 whose own calls would reach these objects, so nothing here is a
substitute for the system's; the objects are the port's own, made out of the data a program gives
them, and every getter answers the release's own answer for what a program has (and has not) said.

**Source: the host's own Network.framework, asked the same question of the port's implementation
compiled beside it with its names changed, and the two answers compared** -
`tests/backports/host/network-objects`, 176 checks, the port's files compiled with every symbol they
define renamed (`-Dnw_x=charonhost_nw_x`, `-DCharonX=CharonHostCharonX`) and one program reaching
either side through one table of function pointers. The host is macOS 27.0 (build 26A428), whose
Network.framework carries the whole of the 26.2 API. Where a value had to come from a real release and
not from a header, it is said so below.

## What is built out of what

- Every `nw_*` type is a protocol of the SDK's own making (`OS_OBJECT_DECL` makes `nw_path_t` an
  `NSObject<OS_nw_path> *`), so each object here is an `NSObject` that adopts the protocol of the type
  it is. The classes and their state are in `CharonNW.h`, their implementations in
  `CharonNWObjects.m`, and the few pieces of C every file needs in `CharonNWSupport.c` - which is C so
  that nothing in it is exported, because a helper an Objective-C file defined would be a symbol the
  registry has to describe and a file that carries API of two releases would be split from under it.
- One file per family **and per release**, named for the release (`nw12-core.m`, `nw13-txtrecord.m`,
  `nw14-privacy.m`, `nw134-quic.m`, `nw16-quic-options.m`, `nw134-framer.m`, `nw16-*.m`, `nw17-proxy.m`, `nw26-*.m`), because
  `modules/apple/backports.lua` raises on an object that exports the symbols of two introductions. What
  the files share is the header and the C file; a helper that lives in a file carrying API of one
  release is dropped from a band that keeps a later release, and a call of that band would then be
  undefined - which only the all-band build of `canon-install` would show.
- A setting is kept under the name the SDK's own setter for it uses, so the connection reads back
  exactly what the program set, and a setting nobody set reads as the default its getter documents.
- The settings that reach the socket are not decoration: the TCP options become `setsockopt` calls
  (`TCP_NODELAY`, `SO_KEEPALIVE` and its three times, the buffer sizes, the service class) and the path
  settings are what the path monitor is asked. That is the connection's own file.

## What the comparison found, and where the port follows its own header instead

These are the answers a program can see that the header alone would not have given, all measured
(tests/backports/host/network-objects):

- **An endpoint is valid only when its port names something.** A host with no port, or with a port that
  is neither a number nor a service in the system's own services file, is no endpoint at all - not an
  endpoint that answers zero. A host that is already an address is an *address* endpoint, and still
  answers the host it was made from as its own text; an address endpoint answers its address as text and
  its port as text, and `nw_endpoint_copy_address_string` is NULL where there is no address rather than
  an empty string.
- **A Bonjour service needs all three of what it is.** No name, no type or no domain is refused. A port
  of "http" is resolved through the system's own services file, so the endpoint keeps the number.
- **A URL is a URL when it has a scheme.** The host is what its authority names and nothing where the
  authority names nothing; the port is its own or, failing that, the one its scheme answers (80 for
  http, 443 for https, 21 for ftp); the brackets of an IPv6 literal are part of the text and not part
  of the host.
- **A final content context is finished.** Once `nw_content_context_set_is_final` has been called it
  reports the default priority and no expiration, whatever was set before it and whatever is set after,
  and it takes no antecedent. An antecedent is the context that was set, held, not a copy of it.
- **Two framer definitions of one name are different protocols.** A framer's definition is made afresh
  and belongs to the program that made it, so two of them are never equal - the built-in definitions,
  which the system hands out as one per process, are.
- **A TXT record of no bytes is no record**, and an empty record is the single zero byte that a service
  saying nothing publishes. A record made of bytes is a dictionary of the key-value pairs in it; a key
  with no `=` has no value at all, which is not the same as an empty value, and a key that is empty, that
  is longer than 255 bytes or that holds a byte outside printable US-ASCII is invalid - refused by
  every call that takes one, as RFC 6764 asks.
- **Options are not metadata.** `nw_protocol_metadata_is_tcp` of TCP *options* is false, and so is the
  rest: a predicate is about a message. `nw_tls_copy_sec_protocol_options` is the exception - it hands
  out the Security.framework object for any options of its own kind, while the QUIC pair asks first
  whether the object is QUIC's.
- **A stack is not a stack until it is used.** The default stack of `nw_parameters_create` holds the
  internet protocol and *no transport*: the transport is decided when a connection is made of it, which
  is a TCP connection because that is what a connection with no transport is. Every other factory
  hands back a stack with a transport, `NW_PARAMETERS_DISABLE_PROTOCOL` leaves that protocol out, and
  QUIC - which carries its own transport - shows no protocol at all.
- **The sentinels are compared by pointer**, so they are real objects: the two blocks the header names
  are defined here as the empty blocks they are documented to behave as, and a factory that is given a
  block of the caller's own runs it.
- **The QUIC defaults are the documented ones**: an idle timeout of 30000 ms, a maximum UDP payload of
  65535, and flow-control limits of `UINT64_MAX`, which is "no limit of our own". A message that is not
  QUIC's answers 0 for every one of QUIC's metadata getters and takes none of its setters.
- **The WebSocket metadata of a message with no close code says 1005**, which is the code for "no status
  received"; options of no version are still options.
- **`nw_data_transfer_report` is a snapshot.** Until the block of `nw_data_transfer_report_collect` has
  been given it, it is outstanding, its state is not `collected`, and every value answers 0 - which is
  what the header says a report that is not collected answers. The connection writes its counters into
  the report when it hands it out, so the numbers appear when it is collected and do not change after.

## What each row was measured against, and the rows a comparison cannot be made for

Every entry's `source` names what was done for that row, and the families where a comparison with the
host is not what happened say so in their own words rather than in a note elsewhere:

- **The proxy configuration, the relay hops and the privacy context's proxies (19 rows)** are the port's
  own checks, `tests/backports/host/network-proxy`, 20 checks, every call of the family. They are not a
  host differential because the host's own Network cannot be driven through this family in this
  build: it answers the five factories - each of which logs its own refusal for a missing argument and
  carries on - and then traps with `EXC_BREAKPOINT` inside `objc_opt_respondsToSelector`, at two
  different points of a run, so it is not one bad argument. Two of the rows, the two domain
  enumerators, are called by the test that adds and clears a domain and stop short of the enumerators:
  the same sequence in a program that links the same objects does not trap, so the trap is in how that
  harness reaches them - measured, not diagnosed, and the rows say so.
- **The path (5 rows)** are compared over a real path of each side's own monitor, both started and both
  paths read. The gateways' *enumeration* is the port's own shape, because what each side can name is
  its own network - the host names its own routers, the port names the ones this release's ioctl can -
  and the link quality is the port's own check, because two different machines' links are not one
  measurement (`NWPath.md`).
- **The framer's engine (24 rows) and the two reports (15 rows) are the port's own and are NOT
  compared with the host.** A framer object is made by a connection and no differential here puts one
  in a stack, so the engine's `parse_input`/`parse_output`, its `deliver_input`, its three writes, its
  pass-through, its wakeups, its handlers and its endpoint and parameter copies have no comparison
  behind them; the framer's *definitions, options and messages* are compared (36 of its rows are), and
  so are the path monitor and the parameters. The reports are filled when a program asks a connection
  for them, and no differential drives that call. What each of those rows says is the effect, and what
  was done is what its `source` now says - implemented and read, not measured. The framer's engine is
  a real state machine, and the reports are real accessors; the claim that is *not* made is that they
  have been compared with Apple's.

## Where the port answers for itself, and says so

- **`nw_content_context_create(NULL)` traps on the host** (measured: the process dies of an
  uncaught `NSInvalidArgumentException`), so there is no host answer to compare. The port refuses it
  with NULL, which is what the header says a factory does when it fails.
- **`nw_group_descriptor_add_endpoint` adds nothing on the host** and answers false for every endpoint
  tried - a name, an address, a URL, a Bonjour service, on a multicast group and on a multiplex one
  (measured; its enumeration still yields the group address and the remote endpoint). That is not what
  its own header says, which is "true if the endpoint was added, false if the endpoint was not of a
  valid type and therefore not added". The port follows the header: an endpoint that names a peer - a
  host or an address - is added and `true` is answered, and one that names no peer is refused with
  `false`.
- **The default of `nw_quic_get_max_datagram_frame_size` on the host is uninitialised memory** (two runs,
  two numbers), so there is no value of the system's to compare. The port answers 0, which is the
  documented way of saying that a connection sends no datagram frames at all.

## What the release has no answer for, and which answer the port gives

- **A constrained path** is Low Data Mode. The release has no such mode, so no path of it is ever
  constrained - the answer a device with the mode switched off gives is `false`. A program that sets the
  flag on its parameters still has it set, and the connection reads it as it reads every other path
  setting.
- **An unsatisfied reason** (iOS 14.2) is one of the system's own policies: a permission the user denied,
  a network the user turned off. This release's reachability says whether the network is there and
  never why it is not, so an unsatisfied path is unsatisfied for a reason the release does not name,
  which is what `nw_path_unsatisfied_reason_not_available` says.
- **Gateways** (iOS 13) are the routers a packet leaves by. The release's own ioctl that names the router
  of an interface without any privilege is `SIOCGIFDSTADDR`, and it answers for a point-to-point
  interface - which is what a cellular data connection on this release is. A Wi-Fi interface is not
  point-to-point and has no such answer, so nothing is enumerated for it; that gap and the ioctl are in
  `facts/Network/NWPath.md` with the measurement.
- **A link quality** (iOS 26) is a measurement the release has no way to make: the interface is up or it
  is not, and what a program can read by hand is not what this measures. Every path answers
  `nw_link_quality_unknown`, which is the first of the four values and is what the system answers where
  it has no measurement either.
- **An ultra-constrained path** (iOS 26) is a low-bandwidth link meant only for a device of its own. The
  release has none, so no path is one.
- **A radio type** (iOS 15) is behind an interface the system does not let a program ask about, so a
  path over Wi-Fi or over cellular has none to report, which is `nw_interface_radio_type_unknown`.
- **A privacy context, a resolver configuration and a proxy configuration** (iOS 14, 17) are carried as
  what a program said: the context has the description it was given, the resolver has its endpoint and
  its addresses, the proxy has its kind, its endpoint, its credentials, its domains and whether a
  failover is allowed. The release resolves names with the resolver the system gives it and has no
  per-connection proxy, so a connection is made to the peer its endpoint names - and says so in its
  establishment report rather than pretending to have gone through a proxy. `facts/Network/NWProxy.md`.

## What the reports are without a connection

`nw_data_transfer_report` and its eighteen accessors, and the establishment and resolution reports a
connection fills in, are here and are measured where they can be measured without one: the state of a
report, and the rule that every value of a report answers 0 until the block of
`nw_data_transfer_report_collect` has been given it, which is what the header says a report that is not
collected answers. The numbers themselves are the connection's - the bytes it moved, the times it took,
the addresses it tried - and the call that hands a program a report,
`nw_connection_create_new_data_transfer_report`, is part of the connection and is not in this delivery.
So a program cannot get a report yet; what it would get is the connection's own measurements, and the
release's `TCP_CONNECTION_INFO` for the three round-trip times, which the SDK declares and which a kernel
older than the call answers ENOPROTOOPT to - where it does, the report says 0 for a measurement the port
could not take, and that is the whole of the gap.

## What the port has no transport for, and what that means for these calls

Three of the protocols these objects configure have no transport in this port: **QUIC**, **WebSocket**
and any **proxy or relay** - and the **application service** of `nw_*_create_application_service`, whose
publishing and browsing side is the listener's and the browser's, which are not in this delivery
either. What is here is the configuration and the description of those protocols -
what a program sets and what it reads back, which is real and is what the host's own Network answers
for the same calls - and what is *not* here is a connection that speaks them. A connection of QUIC or
WebSocket parameters is a connection over its transport with no layer of that protocol on it. The rows
are the option and metadata objects, which work; the transport is absent rather than faked, and
`facts/Network/NWQUIC.md`, `facts/Network/NWWebSocket.md` and `facts/Network/NWProxy.md` say so.

## The 21 names the port's own SDK does not declare

Twenty-one of the functions here are exported and the SDK the port compiles against (16.4) does not
declare them: the seventeen of iOS 17 (`nw_proxy_config_*`, `nw_privacy_context_add_proxy`,
`nw_privacy_context_clear_proxies`, `nw_relay_hop_create`,
`nw_relay_hop_add_additional_http_header_field`) and the four of iOS 26
(`nw_parameters_get/set_allow_ultra_constrained`, `nw_path_get_link_quality`,
`nw_path_is_ultra_constrained`) - measured against the SDK's own headers and
`coordination/corpus/sdk-16.4-declared.json`, which agree. There is no prototype for any of the
twenty-one anywhere in the tree, so **a program built against the port's SDK cannot name one of them
without declaring the prototype itself**; the two types they need (`nw_proxy_config_t`,
`nw_relay_hop_t`) are the port's own declarations, under `__has_include(<Network/proxy_config.h>)` so
that a newer SDK's declarations are never made twice (`CharonNW.h`).

`NW_ALL_PATHS` is **not** one of the twenty-one - the 16.4 SDK declares
`_nw_data_transfer_report_all_paths` at `connection_report.h:538-539` - and neither are the two
sentinel blocks, which it declares through `NW_PARAMETERS_CONFIGURE_PROTOCOL_DECL`
(`parameters.h:72-78`).


## The exported symbols

- `nw_retain` and `nw_release` are C functions here as well as the header's Objective-C macros, for a
  translation unit that is not Objective-C and for the two of them to be found where the SDK declares
  them. The macros are taken back in the file that defines them, or the definitions would be macros.
- `kNWErrorDomainPOSIX` is `NSPOSIXErrorDomain`, `kNWErrorDomainTLS` is `NSOSStatusErrorDomain`,
  `kNWErrorDomainDNS` is `kNWErrorDomainDNS` and `kNWErrorDomainWiFiAware` is `kNWErrorDomainWiFiAware` -
  each read out of the host's own Network with a program that prints what the symbol points at, not
  taken from the name and not from a comment.
- `_nw_data_transfer_report_all_paths` is `UINT32_MAX`, the value the host's own Network holds for it.
