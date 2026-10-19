# The motion effects a view holds, iOS 7

Source: the host's own UIKit, asked case by case, and the run of
`tests/backports/host/uikit2/run.sh`, whose `motion` group holds the backport to the same answers.

A view starts with no effects, and `-motionEffects` answers a copy each time: the array a caller holds
never changes under it, and emptying the array a caller passed to `-setMotionEffects:` leaves the view's
own untouched.

`-addMotionEffect:` appends, and appends once: adding the same effect a second time leaves one. It is
identity that decides, not equality. Nil is ignored. An object that is not a `UIMotionEffect` is **not**
ignored - the system adds it like any other, and so does the backport; it is asked for its values only if
it answers `-keyPathsAndRelativeValuesForViewerOffset:`, which is where the release itself would raise.
`-setMotionEffects:` is the same rule applied to a whole array: it keeps the order, drops the second copy
of an effect already in the list, and keeps what is not an effect.

`-removeMotionEffect:` takes out the one effect that is that object and does nothing when the view does
not hold it. An effect is not owned by a view: added to two views, it is held by both.
