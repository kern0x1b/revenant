# The navigation session: a measurement, decided and measured, and not carried yet

**Fourteen rows: eight are carried and six are `owed`, and this page says which is which.** The eight
that are carried are the 12.0 class and its members plus the 15.4 pause, with the map template's own
`-startNavigationSessionForTrip:` as the way in; the six that are `owed` are the 17.4 members, and what
they need is written down below rather than dressed up.
Their reason used to be "the head unit", which is wrong — a navigation session is not a connection to
a car, and the port can carry it. What is missing is the code, and this page records the decision, the
measurements behind it, and what carrying it needs, so the next round starts from facts rather than
from the old blanket sentence.

## What decides the world, and it is not the wall

The 26.2 header is explicit about who makes one:

```
CPNavigationSession.h:26   @c CPNavigationSession represents the active navigation session. A @c CPNavigationSession will be created for you
CPNavigationSession.h:27   when calling startNavigationSessionForTrip: on @c CYMapTemplate
CPNavigationSession.h:33   - (instancetype)init NS_UNAVAILABLE;
CPNavigationSession.h:34   + (instancetype)new NS_UNAVAILABLE;
```

and the way in is a method the port already registers as `implemented`:

```
CPMapTemplate.h:112        - (CPNavigationSession *)startNavigationSessionForTrip:(CPTrip *)trip;
                           @return CPNavigationSession maintain a reference to the navigation session to perform guidance updates
```

So the session is not the gate: the **scene** is the gate (a `UIScene` the system makes for a
connection, `facts/CarPlay/Scenes.md`), and the session is what the program is handed *inside* one, by
a map template the port already carries. That makes these fourteen rows a measurement — what the SDK
answers with no head unit — and the two `+new`/`-init` rows a third thing, the header's own
`NS_UNAVAILABLE`, which the previous commit settled (`facts/CarPlay/Session.md`).

**The 16.0 cache names the creator, and it is not the program:** the class's only initialiser is the
private `-initWithTrip:mapTemplate:`, and the private protocol `CPNavigationSessionProviding` declares
`-hostStartNavigationSessionForTrip:reply:`. The app is given the session; it does not build one.

## The two releases, measured per class, and why first-rung alone was not enough

`first-rung.lua` answers for NAMES, so three of the six 17.4 members read 16.0 — and every one of them
is a **name collision**, not the member: `CPRouteGuidance` carries `currentLaneGuidance`,
`currentRoadNameVariants` and `maneuverState` at 16.0. `tools/corpus/objc-inventory.lua` answers per
class, and the two disagree exactly where they should:

| member | `first-rung.lua` (a name) | 16.0, per class | 18.0, per class |
| --- | --- | --- | --- |
| `currentLaneGuidance` | 16.0 | **absent** | present |
| `currentRoadNameVariants` | 16.0 | **absent** | present |
| `maneuverState` | 16.0 | **absent** | present |
| `addManeuvers:` | 18.0 | absent | present |
| `addLaneGuidances:` | 18.0 | absent | present |
| `resumeTripWithUpdatedRouteInformation:` | 18.0 | absent | present |

Both numbers are measurements and the per-class one is the one a row may rest on: a selector name
that exists somewhere in a cache is not a member of a class. The 16.0 per-class list for
`CPNavigationSession` is `trip`, `upcomingManeuvers`, `cancelTrip`, `finishTrip`,
`pauseTripForReason:description:`, `pauseTripForReason:description:turnCardColor:` and
`updateTravelEstimates:forManeuver:`, plus the private `initWithTrip:mapTemplate:`, `manager` and
`mapTemplate`. The 18.0 list adds the six, with their private accessors `setCurrentLaneGuidance:`,
`setManeuverState:`, `setCurrentRoadNameVariants:`, `laneGuidances`, `maneuvers` and `pauseReason` —
which is how a band's reader can see that they are stored values and not messages to a car.

Command and verdict, for a reader who wants to repeat it:

```
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/16.0/dyld_shared_cache_arm64e
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/18.0/dyld_shared_cache_arm64e
awk -F'\t' '$2=="CPNavigationSession"' <the two tsvs>
```

(the arm64e caches are split: a 384 KB header and the bodies in `.01`, `.03`, …, and the reader takes
the base path. The 16.0 inventory this repository already had was reused rather than rebuilt — it is
`toolchain/.agent-work/runs/coreml-1/objc16.tsv`, 81 MB, and the 18.0 one is under this band's own
`.agent-work/runs/carplay-1/objc18.tsv`, 104 MB.)

## What carrying the fourteen needs, and the three classes they reach for

Six of the fourteen are 17.4 and two of their types are classes the port does not carry:
`currentLaneGuidance` is a `CPLaneGuidance *` and `resumeTripWithUpdatedRouteInformation:` takes a
`CPRouteInformation *`. So a 17.4 object carries a category on `CPNavigationSession` with the six
members **and** the value classes they need, and those classes are small and measurable:

