# The group of connections

`nw_group_descriptor_create_multicast` and `nw_group_descriptor_create_multiplex`, the member and
enumeration calls, and the three calls of a multicast group are what a program says about the members
of a group of connections: a multicast group address every message goes to, or the set of remote
endpoints a multiplex group sends to.

`nw_group_descriptor_add_endpoint` does not follow the host, and the difference is written down here
because it is a place where the port answers for itself. The header says it answers true when the
endpoint was added and false when the endpoint was not of a valid type and therefore was not added. The
host's own Network, asked for every kind of endpoint - a host name, a numeric host, a URL, a Bonjour
service, on a multicast group and on a multiplex one - answers **false every time and adds nothing**:
the enumeration of a group still yields the group address and the remote endpoint and never a member
(measured; `tests/backports/host/network-objects` records the measurement as two of its own checks
rather than a comparison, and the rest of the group is compared). The port follows its own header: an
endpoint that names a peer - a host or an address - is added and `true` is answered, and an endpoint of
any other kind is refused with `false`.

The group's own transport is not in this delivery: see the delivery's note about the transports.
