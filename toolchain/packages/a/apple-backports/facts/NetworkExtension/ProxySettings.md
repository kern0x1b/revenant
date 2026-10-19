# The proxy and IPv4 settings objects, and what each row rests on

`NEProxyServer`, `NEProxySettings`, `NEIPv4Route` and `NEIPv4Settings` are state, as their headers say of
them: the system reads a settings object when a configuration is applied, so what a port object holds is
what a release's own object would hold. The build SDK is 16.4 and has no NetworkExtension.h, so
`NetworkExtension/CharonNetworkExtensionSettings.h` is this package's, written from the iOS 26.2 headers'
own declarations - including the three names capitalised in Apple's header **and** in the ledger:
`HTTPEnabled`, `HTTPSEnabled`, `HTTPSServer`.

## All twenty-three names are comparable here

Before the differential was written, every property name of these four classes was checked against the
host's own classes with `class_getInstanceMethod`: all twenty-three are carried by macOS's
NetworkExtension. So unlike NEDNSSettings - where three names the host lacks had to be checked against
the header and the port alone - nothing in this slice falls back to a header-only oracle.

## The two binaries, and the proof

```
$ sh tests/backports/host/netext-proxy/run.sh
NEProxyServer.dladdr    /System/Library/Frameworks/NetworkExtension.framework/Versions/A/NetworkExtension
NEProxyServer.dladdr    .../netext-proxy2/.agent-work/runs/netext-proxy/port.m
NEIPv4Settings.dladdr   /System/Library/Frameworks/NetworkExtension.framework/Versions/A/NetworkExtension
NEIPv4Settings.dladdr   .../netext-proxy2/.agent-work/runs/netext-proxy/port.m
compared=30 failed=0
```

The four `dladdr` lines are **proofs, not comparisons**: the harness fails when the two sides name the
*same* implementation, because then one of them is answering for both. An implementation out of the dyld
shared cache reports the cache's own image - the strongest statement this proof can make, that the
answer is not in this process's image at all.

Two bugs in that proof are worth recording, because each printed a line that looked green and was empty:
the label was declared `const char *` and handed an `NSString *`, so every line was keyed by garbage and
the harness's `grep` matched nothing; and the line was compared as if it were a value, so a *correct*
proof - two different implementations - read as a failure. The first version of the port-only rows in
the NEDNSSettings harness had the same shape, and the review caught it there.

## What the differential found in this code

`NEIPv4Settings.addresses` and `NEIPv4Settings.subnetMasks`: the host answers an **empty array** on a
fresh object, and the port answered nil - the zero a fresh `NSArray *` ivar gives. The default is now
empty arrays, with a line saying the differential caught it.

## Mutants

Four, one per state comparison, each going red naming itself. One had to be re-spelled because
`return copy;` appears in both objects and the harness refuses an ambiguous mutation:

```
noticed NEProxyServer.username  noticed roundTrip.exceptionList
noticed NEProxySettings.HTTPEnabled  noticed copy.isSameObject
mutations: 4, failures: 0
```

## The compile, gate flags, no `-w`

```
NEProxySettings    exit=0  errors=0  warnings=1
NEIPv4Settings     exit=0  errors=0  warnings=1
  the one warning in each is the sysroot line every file in this package prints
```

## The five rows that are carried, not implemented

`-initWithAddress:port:`, `-initWithDestinationAddress:subnetMask:`, `-initWithAddresses:subnetMasks:`,
`+settingsWithAutomaticAddressing` and `+defaultRoute` **compile and are answered**, and they are **not in
the registry at all**: the differential reads properties, it does not call these, so the only thing
behind them is the compile, and a row with nothing but a compile behind it is not a row. The registry's
own check is the authority - `registry_test` refused a fifth status, and the right answer to that is
what the check says the schema is: four answers, and a name with no answer behind it stays `missing` in
the ledger, which is where these five are.

The first attempt to call them from the probe went through `performSelector:withObject:withObject:`
with an `NSInteger` argument and raised `NSInvalidArgumentException` in the port's own binary - a mixed
scalar/object selector does not go through that path - so the probe was returned to the state that is
green rather than left holding a construction that cannot work.

Two property rows go with them for the same reason: `NEProxyServer.address` and `NEProxyServer.port`
are readonly and are set only by `-initWithAddress:port:`, so no check reaches them either. That is
**27 of the 27**: the registry carries 25 rows, all `implemented`, and the five class methods plus those
two readonly properties stay `missing` in the ledger until a call reaches them. Nothing in this family
is `absent`.