| class | 18.0 members that matter | what it is |
| --- | --- | --- |
| `CPLane` | `angles`, `primaryAngle`, `secondaryAngles`, `highlightedAngle`, `index`, `status`, `initWithAngles:highlightedAngle:isPreferred:`, NSCopying, NSSecureCoding | one lane and which way it goes |
| `CPLaneGuidance` | `lanes`, `instructionVariants`, `index`, `componentID`, NSCopying, NSSecureCoding | guidance for one lane or a few |
| `CPRouteInformation` | `maneuvers`, `laneGuidances`, `currentManeuvers`, `currentLaneGuidance`, `tripTravelEstimates`, `maneuverTravelEstimates`, `initWithManeuvers:laneGuidances:currentManeuvers:currentLaneGuidance:tripTravelEstimates:maneuverTravelEstimates:` | the route ahead, as values |

All three are value holders with no reference to a car, which is why they are in the measurement world
and not the wall's. Two of the corpus's CarPlay classes are *not* in the queue's 48 for this reason —
they are additions this round would make, and the registry needs an entry for each class the package
builds.

The 15.4 member is one method, `pauseTripForReason:description:turnCardColor:`, and belongs in a 15.4
object as a category on the 12.0 class, the way `CarPlayButtons16.m` carries the 16.0 buttons.

## The row that was a defect in main, and is now carried

`-[CPMapTemplate startNavigationSessionForTrip:]` was registered `implemented` in
`registry/CarPlay/ios12.json` **and no source file in the tree implemented it**: `CPNavigationSession`
appeared nowhere under `packages/`, and neither did that selector. The gate could not see it, because
`backports.lua`'s unbuilt check counts a member row as built when its owner class is exported
(`built = built or (owner and found.classes[owner])`), and `CPMapTemplate` is exported. So the map
template a program pushes answered nothing when it was asked to begin guidance, and the row claimed
otherwise.

It has a body now, and the row's text says what it answers. The same grep over the package finds ten
more `CPMapTemplate` rows with no code — `showTripPreviews:`, `showRouteChoicesPreviewForTrip:`,
`presentNavigationAlert:animated:`, `updateTravelEstimates:forTrip:` and the rest of that family — which
are **not** in this band and are named here so the next one does not have to find them again.

## What the port carries, and what it answers

`CarPlay/CarPlayNavigationSession12.m` is the 12.0 object: the class, its seven members, and
`-[CPMapTemplate startNavigationSessionForTrip:]` as a category on the map template. The class keeps its
own storage for the session in `CarPlayTemplatesView12.m` — a category cannot add an ivar — and three
`revenant`-prefixed accessors cross the file boundary, so nothing of them is in the library's exports.
`CarPlayNavigationSession154.m` is the 15.4 object and holds the one later method, which is the 12.0
pause plus the turn card colour.

- **the way in** is the header's own: `-[CPMapTemplate startNavigationSessionForTrip:]` makes a session
  and the template keeps it. A second call for the same trip hands back the session already running,
  because the header's guidance is per trip.
- **no `-init`, no `+new`**: `CPNavigationSession.h:33-34` marks both `NS_UNAVAILABLE`, so the factory
  is a class method that uses NSObject's own `-init` and two Revenant methods that configure — a method
  outside the init family may not assign to `self`, and a name in the `revenant_` namespace keeps the
  release's private `-initWithTrip:mapTemplate:` out of the exports.
- **`trip`**, **`upcomingManeuvers`** (a copy, in the program's order), **`updateTravelEstimates:forManeuver:`**
  (kept per maneuver), **`pauseTripForReason:description:`**, **`finishTrip`**, **`cancelTrip`**: each
  records what it was given and the map template's own guidance card is redrawn, which is the port's
  half of the seam. A negative `timeRemaining` renders as the header's own `--`, and a zero renders as
  a zero, because `CPTravelEstimates.h:24-31` says a value below 0 is not a value equal to 0.
- **the 15.4 turn card colour** is the header's own chain: the colour given, else the map template's
  `guidanceBackgroundColor`, else the colour the template's own `-init` sets. Each step is a value
  that exists.
- **before the template is pushed** there is no map to draw over, so guidance asked for then draws
  nothing and loses nothing: the estimates are still on the session and the card appears when the
  template has a map.

Thirteen checks drive all of that through the port's own objects in
`tests/backports/host/carplay/runner.m`, and both mutants stay red.

## The rows, and their state

| rows | introduced | state | why |
| --- | --- | --- | --- |
| `CPNavigationSession`, `trip`, `upcomingManeuvers`, `cancelTrip`, `finishTrip`, `pauseTripForReason:description:`, `updateTravelEstimates:forManeuver:`, and `-[CPMapTemplate startNavigationSessionForTrip:]` | 12.0 | `implemented` | carried in the 12.0 object, with the map template as the creator the header names |
| `pauseTripForReason:description:turnCardColor:` | 15.4 | `implemented` | carried in the 15.4 object, a category on the 12.0 class |
| `currentLaneGuidance`, `currentRoadNameVariants`, `maneuverState`, `addManeuvers:`, `addLaneGuidances:`, `resumeTripWithUpdatedRouteInformation:` | 17.4 | `owed` | a measurement the port can take, and not yet taken: they need `CPLaneGuidance` and `CPRouteInformation` carried with them in a 17.4 object |

`owed` is the port's own word for "the release carries the name, the port could carry it, and nobody
has written it yet" (`modules/apple/backports.lua`, the five statuses). The six 17.4 rows are in it and
this page does not claim they are done: they are a measurement that has not been taken, and the two
value classes they need are listed above with their 18.0 members.
