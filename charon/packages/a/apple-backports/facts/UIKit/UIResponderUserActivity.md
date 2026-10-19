# UIResponder and its activity, iOS 8

Introduced in iOS 8: a responder holds the `NSUserActivity` that describes what it shows, is asked to update it with
`-updateUserActivityState:` before the system hands it over, and is asked to restore from one with
`-restoreUserActivityState:` when one arrives.

Source: the host's own UIKit, asked for a view controller and a view: with no application running, setting an activity
keeps it, reading it back answers the same object, `nil` clears it, and the two messages can be called and do nothing.

## What the port does

`userActivity` keeps the activity it was given for any responder, and the two messages are there so that an override
that calls `super` does not fail. Nothing calls them, since iOS 6 has no Handoff: an activity set on a responder is
kept and never advertised, so the property, and both messages, are `inert`. The system also makes a responder that
overrides these adopt the protocol `UIUserActivityRestoring`, which is a header-only protocol and is not adopted by
the port's responders. The application delegate's messages for a continued activity are never sent.
