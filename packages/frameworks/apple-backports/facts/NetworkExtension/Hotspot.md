# NEHotspot: the network and configuration objects, what the host answers, and the join route

Three names of the family are strong-imported by applications in the crash corpus and die at load on
6.1.3: NEHotspotConfiguration, NEHotspotConfigurationManager and NEHotspotHelper
(`coordination/corpus/crash-demand-top.tsv`, rows 80, 81 and 174). This file covers the two data classes
that are carried, NEHotspotNetwork and NEHotspotConfiguration, the manager and the helper, which answer with the
host's answers and drive no join, and the join route they leave undriven.

## What is carried

- `NetworkExtension/RevenantNEHotspot.h`: the declarations, from the iOS 26.2 SDK's `NEHotspotNetwork.h`,
  `NEHotspotConfigurationManager.h`, `NEHotspotHelper.h` and the `(HotspotHelper)` category of `NEHotspotHelper.h`.
- `NetworkExtension/NEHotspotNetwork.m`: the state object, and `+fetchCurrentWithCompletionHandler:`.
- `NetworkExtension/NEHotspotConfiguration.m`: the four initializers and the two that take settings, the properties,
  `-copy` and the keyed archive.
- `NetworkExtension/NEHotspotEAPSettings.m` and `NetworkExtension/NEHotspotHS20Settings.m`: the two settings classes,
  their properties, `-copy` and the keyed archive.
- `NetworkExtension/NEHotspotConfigurationManager.m`: the shared manager and its four methods.
- `NetworkExtension/NEHotspotHelper.m`: the helper's three class methods, and the NSMutableURLRequest category.
- `NetworkExtension/NEHotspotHelperCommand.m` and `NEHotspotHelperResponse.m`: the command and the response.
- `registry/NetworkExtension/hotspot9.json`: one entry per name, with its introduced, minimum and maximum release.
- `tests/backports/host/netext-hotspot/`: the differential, with one planted control per comparison group.

