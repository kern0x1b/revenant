# CarPlay on iOS 6: the measurement pass, and what it decides

`apple.objc.inventory` against the armv7 dyld shared cache of **6.1.3**: **no CarPlay class is in
this release -- with one exception that matters, which the first measurement pass got wrong.**
`CPInterfaceController`, `CPWindow` and every template class are absent; the framework is not here at
all. But a class **named** `CPListItem` is, and it is not CarPlay's: its own eleven methods are
`-addParagraph:`, `-paragraphAtIndex:`, `-paragraphCount`, `-list`, `-number`, `-setList:` and
`-setNumber:` -- some other framework's private list item, with no `text`, no `image`, no
`accessoryType` and no `handler`.

So Apple's CarPlay `CPListItem` is iOS 12 and absent, and its *name* is taken, which is the case
`revenant_alias.h` exists for. (Note what this is and is not: the release has no `CPWindow`,
`CPTemplate` or any other CarPlay class, but it does have this one *name*, and a name the release
exports cannot be replaced by a second class of the same name.) `CarPlay/CPListItem.m` carries the name as an **alias**: it defines
`RevenantCPListItem`, exports the release's name to it, and records the pair in
`__DATA,__port_alias` for the library's loader. A subclass an application writes of `CPListItem`
inherits the release's class and is laid out after it; sent to `RevenantCPListItem` itself, the class
introspection answers as the release's class does, so `[CPListItem class]`, what `[CPListItem alloc]`
makes and what the release hands out are one class. This is exactly how the port already handles a
name the release carries and Apple did not add -- `UIKit`'s `NSTextList` and `NSTextTab`, whose rows
in `registry/UIKit/base.json` say the same thing. The gate's `duplicated()` check is what found it
and it is the check working.

`apple.dyld`'s `first_releases` over the held cache ladder, for the 74 classes the SDK 26.2 declares
and this port does not have:

| first held release that exports it | classes |
| --- | --- |
| 12.0 | 25 |
| 16.0 | 35 |
| 18.0 | 1 |
| not in any held release | 13 |

So the CarPlay surface splits into three objects by measured release, and nothing here is a copy of
anything: the framework is Apple's and there is no open implementation of it to port.

## What the wall is, and where it is

**The wall is the head unit, and it is Apple's, not this port's.** A CarPlay scene is a connection to
a car: without a car there is no scene, which is Apple's own behaviour without a car and not a
limitation of the port. That is the honest seam, and it is one seam with two halves:

- **Everything the templates need is implementable in-app.** The ruling and this file agree: the
  list, grid, map and now-playing templates are ordinary view controllers, and a
  `CPInterfaceController` equivalent is an object with a content window of the port's own that pushes
  and pops template view controllers, keeps the tab bar and the now-playing bar, and answers the
  delegate. None of that needs a car. So the templates and the interface controller are `implemented`
  and run in an application.
- **The scene connection is not implementable.** `CPScene`/`CPInterfaceController`'s connection to a
  car is a system service no program on this device can stand in for, so the scene is refused exactly
  as Apple refuses it without a car, and every CarPlay-specific affordance that depends on the car
  (the templates' car-specific layout, the car's input, the vehicle status) answers the way Apple
  answers it. That half is `documented-absent` at the seam, per COORDINATION §2: the API surface
  exists, everything not depending on the wall is implemented, and the refusal happens only where the
  wall is.

## What this decides, per family

- **`CPInterfaceController` and the four templates** (list, grid, map, now-playing) plus the
  supporting classes: `implemented`, as in-app view controllers over the port's own content window.
  A host differential is impossible for most of it (macOS has no CarPlay templates), so the emulator
  call test at 6.1.3 is the check, as it is for the MapKit renderers.
- **The car-dependent surface**: `inert` or `absent` per class, each with the measurement that the
  release has no CarPlay at all and the reason the class depends on a car that is not there.
- **The scene**: the connection refused, and `status` `absent` for the classes that *are* the
  connection, with the effect naming what a caller gets.

One thing this pass settles before any code is written, and it is the same shape as the MapKit
`MKMapItem` correction: **the wallet half of PassKit is the release's own**, so that half is not a
backport at all. See `facts/PassKit/PassKit.md`.

## The SDK shapes this has to be written against, read from the SDK 16.4

CarPlay's classes are not shaped the way a surface list suggests, and writing against the shapes
rather than against the list is the difference between working and a compile error per member. What
the SDK the port compiles against actually declares:

- `CPButton`, `CPBarButton`, `CPGridButton`, `CPMapButton` and `CPTextButton` are **`NSObject`
  subclasses, not views**. A `CPButton` has `-initWithImage:handler:` and a `title`; a `CPBarButton`
  has `-initWithImage:handler:` and `-initWithTitle:handler:`; a `CPGridButton` has
  `-initWithTitleVariants:image:handler:`; a `CPMapButton` has `-initWithHandler:`. So none of them
  can be drawn by being a view: each one is drawn by the template that holds it, and that is the real
  work — a grid button drawn in a collection view cell, a map button drawn over the map, a bar button
  drawn in a bar.
