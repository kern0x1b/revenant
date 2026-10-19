# The path, the gateways and what this release cannot say

The path itself and the monitor that reports it are in `NWPathMonitor.md`. What is here is the four
calls of iOS 13 to 26 that are about a path, each of which asks this release something it does not have:

- `nw_path_is_constrained` (iOS 13) is Low Data Mode, which this release has not got: no path of it is
  ever constrained, which is the answer a device with the mode switched off gives.
- `nw_path_enumerate_gateways` (iOS 13) names the routers a packet leaves by. The one ioctl that needs
  no privilege and answers it is `SIOCGIFDSTADDR`, and it answers for a **point-to-point** interface -
  which is what `pdp_ip0` is, the cellular data connection of this release. A Wi-Fi interface is not
  point-to-point and has no such answer, so the enumeration is empty for a path over Wi-Fi. The next
  step, a route socket, is what a release with no such socket would refuse, and whether iOS 6.1.3 opens
  one is a device measurement still to be taken; the ioctl here is the part that needs no privilege and
  is the whole of the enumeration that can be had without one.
- `nw_path_get_unsatisfied_reason` (iOS 14.2) answers one of the system's own policies - a permission the
  user denied, a network the user turned off. This release's reachability says whether the network is
  there and never why it is not, so an unsatisfied path is unsatisfied for a reason the release does not
  name, which is what `nw_path_unsatisfied_reason_not_available` says.
- `nw_path_get_link_quality` and `nw_path_is_ultra_constrained` (iOS 26) are about a measurement and
  about a kind of network this release has not got: the link quality is `nw_link_quality_unknown`,
  which is the documented "no measurement available", and no path is ultra-constrained.

`nw_path_monitor_prohibit_interface_type` (iOS 14) is the other way round: a kind of interface the
monitor will not report a path over, which the monitor keeps and leaves out of the interface list it
works out for every path it reports - a path over a prohibited interface is then reported with no
interface, which is what a monitor not allowed to use that interface can honestly say about it. It is in
the Foundation library, in a file of its own (`NWPathMonitor14.m`) because an object that exports the
symbols of two introductions is split by the build.

### The measured table the classification reads

`getifaddrs`' AF_LINK `ifi_type` for every interface of this host, beside `ifconfig -v`'s own type. One
run, the same machine, `ifi_type` read from the `struct if_data` behind the `AF_LINK` address:

```
interface   ifi_type   what it is                            IANA ifType (ianaiftype-mib)
lo0         24          the loopback                          softwareLoopback
en0         6           the wired/whatever link               ethernetCsmacd
en1..en6    6           the USB and the Thunderbolt links      ethernetCsmacd
ap1         6           the access point                      ethernetCsmacd
awdl0       6           Apple Wireless Direct Link            ethernetCsmacd
llw0        6           low-latency WLAN                      ethernetCsmacd
utun0,1,2   1           a tunnel                             other        (NOT 131, `tunnel`)
bridge0,100 209         a bridge                              bridge
gif0        55          a GIF tunnel                          propVirtual
stf0        57          a six-to-four translator              ieee1394
```

Two things in it that a name rule could never have got and that the earlier guess got wrong:

- **a tunnel is `other` (1) to the kernel, not IANA `tunnel` (131)** - so a rule that looked for 131
  would have found nothing, and the `IFF_POINTOPOINT` flag is set on a utun exactly as it is on the
  cellular radio, which is why the flag alone could not tell them apart either;
- **a bridge is 209 (`bridge`)**, which is a real interface type of its own and not the loopback or
  anything else.

The cellular radio is the one number IANA does not carry: it is Apple's own `IFT_CELLULAR`, `0xff`, in
XNU's `net/if_types.h` - open source, APSL - and this port's 16.4 SDK ships a `net/if_types.h` with
none of the constants in it (measured: a grep for `IFTYPE` in it answers nothing), which is why that
one is spelled out and cited here rather than taken from a header.

The classification is therefore four branches over one number, and each of them is a check in
`tests/backports/host/network-objects` that the port's own classifier answers, built over synthetic
`AF_LINK` entries carrying the numbers above:

| branch | check | mutation that turns it red |
| --- | --- | --- |
| 24 -> loopback | the loopback number types the loopback | typing 24 as cellular: `system 2 != port 4` |
| 0xff -> cellular | the cellular number types cellular | typing 0xff as loopback: `system 4 != port 2` |
| 6 -> Wi-Fi | the ethernet number types Wi-Fi | typing 6 as other: `system 0 != port 1` |
| default -> other | a tunnel and a bridge are other | typing the default as loopback: both `system 4 != port 0` |
| no AF_LINK entry, `IFF_POINTOPOINT` | an unclassified point-to-point link is other without a gateway | the rule is only reached when the kernel classified nothing |

