# The colour, the event view controller and the classes of the devices, iOS 9.0 to 14.5

`GCColor` (iOS 14.0) is three floats, the colour of a controller's light. `GCEventViewController` (iOS 9.0) is a view
controller with one switch, `controllerUserInteractionEnabled`, that says whether the events of a game controller also flow through
the responder chain. Both need no device and are carried whole: the colour keeps what it is given without clamping, copies to a new object, describes itself
as `<GCColor r=0.250000 g=0.500000 b=0.750000>` and encodes its three floats under the keys `red`, `green` and `blue` with secure coding; the
view controller starts with the switch off, as the header says, and keeps it as set.

The classes of the devices - the Xbox, DualShock and DualSense profiles, the touchpad, the battery, the light, the haptics, the keyboard and mouse
inputs, the cursor, the DualSense adaptive trigger and the directional gamepad - are carried for what names them: an application that refers to one loads, and a check for it
with `isKindOfClass:` answers NO. iOS 6 attaches none of these devices, so no object of any of them is made and their members are absent, each row in
`registry/GameController/absent_GameController.json`.

Source: the host's GameController for the colour (its description, its keys and its copy) and the header of iOS 16.4 for the rest.
