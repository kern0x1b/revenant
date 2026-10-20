# The 17.4 members of the navigation session, and the two classes they need

**The six rows this page is about were `owed`, and `owed` is not a landing state: the release carries the
names, the port could carry them, and nobody had written them. They are `implemented` now, and the claim
is a measurement rather than a queue entry.** The reason the whole slice turned on measurement is that
"the car renders the guidance on its own screen" is the wall for CarPlay, and these six members are not
on that side of it: they are the program's own values on the session the program already holds.

| row | introduced | what it is |
| --- | --- | --- |
| `-[CPNavigationSession addManeuvers:]` | 17.4 | the chronological maneuver list a program feeds as it computes |
| `-[CPNavigationSession addLaneGuidances:]` | 17.4 | the chronological lane guidance, drawn one plate per lane |
| `-[CPNavigationSession currentLaneGuidance` | 17.4 | which of them is current, and nil is a real answer |
| `CPNavigationSession.currentRoadNameVariants` | 17.4 | the road name, most to least verbose |
| `CPNavigationSession.maneuverState` | 17.4 | how close the maneuver is |
| `-[CPNavigationSession resumeTripWithUpdatedRouteInformation:]` | 17.4 | resume on a rerouted route |

## What the release carries, per class, and the command that reads it

`tools/corpus/objc-inventory.lua` over the arm64e dyld shared caches, read per class. The 16.0 cache has
none of the six; the 18.0 cache has all six together with their **private storage writers**, and that is
what decides the disposition:

```
== 16.0, CPNavigationSession (present, super=NSObject, image=CarPlay)
   -cancelTrip -finishTrip -initWithTrip:mapTemplate: -pauseTripForReason:description:
   -pauseTripForReason:description:turnCardColor: -setTrip: -setUpcomingManeuvers: -trip
   -upcomingManeuvers -updateTravelEstimates:forManeuver: -_currentTripId
   (none of: addManeuvers: addLaneGuidances: currentLaneGuidance currentRoadNameVariants
    maneuverState resumeTripWithUpdatedRouteInformation:)
== 18.0, CPNavigationSession (present, super=NSObject, image=CarPlay)
   -addLaneGuidances: -addManeuvers: -currentLaneGuidance -currentRoadNameVariants
   -maneuverState -resumeTripWithUpdatedRouteInformation: -setCurrentLaneGuidance:
   -setCurrentRoadNameVariants: -setManeuverState: -setLaneGuidances: -setManeuvers:
   -_updateLaneGuidanceIndiciesWithStartIndex:laneGuidances:
   -_updateManeuverIndiciesWithStartIndex:maneuvers:
```

A value whose writer is a setter on the object is the object's own state. A message to a car would have
no setter here at all. So these six are the program's values, and that is why they are `implemented` and
not `inert` — `inert` would promise the symbol loads and nothing applies it, and something does apply
them: the map template's own guidance card, which reads the road name, the estimates and the lane plates.

The command, verbatim, from this repository's root with `REVENANT_ROOT` at the tree:

```
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua $HOME/.revenant/dyld/18.0/dyld_shared_cache_arm64e
```

Two runs, 168686 lines at 16.0 and 221703 at 18.0, both through `coordination/heavy.sh` because a whole
arm64e dyld shared cache is a heavy job on this machine. The reader is the tree's own; the cache is split
(the base file is the header and the bodies are in `.01`/`.03`/`.05`) and the tool takes the base path.

## Presence on the held ladder, and why 16.0 is the answer and not 17.4

```
$ xmake l tools/cache-index/first-rung.lua CPLaneGuidance CPRouteInformation
CPLaneGuidance	16.0
CPRouteInformation	18.0
```

This is **presence, not version**. The held ladder is dense to 12.0 and then has a hole — no 13.0, 14.0 or
15.0 — so a class the SDK marks 17.4 first appears in the index at the next held rung. `introduced` on
every row here is the SDK 26.2 availability, read from `coordination/corpus/sdk-26.2-surface.tsv`, which
the queue header names as the registry's own source for it:

