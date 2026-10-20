# The path monitor of Network, iOS 12

`nw_path_monitor_t` reports the path the device reaches the network by: whether there is one, over which
interface, whether it costs money. Swift's `NWPathMonitor` and `NWPath` are made of these calls, so a program that
imports Network and only watches the network is carried by them. Only the path monitor is: connections, listeners,
browsers and the rest of Network are not carried.

Source: the host's Network, asked for every call (`tests/backports/host/network`, 20 checks, the port compiled with
its names changed beside the system's); SystemConfiguration of iOS 6, whose reachability the port is built on; an
iPad 2 running 6.1.3 with its Wi-Fi taken away and put back (`tests/backports/device/nwpath.m`).

## What it does

- The path is worked out from `SCNetworkReachability` of the network in general and from the interfaces that are up:
  **satisfied** when the network is reachable and needs no connection, **satisfiable** when a connection is needed
  first, **unsatisfied** when it is not reachable. The interface is the Wi-Fi one (`en0`) or, when the reachability says
  the network is over the cellular data (WWAN), `pdp_ip0`; a path that is over cellular is expensive. IPv4 and IPv6 are
  addresses on the interface that are not link-local; the name server is the resolver's.
- `nw_path_monitor_start` reports the path **on the queue**, never before the call returns, and again on every
  start; after that a path is reported when it is different from the last one (status, interface, expense, addresses).
  A monitor without a queue reports nothing. `nw_path_monitor_cancel` calls the cancel handler once on the queue, however
  often it is asked, and nothing is reported after it; a cancel that comes at once does not take back the path
  that was already on its way.
- A monitor made with a type reports only paths over an interface of it: cellular on a device with no cellular is
  unsatisfied and lists no interface, loopback is satisfied with `lo0` and has no addresses.
- The interface answers its name, index and type; two paths are equal when they say the same.

## Where iOS 6 answers differently

- The system lists an interface twice (the host said `en0` twice); the port lists it once.
- The path knows one interface, the one of the network in general: a device with Wi-Fi and cellular at once is told
  by the system to have both, and here by the flags to have the one the reachability says.
- `nw_path_monitor_prohibit_interface_type` (iOS 14), `nw_path_is_constrained`, the gateways and the unsatisfied reason are iOS 13 and 14 and not carried;
  `nw_path_copy_effective_*_endpoint` answer NULL, as the system does for a monitor's path.
- From iOS 9 the release has `nw_path_*` and `nw_interface_*` calls of its own (its path type is a class of its own, and it has no
  monitor until iOS 12). The port's paths are objects of the port's own classes, so on those releases the release's calls
  receive them and are not meant to; the port is written for iOS 6 to 8, where the release has none of it.

## How many updates a start delivers

The host's monitor is not steady in how many updates a start delivers, and the port's is. Measured by running the
host differential (`tests/backports/host/network`) 25 times, 10 at rest and 15 with eight processes spinning on the
CPU, the counts per case were (host, then port):

| case | host | port |
|---|---|---|
| general, general cancelled at once, type cellular, type loopback, type wired | 1 in 25 | 1 in 25 |
| general twice | 2 in 24, 3 in 1 | 2 in 25 |
| type other | 1 in 22, 2 in 3 | 1 in 25 |
| type wifi | 1 in 23, 2 in 2 | 1 in 25 |

The port's counts did not vary in any run. The host's did, on three cases, and only under load: the extra update is a
second delivery of a path the host had already reported. The port reports a reachability change only when the path
differs from the last one it reported (revenant_deliver), and its count is what it always is. The differential therefore compares the port's count exactly with the host's count where
the host is steady, and for the three cases above it requires the port to deliver the host's floor (2, 1, 1) and
the host to deliver at least that floor.