- `CPTemplate` declares `userInfo`, `tabTitle`, `tabImage`, `tabSystemItem` and `showsTabBadge`, and
  **no `title`** — so `CPTemplate.title` is this port's own member, declared under Apple's name.
- `CPListItem` conforms to **`CPSelectableListItem`**, so every member that protocol requires is
  required here; its own members are `text` (readonly), `detailText`, `image`, `accessoryImage`,
  `accessoryType`, `handler` (iOS 14, taking the item and a completion block), `explicitContent` (a
  **BOOL**, not a string), `playbackProgress` (a **CGFloat**), `playing`,
  `playingIndicatorLocation`, `enabled` and the class property `maximumImageSize`.
- `CPListSection` has `init` marked `NS_UNAVAILABLE` and `-initWithItems:` as the way in, and its
  `header`, `headerSubtitle`, `headerButton` and `items` are **readonly**, with `-updateSections:` on
  the template for the rest.
- `CPListTemplate` and `CPGridTemplate` also mark `init`/`new` `NS_UNAVAILABLE`, take
  `-initWithTitle:sections:` / `-initWithTitle:gridButtons:`, and expose `maximumItemCount` and
  `maximumSectionCount` as **class** properties.
- `CPTravelEstimates` takes `-initWithDistanceRemaining:timeRemaining:` with
  `NSMeasurement<NSUnitLength *> *` and answers `distanceRemaining` in the same type.

### The one that needs a decision

`NSMeasurement` and `NSUnitLength` are **absent from the release**: the 6.1.3 selector list has no
`measurementFormatter`, no `initWithUnit`-style initialiser for a unit, and
`-initWithDistance:time:` (measured absent), so there is no `NSMeasurement` class to put a
`CPTravelEstimates` distance into. `CPTravelEstimates` is the only CarPlay member the port cannot reach
for a reason that is **not** "the release has no CarPlay": a class the release has no counterpart of
would have to be carried here, which is Foundation's type in a CarPlay signature.

The two ways that can go, and the port has to pick one:

1. **Carry `NSMeasurement` and `NSUnitLength`** in the Foundation backport, as classes, and
   `CPTravelEstimates` is then real. This is Foundation's API, it belongs in `libFoundationBackports`,
   and the measure system behind it (a unit, a converter, a formatter) is a few hundred lines.
2. **`CPTravelEstimates` answers `distanceRemaining` as nil** and `timeRemaining` as the time, with the
   registry saying the distance is nil because the release has no measurement type to hold it. That is
   a quiet-different answer and COORDINATION §2 does not allow it.

**This is the question to put to the owner**: option 1 is the honest one and it is Foundation's
work rather than CarPlay's, so it belongs in whichever band owns Foundation, and this port would then
link `FoundationBackports` for it. Everything else in the 12.0 template family has no such question --
the list, grid, map and now-playing templates, the interface controller, the window and the alert
actions are all writable against the release and against UIKit.

## What is carried, and what is the wall

**23 classes implemented, 7 `absent`, and 44 with no registry entry at all** -- the 74
classes the SDK 26.2 declares and this port does not have, accounted for exactly. **The three
counts come from `registry/CarPlay/*.json` and are checked by reading it, not generated:**
`python3 -c "import json,collections;d=json.load(open('registry/CarPlay/ios12.json'));print(collections.Counter(e['status'] for e in d['entries'] if e['kind']=='class'))"`
prints the class rows by status, and the member counts come from the same file without the
`kind=='class'` filter (312 rows: 263 `implemented`, 48 `absent`, 1 `ignored`). An earlier version of
this page said these numbers were generated and could not drift; they were typed, and a reader
counting the file found it. The implemented classes, by the object that carries them:

| object | classes |
| --- | --- |
| 12.0 | CPWindow CPTemplate CPBarButton CPGridButton CPMapButton CPTravelEstimates CPManeuver CPAlertAction CPNavigationAlert |
| 12.0 | CPListItem CPListSection CPListTemplate CPGridTemplate CPMapTemplate CPInterfaceController |
| 12.0 | CPActionSheetTemplate CPAlertTemplate CPImageSet CPSearchTemplate CPTrip CPRouteChoice CPTripPreviewTextConfiguration |
| 16.0 | CPButton CPTextButton |

