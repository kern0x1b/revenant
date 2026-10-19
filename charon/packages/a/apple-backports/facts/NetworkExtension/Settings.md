# NEDNSSettings: pure state, and what each answer was measured against

The settings objects are state and nothing else: the system reads them when a configuration is
applied, and the port's object holds what a caller sets. That is why the implementations here are
property storage with the `NSCopying`/`NSSecureCoding` behaviour the header declares, and why no daemon
is involved — an object that answered from a daemon would be a different API.

## What the host's own NetworkExtension answers, and the dladdr proof

The differential is **two binaries**, because one process cannot hold both implementations of a class
with the same name and a comparison that cannot say which answered proves nothing:

```
$ sh tests/backports/host/netext-settings/run.sh
=== host: Apple's own answers, and the image that answered
dladdr	NetworkExtension          <- from /System/Library/Frameworks/NetworkExtension.framework
=== port: the port's own answers, Apple's framework not linked at all
dladdr	port
=== compared, name by name
ok  fresh.servers (nil)          ok  fresh.searchDomains (nil)   ok  fresh.matchDomains (nil)
ok  fresh.matchDomainsNoSearch YES   ok  copy.isSameObject NO      ok  copy.isKindOfClass YES
ok  archive.hasData YES          ok  archive.errorDomain (none)  ok  roundTrip.isKindOfClass YES
ok  roundTrip.servers (nil)
=== the three names Apple's class does not carry, against the iOS 26.2 header
ok  dnsProtocol    declared in the 26.2 header (@property (readonly) NEDNSProtocol dnsProtocol)
ok  domainName     declared in the 26.2 header (@property (copy, nullable) NSString *domainName)
ok  allowFailover  declared in the 26.2 header (@property BOOL allowFailover)
compared=13 failed=0
```

`dladdr` on the `servers` selector's implementation pointer names the answering image in each binary,
which is the proof the comparison rests on: `NetworkExtension` on the host side, `port` on the port
side. The host's class does **not** carry `dnsProtocol`, `domainName` or `allowFailover`.

**Three of the nine values are therefore checked by the header and the port alone**, and the harness
says so on every line it prints: the declaration against the 26.2 header, and the behaviour against
eight port-only assertions — each property's declared default, the setter round trip and the keyed-archive
round trip — read through the typed getter, so a getter that answers the wrong value fails rather than
passing:

```
ok  portOnly.dnsProtocol.default   YES       (port-only: the host has no such name)
ok  portOnly.dnsProtocol.afterSet  YES       (port-only: the host has no such name)
ok  portOnly.domainName.isNil      YES       (port-only: the host has no such name)
ok  portOnly.domainName.afterSet   a string  (port-only: the host has no such name)
ok  portOnly.allowFailover.default YES       (port-only: the host has no such name)
ok  portOnly.allowFailover.afterSet YES      (port-only: the host has no such name)
ok  portOnly.coding.domainName     a string  (port-only: the host has no such name)
ok  portOnly.coding.allowFailover  YES       (port-only: the host has no such name)
compared=21 failed=0
```

The six names the host does carry are compared against Apple's own answers as before. The three above
are the ones whose oracle is this paragraph and those assertions, and the three rows' `source` fields
name it where a reader of the registry looks.

## What the differential found

`fresh.matchDomainsNoSearch`: the host answers **YES** on a fresh object, and the port answered **NO**
— the zero a fresh `BOOL` ivar gives. The default is now YES, with a line saying the differential
caught it. That is the whole reason the two answers are in two binaries and compared, rather than the
port's defaults being written down from the header and believed.

## The mutants

One per comparison, seven of them, each has to go red naming its own comparison and a mutation that
does not build is RUN FAILED, never counted as noticed:

```
$ sh tests/backports/host/netext-settings/run.sh --mutation
noticed fresh.servers   noticed fresh.searchDomains   noticed fresh.matchDomains
noticed fresh.matchDomainsNoSearch                   noticed copy.isSameObject
noticed copy.isKindOfClass                           noticed roundTrip.servers
mutations noticed: 7, failures: 0
```

## The compile, with the gate's flags and no -w

```
$ clang -target armv7-apple-ios6.1.3 -isysroot <16.4 SDK> -fobjc-arc -Os -g0 -Wall \
        -Wno-unguarded-availability-new -Wno-unguarded-availability \
        -Werror=objc-missing-property-synthesis -I… -c NetworkExtension/NEDNSSettings.m
exit=0  errors=0  warnings=1
  the one warning is the sysroot line every file in this package prints
```

## The rest of the family

`NEDNSSettingsManager` and the other manager classes are the half of NetworkExtension that talks to the
system's preference daemon, and they are a different job: they answer as Apple does without an
entitlement, with the documented error domain and codes, measured on the host. The four classes
`NEProxySettings`, `NEProxyServer`, `NEIPv4Settings`, `NEIPv4Route`, `NEIPv6Settings` and `NEIPv6Route`
are settings objects like this one, and their header and object are written.

**The IPv6 pair** (`NetworkExtension/NEIPv6Settings.m`, one object and one release, the 9.0 both get from
the 26.2 header) is state over its IPv4 counterparts, and its one answer that is not a copy is
`+[NEIPv6Route defaultRoute]`: the route whose destination is the unspecified address with a prefix
length of zero. The header only says "the route that matches everything", so the value came from the
host's own class - `tests/backports/host/netext-proxy/run.sh` compares it name by name and both sides
answer an object whose destination and prefix are those, which is what makes the port's answer measured
rather than asserted.

The two class methods `+settingsWithAutomaticAddressing` and `+settingsWithLinkLocalAddressing` are
marked `API_UNAVAILABLE` on every platform in the 26.2 header, so Apple's own class does not carry them
and a host comparison cannot be their oracle. They are carried, because the header's own text declares
them and a caller that reads them compiles against this package's header; the run checks each name
against that header, which is the oracle `registry/README.md` names for a name no host carries.

**The capitalised names, corrected.** An earlier version of this paragraph said the ledger spells two of
`NEProxySettings`'s properties in lowercase. It does not: `NEProxySettings.HTTPEnabled`,
`NEProxySettings.HTTPSEnabled` and `NEProxySettings.HTTPSServer` are capitalised in the ledger and
capitalised in the 26.2 header, and the rows for the next series are written that way. The error was in
reading the surface dump, not in the ledger.