**Where `ifi_type` cannot decide, the destination-address rule decides, and only there:** when an
interface has no AF_LINK entry at all, the kernel named nothing, and the classifier asks whether the
interface is a point-to-point link **with** a gateway (`SIOCGIFDSTADDR` answering), which is the
cellular radio on this release and which a tunnel does not have. That is the whole of the rule's reach,
and it is why the earlier version of it - which used it for *every* point-to-point interface, on the
theory that a tunnel has no gateway and a p2p link does - was a guess standing in for the fact: it
happened to be right about the two and wrong about the ordering, and it could not have been wrong at
all if it had not been asked `ifi_type` first.

## How an interface's type is decided, and what the name was wrong about

`charon_type_of()` used to read the interface's **name**: `lo` for the loopback, `pdp_ip` for the
cellular radio, `en` for Wi-Fi, everything else `other`. A device run showed four of twenty checks
failing on the untyped cases, and the two halves of it were wrong in the same way:

- `NWPathMonitor.m` dropped every interface it had typed `other` from a monitor that asked for `other`, which is
  the default one, and that was wrong: an `other` interface **with an address** is on the path, and a live
  tunnel has one and a bridge has none.
- a name cannot tell those apart from anything: `utun*` and `bridge*` both fell through to `other`
  because there was no branch for either, and a `pdp_ip*`-named interface was called cellular whatever
  it carried, which a tunnel over Wi-Fi is not.

It reads the kernel's own answers now, none of which is a name:

- `IFF_LOOPBACK` on the flags says a loopback;
- `SIOCGIFDSTADDR` answering for the interface says a point-to-point link **with a gateway**, which on
  this release is the cellular radio. A tunnel is point-to-point too and has no gateway, and that is
  what separates the two;
- anything else is a broadcast-capable link or a bridge, which on this release - which has no wired
  Ethernet - is the Wi-Fi radio.

The `struct if_data` behind the `AF_LINK` entry carries the kernel's `ifi_type` as well, and that is
what the release itself reads, but the `IFTYPE_*` names for it are in XNU's `net/if_types.h` and in
**no Apple SDK** - this port's 16.4 SDK has a `net/if_types.h` with none of them in it (measured: the
grep for `IFTYPE` in it answers nothing). Spelling those numbers out would be a mapping of constants no
SDK on this port carries, and the three answers above are all measurable on a device.

**The device harness, and what it cannot decide.** `tests/backports/device/nwpath.m` asks the monitor for
the type of each interface and compares it with what *it* decides from the interface's **name** -
`pdp_ip*` cellular, `en*` Wi-Fi, `lo*` the loopback, everything else `other`. That rule is in the
harness, not in the port, and it is the rule that cannot tell a tunnel from a bridge: both are `other` to
it, and both would read as `other` whatever the port answers. So a device run confirms the loopback, the
cellular radio and Wi-Fi, and it cannot by itself confirm a tunnel or a bridge; those two are confirmed
here, against the kernel's own `ifi_type` numbers and the mutations in the table above.

### What the release's own path does with a tunnel and a bridge

**One statement, and it is a measurement of this machine: reading only, nothing configured, no network
preference touched.** With 44 interfaces up (`ifconfig -l`), `nw_path_enumerate_interfaces` on a live
path returns, three runs apart and stable:

```
en0      type=1   (wifi)
en0      type=1
utun21   type=0   (other)
```

So **`other` IS on a path.** `utun21` is a live tunnel, the classifier types it `other` because the
kernel's `ifi_type` for it is 1 - IANA `other`, and not 131, `tunnel` - and the release puts it on the
path beside the Wi-Fi interface. What decides an `other` interface is therefore **not its type but
whether the path actually goes through it**, which is whether it carries an address the path can be over.
A bridge has none and is left out for that, not for its name.

That makes the claim the review of 2026-09-29 rejected - and which this file, the monitor's comment and
the differential's comment all said in three places - wrong in all three, and the mutant that took the
`other` filter *out* of the predicate was a mutant in the wrong direction: putting the type filter back
turns the tunnel row red, and so does taking the address away.

The predicate is `charon_path_wants()`, asked with synthetic types in the objects differential - nine
rows, so a filter on the path is a check that can fail rather than a line in a comment - with a mutant
each. A device run over a real tunnel is what would confirm the same thing in the port's own path
assembly, and this file says so rather than claiming it.


**What this does not settle:** the four checks that failed are the device harness's, and they are
re-measured on a device, which is not mine to run. What is measured here is that the four interfaces
the review names are now distinguished by mechanism rather than by name, that both targets compile with
the change (0 errors at armv7-apple-ios6.1.3 and 0 for either at 4.3), and that the light guard and
every host differential still pass. The `NWPathMonitor` rows stay as they were until a device run says
otherwise; if a case there cannot be reproduced, it is written into this file and those calls are not
marked `implemented`.
