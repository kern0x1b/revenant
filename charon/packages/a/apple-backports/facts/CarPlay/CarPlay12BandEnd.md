# The 12.0 band end carries CarPlay, and the rows that said 16.0 was the first rung to

**Twenty-seven rows, and this page is what nine of them rest on.** It answers one question with a
command and its output, for the release this band is about: which of the names
`registry/CarPlay/ios12.json` carries does **12.0** itself carry, and which does it not.

The answer moved. Nine rows in that file said, in their own `reason`:

> at 16.0, the first held rung that carries CarPlay at all, the release's own CarPlay framework has
> it and the port does not

**That is measured false.** 12.0 carries CarPlay, it is a held rung, and it is the band end this very
file is about. What is true is the weaker sentence the nine rows already lead with — at 6.1.3 and at
4.3 there is no CarPlay class of any name, so below 12.0 nothing in the release answers any of these
names — and it is true of 16.0 as well, which is simply not the first rung. The nine rows keep their
status; the sentence that named the wrong rung is replaced by this measurement, because a row's claim
about the release has to be the claim the release's own cache supports.

## The census, with the control that certifies the reader

```
$ CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua CP 6.1.3 4.3
6.1.3     ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming CP 1
         classes 11378, of which CP* 112 (CPAggregateDictionary CPArchive CPBitmapStore ... CPZone)
         protocols 1171, of which CP* 5 (CPCopying CPDisposable CPEnhancedWarningReporting CPGraphicUser CPVisitor)
4.3       ~/.charon/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming CP 0
         classes 7187, of which CP* 99 (CPAggregateDictionary CPArchive CPBitmapStore ... CPZone)
         protocols 564, of which CP* 3 (CPDisposable CPEnhancedWarningReporting CPVisitor)
control: 219 name(s) beginning CP found in this run, so a zero on another rung is the release's and not the reader's
```

and the rung the nine rows were wrong about:

```
$ CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua CP 12.0
12.0      ~/.charon/dyld/12.0/dyld_shared_cache_arm64
         images 1368, of which naming CP 4
         classes 63192, of which CP* 348 (CPActionSheetTemplate CPAlertAction CPAlertTemplate CPBarButton
             CPGridButton CPGridTemplate ...)
         protocols 11426, of which CP* 71 (CPAlertDelegate CPBarButtonDelegate CPBannerDelegate ...)
control: 419 name(s) beginning CP found in this run, so a zero on another rung is the release's and not the reader's
```

The `CP*` prefix is not the port's; it is Apple's, and it matches CoreFoundation's own `CPList`,
`CPString` family and CarPlay's classes both. Reading it is how the false claim became visible: the
6.1.3 and 4.3 lists are CoreFoundation's, and the 12.0 list is that same list **plus CarPlay**. Both
controls are in the run, so the 348 on 12.0 and the 0 for any one CarPlay name on 6.1.3 are both the
release's answer and not the reader's.

Class-scoped, for the four names the nine rows are about:

```
$ CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua CPNavigationSession 6.1.3 4.3 12.0
6.1.3  classes 11378, of which CPNavigationSession* 0        protocols 1171, of which CPNavigationSession* 0
4.3    classes 7187,  of which CPNavigationSession* 0        protocols 564,  of which CPNavigationSession* 0
12.0   classes 63192, of which CPNavigationSession* 1 (CPNavigationSession)
                                                    protocols 11426, of which CPNavigationSession* 1 (CPNavigationSessionProviding)
control: 2 name(s) beginning CPNavigationSession found in this run
```

The same three-rung run for `CPSessionConfiguration` (12.0: the class and `CPSessionConfigurationDelegate`),
`CPRouteChoice` (12.0: the class) and `CPVoiceControl` (12.0: `CPVoiceControlState`,
`CPVoiceControlTemplate`, `CPVoiceControlTemplateDelegate`) reads the same way. The whole transcript
is `.agent-work/runs/carplay-12/census-cp.txt`.

## What the members are, read the way the gate reads them

`cache-census.lua` answers whether a *class* is there. Whether a *member* is there is
`modules/apple/backports.lua:1627`'s `carried_by_release`, which asks the per-class instance and class
selector sets — so this is the measurement a member row may rest on, and a name that exists somewhere
in a cache is not a member of a class:

```
$ CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/12.0/dyld_shared_cache_arm64 \
      > .agent-work/runs/carplay-12/objc12.tsv          # 74618 lines
$ python3 .agent-work/runs/carplay-12/members-at-12.py  # reads the two selector columns, asserts a control
control: NSObject at 12.0 answers -class and -hash through the same reader, so a 0 below is the release's
CARRIED  CPNavigationSession      -[trip]
CARRIED  CPNavigationSession      -[upcomingManeuvers]
CARRIED  CPNavigationSession      -[cancelTrip]
CARRIED  CPNavigationSession      -[finishTrip]
CARRIED  CPNavigationSession      -[pauseTripForReason:description:]
CARRIED  CPNavigationSession      -[updateTravelEstimates:forManeuver:]
absent   CPNavigationSession      -[init]
absent   CPNavigationSession      +[new]
CARRIED  CPSessionConfiguration   -[delegate]
CARRIED  CPSessionConfiguration   -[limitedUserInterfaces]
CARRIED  CPSessionConfiguration   -[initWithDelegate:]
absent   CPSessionConfiguration   -[init]
absent   CPSessionConfiguration   +[new]
absent   CPRouteChoice            +[new]
CARRIED  CPVoiceControlState      -[identifier]
CARRIED  CPVoiceControlState      -[titleVariants]
CARRIED  CPVoiceControlState      -[image]
CARRIED  CPVoiceControlState      -[repeats]
CARRIED  CPVoiceControlState      -[initWithIdentifier:titleVariants:image:repeats:]
CARRIED  CPVoiceControlTemplate   -[activeStateIdentifier]
CARRIED  CPVoiceControlTemplate   -[voiceControlStates]
CARRIED  CPVoiceControlTemplate   -[activateVoiceControlStateWithIdentifier:]
CARRIED  CPVoiceControlTemplate   -[initWithVoiceControlStates:]
```

