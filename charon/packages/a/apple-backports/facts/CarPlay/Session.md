# The session configuration, and the five calls the SDK's own header forbids

**Ten rows, and neither of the two worlds the family starts from.** Seven are a hardware absence and
the hardware is a CarPlay head unit; three are something the port has no status word for, which is
that **the 26.2 header marks the call `NS_UNAVAILABLE`** — a fact in a file in this repository, not a
fact about a device, and checkable by reading the header.

| rows | what they are |
| --- | --- |
| the whole of `CPSessionConfiguration`: the class, `delegate`, `contentStyle`, `limitedUserInterfaces`, `initWithDelegate:`, `init`, `new` (7) | a hardware absence: the configuration OF a session with a head unit, whose two values the connected system fills in — and two of the seven are also forbidden calls |
| `+[CPRouteChoice new]`, `+[CPNavigationSession new]`, `-[CPNavigationSession init]` (3 more) | the SDK forbids the call: `NS_UNAVAILABLE` |

Ten rows in all, and none of them is a "measurement" row: five of the ten are the same fact (the
header says no) and seven of the ten are the same fact (there is no head unit), overlapping on the
configuration's own `init` and `new`. All ten are `absent`, whose claim is about the release: the 6.1.3
armv7 cache carries no CarPlay class of any name, so nothing in it answers any of these names. The head
unit and the header are the reasons the port does not carry what the release lacks.

## The forbidden ones, with the line each rests on

```
CPTrip.h:25                 - (instancetype)init NS_UNAVAILABLE;      (CPRouteChoice)
CPTrip.h:26                 + (instancetype)new NS_UNAVAILABLE;       (CPRouteChoice)
CPNavigationSession.h:33    - (instancetype)init NS_UNAVAILABLE;      (CPNavigationSession)
CPNavigationSession.h:34    + (instancetype)new NS_UNAVAILABLE;       (CPNavigationSession)
CPSessionConfiguration.h:29 - (instancetype)init NS_UNAVAILABLE;      (CPSessionConfiguration)
CPSessionConfiguration.h:30 + (instancetype)new NS_UNAVAILABLE;       (CPSessionConfiguration)
```

read out of the SDK 26.2 the port targets
(`charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk/System/Library/Frameworks/CarPlay.framework/Headers`),
and the same three pairs are in the SDK this host's CarPlay ships with, so it is not a transcription
of one SDK's copy. `NS_UNAVAILABLE` is a compile-time refusal: a program that calls one of the six does
not build against Apple's header and must not build against the port's either. So these rows are
`absent` and the port's own header carries the same annotation, which is the only way the refusal
reaches a caller at all.

`+[CPRouteChoice new]` is the row that was wrong for a different reason: it said "the head unit", and
a route choice has nothing to do with a head unit — it is a choice of route between two places, and
the port builds the class. What is true of it is that the header forbids the call (`CPTrip.h:25-26`).
The row's status stays `absent` and its reason is replaced with the one that is checkable from a file.

**What the framework does when a program sends one anyway** is measured, not assumed, and it is why
`absent` is the honest status rather than `inert`:
`tests/backports/host/carplay/headunit-probe.m` calls each through `objc_msgSend`, because a header
that refuses the call cannot be asked by a program that compiles:

```
ok   +new, which the header marks NS_UNAVAILABLE, is the inherited NSObject one CPSessionConfiguration
ok   +new, which the header marks NS_UNAVAILABLE, is the inherited NSObject one CPNavigationSession
```

An inherited `+new` is exactly why this is not `inert`: a carried class would answer `+new` from
`NSObject` and hand back an object no header says may be made, which is the quiet stand-in the
registry's `absent` exists to prevent. The refusal belongs in the header, where the caller meets it.

## `CPSessionConfiguration`: a configuration of a session, and the session is the head unit

The class is a value the app builds and hands to the interface controller, and both of its values
come from the other end:

```
CPSessionConfiguration.h:32   // A bitmask of what type of user interfaces are limited
CPSessionConfiguration.h:35   // The current content style suggested by the connected CarPlay system.
```

Both are `readonly` and both are the **connected system's** answer. The 16.0 arm64e cache shows how:
the class's own private members are `_limitedUIDidChange:`, `_updateLimitedUIStatus`,
`_updateContentStyleWithScene:` and `_setContentStyle:` / `_setLimitedUserInterfaces:`, and it
conforms to the private protocol `CARSessionObserving` — it observes a CarPlay session. So the value
of each public property is written by a session, and a session is a connection to a head unit.

**Measured with no head unit, in Apple's own framework** — both are 0:

```
ok   limitedUserInterfaces answers the mask the connected system suggests 0
ok   contentStyle answers the style the connected system suggests 0
```

That measurement is the whole argument, and it cuts both ways, so here is the other one. Carrying the
class would make those rows `implemented`, and today's answer would be right — 0 is what Apple answers
with no car. **It is still not what the port should do**, for the reason the brief calls a silent
fake: the port's object would answer 0 for the rest of time and could not answer anything else,
because there is no path from this library to a head unit, while Apple's object on a real device
answers 0 only until a car connects and then answers what the car suggests. A program could not tell
the two apart, and the delegate the class holds would never be called
(`sessionConfiguration:limitedUserInterfacesChanged:` is the connected system's message). So the seven
rows are `absent` with the hardware named, which is also the state in which `respondsToSelector:`
tells the truth: there is no object, so there is nothing to ask.

`initWithDelegate:` is in the same seven: it is the only way in, and what it takes is the delegate a
connected system would query.

## What a caller gets, per row

| row | what a caller gets |
| --- | --- |
| `CPSessionConfiguration` | the class is not there: `NSClassFromString` answers nil and a compile-time reference has nothing to link |
| `.initWithDelegate:` | there is no session to configure, so there is nothing for the delegate to be asked about; the class is not there to ask |
| `.delegate` | the delegate is the one the connected system calls when the limited interfaces or the content style change; with no class there is no object to set it on, which is the honest answer rather than a delegate that is never called |
| `.limitedUserInterfaces` | the mask the connected system suggests, which measures 0 with no head unit — and the port does not carry an object whose every answer would be that one value forever |
| `.contentStyle` | the style the connected CarPlay system suggests, and the same: measured 0, and unreachable for anything else from here |
| `+[CPRouteChoice new]`, `+[CPNavigationSession new]`, `-[CPNavigationSession init]` and the configuration's own `init` and `new` | the SDK's own header forbids the call, and the port's header refuses it the same way; nothing of ours answers it, and an inherited `NSObject` one is not carried on purpose |