```
CarPlay	class	objc	CPLaneGuidance	17.4
CarPlay	class	objc	CPRouteInformation	17.4
CarPlay	method	objc	-[CPNavigationSession addManeuvers:]	17.4
CarPlay	method	objc	-[CPNavigationSession resumeTripWithUpdatedRouteInformation:]	17.4
```

## Apple's own object, with no head unit, and the line where it beats a first reading

`tests/backports/host/carplay/headunit-probe.m` section 8, built for Mac Catalyst
(`-target arm64-apple-ios17.0-macabi`), run by `tests/backports/host/carplay/run.sh`. Mac Catalyst is the
only place on this machine where Apple's CarPlay loads at all: the fleet devices run 6.1.3, which has no
CarPlay class of any name. This is the half of the run that `run.sh` diffs label by label against the
port's own objects.

```
== 8. the 17.4 members, on a session the program holds ==
ok   a session with nothing added answers no maneuvers at all   nil
     [CPNavigationSession addManeuvers:] present
     [CPNavigationSession addLaneGuidances:] present
     [CPNavigationSession currentLaneGuidance] present
     [CPNavigationSession currentRoadNameVariants] present
     [CPNavigationSession maneuverState] present
     [CPNavigationSession resumeTripWithUpdatedRouteInformation:] present
ok   currentRoadNameVariants answers nil before anything is set nil
ok   currentLaneGuidance answers nil before anything is set     nil
ok   maneuverState answers 0 before anything is set             0
     [CPNavigationSession setCurrentRoadNameVariants:] present
     [CPNavigationSession setManeuverState:] present
ok   CPLaneGuidance is the class currentLaneGuidance's value is present
ok   CPRouteInformation is the class resumeTrip takes           present
ok   a fresh lane guidance's lanes answer nil, not an empty array (measured) nil
ok   a fresh lane guidance's instructionVariants answer nil, not an empty array (measured) nil
ok   +supportsSecureCoding is YES (NSSecureCoding is in the header, CPLaneGuidance.h:17) YES
ok   route information from nil in every slot: maneuvers answers nil            nil
ok   route information from nil in every slot: laneGuidances answers nil         nil
ok   route information from nil in every slot: currentManeuvers answers nil     nil
ok   route information from nil in every slot: currentLaneGuidance answers nil   nil
ok   route information from nil in every slot: tripTravelEstimates answers nil  nil
ok   route information from nil in every slot: maneuverTravelEstimates ... nil  nil
```

**The honest line in this run is `lanes answer nil, not an empty array`.** A first reading of
`CPLaneGuidance.h:22` says an array of `CPLane`, and the default for a collection property would be `@[]`;
Apple's own object answers nil, and so does the port's. Nil in and nil out are kept apart from an empty
array in and an empty array out, because a guidance with no instruction is not the same object as no
guidance at all. This is the same shape as the dismissal rule elsewhere in this family: a first reading
says no, the framework says yes, and the port follows the framework.

## The obstacle, and the shape that gets round it

**Every one of these six writes a private ivar of a class whose `@implementation` is in a file for another
release, and a category cannot add an ivar.** `CPNavigationSession`'s implementation is
`CarPlayNavigationSession12.m`. That is why the port already splits: `CarPlayNavigationSession154.m` is a
category on the same class that keeps nothing of its own and reaches the storage through a
Revenant-prefixed accessor the 12.0 object declares.

So the storage for the six lives with the class's own ivars in `CarPlayNavigationSession12.m` behind
`revenant_` accessors, and `CarPlayNavigationSession174.m` carries only the six 17.4 selectors. Same rule,
same tree, already proved twice — `CarPlayMapTemplate12.m` and `CarPlayGridButton26.m` on the sibling
series `band-carplay12-1` are the other two instances of it.

The 12.0 object's storage accessors, each answering one header sentence:

