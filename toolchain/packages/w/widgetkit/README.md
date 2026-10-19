# charon@widgetkit

The WidgetKit framework of iOS 14, as one Swift module a port writes `import WidgetKit` for, built
against the `charon@swift-runtime` a port carries.

    target("my-port")
        add_requires("charon@swift-runtime")
        add_requires("charon@appintents")
        add_requires("charon@activitykit")
        add_requires("charon@widgetkit")
        add_packages("swift-runtime", "appintents", "activitykit", "widgetkit")

## What the module is

`Timeline`, `TimelineEntry`, `TimelineProviderContext`, `TimelineEntryRelevance`, `TimelineReloadPolicy`,
`WidgetFamily`, `WidgetLocation`, `WidgetCenter`, `WidgetInfo`, `WidgetConfiguration` and the four
configurations, the four providers, `Widget`, `WidgetBody`, the relevance types, `WidgetTexture`,
`WidgetPushInfo`, `ControlCenter`, `ControlInfo`, the control providers, the Dynamic Island types,
`ActivityConfiguration`, `ActivityViewContext`, `AccessoryWidgetBackground` and the activity families.

## The seam: there is no widget host

A widget is drawn by the system's own widget host, on a surface of its own, from a timeline the system
asks the app's provider for. iOS 6.1.3 has no widget host, no widget daemon and no surface: there is
no Home Screen with a widget gallery, no Lock Screen widgets, no Control Center and no Dynamic Island.
So:

* a widget is **drawn in the app** - the module declares the configurations and the provider, and what
  draws is the app's own view, which is whatever the port has (including the SwiftUI it may already
  carry);
* `WidgetCenter.reloadTimelines(ofKind:)` and `reloadAllTimelines()` are the port's own redraw: they
  call the handler the app installs in `CharonWidgetRegistry.shared.redraw`, and nothing else;
* `currentConfigurations()` and `getCurrentConfigurations(_:)` answer with the configurations the app
  registered in `CharonWidgetRegistry`, which is where `WidgetInfo.widgetConfigurationIntent(of:)` reads
  the intent back from;
* `currentPushInfo` is `nil` unless a caller installs one, because only the system's host mints a push
  token for a widget;
* the Dynamic Island's four regions, their positions, margins, keyline tint and URL are real values the
  app stores and its own surface draws - there is simply no cutout to draw them around.

`facts/WidgetKit/Host.md`.

## What it needs from the port

`Widget`'s `body` is a `WidgetBody`, whose one requirement is the type the system draws. That is the
port's own view type: SwiftUI where the port has it, the port's own view where it does not. The
configurations and the providers are declared with the framework's own shape, so an app written against
either builds unchanged.

## Licence

MIT, the repository's.

## Building it on its own, and the one-at-a-time rule

`xmake` resolves these packages out of the shared `~/.xmake` store, and that store takes a
**machine-wide** lock per package: a second `xmake` that reaches the same package waits, and prints
`package(swift-runtime) is being accessed by other processes, please wait!` until the first is done.
So every `xmake` command that touches the store goes through `coordination/heavy.sh`, one at a time,
or it hangs:

    coordination/heavy.sh xmake f -c -y      # resolve
    coordination/heavy.sh xmake -y            # build

To build one of these Swift packages without a port, give `xmake` a project of its own, shaped as
the gate's `resolve()` shapes one (`coordination/build-gate.lua:44-48`):

    set_project("gate-tipkit")
    add_repositories("charon <path to a checkout>")
    add_addons("charon v0.8.13")             -- the newest version the checkout's recipe names
    set_config("apple_minimum", "6.1.3")
    includes("@addon/charon/apple-ios")
    set_defaultplat("iphoneos")
    set_defaultarchs("iphoneos|armv7")
    add_requires("charon@swift-runtime", {alias = "swift-runtime"})
    add_requires("charon@appintents", {alias = "appintents"})
    add_requires("charon@tipkit", {alias = "tipkit"})

A **fresh directory name per attempt** matters: xmake keeps a repository search index under
`~/.xmake/cache/quick_search`, and a directory name it has seen before is answered from that index
rather than from the checkout, so a stale entry makes a package that is present look absent. The
projects must be built through `heavy.sh` even to resolve, because resolution alone takes the lock.
