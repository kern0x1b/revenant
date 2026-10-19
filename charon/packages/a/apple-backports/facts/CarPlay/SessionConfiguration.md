# The session configuration: the application's half carried, the connected system's two values inert

**These five rows said `absent`, and that was wrong.** The claim `absent` makes is that the *release* has
nothing under the name — "the release carries the name" is the gate's own test at
`modules/apple/backports.lua:1905`. But the 26.2 header declares this class and all four of its members,
and Apple's own framework carries them, so an `absent` row here was a claim about Apple's framework rather
than about this port. What the rows are now: three `implemented`, two `inert`, and no `absent`.

The split between them is the header's own, not the band's:

| row | introduced | status | whose it is |
| --- | --- | --- | --- |
| `CPSessionConfiguration` | 12.0 | implemented | the application's |
| `-[CPSessionConfiguration initWithDelegate:]` | 12.0 | implemented | the application's — the designated initialiser |
| `CPSessionConfiguration.delegate` | 12.0 | implemented | the application's — readwrite, `:38` |
| `CPSessionConfiguration.limitedUserInterfaces` | 12.0 | **inert** | the connected system's — readonly, `:33` |
| `CPSessionConfiguration.contentStyle` | 13.0 | **inert** | the connected system's — readonly, `:36` |

`:38` declares the delegate `@property (nonatomic, weak) id<CPSessionConfigurationDelegate> delegate` and
its comment says the system will use it "to configure the system UI" — readwrite, so a caller sets it.
`:33` declares `limitedUserInterfaces` readonly and says only "A bitmask of what type of user interfaces
are limited". `:36` declares `contentStyle` readonly and says "The current content style **suggested by
the connected CarPlay system**". Readwrite against readonly, the application's half against the car's.

## Who writes the two values, from the release's own cache

`tools/corpus/objc-inventory.lua` over the 16.0 arm64e dyld shared cache, read per class. This is the
measurement that decides `inert` rather than `implemented`, and it names a connection:

```
CPSessionConfiguration  super=NSObject  image=CarPlay  protocol=CARSessionObserving
   -initWithDelegate:  -delegate  -setDelegate:
   -limitedUserInterfaces  -setLimitedUserInterfaces:  -convertLimitableUserInterfaces:
   -contentStyle            -setContentStyle:  -_contentStyleUpdated:
   -sessionDidConnect:  -_limitedUIDidChange:  -_updateContentStyleWithScene:
   -_updateLimitedUIStatus  -setCurrentStatus:  -currentStatus
```

Every one of the two values' writers is private, and the class conforms to `CARSessionObserving` — a CarPlay
session observing its connection. The surrounding methods are the connection's own: `-sessionDidConnect:`
is a session arriving, `-_updateContentStyleWithScene:` is the scene suggesting, `-_limitedUIDidChange:` is
the input method changing. So the writer of both values is a connected head unit. Neither fleet device
(iPhone 4S, iPad 2, iOS 6.1.3) has one, so nothing in this library writes either value: the symbol loads
and nothing applies it, which is what `inert` says.

## What Apple's own object answers with no head unit, and what that settles

`tests/backports/host/carplay/headunit-probe.m` section 5, built for Mac Catalyst, run by
`tests/backports/host/carplay/run.sh`:

```
ok   the designated initialiser makes a configuration               CPSessionConfiguration
ok   delegate answers the delegate it was given (nil here)          nil
ok   limitedUserInterfaces answers the mask the connected system suggests  0
ok   contentStyle answers the style the connected system suggests    0
ok   +new, which the header marks NS_UNAVAILABLE, is the inherited NSObject one
```

Two things follow from those 0s that a row has to say rather than leave to the reader:

**0 is not one of the header's members.** `CPLimitableUserInterfaceKeyboard = 1 << 0` and
`CPLimitableUserInterfaceLists = 1 << 1` (`:13-16`); `CPContentStyleLight = 1 << 0` and
`CPContentStyleDark = 1 << 1` (`:18-21`). So the content style answers neither light nor dark, and the port
does not turn it into either. A caller that treats 0 as a style is reading a value no system chose.

**`+new` and `-init` are absent, and that is measured too.** At both 16.0 and 18.0 the class's own method
list contains neither selector, so `CPSessionConfiguration` declares no initialiser of its own and both are
NSObject's. That is what makes those two rows `absent` rather than `ignored`: `absent` claims the release
carries nothing under the name, and here the class's own metadata carries neither selector, while
`ignored` is for a name the release *does* carry and the port declines to — which is the case for
`+[CPRouteChoice new]`, where the measurement comes out the other way.

## The port's half, and where each release lives

`CarPlaySessionConfiguration12.m` carries the class, `initWithDelegate:`, `delegate`, `setDelegate:` and
`limitedUserInterfaces` — all 12.0. `CarPlaySessionConfiguration13.m` carries `contentStyle`, which is
13.0, as a category. A category cannot carry storage, so `_charonContentStyle` sits with the class's own
ivars in the 12.0 object and the 13.0 category reads it through the accessor in
`CharonCarPlaySessionConfiguration.h`.

The reader there has **no writer**, and that is deliberate. The header declares the property `readonly`
with no public setter and the release's only writer is the connected system's private `-setContentStyle:`,
so a Charon setter would be a writer nothing calls — dead code rather than the `inert` a row means.
`inert` is about the *symbol*, and the symbol is the getter, which loads and answers. (The 17.4 members of
the navigation session are the opposite case and do have Charon writers, because a public readwrite
property needs one: `facts/CarPlay/NavigationSession174.md`.)

The 12.0 object says `@dynamic contentStyle` and does **not** `@synthesize` it, because the compiler
auto-synthesises every property an SDK header declares whether or not the object implements it, and
`@synthesize` would put the 13.0 getter into a 12.0 band.

## One release per object, from the IMPs

```
CarPlaySessionConfiguration12.o  initWithDelegate: limitedUserInterfaces delegate setDelegate:
                                charon_contentStyle .cxx_destruct
CarPlaySessionConfiguration13.o  -[CPSessionConfiguration(CharonContentStyle13) contentStyle]
```

## What this page does not claim

The number of connected sessions, and anything that needs a head unit to answer, is not measured here and
no row in this slice claims it. What is measured is the shape of the class: a designated initialiser, a
weak readwrite delegate the application owns, and two readonly values whose only writer is a connection.