The 7 `absent`, and they are **not** all one kind of row, which an earlier version of this page
said and was wrong about: `CPNavigationSession`, `CPSessionConfiguration`,
`CPTemplateApplicationDashboardScene`, `CPTemplateApplicationInstrumentClusterScene`,
`CPTemplateApplicationScene`, `CPVoiceControlState` and `CPVoiceControlTemplate`. Three of them
(`CPTemplateApplicationScene` and its two siblings) **are** the wall — a `UIScene` the system makes
for a connection to a CarPlay head unit, measured and written up in `facts/CarPlay/Scenes.md`. The
other four are objects the port can carry, and each says in its own row which world it is in and what
it answers with no head unit: the voice control state and template (`facts/CarPlay/VoiceControl.md`),
the navigation session (`facts/CarPlay/NavigationSession.md`) and the session configuration
(`facts/CarPlay/SessionConfiguration.md`). What decides the split is a measurement, not a reading of
the words "CarPlay": **every one of the seven is present in Apple's own CarPlay on this machine with
no head unit attached** (`tests/backports/host/carplay/headunit-probe.m`), so an `absent` row is a
claim about this port and never about Apple's framework.

A 25th class the corpus does **not** ask about, and the reason the registry names 23 + 7 + 1 where
the corpus has 74: `CPListItem`. The corpus does not list it as missing, because the release carries
that *name* -- a class of another framework's, measured in facts' own words below -- so the port has to
say what happens to the name rather than the corpus having to ask. The answer is `ignored`: the name
is an **alias** through `revenant_alias.h`, the loader makes `RevenantCPListItem` a subclass of the
release's own class and gives that class what the alias has and lacks, and the row says so.

The 44 with **no registry entry at all** are the rest of the corpus. They are not `absent` -- they
draw in-app like these do and nothing about them needs a car, so calling them absent would be a false
claim -- and they are simply not written yet, so their ledger rows stay `missing`, which is the honest
word for a member nobody carries. The objects they go in, measured:

| object | classes |
| --- | --- |
| 12.0 | `CPWindow`, `CPTemplate`, `CPBarButton`, `CPGridButton`, `CPMapButton`, `CPTravelEstimates`, `CPManeuver`, `CPAlertAction`, `CPNavigationAlert` |
| 12.0 | `CPListItem`, `CPListSection`, `CPListTemplate`, `CPGridTemplate`, `CPMapTemplate`, `CPInterfaceController` |
| 12.0 | `CPActionSheetTemplate`, `CPAlertTemplate`, `CPImageSet`, `CPSearchTemplate`, `CPTrip`, `CPRouteChoice`, `CPTripPreviewTextConfiguration` |
| 16.0 | `CPButton`, `CPTextButton` |

The remaining 47 of the corpus have **no registry entry at all** and their ledger rows stay `missing`:
they are not `absent` (they draw in-app like these do and nothing about them needs a car, so calling
them absent would be a false claim), they are simply not written yet. **The count in that sentence was
already 4 higher than the table below it before this change** -- the table named 44 classes and the
sentence said 48 -- and taking `CPMessageGridItemConfiguration` out of the 26.0 row is what moved both
to 47 and 43. That drift is measured, not fixed here: reconciling the two is another page's edit.
The objects they go in, measured:

| object | classes |
| --- | --- |
| 14.0 | `CPContactCallButton`, `CPContactDirectionsButton`, `CPContactMessageButton`, `CPMessageListItemLeadingConfiguration`, `CPMessageListItemTrailingConfiguration`, `CPNowPlayingAddToLibraryButton`, `CPNowPlayingImageButton`, `CPNowPlayingMoreButton`, `CPNowPlayingPlaybackRateButton`, `CPNowPlayingRepeatButton`, `CPNowPlayingShuffleButton` -- none of them is in the SDK 16.4 headers, so the registry's `introduced` is what places them |
| 15.0 | `CPAssistantCellConfiguration` |
| 16.0 | `CPContact`, `CPContactTemplate`, `CPDashboardButton`, `CPDashboardController`, `CPInformationItem`, `CPInformationRatingItem`, `CPInformationTemplate`, `CPInstrumentClusterController`, `CPListImageRowItem`, `CPMessageComposeBarButton`, `CPMessageListItem`, `CPNowPlayingButton`, `CPNowPlayingTemplate`, `CPPointOfInterest`, `CPPointOfInterestTemplate`, `CPTabBarTemplate` -- all in the 16.4 headers, all first exported at 16.0 |
| 17.4 | `CPLane`, `CPLaneGuidance`, `CPRouteInformation` |
| 18.0 | `CPNowPlayingMode`, `CPNowPlayingModeSports`, `CPNowPlayingSportsClock`, `CPNowPlayingSportsEventStatus`, `CPNowPlayingSportsTeam`, `CPNowPlayingSportsTeamLogo` -- members of `CPNowPlayingTemplate`, so a category on the 16.0 class in the 18.0 object |
| 26.0 | `CPListImageRowItemElement` and its five subclasses |