| accessor | the header it answers |
| --- | --- |
| `revenant_addManeuvers:` | `:83-86` chronological order, "as soon as they are available" |
| `revenant_addLaneGuidances:` | `:90-91` the same, for lane guidance |
| `revenant_setCurrentLaneGuidance:` | `:78` "Must be set to nil if there is no current lane guidance" |
| `revenant_setCurrentRoadNameVariants:` | `:96-97` `copy`, "From most to least verbose" |
| `revenant_setManeuverState:` | `:101-102` the state, by how close the maneuver is |
| `revenant_resumeWithRouteInformation:` | `:54-57` resume on the updated route information |

`CPLane` is the same problem one release further on: `CPLane.h` is two releases in one header (17.4 at
`:22-48`, 18.0 at `:26-27`, `:43` and `:53`), so it is `CarPlayLane174.m` for the 17.4 half and
`CarPlayLane18.m` for the 18.0 half, sharing the storage through `RevenantCarPlayLane.h`. What the 18.0 half
IS is in the header's own deprecation text — `CPLane.h:33` "Use -[CPLane initWithAngles:] to create a
CPLane with CPLaneStatusNotGood, use -[CPLane initAngles:highlightedAngle:isPreferred:] to create a
CPLane with status CPLaneStatusGood or CPLaneStatusPreferred" — so the 18.0 API replaces the 17.4 way of
building a lane, and the port carries both.

## One defect this slice found, and the measurement that found it

**The 17.4 object was carrying the 18.0 API, and `@dynamic` is what stopped it.** The compiler
auto-synthesises every property an SDK header declares whether or not the object implements it, and the
first build of `CarPlayLane174.m` produced:

```
[__objc_class] property  highlightedAngle    (17.4 object)
[__objc_class] property  angles              (17.4 object)
[__objc_ivar]  _highlightedAngle             (17.4 object)
[__objc_ivar]  _angles                       (17.4 object)
```

That is 18.0 storage and 18.0 accessors inside a 17.4 band, and `xcrun otool -ov` on the object is what
printed it. It is the same defect commit `329b2b23c` found for `CPSessionConfiguration`'s `contentStyle`
and which main's tip commit fixed for `PHPhotoLibrary`'s availability property. `@dynamic highlightedAngle;`
and `@dynamic angles;` moved the storage to where the 18.0 object's category is, and the same is done in
`CarPlayNavigationSession12.m` for the three 17.4 properties it now stores.

The proof that each object holds one release, from the IMPs rather than from the property names:

```
CarPlayNavigationSession12.o   trip upcomingManeuvers pauseTripForReason:description:
                               updateTravelEstimates:forManeuver: finishTrip cancelTrip
                               + the eleven revenant_ accessors, and NO 17.4 selector
CarPlayNavigationSession174.o  addManeuvers: addLaneGuidances: setCurrentLaneGuidance:
                               setCurrentRoadNameVariants: setManeuverState:
                               resumeTripWithUpdatedRouteInformation:
CarPlayLane174.o               init setStatus: status primaryAngle secondaryAngles + NSCopying
                               and NSSecureCoding, and NO 18.0 selector
CarPlayLane18.o                initWithAngles: initWithAngles:highlightedAngle:isPreferred:
                               highlightedAngle angles
CarPlayLaneGuidance174.o       init lanes instructionVariants + NSCopying and NSSecureCoding
CarPlayRouteInformation174.o   initWithManeuvers:...:maneuverTravelEstimates: and the six getters
```

## What this page does not claim

The number of connected scenes, and anything else that needs a head unit, is not measured here and no row
in this slice claims it — `facts/CarPlay/Scenes.md` says so for the scenes and it holds for these six too.
What is measured is the shape of a session the program holds: six selectors present, three values
answering nil or 0 before anything is set, and private setters that say the values are its own.

Nor is anything here a claim about what a car would show for a maneuver state. `CPNavigationSession.h:101`
says the state is "based on how close the maneuver is" and does not say what a card shows for one, so the
port records the value and does not invent a drawing for it.