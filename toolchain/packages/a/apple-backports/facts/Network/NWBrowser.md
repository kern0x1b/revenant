# The browser of Network, and what a browse result is

`nw_browser_*` and `nw_browse_result_*` are the surface iOS 13 added for looking for Bonjour services,
and this is what they are built on.

## The substrate is the release's own DNS-SD

A browse is asked with `DNSServiceBrowse`, which is mDNSResponder's own entry point for one and names each
instance it finds and the interface it was found on; `DNSServiceResolve` then answers for each instance with
the port it publishes and the record it advertises. Both are the documented C interface of mDNSResponder
(`dns_sd.h`, shipped in the SDK). Every callback runs on the queue the program gave the browser: each
reference is driven by a dispatch source over its own descriptor (`DNSServiceRefSockFD`,
`DNSServiceProcessResult`), created on that queue, and no handler runs before the browser has been
started.

The browse was a PTR record query until the differential below found it: **a PTR question asked with
`DNSServiceQueryRecord` is answered by nothing on this machine**, while a browse for the same type answers
and a `DNSServiceResolve` in the same process answers three times. Measured in one process that registers
the service itself, driven by `select()` on `DNSServiceRefSockFD` exactly as `dns-sd` drives its own:

| question | `DNSServiceQueryRecord` | `DNSServiceBrowse` | `DNSServiceResolve` |
| --- | --- | --- | --- |
| the type being browsed, PTR | 0 answers in 8 s | answers | - |
| `_services._dns-sd._udp.local.`, PTR - the enumeration of every type on the link, which `dns-sd -B` answers at once | 0 answers in 8 s and in 30 s | answers | - |
| `_airplay._tcp.local.`, `_companion-link._tcp.local.`, `_apple-mobdev2._tcp.local.`, PTR - types that are on the link | 0 answers each | answers | - |
| the registered service's own TXT, SRV and ANY records | 0 answers each | - | answers |
| the registered service, resolve | - | - | 3 answers, one per interface |

So the substrate is the entry point that is a browse, and the port's browse answers on a live link where it
answered nothing at all before.
started.

Every entry point is exported by every release this package builds, measured on the ladder's own caches
through the export trie - `tools/corpus/cache-exports.lua`, because the trie compresses names and a raw
search over the cache bytes is not an oracle (`tools/cicontext-bounds.lua` says so in the same words):

| release | images in the cache | the five DNS-SD entry points | `dispatch_queue_set_specific`, `dispatch_get_specific` |
| --- | --- | --- | --- |
| 4.3 | 354 | `_DNSServiceBrowse`, `_DNSServiceResolve`, `_DNSServiceProcessResult`, `_DNSServiceRefSockFD`, `_DNSServiceRefDeallocate`, all in `/usr/lib/system/libsystem_dnssd.dylib` | **not exported** |
| 6.0 | 516 | the same five, the same image | `/usr/lib/system/libdispatch.dylib` |
| 6.1.3 | 524 | the same five, the same image | `/usr/lib/system/libdispatch.dylib` |

So the browser binds them directly: there is no weak import and no fallback, because there is nothing to
fall back from. The two dispatch calls are not exported by 4.3, which is no gap here: every entry of
`registry/Network/` carries `minimum: 6.0` and the 4.3 band leaves the library out (`facts/Network/NWFloor.md`
says why), so no band that links this object is one that does not export them.

```
VNET_RELEASES="4.3 6.0 6.1.3" VNET_SYMBOLS="_DNSServiceBrowse _DNSServiceResolve \
  _DNSServiceProcessResult _DNSServiceRefSockFD _DNSServiceRefDeallocate \
  _dispatch_queue_set_specific _dispatch_get_specific" xmake l tools/corpus/cache-exports.lua
```

The last column is the whole of what the browser asks the machine for: five DNS-SD entry points and the
pair of libdispatch calls that answer for a queue's own value.

## What each release's own DNS-SD takes, read out of the release

The build SDK is iOS 16.4, and its header is the newest answer to what these entry points take - a
release is free to be older, so the header is not taken for it. One image is taken out of each cache of
the ladder with `tools/cache-extract.lua`, which is dyld.lua's own `extract()`, and the symbol's own
disassembly is read:

```
xmake lua tools/cache-extract.lua modules $HOME/.revenant/dyld/<release>/dyld_shared_cache_<arch> \
  libsystem_dnssd.dylib <out.dylib>
objdump --macho --disassemble <out.dylib>            # then read the symbol
```

| release | image | `_DNSServiceBrowse` takes | the reply it makes takes | its reply handler at |
| --- | --- | --- | --- | --- |
| 4.3 | `libsystem_dnssd.dylib`, armv7 | 7 parameters | 6 | `0x329de514` |
| 6.1.3 | `libsystem_dnssd.dylib`, armv7 | 7 parameters | 6 | `0x3935c970` |
| 8.0 | `libsystem_dnssd.dylib`, armv7 | 7 parameters | 6 | `0x2f977654` |

The entry point's seven are the header's seven, in the header's order: r0 the reference, r1 the flags,
r2 a 32-bit word compared against zero, which is `kDNSServiceInterfaceIndexAny`
(`2f975ace: cmp.w r10, #0x0` on 8.0), r3 the service type as a string, and three incoming stack words for
the domain, the reply and the context. **The reason this port used to avoid `DNSServiceBrowse` - that the
header's `interfaceIndex` is a parameter the releases do not pass - is measured to be false**, and the
entry point is declared in `Network/nw12-browser.m` with what the releases' own symbols take.

