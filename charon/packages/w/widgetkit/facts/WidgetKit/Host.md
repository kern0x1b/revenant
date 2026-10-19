# The seam: there is no widget host

A widget is a view the system draws on a surface of its own. The system owns three things here and none
of them is on a release this port builds for:

* **the host** - the process and the surface that draws widgets: a Home Screen gallery, the Lock Screen,
  the Control Center, the Dynamic Island. iOS 6.1.3 has no widget host of any kind;
* **the daemon** - the widget agent that keeps the installed widgets, hands out push tokens and asks
  for timelines to be redrawn. There is no such image in the 6.1.3 dyld cache ladder;
* **the gallery** - the system's own place where a widget is added, previewed and configured, and the
  `WidgetConfigurationIntent` the system runs to ask the owner to configure a widget.

What the module does about it:

| the framework's call | this module's answer |
| --- | --- |
| the system draws the widget | the app's own surface draws it. `Widget.Body` is the port's view type, and the configuration's `body` is what the app's surface shows |
| `WidgetCenter.reloadTimelines(ofKind:)` / `reloadAllTimelines()` | the port's own redraw: `CharonWidgetRegistry.shared.redraw(kind)` and `.redrawControl(kind)`, the handlers the app installs for its in-app widget and control surfaces |
| `WidgetCenter.currentConfigurations()` / `getCurrentConfigurations(_:)` | the configurations the app registered in `CharonWidgetRegistry`, in the order it registered them; `WidgetInfo.widgetConfigurationIntent(of:)` reads the intent back out of the same record |
| `WidgetCenter.invalidateConfigurationRecommendations()` / `invalidateRelevance(ofKind:)` | the registry forgets what it cached, which is what the system does; with nothing cached it is a no-op that changes nothing |
| `WidgetCenter.currentPushInfo` | `nil` until a caller installs a token, because only the system's host mints one for a widget |
| the recommendations the system shows for a widget it does not have | `AppIntentRecommendation` and `IntentRecommendation` are the app's own values, offered to the app's own surface |
| the Dynamic Island | the four regions, their positions, their margins, the keyline tint and the URL are real stored values; there is no cutout on these devices to draw them around |
| `AccessoryWidgetBackground`, `ControlWidgetButton`, `ControlWidgetToggle` and their labels | declared with the framework's own shape; what draws is the app's own view, and the accessory background's `body` stops with a message rather than pretending to be a view |

What is the app's own and is real: the timeline, its entries, the reload policy, the relevance, the
provider context (family, preview flag, size, variants), the configurations with their kinds, intents and
providers, the recommendations, and every value the control and activity types hold.
