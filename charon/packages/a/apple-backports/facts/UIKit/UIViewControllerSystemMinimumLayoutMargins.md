# The system minimum layout margins, iOS 11.0

Introduced in iOS 11.0: the margins the system insists a controller's view keeps
at least, and the switch that lets a controller ignore them.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`-[UIViewController systemMinimumLayoutMargins]` at `0x18a329698`,
`-_minimumLayoutMarginsForView` at `0x18a30eea8`,
`-viewRespectsSystemMinimumLayoutMargins` at `0x18a30ee90`).

## What iOS 11 does

`systemMinimumLayoutMargins` is a field the system fills in from the device and
the width of the screen — sixteen or twenty points at the sides on a phone.
`-_minimumLayoutMarginsForView` reads it when
`viewRespectsSystemMinimumLayoutMargins` is on, and answers zeroes when it is
off. The flag itself is a bit of the controller's flags word and starts on.

## Why the port carries neither

iOS 6 has no system minimum at all: the layout margins of a view are eight
points on every side and nothing insists on more. So there is no value here to
read, only a value to invent.

Zero would be the tempting answer, and it is the wrong one: a caller reading
`systemMinimumLayoutMargins` is asking what the system demands, and answering
zero says the system demands nothing — a statement about a mechanism the
release does not have. Sixteen would be worse still: a number taken from
another release and handed over as this one's.

The rule the port follows is that a value is carried where the release's own
behaviour produces it. The safe area is carried because iOS 6 really has the
bars it is measured from; the system minimum is not, because iOS 6 produces
nothing to measure. Both members are `absent`, and `respondsToSelector:`
answers honestly.