The control is the reader's own: `NSObject` is read out of the same two columns of the same file and
answers `+class` and `+hash`, so a line reading `absent` above is the 12.0 cache's answer rather than
a column that was never filled.

## The 18 `implemented` rows, confirmed against the band end

Eighteen rows sit at `implemented` and every one of them is carried by 12.0 under the reading above:
the class, its six instance selectors, the two properties (`trip` is `-trip`; `upcomingManeuvers` is
`-upcomingManeuvers`, and `-setUpcomingManeuvers:` is in the same set), the two voice control
classes, their six properties and their three selectors. Their objects are
`packages/a/apple-backports/CarPlay/CarPlayNavigationSession12.m` and `CarPlayVoiceControl12.m`, and
their `source` now names this page's commands beside the header lines they rest on.

Two things in the 12.0 lists are worth reading, because the port's objects are built against 16.0 and
18.0 and the older release is the one this band places them on:

- **`CPNavigationSession`'s only initialiser at 12.0 is `-initWithTrip:provider:mapTemplate:`** — a
  *provider*, not the two-argument `-initWithTrip:mapTemplate:` the 16.0 and 18.0 caches carry, and
  the class has `-provider` and `-setProvider:` beside it. So at 12.0 the creator was handed a
  provider object as well as the trip and the template. The port's own factory
  `+charon_sessionForTrip:mapTemplate:` is a `charon_` name and takes two, which is a port-internal
  seam and not this initializer; what the row rests on is the direction both releases agree on: the
  app is handed the session, it does not build one.
- **neither class declares `-init` or `+new` of its own.** `CPRouteChoice` *does* declare `-init` at
  12.0 (and `-[CPRouteChoice init]` is a row in this file, but not one of these 27), which is exactly
  why `+[CPRouteChoice new]` is judged on the header's `NS_UNAVAILABLE` and not on an absence here.

## The 9 `absent` rows, and what each one rests on now

Five of the nine are calls the 26.2 header marks `NS_UNAVAILABLE`, and the measurement above agrees
with the header on every one: the 12.0 cache declares no `-init` or `+new` on `CPNavigationSession`
or `CPSessionConfiguration` and no `+new` on `CPRouteChoice`. The header's own lines are in
`facts/CarPlay/Session.md`; what is added here is that the release's own classes back the refusal, so
the row rests on two independent things rather than on a transcription of one SDK.

The other four are the whole of `CPSessionConfiguration`, and here the row is a claim about the
release that the release contradicts **at 12.0**: the class is there, with `-delegate`,
`-limitedUserInterfaces` and `-initWithDelegate:`. Those four rows stay `absent`, and the reason is
not a hardware story:

- the port's deployment floor for this file is 6.0, and at 6.1.3 and at 4.3 there is no CarPlay class
  of any name (the census above), so **below the release that introduced the framework nothing
  answers any of the four** — which is the claim `absent` makes;
- from 12.0 up the release itself answers them, so the row is a placement record rather than a gap:
  `minimums()` at `backports.lua:2014` reads `entry.minimum` and never `entry.status`, so the row still
  carries the class from 6.0 and a band at 12.0 links against the device's own CarPlay;
- the port declining to carry them is still the right call, and the reason is the one
  `facts/CarPlay/Session.md` measured on Apple's own framework with no head unit: the two properties
  are the **connected system's** answers (0 with no car, and only 0 is reachable from a library that
  has no path to one), and `delegate` is a callback no connected system will ever send. Carrying a
  class whose every answer is a stand-in is the thing `absent` exists to prevent, and
  `respondsToSelector:` tells the truth only while there is no object.

So the nine rows keep their status and lose one wrong sentence each: the release claim becomes the
measurement on this page — no CarPlay at 6.1.3 or 4.3, CarPlay present at 12.0, and for the five
forbidden calls no member declared even at 12.0 — instead of a claim that 16.0 was the first rung to
carry CarPlay, which the 12.0 census contradicts.

## The files, and what is regenerable

```
.agent-work/runs/carplay-12/census-cp.txt          the census transcript quoted above
.agent-work/runs/carplay-12/objc12.tsv             the 12.0 inventory, 74618 lines, regenerable by the command above
.agent-work/runs/carplay-12/carplay-classes-12.tsv the five classes' two selector columns
.agent-work/runs/carplay-12/members-at-12.py       the reader, with its control
.agent-work/runs/carplay-12/members-at-12.txt     its output, quoted above
```

`objc12.tsv` is 36 MB (37351344 bytes, 74618 lines) and is regenerable from the cache by the one
command on this page, so it keeps its evidence and loses its bulk at the next worktree sweep.
