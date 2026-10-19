# The three scenes: a CarPlay head unit, named, and nothing else

**These thirteen rows are `absent`, and the claim is about the release: nothing in it answers these
names.** `apple.objc.inventory` over the armv7 dyld shared cache of 6.1.3 finds no CarPlay class of
any name, so no `CP*` name is answered by anything on either fleet device. The head unit is the
*reason* the port does not carry what the release lacks, and it is named in each row, because a claim
with nothing behind it is not a row. A CarPlay scene
is not a view, a window or a controller an application makes: at iOS 16.0 it is a `UIScene`, the
system's own class for a connection, and the only initialiser any of the three carries is
`-initWithSession:connectionOptions:`, which UIKit calls when a session connects. There is no head
unit on either fleet device — an iPhone 4S and an iPad 2 on iOS 6.1.3, neither connected to a car —
so there is no connection, no session, and no scene. `NSClassFromString` answering nil is the
correct answer here and is what `absent` means.

What is **not** the reason, because it is measurable and comes out the other way: the port's
releases have no CarPlay class of any name (`apple.objc.inventory` over the armv7 dyld shared cache
of 6.1.3), but that is a fact about *this port's* releases, not about Apple's framework, and Apple's
own CarPlay carries all three classes with no car attached. The measurement is in
`tests/backports/host/carplay/headunit-probe.m`, which asks Apple's own framework on this machine and
prints, for every class this page is about:

```
== 1. class presence in Apple's CarPlay, no head unit ==
     CPTemplateApplicationScene                     present
     CPTemplateApplicationDashboardScene            present
     CPTemplateApplicationInstrumentClusterScene    present
```

So an `absent` row here is a claim about what *this port* carries, never a claim that Apple has no
such class. That is the distinction the whole family turns on, and it is why the seven absent class
rows are not all the same kind of row: six of them are objects the port can carry (§ the other
pages), and these three are the gate itself.

## The three, and what each one is the gate FOR

| class | introduced | first held rung carrying it | what the hardware is |
| --- | --- | --- | --- |
| `CPTemplateApplicationScene` | 13.0 | 16.0 | the car's centre screen |
| `CPTemplateApplicationDashboardScene` | 13.4 | 16.0 | the dashboard widget, a second screen in the car |
| `CPTemplateApplicationInstrumentClusterScene` | 15.4 | 16.0 | the instrument cluster, the car's gauges |

"First held rung carrying it" is `xmake l tools/cache-index/first-rung.lua CPTemplateApplicationScene
CPTemplateApplicationDashboardScene CPTemplateApplicationInstrumentClusterScene`, which answers 16.0
for all three. That is **presence, not the release that introduced the name**: the held ladder has no
13.x or 14.x or 15.x rung — it goes 12.0 then 16.0 (`ls ~/.charon/cache-index/*.names.gz`) — so a
class the SDK marks 13.0 first appears in the index at 16.0. The `introduced` field of every row here
is the SDK 26.2 availability, and it is right: `coordination/corpus/sdk-26.2-surface.tsv` reads
13.0, 13.4 and 15.4 for the three classes, and the registry says the same.

## What the release says, read out of the 16.0 arm64e cache

`tools/corpus/objc-inventory.lua` over `~/.charon/dyld/16.0/dyld_shared_cache_arm64e` (the cache is
split: a 384 KB header and the bodies in `.01`, `.03`, … — the reader takes the base path), for the
three classes:

```
CPTemplateApplicationScene                     super=UIScene   -initWithSession:connectionOptions:
CPTemplateApplicationDashboardScene            super=UIScene   -initWithSession:connectionOptions:
CPTemplateApplicationInstrumentClusterScene    super=UIScene   -initWithSession:connectionOptions:
```

and, on the first of them, the connection lifecycle around it:

```
_readySceneForConnection   _sceneWillConnect   _deliverInterfaceControllerToDelegate
_shouldCreateCarWindow     _updateContentStyle  _attachWindow:   _detachWindow:
```

Every one of those is the system talking to a connection: a session connects, the scene becomes
ready, the interface controller and the car window are delivered to the app's delegate, and the
content style is updated. There is no path through them that a program on a device with no car can
take, and no public initialiser that would let it start one. The same cache shows the same shape on
the other two, each with its own `_deliver…ControllerToDelegate`:

```
CPTemplateApplicationDashboardScene            _deliverDashboardControllerToDelegate  _readySceneForConnection
CPTemplateApplicationInstrumentClusterScene    _deliverControllerToDelegate           _readySceneForConnection
```

## What Apple's own framework answers with no head unit, and what that settles

`tests/backports/host/carplay/run.sh` builds `headunit-probe.m` for Mac Catalyst
(`-target arm64-apple-ios17.0-macabi`) and runs it. Mac Catalyst is the only place on this machine
where Apple's CarPlay loads at all: the fleet devices run 6.1.3, which has no CarPlay class of any
name, and `/System/Library/Frameworks` has no CarPlay outside the SDK. The run is 28 checks, and it
carries its own red control — the same source with the voice control template's five-state limit read
as six — so a green run is a run that can fail:

```
checks=28 failures=0
real exit=0 mutant exit=1
```

The three checks that are about this page:

```
ok   CPTemplateApplicationScene is a UIScene subclass (a scene, not a view) superclass UIScene
ok   CPTemplateApplicationScene declares no initialiser of its own -init is NSObject's
ok   CPTemplateApplicationDashboardScene declares no initialiser of its own -init is NSObject's
ok   CPTemplateApplicationInstrumentClusterScene declares no initialiser of its own -init is NSObject's
```

`class_getInstanceMethod(cls, @selector(init))` against `NSObject`'s own is what "declares no
initialiser of its own" is measured with, not a reading of the header's prose: a scene cannot be
made by a program, and the framework will not make one without a connection.

And the honest limit of the measurement, which is in the probe's own output: this SDK's CarPlay
declares no `+[CPInterfaceController sharedController]`, no `connectedSceneCount`, no
`templateApplicationScene` and no `connectedScenes`, so **on this machine the count of connected
scenes cannot be asked at all**:

```
     [CPInterfaceController sharedController         ] not in this SDK's CarPlay
     [CPInterfaceController connectedSceneCount      ] not in this SDK's CarPlay
     [CPInterfaceController templateApplicationScene ] not in this SDK's CarPlay
     [CPInterfaceController connectedScenes          ] not in this SDK's CarPlay
```

The number of connected scenes is therefore **not** measured here, and no row in this family claims
it. What is measured is the class's shape — a `UIScene` with no initialiser of its own, created by
the system for a connection — and the absence of the connection is a fact about the two devices the
fleet has, named here rather than assumed: an iPhone 4S and an iPad 2, iOS 6.1.3, no head unit.

## The rows, and what a caller gets

| row | what a caller gets |
| --- | --- |
| `CPTemplateApplicationScene` and its two siblings | the class is not there: `NSClassFromString` answers nil, and a compile-time reference has nothing to link |
| `.delegate` (all three) | the delegate is the one the system calls when a screen connects and disconnects; there is no screen, so nothing ever calls it and there is no object to set it on |
| `.interfaceController` | the controller the scene hands the app when the CarPlay screen connects (`_deliverInterfaceControllerToDelegate` is the release's own name for that handoff); there is no screen and no handoff |
| `.carWindow` | the window the scene owns on the car's screen, created by `_shouldCreateCarWindow`; there is no car's screen and no such window |
| `.dashboardController`, `.dashboardWindow` | the dashboard widget's controller and window, a second screen in the car; there is no dashboard |
| `.instrumentClusterController` | the controller for the car's instrument cluster, the gauges; there is no cluster |
| `.contentStyle` (13.0's scene, and 15.4's cluster) | the style the connected CarPlay system suggests — the same value `CPSessionConfiguration.contentStyle` carries, and measured there as 0 with no head unit |

The port's own half is unaffected and stays where it was: `CPInterfaceController`, `CPWindow` and the
templates are carried (`implemented`), because they draw in the application. The one place the scene
is named inside them is `CPWindow.templateApplicationScene`, which the port carries as the header's
own weak property (`CarPlayTemplates12.m`, `-templateApplicationScene` answers the weak ivar and
`-setTemplateApplicationScene:` sets it): it answers nil, because no scene is ever made on a device
with no head unit, and nil is the honest answer rather than a stand-in.