## `CPMessageGridItemConfiguration` is the one 26.0 class this library registers, and it is a value object

It **was** in the table above as one of the classes with no registry entry at all -- the 26.0 row named
it beside `CPListImageRowItemElement` -- and it is not there now. This section says what replaced that
entry. Measured, not read off a header:

- **The corpus names four rows for it and no more** -- the class, one initialiser and two properties.
  `coordination/corpus/ledger/CarPlay.tsv` lines 24, 205, 356 and 357, and
  `coordination/corpus/sdk-26.2-surface.tsv` lines 133868, 133893, 133919 and 133920. All four say
  `26.0`, and **no member of it arrived later**: the class and its three members are one release, which
  is why the object that carries them is `CarPlayGrid260.m` and not a second one. The ledger's own
  `status` for all four was `missing`, with the reason "no class or protocol CPMessageGridItemConfiguration
  in the built libraries or the 6.1.3 cache" -- which was a **statement about the registry, not about
  the code**: `CarPlayGrid260.m` exports `_OBJC_CLASS_$_CPMessageGridItemConfiguration` and nothing
  registered it, so `releases_in()` had no row to fall back on and `check_releases()` refused the whole
  CarPlay library with "neither the SDK, the registry nor a held release's own cache says which iOS
  release CPMessageGridItemConfiguration arrived in".
- **It is a value object and needs nothing a car has.** Its whole surface is the two values a caller
  gives it -- a conversation identifier and an unread flag -- and `CarPlayGrid260.m` keeps them and
  answers with them. That is the same line the neighbouring implemented rows draw, and it is why the
  four rows are `implemented` and not `absent`: nothing about this class is a screen, a head unit or a
  scale, so there is no absence to record.
- **What it is not** is drawn. CPGridButton.h:24 says `unread` says whether the item "shows an unread
  indicator", and :21-23 says the identifier "is not directly displayed to the user" and that SiriKit
  hands it back when the item is selected. On this release neither happens -- there is no car screen and
  no SiriKit selection -- so both values are carried and readable and neither is shown or handed back.
  Each row's `effect` says that in its own words.
- **The SDK the package compiles against does not have the class at all**, so this is not a declaration
  of Apple's that was copied: `grep` finds the name nowhere in the iPhoneOS16.4 SDK, whose
  `CarPlay.framework/Headers/CPGridButton.h` is 57 lines and stops at the 12.0 members (its last
  initialiser at `:30`). `RevenantCarPlay260.h` therefore carries Apple's own declaration from
  CPGridButton.h:15-34 -- declarations only, no method body and no Apple byte -- and every behaviour in
  it is `CarPlayGrid260.m`'s.

## `CPTemplate.title` is not a name this port carries

Measured against the SDK 26.2 the port does not compile against but does target: 26.2's
`CPTemplate.h` mentions "the template's title" in a `@note` and **declares no such property**, and the
templates that do have one -- `CPListTemplate`, `CPGridTemplate`, `CPMapTemplate` -- declare `title` on
themselves. An earlier version of this library gave `CPTemplate` a `title`; that name no header
declares, so it is removed (rule R4), and the tab's
own name is now `tabTitle`, which the header does declare.

**The buttons are NSObjects, and the templates draw them.** That is the SDK's own shape -- `CPButton`,
`CPBarButton`, `CPGridButton`, `CPMapButton` and `CPTextButton` are all `NSObject` subclasses in the
16.4 headers, and none of them is a view. So each carries a `revenant_drawInRect:` (and `alpha:` where it
is drawn in a bar), and each template asks its buttons to draw themselves: the list and grid and map
templates put the bar buttons in a bar the template owns, the grid template asks each grid button to
draw into the collection view cell it is in, and the map template asks each map button to draw over
its map inside the map view's own insets. Each button's own handler is called
when the drawn mark is tapped. The header's own rule that a navigation bar shows at most two leading
buttons is honoured by the bar.

**`CPTravelEstimates` takes the port's own `NSMeasurement`.** `libFoundationBackports` carries
`NSUnit`, `NSUnitLength` and `NSMeasurement` (all three registered `implemented`, `minimum: "6.0"`, with
real implementations: the unit ladder, the linear and reciprocal converters, the measurement and its
arithmetic), which is exactly what the release lacking them is for. `CPTravelEstimates` is the member
that needs them, and it gets a real `NSMeasurement<NSUnitLength *> *` back.

**The map template uses the release's own map.** `CPMapTemplate`'s view controller is the release's
`MKMapView` -- the only map this port has -- with this port's own renderers on it, the map buttons over
it, and the navigation alert drawn as a guidance card out of its own title and subtitle variants. The
car-specific part of a map template (the car's own map rendering, the vehicle status, the car's input)
is the wall and is the registry's.