Carried in this slice: NEHotspotEAPSettings and NEHotspotHS20Settings, their enumerations, and the two initializers
of NEHotspotConfiguration that take them (measured in "The enterprise and Hotspot 2.0 settings" below). Not carried:
the iOS 18 `interface` property of NEHotspotHelperCommand (its type is Network's nw_interface_t) and the two
`joinAccessoryHotspot` methods of the manager (they take an ASAccessory); those stay absent in the registry, so they
answer NO to respondsToSelector:.

## What the host answers, measured

The host is Mac Catalyst: NEHotspotNetwork and NEHotspotConfiguration are `API_UNAVAILABLE(macos)` in the SDK,
and only the Catalyst image carries them. The probe is `tests/backports/host/netext-hotspot/probe.m`, built once
for the host with `-framework NetworkExtension` and once for the port with the port's sources, and each
operation runs in its own process.

NEHotspotNetwork, a fresh object built with `alloc` and `init`:

```
securityType 0, signalStrength 0, isSecure NO, didAutoJoin NO, didJustJoin NO, isChosenHelper NO
setConfidence: and setPassword: return, and the object keeps going
SSID: SIGSEGV (signal 11, exit 139) on the read. BSSID is not reached.
```

fetchCurrentWithCompletionHandler::

```
calls the handler once, on the main thread, after the call returned (fetch.beforeReturn 0)
answers nil on this Mac, which has no Wi-Fi network to name
```

NEHotspotConfiguration (the port's answers are the same line for line, `dladdr` aside):

```
initWithSSID:            SSID = the name, SSIDPrefix = "" (the empty string, not nil)
initWithSSIDPrefix:      SSID = "", SSIDPrefix = the prefix
defaults                 joinOnce NO, hidden NO, lifeTimeInDays nil
setters                  joinOnce, hidden and lifeTimeInDays keep what is set
-copy                    another object (isSameObject NO), with the same values
NSKeyedArchiver          data, no error; the round trip decodes the same values
```

The `dladdr` line names the image that answered each selector: `NetworkExtension` on the host and `port` on the
port. The harness checks both, so a comparison that a port answers with the host's own class cannot pass.

## Where the port does not match the host, and why

- **SSID and BSSID of an unmeasured network.** The host crashes on the read. A crash is not an answer, and the
  rule is that an API must never crash its caller, so the port answers nil and the harness asserts nil on the
  port alone. The host crash is recorded here and in the harness output, not reproduced.
- **fetchCurrent's network.** The port answers it from CaptiveNetwork (`CNCopySupportedInterfaces` and
  `CNCopyCurrentNetworkInfo`, SSID and BSSID), which the release has and which needs no entitlement. The host
  answers nil on a Mac with no network. The port answers nil on that same Mac, so the two agree here; on a
  device on a Wi-Fi network the port answers the network and the host, without the entitlement, would not.
- **The CaptiveNetwork declarations.** They are declared in `NEHotspotNetwork.m`, not imported: the SDK marks the
  functions deprecated from iOS 9.0 in favour of NEHotspotHelper, and a deprecation warning would need a pragma
  the house rule does not allow. The symbols are the release's own, and the library links SystemConfiguration.

## The fields CaptiveNetwork does not give

`securityType`, `signalStrength`, `secure`, `autoJoined`, `justJoined` and `chosenHelper` answer as the host
answers for a network it did not measure: 0, 0, NO, NO, NO, NO. That is what the brief asked for, and it is named
here so it is not silent. It is also the one place the port can be quietly wrong: an application that reads
`secure` on a WPA network from fetchCurrent gets NO. The coordinator should rule on whether these should answer
something else; the port does not know the security of a network CaptiveNetwork names.

## The manager and the helper: the host's answers, and the join they do not drive

The manager and the helper are carried with the answers of the host, not of the release. The host is Mac Catalyst,
which has these classes; the 6.1.3 release has none of them (below). Each answer is the one the host gives an
application that has no hotspot entitlement, and the port gives the same answer. The probe is
`tests/backports/host/netext-hotspot/probe.m`, with the ops `apply`, `configured`, `helper`, `remove`, `command`,
`response` and `bind`, and `run.sh` compares each answer line for line, with a planted control per group.

The host's answers, measured:

```
applyConfiguration:completionHandler:    handler called once, on the main queue, after the call returned;
                                         NSError NEHotspotConfigurationErrorDomain, code 8
                                         (NEHotspotConfigurationErrorInternal)
getConfiguredSSIDsWithCompletionHandler: handler called once, with nil, on the main queue
removeConfigurationForSSID:              returns; no callback; no change to the preferred list
removeConfigurationForHS20DomainName:    returns; no callback (the header's name is removeConfigurationForHS20DomainName:)
+[NEHotspotConfigurationManager sharedManager]  the same object on each call
+[NEHotspotHelper registerWithOptions:queue:handler:]  returns NO; the handler is never called in 3 seconds
+[NEHotspotHelper supportedNetworkInterfaces]   nil
+[NEHotspotHelper logoff:]                      returns NO
fresh NEHotspotHelperCommand             type 0 (None); network and networkList nil; createResponse: nil;
                                         createTCPConnection: and createUDPSession: nil for a nil endpoint
fresh NEHotspotHelperResponse            setNetwork: and setNetworkList: accepted, with no getter; deliver returns
bindToHotspotHelperCommand: on a request  with a fresh command, allHTTPHeaderFields is nil before and after
```

The apply op applies a configuration for an SSID that does not exist. Afterwards
`networksetup -listpreferredwirelessnetworks en0` does not list it, so nothing was saved and nothing joined. The
`interface` property (iOS 18) of a fresh command is nil on the host; it is measured in the scratch probe only, since
its type (Network's nw_interface_t) is not carried.

### The join route the port does not drive

The release's join route is the private `WiFiUtils` class of
`/System/Library/PrivateFrameworks/AirPortAssistant.framework/AirPortAssistant`. Its join selectors, from the 6.1.3
cache by name (`tools/corpus/objc-inventory.lua`):

```
-joinNetworkWithNameAsync:password:rememberChoice:
-joinNetworkWithScanInfoAsync:password:rememberChoice:
-joinNetworkWithScanInfo:password:rememberChoice:
-getCurrentAssociationInfo
-dissassociateSync
-asyncWiFiScan:
```

It is private: the framework is not in the SDK, and an application reaches the class only by loading the framework at
run time. `WiFiNetwork` in SkankKit is a user-interface class and is not a route.

The emulator measured the release itself (`tests/backports/host/netext-hotspot/emulate/wifi-join.m`, run as
`xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/wifijoin613`; the report is
`coordination/wave-2026-10-03/v-hotspot2-report.md`):

- NEHotspotConfiguration, NEHotspotConfigurationManager and NEHotspotHelper are absent on 6.1.3; WiFiUtils is present.
- AirPortAssistant loads for a process with no entitlements.
- CNCopySupportedInterfaces names no Wi-Fi interface: the emulated guest has no Wi-Fi, so a join cannot be measured
  as a join.
- `joinNetworkWithNameAsync:password:rememberChoice:` returns, with no callback in a 10-second run loop, and no crash.

So the release's answer to an unentitled application that asks for a join is not observed. The coordinator ruled on
2026-10-15 that the port does not call WiFiUtils or any AirPortAssistant symbol: applyConfiguration gives the host's
answer above, and the helper refuses to register, as the host does. Those answers are the host's, not the release's;
the open crutch is recorded in `coordination/crutches.md`.

A device measurement would decide the WiFiUtils route: on an iPhone 4S or an iPad 2 at 6.1.3, with a Wi-Fi network in
range that the owner names as a test network, the same probe run unentitled. The question is whether the release
joins, refuses (and with what error), or calls back. Until that measurement, the manager's answers are the host's.
The host is never joined.

### The command and the response: what the port can deliver

The helper never registers, so no command is handed to its handler and no command reaches the port. A command the
port makes answers the host's values for a fresh command. Its createTCPConnection: and createUDPSession: answer nil for
any endpoint, which is the host's answer for a nil endpoint; a real endpoint is not measured, because an NWEndpoint
cannot be made from Objective-C here. Since no command reaches the port, these calls are unreachable in practice.
The response's deliver sends nothing for the same reason.

### The constant

NEHotspotConfigurationErrorDomain is the generated constant (`.gen/NetworkExtension/NetworkExtensionConstants160.m`,
written by `tools/gen.lua`), not a hand-written one. The differential needs that generated file, so `run.sh` names it.

### The enterprise and Hotspot 2.0 settings

Measured on the host with the probe's ops `eap`, `hs20` and `wiring` (run.sh compares each line with the port):

```
NEHotspotEAPSettings, a fresh object: every list and string nil, ttlsInnerAuthenticationType 0, tlsClientCertificateRequired NO,
  preferredTLSVersion 0
setters: supportedEAPTypes, username, password, outerIdentity and trustedServerNames are copied (a later change to
  the caller's mutable array or string does not show); the enumerations and the Boolean are values
setIdentity:nil and setTrustedServerCertificates: nil and @[] all return NO
copy: another object with the same values
NSKeyedArchiver round trip: all eight values decode back; the archive holds the password in the clear
```

The identity and certificate answers for a non-nil value are not measured: a SecIdentity needs a keychain item and a
certificate needs a certificate the test does not import (the test imports no certificate or key). The port answers NO
for them and keeps nothing; that is the one row whose port answer is not the host's measured answer.

```
NEHotspotHS20Settings, initWithDomainName:roamingEnabled:: domainName kept, roamingEnabled kept; the lists nil
-init (no domain): domainName nil, roamingEnabled NO
the lists are copied on set; copy has the same values; the archive round trip restores all five values
```

NEHotspotConfiguration with the two initializers that take settings:

```
initWithSSID:eapSettings:       SSID kept, SSIDPrefix nil (not empty, unlike initWithSSID:), joinOnce NO
initWithHS20Settings:eapSettings: SSID "" (the empty string), SSIDPrefix nil, joinOnce NO
the configuration holds a COPY of the EAP settings (held == the caller's object: NO; the copy's username is the
  value at init: a later change to the caller's object does not show in the held copy or the archive)
the configuration holds a copy of the HS20 settings (its domainName is the one given)
the archive holds the EAP class and the SSID, and a round trip restores the SSID and the EAP username
copy: the copy holds the EAP username and the HS20 domain
the archive of an HS20 configuration holds the HS20 class, and a round trip restores its SSID and domain
```

The configuration's instance variables (`class_copyIvarList`, read by the probe's `wiring` op) are the host's own
layout and are printed but not compared: they differ from the port's by design (the port carries `_isWEP` and
`_passphrase`, the host keeps `_securityType`, `_useSSIDPrefix` and `_isAccessory`). The port names its two held
objects `_eapSettings` and `_hs20Settings`, as the host does, and the held-object lines are compared by value.
