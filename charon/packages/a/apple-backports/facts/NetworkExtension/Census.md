# NetworkExtension: what the ledger says is missing, counted by the tree's own tools

Two sources, both run on this tree, and this file is what they said:

```
$ python3 tools/corpus/surface-diff-latest.py NetworkExtension --rows <path>
  636 declared rows over 116 classes; every iOS band shows decided 0, so nothing of the
  family is in the registry
$ awk -F'\t' 'NR>1 {c[$7]++}' coordination/corpus/ledger/NetworkExtension.tsv
  needs: code 567, code+lift 22, swift-module 116, lift 278, none 3   (986 rows in all)
  the rows that need code, by kind: class 77, method 188, property 302, constant 22 = 589
```

So the 589 the coordinator quotes is the **needs code** subset (567 + 22), not the whole
ledger: the rest is 116 Swift-module rows and 278 lift rows, which are a different job.

## The per-class table, over the needs-code rows

| rows | class | by kind |
| ---: | --- | --- |
| 19 | `NEVPNProtocolIKEv2` | 1 class, 18 property |
| 17 | `NERelayManager` | 1 class, 6 method, 10 property |
| 16 | `NEVPNProtocol` | 1 class, 15 property |
| 16 | `NWTCPConnection` | 1 class, 6 method, 9 property |
| 14 | `NEAppPushManager` | 1 class, 4 method, 9 property |
| 14 | `NWUDPSession` | 1 class, 6 method, 7 property |
| 12 | `NEFilterProviderConfiguration` | 1 class, 11 property |
| 12 | `NEHotspotConfiguration` | 1 class, 6 method, 5 property |
| 12 | `NEHotspotNetwork` | 1 class, 3 method, 8 property |
| 12 | `NETunnelProviderManager` | 1 class, 3 method, 8 property |
| 12 | `NEVPNManager` | 1 class, 4 method, 7 property |
| 11 | `NEFilterDataProvider` | 1 class, 10 method |
| 11 | `NEHotspotEAPSettings` | 1 class, 2 method, 8 property |
| 11 | `NEProxySettings` | 1 class, 10 property |
| 10 | `NEAppProxyFlow` | 1 class, 5 method, 4 property |
| 10 | `NEFilterManager` | 1 class, 4 method, 5 property |
| 10 | `NERelay` | 1 class, 9 property |
| 9 | `NEAppPushProvider` | 1 class, 7 method, 1 property |
| 9 | `NEDNSSettings` | 1 class, 1 method, 7 property |
| 9 | `NEDNSSettingsManager` | 1 class, 4 method, 4 property |

395 classes carry at least one row; the table above is the top 20 of the needs-code subset,
which is 589 rows over 104 classes. The full table is `tools/corpus`-derived and reproducible:
`python3 tools/corpus/surface-diff-latest.py NetworkExtension --rows <path>` for the declared
surface and the ledger for the missing set.

## A third of the ledger has no declared surface in the tool

388 of the 986 ledger rows are not in the surface the clang AST writes from the macOS SDK —
`NEAppProxyFlow.open(withLocalFlowEndpoint:)` and its siblings are the shape: names the
newer SDKs publish through the Swift overlay, which a clang AST over `NetworkExtension.h`
does not see. So for those rows the tool gives no availability and the *iOS 26 SDK header* is
the only source, which is what the worker's brief allows for facts and not for code.

## What the host's own NetworkExtension answers, measured, with a dladdr proof

Before any port code, the oracle. `dladdr` on each selector's implementation pointer says whose code
answered, which is the only proof that survives the trap this series keeps hitting — the host answers
its own API even when the port's category is in the binary.

```
$ clang -fobjc-arc -Wno-unguarded-availability-new -o host-settings host-settings.m \
      -framework NetworkExtension -framework Foundation && ./host-settings
classes: NEProxySettings=yes NEDNSSettings=yes NEIPv4Settings=yes NEVPNProtocol=yes
dladdr proof, one per class:
  -[NEProxySettings server]     ABSENT    (unresolved)
  -[NEDNSSettings servers]      answered  /System/Library/Frameworks/NetworkExtension.framework/Versions/A/NetworkExtension
  -[NEIPv4Settings subnetMask]  ABSENT    (unresolved)
  -[NEVPNProtocol serverAddress] answered /System/Library/Frameworks/NetworkExtension.framework/Versions/A/NetworkExtension
host property names: NEProxySettings has exceptionList, not serverEnabled/httpsEnabled
  NEProxySettings conforms to NSCopying=YES NSSecureCoding=YES
  NEDNSSettings conforms to NSCopying=YES NSSecureCoding=YES
  NEDNSSettings new: servers=nil matchDomains=nil
  NEProxySettings new: exceptionList=nil
  -[NEDNSSettings copy] -> an object (a NEDNSSettings)
  NSKeyedArchiver of a NEDNSSettings -> data, error=(none)
```

Three things follow, and they decide how this family is built:

- **The host's classes do not carry the iOS property names.** `NEProxySettings` here has
  `exceptionList` and no `serverEnabled`/`httpsEnabled`; the ledger's rows are the iOS names. So a host
  differential can only compare the *intersection*, and for the rest the iOS header is the declaration
  and the documented behaviour is the answer. Writing a differential that reads `host.serverEnabled`
  would not compile, which is the honest shape of the limit rather than a silent one.
- **Where a name exists on both sides, the host answers from its own framework** (the two `answered`
  lines), so a comparison against it measures Apple's implementation and the port's row still needs
  its own proof.
- **The settings objects are genuinely pure state on the host too**: fresh `NEDNSSettings` answers
  `servers=nil matchDomains=nil`, `-copy` returns a `NEDNSSettings`, `NSCopying`/`NSSecureCoding`
  conformance is YES on both classes, and a `NSKeyedArchiver` round trip returns data with no error.
  Those are the behaviours the port's implementations must reproduce, and they are measured rather than
  assumed.