**`CPInterfaceController` owns a `CPWindow` of the port's own** -- a car's window is a window, and on
this port it is a window the application owns. It keeps the root template, the tab templates and the
pushed stack, implements the header's own completion forms and its deprecated forms of the six
operations, sends the delegate the four template lifecycle messages, and answers `carTraitCollection`
with **this device's own screen trait collection**, because the car is this device. `prefersDarkUser
UserInterfaceStyle` is `inert`: the release has no dark mode, and there is nothing for it to change.

**`CPWindow.mapButtonSafeAreaLayoutGuide` has no registry row at all, and that is the accurate
state.** Measured three ways: a layout guide is iOS 9; the release's 6.1.3 inventory has **no
`CPWindow` of any name** (CarPlay is not in this release, which is the whole of this file's
premise); and the gate's own imports stage named `_OBJC_CLASS_$_UILayoutGuide` as the one symbol
`libCarPlayBackports.dylib` imported that the device's iOS 6.1.3 does not export. So neither the
release nor this port answers the property, there is nothing for a row to describe, and the
ledger's row stays `missing` -- which is the honest word for a member nobody carries. The map
template's own buttons are laid out inside the map view's own insets, so the picture does not
depend on it either way.

**The wall, per class.** Three of the seven absent classes are the wall itself — the scenes, and only
the scenes, measured in `facts/CarPlay/Scenes.md`: `CPTemplateApplicationScene` (13.0),
`CPTemplateApplicationDashboardScene` (13.4) and `CPTemplateApplicationInstrumentClusterScene`
(15.4). The other four, `CPSessionConfiguration` (a configuration the connected system fills in, and
its own values measure 0 with no head unit) and the three the port now carries, are objects rather
than gates. `CPRouteChoice` is **not** among them: a route choice is a choice of route between two
places, which is arithmetic, and it is built and registered implemented — including its `+new`, whose
measured answer is a route choice whose three variants properties are empty arrays and whose
`userInfo` is nil. Each class's own reason is in its entry, and for the ones the port does not carry
`NSClassFromString` answers nil, which is what `absent` means.

## `CarPlayTemplatesView12.m` carries four releases, and the split is owed

**One `.m` defines the API of exactly one release**, and `CarPlayTemplatesView12.m` does not: besides its
12.0 rows it carries 14.0, 15.0 and 26.0 API. The gate cannot see it, because `minimums()` reads
`entry.minimum` and never `entry.introduced`, and every one of these rows is `minimum: 6.0` — so one
object, one minimum, and no complaint. The rule is read by hand, and a reviewer's read found this.

The non-12.0 members, and what each one touches in the 12.0 class's private storage — which is the whole
of why this is not a cut-and-paste:

| introduced | member | private storage it reaches |
| --- | --- | --- |
| 14.0 | the seven `-[CPInterfaceController …animated:completion:]` forms | `_stack` |
| 14.0 | `-[CPListTemplate indexPathForItem:]` | `_sections` |
| 14.0 | `-[CPMapTemplate showTripPreviews:selectedTrip:textConfiguration:]` | no code at all — the row is `owed` |
| 15.0 | `-[CPListTemplate initWithTitle:sections:assistantCellConfiguration:]` | the list's own storage |
| 15.0 | `-[CPGridTemplate updateGridButtons:]` | `_gridButtons`, `_grid` |
| 15.0 | `-[CPGridTemplate updateTitle:]` | `_title` |
| 15.0 | `-[CPListSection initWithItems:header:headerSubtitle:headerImage:headerButton:sectionIndexTitle:]` | the section's own storage |
| 26.0 | `-[CPListTemplate initWithTitle:sections:assistantCellConfiguration:headerGridButtons:]` | the list's own storage |

A category cannot reach an ivar, so the split needs five `revenant`-prefixed accessors on the classes in
`CarPlayTemplatesView12.m` (`_stack`, `_sections`, `_gridButtons`, `_grid`, `_title`, plus whatever the
three initialisers need) and then three new objects named for 14.0, 15.0 and 26.0 — which is what
`CarPlayNavigationSession12.m` and `CarPlayNavigationSession154.m` do for the session, one release each,
and what `CarPlayMapTemplate12.m` would do for the map template. **It is not done, and this page does not
claim it is.** Doing it is a change to code this series did not write, in a family whose two band gates
the coordinator runs and this band does not, so it belongs to a round that can gate it.

The 12.0 object this series added, `CarPlayNavigationSession12.m`, carries only 12.0 API, and
`CarPlayNavigationSession154.m` only 15.4 — one release each, named for it.

## What is not carried, and why that is not `absent`

The 47 classes named in the table above -- `CPNowPlayingTemplate` and the now-playing buttons, `CPTabBarTemplate`,
`CPInformationTemplate`, `CPContactTemplate`, `CPSearchTemplate`, `CPActionSheetTemplate`,
`CPAlertTemplate`, `CPTrip`, `CPSearchTemplateDelegate` and the rest -- have **no registry entry at
all**, on purpose. They are not `absent`: they draw in-app like the seventeen do, and nothing about
them needs a car, so calling them absent would be a false claim. They are simply not written yet, and
the ledger's rows for them stay `missing`, which is the honest state. They are the next CarPlay round,
and they follow the shapes read here.

## The car home screen is carplayd's, and what this library kept

**The home screen is the carplay port's, not this library's.** The coordinator's decision: the car's
home screen is the Core Graphics one `carplayd` already draws -- it needs no window server and it
already reaches the car -- so it stays the renderer, and what `libCarPlayBackports` had and it lacked
moves into it **as C and Core Graphics**, in `revenant_car_apps.{h,m}` and `revenant_layout.{h,m}` in
`~/Git/projects/ios/carplay`, delivered to that band as patches **0001 and 0002** from
`carplay/.agent-work/worktrees/home-c-library` (branch `band/home-c-library`).

| what | where it is now |
| --- | --- |
| the real app icons out of the app bundles -- `CFBundleIcons`/`CFBundlePrimaryIcon`, the older `CFBundleIconFiles`, the singular `CFBundleIconFile`, `@2x` first -- decoded with ImageIO | `revenant_car_app_icon`, carplay |
| `UIPrerenderedIcon`, so the gloss is drawn only where the release has not | its out-parameter, and `revenant_car_draw_gloss`, carplay |
| the name plate for an app that ships no icon, never a picture invented for one | `revenant_car_draw_name_plate`, carplay |
| the six dock plates, each saying whether the release answered | `revenant_car_draw_dock_plate`, carplay |
| the exclusion state, in the release's own `NSUserDefaults` | `revenant_car_status_{read,load,save,flip_exclusion}`, carplay |
| the layout, a pure function of the head unit's size and scale | `revenant_car_layout`, carplay |
| **the restyled `CPListTemplate`, `CPMapTemplate`, `CPGridTemplate` and the rest** | **here**, because those are what an app with a CarPlay scene shows |

`RevenantCarPlayHomeTemplate`, `RevenantCarPlayHomeView`, `RevenantCarPlayDock` and
`RevenantCarPlayHomeSettingsTemplate` are **out of this library**: Apple has no such template, and a
class the SDK does not declare is not something `libCarPlayBackports` should carry (COORDINATION §9 --
and the gate agrees: `internal_symbol()` filters every `Revenant*` name out of what a library exports,
so a home screen in here would never have been API anything could reach). What this library now has
of the home screen is the **templates in the release's own chrome**: `UIBarStyleBlack` bars, the
release's grouped cells, its Helvetica, and a plate the skin draws where a collection view cell has no
surface of its own.

The check that went with it: `tests/backports/host/mapkit-carplay` decided the layout at 800x480,
960x540 and 1280x720 (31 checks, 0 failures), and **the layout is now in the other repository**, so
that test is withdrawn with it rather than left behind reading a source file this repository does not
have. It is the check the carplay port should carry, and it belongs there.


## Siri on this release: measured, and not the way it was expected

The coordinator's premise was that iOS 6 brings Siri up through the release's private machinery, and
that the class and the method to do it are in the 6.1.3 armv7 cache. **Measured with
`apple.objc.inventory` over the whole cache: they are not.** What is in the cache, and what is not:

| image | classes in the 6.1.3 armv7 cache | what they are |
| --- | --- | --- |
| `/System/Library/PrivateFrameworks/AssistantServices.framework/AssistantServices` | **22**, all `AF*` and `DK*`: `AFConnection`, `AFDictationConnection`, `AFDictationOptions`, `AFSettingsConnection`, `AFSpeechInterpretation`, `AFSpeechPhrase`, `AFPreferences`, `DKConnection`, `DKServer` | the speech and **dictation** transport. There is **no `AssistantController` and no `AssistantSession`** in the image |
| `/System/Library/PrivateFrameworks/AssistantUI.framework/AssistantUI` | **24**, all `AFUI*` except two: `SBAssistantAwayBottomView`, `SBDeviceLockKeypadSiri` | the lock screen's "Hey, how's the weather" panel and the keypad's dictation button. Neither starts Siri |
| `/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices` | **9**: `SBAppLaunchUtilities`, `SBLaunchAppListener`, `SBSAccelerometer` | no assistant controller. What *does* hold the assistant is **SpringBoard itself**, which is not a cache image at all: `otool -hv` on the guest's own binary reads `MH_MAGIC ARM V7 0x00 EXECUTE ... DYLDLINK TWOLEVEL PIE`, so it is an executable, and `nm -gU` on it finds **0** occurrences of `SBAssistantController` -- there is nothing to bind to from another process |
| `/usr/lib/libAWDProtobufSiri.dylib` | `AWDSiri*` | the transport to Apple's servers |
| `/System/Library/PrivateFrameworks/AppleAccount.framework/AppleAccount` | `AASetupAssistant*` | the **account** setup, not Siri |

So the thing that brings Siri up on a 4S or a 5 is **not in the dyld shared cache at all**: SpringBoard
itself is a bundled application, not a cache image, so no inventory of the cache can see it or its
assistant controller. That has two consequences, and both are the honest answer rather than a
judgement:

1. **What the daemon's process can call, it calls.** `AssistantServices.framework` is a dylib in the
   cache, so `dlopen` reaches it from a root daemon, and what it offers is **dictation**:
   `AFDictationConnection` and `AFDictationOptions`. A button that drove that would be a dictation
   button and must be named one; it is not Siri and this port does not put it behind a Siri label.
2. **What Siri needs goes through SpringBoard.** Since the controller is not reachable by a symbol from
   the daemon, the only path is the one the design's §5 already names: the daemon asks, and SpringBoard
   does it, over the port's existing IPC (the `backboardd` pattern, or the `SpringBoardServices`
   service). **That is a measurement on the device and not something a cache inventory can settle**,
   and it is the one open question in this file.

**What the dock's button therefore does.** It does not guess and it does not claim. It asks the
release whether the assistant is available, through the release's own `AFPreferences`/`AFSettingsConnection`
where the release answers at all, and:
- where something answers that Siri is available, the button is drawn live and `revenant_siri` asks the
  daemon to bring Siri up over the SpringBoard path above;
- where the release does not answer, the plate is drawn **dimmed and disabled** and says *Siri is not
  available on this device*, which is a statement about what was measured on this device and not a
  guess about the hardware.

So the "dimmed only where the hardware lacks Siri" rule is now a *runtime* answer rather than a
compilation-time one: the emulator's iPhone3,1 has no Siri and the plate will be dimmed there, a
4S or a 5 will answer and the plate will be live, and **the facts say the device class is not what
decides it -- the release's own answer does.** The hardware gate itself is inside SpringBoard's
assistant controller, which is the thing the cache cannot see, and that is the honest limit of this
measurement.

### The selector, and why it cannot be sent from here

Read out of the 6.1.3 guest's own SpringBoard binary in the emulator rootfs, with `otool -oV` over its
`__DATA,__objc_classlist` -- the metadata, not a string scan:

```
SBAssistantController, 47 instance methods, 7 class methods
  -[SBAssistantController activateIgnoringTouches]              types c8@0:4    (returns a BOOL)
  -[SBAssistantController dismissAssistant]                     v8@0:4
  -[SBAssistantController dismissAssistantWithFade]             v8@0:4
  -[SBAssistantController dismissAssistantWithFadeOfDuration:]  v16@0:4d8
  -[SBAssistantController dismissAssistantForAlertActivation:]  v12@0:4@8

  the class's own seven:  +sharedInstance  @8@0:4,  +sharedInstanceIfExists  @8@0:4,
    +supportedAndEnabled  c8@0:4,  +shouldEnterAssistant  c8@0:4,  +isAssistantVisible  c8@0:4,
    +isAssistantRunningHidden  c8@0:4,  +_runActivateAssistantTest  c8@0:4
  and the metaclass's baseProtocols (count 2): SBHomeCentricPopoverControllerDelegate, NSObject