The reply is where the header is *not* the answer: the 4.3, 6.1.3 and 8.0 handlers set r0-r3 and two stack
words before calling the program's reply, and the two stack words are the instance name and the context
(`3935c9be..3935c9ce` and `2f9776b6..2f9776c2`), while the 16.4 header's `DNSServiceBrowseReply` declares
eight - the same five, then the service type and the domain, then the context. The port's reply is
therefore declared with the five parameters every measured release's handler sets, and the browser is not
taken from the reply at all: it is the queue's own answer, through the reference the reply carries and
`dispatch_get_specific()`. Every reference of a browser is created and driven on the queue the program
gave it, so the key - the reference itself - is found on that queue and nowhere else, and two browsers on
one queue cannot answer for each other. Reading the five named parameters is right whichever release made
the call, because they arrive in the same registers either way.

What is **not** measured, and is named here rather than assumed: the shape of the reply above iOS 8.0.
`libsystem_dnssd.dylib` of 12.0 hides its internals - 114 exported symbols against 4.3's 154, and no
`_internal_DNSServiceBrowserReply_rpc` - so that image cannot answer it. It does not matter for the
browse, whose reply is read as far as every measured release agrees. It does matter for the **resolve**,
whose reply is read positionally like any other `dns_sd` client's and which this port has always read
with the SDK header's ten parameters, a shape no release of this ladder has been shown to make; the
browse's record comes through that resolve, so on a release that makes a shorter resolve reply the record
would be read from the wrong words. Nothing on this machine can settle that and no device run has been
made.

## Which file holds which call, and why

An object carries the API of one release, measured from the export trie of the caches the ladder holds
and not from the SDK's `API_AVAILABLE`, and this family splits along that measurement:

| file | calls | measured |
| --- | --- | --- |
| `nw12-browser.m` | `nw_browser_create`, `nw_browser_cancel`, and the object | 12.0 |
| `nw16-browser.m` | the two copy calls, `nw_browser_set_queue`, the two handler setters, `nw_browser_start`, and the five `nw_browse_result_*` | 16.0 |

`coordination/corpus/caches/12.0.tsv` carries `_nw_browser_create` and `_nw_browser_cancel` in
`libnetwork.dylib` and carries neither `nw_browser_set_queue` nor any `nw_browse_result_*`; the 16.0
file carries `_nw_browser_set_queue` and `_nw_browse_result_get_changes` in `Network`. The ladder has
no rung between 13.4 and 16.0, so an API the SDK's header calls iOS 13 that no rung up to 13.4 exports
is placed at 16.0. `nw16-listener.m` holds the listener's iOS 16.0 call, and `nw134-listener.m` its
iOS 13.4 calls.
## The port of a browse result's endpoint is 0, which is Apple's own answer

`nw_browse_result_copy_endpoint` hands back an endpoint that names the service - its instance, its type and
its domain - and **carries no port**. Apple's own browse result for the same service, on the same link, in
the same second, answers `nw_endpoint_get_port` with `0`: `tests/backports/host/network-browser` prints
`endpoint.port 0` on the host side and `0` on the port side. That is also what the header of
`nw_endpoint_get_port` says - 0 for an endpoint that is not a host or address endpoint or has no port -
and a Bonjour service endpoint is named by its instance, its type and its domain. The port the service
publishes belongs to the service, and a program reads it by connecting and letting the resolve a
connection makes answer it. The port the browse's own resolve brings is therefore not put on the
endpoint, and `revenant_browser_resolved` does not keep it.

## The interfaces of a result

A browse result hands out `nw_interface_t`. The only objects of that type anywhere on a release with no
Network.framework are the ones `Foundation/NWPathMonitor.m` makes for the path, so the browser keeps one
object per index as the path monitor reports it and an answer naming an index picks its object out of
that table (`nw_interface_get_index` is the port's own way of saying which interface an object is).
Two consequences, both of them what the port can see and neither of them a guess:

* an answer naming an interface the port has no object for - one that went down between the answer and
  the last path update - contributes no interface, and `nw_browse_result_get_interfaces_count` counts
  what is there;
* the path monitor reports the interfaces that carry an address and are up, so an interface that is up
  but not on any path has no object and is not reported.


## What is verified

`tests/backports/host/network-objects` compiles every file of `Network/` - these two included - with
every name it defines renamed, links it beside the host's own Network.framework and runs 203 checks of
the object families (`checks=203 failures=0`).

`tests/backports/host/network-browser` is the browser's own differential, and it is what the substrate and
the port of the endpoint above are measured by: two binaries, one registering a Bonjour service and
browsing for it with Apple's `nw_browser`, the other doing the same with the port's browser compiled
beside it under renamed names with Apple's Network.framework not linked at all. Both are given the same
instance name, and both have to answer with that name - a machine with another publisher of the type says
so rather than passing on it. Ten comparisons - found, the endpoint's type, name, service type, domain
and port, the record's key count, whether it is a dictionary, the change bits and the interface count -
give `compared=10 failed=0`, and with `--mutation` one mutation per comparison, each of which must go red
naming itself: `mutations: 10, failures: 0`. `found` is the one line no single value can move, because a
browser that reports no result at all reports none in every line, so that mutation is asked only to make
`found` red and it takes the other nine with it.
