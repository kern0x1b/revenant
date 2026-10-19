# LAEnvironment, its state and its mechanisms, and LADomainState, iOS 18.0

iOS 18 added a way to ask the system *what the device can authenticate the owner with*, separately
from asking it to authenticate: `LAEnvironment.currentUser.state` lists the mechanisms — biometric
sensors, a paired watch or Mac companion, the passcode — with the state of each, and `LADomainState`
(the same question for one security domain, which is what `LAContext.domainState` answers) reports
which of them are available to that domain, with hashes that identify the state so an application can
tell that it changed.

The port's build SDK is `charon@iphoneos-sdk` 16.4, which predates every class of this file, so the
declarations the headers of the 26.2 SDK give are written in the backport's own source
(`LAEnvironment18.m`, `LADomainState18.m`). `LABiometryType` is the one piece the 16.4 SDK does
declare, in `LAContext.h`, and is used from there.

## What the devices this port runs on are

Measured and read, not assumed:

- **No biometric sensor.** An iPhone 4S and an iPad 2 have none; Touch ID came with the A7 of the
  iPhone 5s. This package's own `facts/LocalAuthentication/LAContext.md` records the same, with
  `LAErrorBiometryNotAvailable` as the release's own answer for a question about biometry, and
  `-biometryType` as `LABiometryTypeNone`.
- **No companion.** The release pairs with no watch and no Mac, so there is no companion mechanism and
  no available companion type.
- **A passcode the port cannot read.** iOS 6's passcode belongs to the lock screen: an application can
  neither ask for it nor ask whether one is set. The port's `LAContext` already answers
  `LAPolicyDeviceOwnerAuthentication` with `NO` and `LAErrorNotInteractive` for that reason
  (`facts/LocalAuthentication/LAContext.md`), and deliberately does *not* answer
  `LAErrorPasscodeNotSet`, because that would claim something it cannot know.

So the state of this device has exactly one mechanism — the lock screen's passcode — which no
application can use, no biometry, and no companion.

## What the port answers

- `+[LAEnvironment currentUser]` is one object, made once, the same every time. The release has no
  second user account and no second profile to ask for.
- `-[LAEnvironment state]` is one `LAEnvironmentState`, the same every time, holding the one
  mechanism. `-copyWithZone:` gives a new object equal to the original, and `-isEqual:` compares the
  mechanisms, which is the shape the host has (measured: the host's copy is a different object that
  `-isEqual:` the original).
- `state.biometry` is **nil**: there is no sensor, so there is no biometry mechanism to describe.
  `state.companions` is an **empty array**; `state.allMechanisms` holds the one mechanism.
- The passcode mechanism answers `isUsable` **NO** — which follows from the port's own `LAContext`
  answer above, not from a guess — and `isSet` **NO**. That second one needs saying plainly: the
  release gives an application no way to read whether a passcode is set, and `NO` is the answer that
  claims nothing. An application that checks `isUsable` — the documented way to decide — gets `NO`,
  which is the truth whatever the passcode is.
- Its `localizedName` is **"User Password"** and its `iconSystemName` is **"lock.shield"**: the host's
  own strings for the passcode mechanism, measured, carried verbatim rather than invented.
- `-addObserver:` takes an observer and `-removeObserver:` takes it back; **no message is ever sent
  to either**. Nothing about this device's environment can change while an application runs: no
  sensor can be enrolled, no companion can be paired, and the passcode belongs to the lock screen,
  which is not up while an application is. A nil observer is allowed.
- `LAContext.domainState` is one shared `LADomainState`: `biometry` is an `LADomainStateBiometry` with
  `biometryType` `LABiometryTypeNone` and a **nil** `stateHash`; `companion` is an
  `LADomainStateCompanion` with an **empty set** of available types, a **nil** `stateHash` and **nil**
  from `-stateHashForCompanionType:` for every type; the domain's own `stateHash` is **nil**.

Every hash is nil, and that is the host's own answer for a state with nothing in it. Measured on the
host: the `LADomainStateCompanion` of a Mac with no watch paired has a **null** `stateHash` and
`-stateHashForCompanionType:` gives **nil** for each type asked of it (types 0, 1 and 2); and a
**fresh** `LAContext` — one that has never evaluated a policy, so its domain has no enrolled biometry
either — answers **nil** for `LADomainStateBiometry.stateHash` and for the domain's own `stateHash`,
while a context whose biometry is enrolled carries 32 bytes. There is no state here to identify, so no
hash is invented.

## Where the port answers outside what the header promises

Three properties are declared non-nullable and this port answers nil for them. They are unreachable on
this port, and the reason is the port's own declarations rather than Apple's alone:

- `LAEnvironmentMechanism.localizedName` and `.iconSystemName` on the base class and on the biometry
  and companion kinds. The system names a mechanism after the sensor it is — the host's are
  "Touch ID" with the `touchid` symbol — and a device with no sensor has no such name; naming one
  would be a claim. **The port's own `LAEnvironmentMechanism` declaration carries the
  `+new`/`-init` `NS_UNAVAILABLE` pair the 26.2 header has**, so an application cannot make one of
  these to ask; the two other paths are `-state.biometry` (nil, there is no sensor) and
  `-state.companions` (empty, the release pairs with none).
- `LAEnvironmentMechanismBiometry.stateHash`, for the same reason: no biometry state to identify.

`LAEnvironment` carries the same pair, so the one environment is made the way Apple's is: through
`+currentUser`. The one mechanism of this release, the lock screen's passcode, and the one state, are
made through initialisers of their own in a class extension, each of which is NSObject's `-init`
reached at run time — the framework's header marks `-init` unavailable for an application, and a
backport that made its own class through the same selector would be one call away from an object
nothing should make.

**One thing the fallback declaration does not have.** The port's `LACompanionType`, written in this
file because the 16.4 SDK the port builds against has no `LACompanionType.h`, names `Watch` and `Mac`
but not `LACompanionTypeVision` (26.0, `1 << 2`, in the SDK 26.2's `LAPublicDefines.h`). The
corpus files that case under 26.0, which is not this band's row, but the declaration an application
compiles against here is this one, and it is named in `LAEnvironmentMechanismCompanion.type`'s
registry entry.

**The observer protocol is carried, not only declared.** `-[LAEnvironment addObserver:]` asks
`[observer conformsToProtocol:@protocol(LAEnvironmentObserver)]` before it keeps the observer, which is
what a real implementation does before it ever sends the protocol's one message — and it is what puts
the protocol into a conformance list, so this library **defines**
`__OBJC_PROTOCOL_$_LAEnvironmentObserver` and `NSProtocolFromString(@"LAEnvironmentObserver")` finds
it in a process that has one. A nil observer, and an observer that does not adopt the protocol, are
both allowed and neither is kept.

The one mechanism that *is* reachable carries the host's real strings, so nothing an application can
actually see on this port is nil.

## What was measured, and what was not

Measured on the host's own LocalAuthentication under MacOSX.sdk (`tests/backports/host/localauth18`),
which has a Touch ID and a passcode set — the shapes, the string values, the copy's equality, the
empty companion set, the null companion hash, and nil from `-stateHashForCompanionType:`. Measured
on the release: no sensor, no companion, no way to read or ask for a passcode (the 6.1.3 armv7 cache
and this package's own `LAContext` facts).

Not measured: Apple's own answers *on a device with no biometry*, which is this port's case — no
device this port runs on, and no host, can be asked them. The two strings of the unreachable
mechanisms and the one `NO` that stands for an unreadable passcode are therefore reasoned from the
port's own measured `LAContext` answers and named as such in the registry, not presented as
measurements.