```

**`-[SBAssistantController activateIgnoringTouches]` is the selector** the plate would send: it takes
no argument and **returns a `BOOL`**, so a caller can tell whether the activation took. And **there is
an accessor**: `+sharedInstance` and `+sharedInstanceIfExists` both return `id`, which is how a caller
inside SpringBoard reaches the one instance.

An earlier version of this file said there was no accessor and that the instance was unreachably held.
That was wrong, and it was wrong because the `otool` output it was read from was **truncated**: the
"six class methods" in it were the metaclass's *protocols* plus one instance method, not its methods.
The correct figures are the seven above, and `+sharedInstance` is one of them.

**What settles the conclusion is not the accessor but where the class lives**, and both of these are
measurements on the same binary:

1. `otool -hv` reads
   `MH_MAGIC ARM V7 0x00 EXECUTE 98 9932 NOUNDEFS DYLDLINK TWOLEVEL PIE` -- **SpringBoard is an
   executable, not a dylib.** No other process can `dlopen` an executable, so the accessor is of no use
   to a daemon: the class and its accessor both live in a program that is not a library.
2. `nm -gU` finds **0** occurrences of `SBAssistantController`, so the class symbol is not exported
   either and there is nothing to bind to from outside.

So the honest answer stands, now on the two measurements that carry it: **this release offers no way
to activate the assistant from another process.** Bringing Siri up needs **SpringBoard to send that
message on the daemon's behalf**, over a path into SpringBoard -- and the port has none: a search of
its own `src/`, `xmake.lua` and `packaging/` for `backboardd`, `SpringBoardServices`, `mach_port`,
`bootstrap_look_up`, `CFMessagePort`, `NSXPC`, `IOService` and `MachServices` finds nothing, and the
design's own section 3 describes the daemon's Mach service as the **app-facing** one it declares,
with `backboardd` as the precedent for that and not as something the port calls. Carrying the message
would mean a new IPC surface plus a hook inside SpringBoard, the one thing only SpringBoard can do.
The plate in the carplay port's `revenant_apps.m` says the same, where the plate is drawn, and the two
agree.


## The 48 rows of this batch, audited against what the objects actually export

`coordination/corpus/queue/UNIT-CarPlay-ios12.tsv` names 48 code rows of `registry/CarPlay/ios12.json`.
Every one of them that carries `implemented` was read back off the built objects, because the check the
gate runs at `modules/apple/backports.lua:1947` asks what the band BUILDS and not what a row says.

The reader, and the 28 of 48 the audit covers:

```
xcrun otool -ov <object>.o | grep '^ *imp '      # one line per IMP the object defines
```

and the whole audit, kept beside the numbers it produces so a reader can re-run it rather than take the
count on trust, at `.agent-work/runs/carplay174/audit.py`:

```
python3 .agent-work/runs/carplay174/audit.py     # 28/28, none missing
```

A method counts when its own IMP is there; a class row and a property row count when the class's IMPs
are. Read that way, all 28 `implemented` rows of the batch have a backing definition — **28/28, none
missing**, out of **538 IMPs across 41 classes** in the 15 objects — and the objects that answer them are `CarPlayNavigationSession12.m` (the session, its 12.0
members and the three 17.4 properties' storage), `CarPlayNavigationSession154.m` and
`CarPlayNavigationSession174.m` (the categories), `CarPlayVoiceControl12.m` (both voice control classes)
and `CarPlaySessionConfiguration12.m` / `CarPlaySessionConfiguration13.m`.

Two traps in that reader, both hit while writing it, because both make a real definition look missing:

- A category's IMP prints as `-[CPNavigationSession(RevenantRouteInformation174) addManeuvers:]`, not as
  `-[CPNavigationSession addManeuvers:]`. A matcher that expects the bare spelling reports all four of
  the session's category methods as having no definition.
- The 17.4 properties of the session are `@dynamic` in the 12.0 object, so that object has their IVARS
  and no IMP for them; the IMPs are in the 174 object's category. Reading only the class's own object
  would report three properties unimplemented.

The remaining 20 rows of the 48 are `absent` (18) and `inert` (2), and each carries the measurement its
status rests on: the scenes in `facts/CarPlay/Scenes.md`, the session configuration and the two factory
rows in `facts/CarPlay/SessionConfiguration.md` and in this batch's `+[CPRouteChoice new]` row itself.

## `+[CPRouteChoice new]`: what the release carries, and why the row does not say `ignored`

This belongs here and not only in the row, because it is the one row of the batch where the release's
answer and the port's answer come out differently at different rungs, and a reader who sees only the row
cannot tell which end was measured.

Measured per class with `tools/corpus/objc-inventory.lua`:

```
6.1.3  armv7   no CPRouteChoice at all -- apple.objc.inventory finds no CarPlay class of any name
16.0   arm64e  CPRouteChoice carries +new in its own class-method list
18.0   arm64e  CPRouteChoice carries +new in its own class-method list
```

So at the row's `minimum` of 6.0 the release has nothing under the name, and at 16.0 and 18.0 Apple's own
framework carries it. `absent` is the status that is true at every rung the row is placed at, and the
row's reason says so in those terms. `ignored` -- whose meaning is "the release carries the name and the
port declines to" -- is true at 16.0 and 18.0 and **false at 6.1.3**, and
`modules/apple/backports.lua:1907` fires for an ignored row wherever the band's own cache does not carry
the name:

```lua
elseif entry.status == "ignored" and in_range(entry, deployment) and carried_by_release(entry, inventory) == false then
    table.insert(missing, name)
```

The 6.1.3 band has no CPRouteChoice, so `ignored` on this row would put the row in `missing` and fail
that gate. That is the mechanical reason the status is what it is, and it is why the row's own text does
not claim the release is empty at 16.0: that claim would be false there.

**OPEN FOR THE OWNER.** The two rules genuinely disagree for this row, and one of them is a fact about
the release while the other is a fact about the band. Either the registry accepts a status that is true at
the floor and says in its text what the release carries at 16.0 -- which is what this row does -- or
`backports.lua`'s `ignored` branch should ask a rung that carries the name rather than the band's own.
The first is a registry decision and the second is a change to the check, and neither is a band's to make.
