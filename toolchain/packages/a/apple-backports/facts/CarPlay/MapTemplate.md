# The map template

`CPMapTemplate` is the object a CarPlay application puts its map in: the template draws the map, the
buttons, the bar and the chrome, and it is the template that presents a navigation alert, shows trip
previews, and begins a navigation session. The port builds it at 12.0, where the release has no
CarPlay at all.

## What was measured, and against what

Three sources, and which one a claim rests on is said in the claim.

**Apple's own CarPlay on this machine, with no scene and no head unit.** Section 6b of
`tests/backports/host/carplay/headunit-probe.m` asks Apple's own `CPMapTemplate` class which of the
members this port carries answers on it. Every one of them is present: the release that has the class
has the members, so a row that said `absent` would be a claim about this port and not about Apple.
What the class cannot be asked is a value - with no scene there is no map, no bar and nothing to draw
- which is why every answer below about what the port does is read from the port and not from Apple's
object.

**The release's own dyld shared cache at 16.0**, per class and through
`tools/corpus/objc-inventory.lua`: `CPMapTemplate` carries `-presentNavigationAlert:animated:`,
`-dismissNavigationAlertAnimated:completion:`, `-updateTravelEstimates:forTrip:`,
`-showTripPreviews:textConfiguration:`, `-showRouteChoicesPreviewForTrip:textConfiguration:`,
`-hideTripPreviews`, `-showPanningInterfaceAnimated:`, `-dismissPanningInterfaceAnimated:` and the
rest, and its own `-init` has already made the alert, the guidance colour and the map buttons. That is
what makes these members modellable on a release with no CarPlay: the class does this work, and what it
does not have is a car to do it in.

**The 26.2 headers this port targets**, which are what each member is written to. Every one of them is
answered by its own declaration, and the two that needed it most are quoted rather than paraphrased:

- `CPMapTemplate.h:164-166` — `@warning If a navigation alert is already visible, this method has no
  effect. You must dismiss the currently-visible navigation alert before presenting a new alert.` So
  `-presentNavigationAlert:animated:` returns when one is already visible, and it does not replace it.
- `CPMapTemplate.h:176-177` — the completion's `BOOL` "indicates whether any visible alert was dismissed
  (YES) or if no action was taken because there was no alert to dismiss (NO)". So the answer reports
  the state *before* the call: YES when there was a visible alert, NO when there was none. The block
  takes one argument, not two.
- `CPMapTemplate.h:130-134` — "a maximum of two mapButtons will be visible. If more than two mapButtons
  are visible when the template transitions to panning mode, the system will hide one or more map
  buttons **beginning from the end** of the mapButtons array." So the last ones are hidden, and
  `-dismissPanningInterfaceAnimated:`'s `@note` at `:142` — "mapButtons previously hidden by the system
  will no longer be hidden" — means *every* button becomes visible again, not merely the excess.
- `CPMapTemplate.h:36-41` — `CPTimeRemainingColor` is an enumeration of four cases (Default = 0, Green,
  Orange, Red), not a colour object. `-updateTravelEstimates:forTrip:` is the specified-colour member
  with `CPTimeRemainingColorDefault`, which is the first case and the number an unset value already
  holds; the preview card names the four cases by the names the header gives them.
- `CPMapTemplate.h:76` — "Number of trips will be limited to 12." Both preview members keep twelve and
  drop the rest.

## What the port draws, and what it does not measure

The drawing is the class's own, in `CarPlayTemplatesView12.m`: `-charon_showCurrentAlert` draws the
navigation alert over the release's `MKMapView`, `CharonMapButtons` draws the map buttons, and
`-charon_drawTripPreviews` (in `CarPlayMapTemplate12.m`) draws the preview card. The members drive that
drawing; none of them reimplements it.

Two cards are classes of their own — `CharonCarPlayAlertCard` and `CharonMapPreviewCard` — for one
reason: a dismissal and a `-hideTripPreviews` have to be able to *find* the card they take off the map.
A plain `UIView` could not be told apart from the map's own subviews.

The card geometry is this port's own and is said to be: there is no car screen to measure a card on.
The 420-point width is the alert card's, and the map underneath is the release's own `MKMapView` at the
frame `CarPlayTemplatesView12.m` puts it at, so the card is a card over something real. What is *not*
this port's own is the text: each preview line is the trip's own origin and destination as MapKit items
name them, and the time remaining is read from the estimates the caller gave.

**The `textConfiguration` argument is in the signature and is not read.** It is the system's font and
scale for a car screen. Reading it would mean applying a number this port cannot measure, and ignoring
it silently would mean the row's effect said nothing about what a caller gets. So the rows say it: the
previews are drawn in this port's own label at the system's default. That is the one place a declared
argument does not reach the answer, and it is written down in the row rather than left to be found.

## Where each member lives, and one release per object

| member | release | object |
| --- | --- | --- |
| `-presentNavigationAlert:animated:`, `-dismissNavigationAlertAnimated:completion:` | 12.0 | `CarPlayMapTemplate12.m` |
| `-showPanningInterfaceAnimated:`, `-dismissPanningInterfaceAnimated:` | 12.0 | `CarPlayMapTemplate12.m` |
| `-showTripPreviews:textConfiguration:`, `-showRouteChoicesPreviewForTrip:textConfiguration:`, `-hideTripPreviews` | 12.0 | `CarPlayMapTemplate12.m` |
| `-updateTravelEstimates:forTrip:`, `-updateTravelEstimates:forTrip:withTimeRemainingColor:` | 12.0 | `CarPlayMapTemplate12.m` |
| `-[CPImageSet initWithLightContentImage:darkContentImage:]` | 12.0 | `CarPlayMapTemplate12.m` |
| `-showTripPreviews:selectedTrip:textConfiguration:` | 14.0 | `CarPlayMapTemplate14.m` |
| `-[CPGridButton updateImage:]` | 26.0 | `CarPlayGrid260.m` |

A category cannot add an ivar, so the storage for the alert, the previews, the per-trip estimates and
the time-remaining colour is declared with the class's own ivars in `CarPlayTemplatesView12.m` and
reached through the accessors declared in `CharonCarPlayTemplate.h` — the header this tree keeps for
exactly this, and the same seam shape `CarPlayGrid260.m` and `CarPlayNavigationSession154.m` already
use. `CPGridButton`'s 26.0 `-updateImage:` went into the object this library already had for that
release rather than into a second 26.0 object of its own, and `CPImageSet`'s initialiser is a category
whose storage is the class's own in `CarPlayTemplatesMore12.m`, which is the reason the header holds
both seams rather than each object declaring its own category interface.

## The rows that said implemented with nothing behind them

These twelve rows said `implemented` while their selectors were in no source file in the package. The
gate could not see it, and the reason is worth writing down: `modules/apple/backports.lua`'s unbuilt
check counts a member row as built when its owner class is exported, so a class answers for a member it
never defined. Thirteen selectors were in no source file; the thirteenth,
`-[CPMapTemplate startNavigationSessionForTrip:]`, is not here because `CarPlayNavigationSession12.m`
gives it a body — the 26.2 header says that method is where a session comes to exist, and this object
holds it for that reason and not for the other twelve.

Each of them now names something the code defines, and each `effect` says what a caller gets.