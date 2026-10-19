# UIWindowSceneActivationConfiguration, UIWindowSceneActivationRequestOptions and UIWindowSceneActivationAction, iOS 15.0

Introduced in iOS 15.0: the values a window scene activation is made from. An action (`UIWindowSceneActivationAction`, a `UIAction`) asks its
configuration provider what a new window opens with, and the configuration carries the user activity, the request options and a targeted
preview. The request options are a `UISceneActivationRequestOptions` with the presentation style a new window asks for.

The interaction that shows the new window from a pinch, `UIWindowSceneActivationInteraction`, is **not** here: it is still absent in
`registry/UIKit/ios15-16.json` and owed (see below).

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=15.0` on each class,
`-init` and `+new` marked unavailable on the configuration and the interaction).

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/windowscene-activation`, which compiles the
three port sources beside the host's classes in one process and prints the same checks for both.

## As UIKit does

- `-initWithUserActivity:` keeps the activity object it was given (the same object comes back); a nil activity is kept as nil.
- A configuration's `options` and `preview` start nil. Both are readwrite and stored as set.
- The runtime `-init` answers a configuration with a nil activity, nil options and nil preview.
- `UIWindowSceneActivationRequestOptions` is a `UISceneActivationRequestOptions`. Its `preferredPresentationStyle` starts at 0 (the automatic
  style) and is stored as set.
- `+actionWithIdentifier:alternateAction:configurationProvider:` makes a `UIWindowSceneActivationAction` whose `identifier` is the one given and
  whose `title` is `Open in New Window`; a title set afterwards is kept. The class inherits `+actionWithHandler:` from `UIAction`.

## What the port does

- `UIKit/UIWindowSceneActivationConfiguration.m`: `-initWithUserActivity:` is the constructor, through `self = [super init]`, which the init
  family allows. The runtime `init` answers the empty state through the ivars' zero values.
- `UIKit/UIWindowSceneActivationRequestOptions.m`: a stored `preferredPresentationStyle`.
- `UIKit/UIWindowSceneActivationAction.m`: the factory makes the action with `+actionWithTitle:image:identifier:handler:` (so the identifier and
  the title are `UIAction`'s own), and the handler it passes captures the configuration provider and the alternate action. Nothing else is
  stored: the action keeps no ivars, and the host exposes neither the provider nor the alternate action publicly.
- The tap. The handler asks the configuration provider for the configuration, and asks the application for a scene with its activity and options
  (`requestSceneSessionActivation:userActivity:options:errorHandler:`, with a nil session). The port has one scene and refuses any other with
  `UISceneErrorDomain` code 0 (`facts/UIKit/UIScene.md`); the refusal runs the alternate action with the action as sender. With no alternate
  action the refusal has nowhere to go, and nothing else happens.

## A named difference, not a divergence

- **The title is English in every language.** The host answers `Open in New Window` under an English locale, and the system's own string is
  localized. The port carries the English text, since iOS 6 has no such string table for the action; another locale's title would need its own
  text, which is not carried.

## What is not measured on the host

- The tap path (provider, request, refusal, alternate action) is **not** exercised by the differential: a plain Mac Catalyst tool has no scene
  to ask, and the host would open a second window where the release refuses one. The claim above is the port's documented behaviour, read
  from `UIApplication+Scenes.m`, not a host measurement.

## Owed: the interaction

- `UIWindowSceneActivationInteraction` (`initWithConfigurationProvider:errorHandler:`) stays absent. It is a `UIInteraction` that opens a view's
  content in a new window on a pinch. Building it needs a pinch recogniser on the view, the configuration provider called at the pinch point,
  and the error handler called on the refusal, which is the one new piece of behaviour: the release refuses every second scene with the code above,
  so the handler is always called with that error. It is owed, not impossible: the view's pinch and the handler are real work for a later band.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The value classes are plain Objective-C state, so the host run is
  their oracle; the tap path is not measured on any target.
