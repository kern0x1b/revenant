# The group of connections

`nw_connection_group_*` is the surface iOS 14 and iOS 15 added for a group of connections: one object
that listens for, processes and answers the messages of a group, rather than one connection at a time.

## What the two kinds of group are here, and which one this release can carry

The descriptor says which of the two a group is (`nw_group_descriptor_create_multicast` or
`nw_group_descriptor_create_multiplex`, facts/Network/NWGroup.md).

**A multicast group** is one datagram socket, bound to the port the group's endpoint names, joined to the
group address and to every address endpoint the descriptor added, on every interface that is up. Each
datagram is one message: the bytes arrive whole, the sender's address is the message's remote endpoint,
and the address the datagram was *sent to* is the message's local endpoint - read out of the kernel's own
`IP_PKTINFO` for that datagram (`setsockopt(IP_PKTINFO)` and a `recvmsg` that asks for it), so a datagram
that arrived for a different group on the same port is not mistaken for one of this group's. A descriptor
that says `disableUnicastTraffic` refuses a datagram whose destination is not one of the group's
addresses, which is what that setting means and what the destination address tells.

This is the whole transport: the multicast membership, the bind and the read are the kernel's and the
port's own, and the port adds the four accessors, the answer and the extract the header describes.

**A multiplex group** is one connection that carries many peers, which in Apple's implementation is
QUIC. This release cannot carry it, and the measurement is this library's own: the QUIC transport's facts
(`facts/Network/NWQUIC.md`) record that iOS 6.1.3's SecureTransport has no TLS 1.2, let alone the TLS 1.3
a QUIC handshake is built on, so the port's QUIC connection is a connection over its transport with no
QUIC layer on it. A multiplex group is therefore reported `nw_connection_group_state_failed` with
`EPROTONOSUPPORT` - "protocol not supported", which is what it is - and after that the group answers
every call as an object with no transport answers: no socket, no messages, nothing for a path, and
nothing for the metadata of a protocol. `nw16-quic-options.m` takes the same shape for a parameters of QUIC, and
the four extract and reinsert calls a multiplex group alone would answer are not carried as a
consequence: nothing in this tree calls them.

## Which object holds what

An object holds the API of one release, measured from the export trie of the caches the ladder holds and
not from the SDK's `API_AVAILABLE`. `coordination/corpus/caches/12.0.tsv` carries no `nw_connection_group_*`
at all and `16.0.tsv` carries 32 of them, so the whole family measures at 16.0 and lives in the one file
`nw16-connection-group.m`.

## The interfaces a caller gets, and which are the port's own

`nw_connection_group_extract_connection_for_message` returns an `nw_connection_t`, which is this library's
own connection object over a datagram socket to the address the sender used - the same object
`nw_connection_create` makes, with the group's parameters and its queue. The interfaces a message names
are not in this file's surface: a group has none of its own, and the port's interface objects come from
the Foundation library's path monitor, which this file does not touch.

## What is verified

`tests/backports/host/network-objects` compiles every file of `Network/` - this one included - with every
name it defines renamed, links it beside the host's own Network.framework and runs the object families'
checks; the run's verdict line is in the commit that landed this file.

There is no host differential for a group's own behaviour and this says so plainly: a group needs a
peer on a live link, and a check that joins a multicast group and sends itself a datagram would be a
check of this machine's own loopback rather than of the port against a system that has the API. What the
host differential does cover for this file is that it compiles and links against the host's
Network.framework with every name it defines renamed, which is a real check of the declarations it makes
- `nw_connection_group_reply`'s and `nw_connection_group_send_message`'s `dispatch_data_t`, the receive
handler's `bool` and the state enumeration all come from the host's header there.

`nw16-connection-group.m` has not run on a device. The claim each of its registry entries makes is a
statement about what the code does when a group is brought up, a datagram arrives or a message is
answered, and none of them quotes a host answer.