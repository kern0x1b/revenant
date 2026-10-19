# The profiles, elements and motion of a controller, iOS 7.0 to 14.0

`GCController` gives an application a profile of buttons, direction pads and triggers to read, and handlers to be told
when one changes. On a release with a device this is what a controller that is attached reports. iOS 6 has no such device, but a
profile does not need one: from iOS 13 an application makes a controller of software with `+controllerWithExtendedGamepad`
or `+controllerWithMicroGamepad` and sets the values of its elements itself. The elements, the profiles and the motion are
carried whole for that, and a controller of software is the only controller there is.

## What was held to the host

The host's GameController makes the same controllers, and the port is compared with it, over the events that a random
sequence of 4000 values makes to the buttons, the axes and the direction pads, the copy of a state, the capture and the motion, by
`tests/backports/host/gamecontroller`: 8576 lines, and none differs. What it settles:

- The elements of an extended gamepad are 40 with the four that the paddles and back buttons add, and each is listed under every one of its aliases;
  a micro gamepad has 10. The localized name, the SF Symbols name, the analog flag, the collection and the system gesture flags are those the host has.
- A button holds a value between 0 and 1, and is pressed and touched above 1/512. Its handlers are called on the handler queue of the
  controller (the main queue to begin with, and one that is set), asynchronously, with the handlers the button had when the value was set: the value handler, then
  the touched handler when touched changed, then the pressed handler when pressed changed. A value that clamps to what the button held changes nothing.
- An axis holds a value between -1 and 1; its handler is given the value as it was set, and an axis set to a value that clamps to what it held is not called again unless the value
  set differs from it. The buttons of its two directions are told first, the negative one and then the positive one, then the axis, then the direction pad,
  which is given the two values held at that moment. `-setValueForXAxis:yAxis:` sets the x axis and then the y axis.
- The button of a direction that follows an axis reads its value from the axis and is pressed when that is above 0, and touched above 1/512; the value it hands to a handler is rounded to a multiple of 2^-25
  (positive) or 2^-24 (negative), and a change that rounds to the value it held is not told. Setting such a button by hand tells its handlers and changes what it holds for them, not what it reads.
- `-setStateFromExtendedGamepad:` and `-setStateFromMicroGamepad:` set the direction pads, in the order the host has them, and then the buttons, in the order the host has them.
  `-capture` makes a profile of the same class with the state copied and no controller.
- Setting a localized name to nil restores the default, the SF Symbols name is kept as set, and setting the unmapped SF Symbols name sets both.
- The profile's own value handler and the value change handler of a profile are never called: no device sends events, and the host does not call them for a
  controller of software either.
- A controller of software is a snapshot and not attached; its vendor and product category are ExtendedGamepad and MFi, or MicroGamepad and Siri Remote; its player index starts at
  `GCControllerPlayerIndex1`; `gamepad` and `microGamepad` answer the extended profile as well, as they do on the host; the battery, the light and the haptics are nil.
- A motion starts with the gravity at (0, 0, -1) and the rest at 0; its setters call nothing, and `-setStateFromMotion:` copies the vectors and calls the handler once on the handler queue.
  The sensors of a motion are always active, and only a micro gamepad's and a captured controller's motion has an attitude and a rotation rate.

## What is absent

The snapshots and the functions that make them from data, the profiles of the DualShock, Xbox and DualSense devices, the touchpad, the light, the battery, the haptics, the
virtual controller and the physical input protocols of iOS 16: each needs a device or the framework's own service, and none is made here. `saveSnapshot` is absent for
the same reason. The rows are in `registry/GameController/absent_GameController.json`.

Source: the host's GameController, with the header of iOS 16.4 for the declarations.
