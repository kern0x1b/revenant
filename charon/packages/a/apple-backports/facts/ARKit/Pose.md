# Which half of the body's skeleton is carried, and which half is not

The body's joints and the body's pose are two different objects in this framework, and they are
measurable in two different ways. `ARSkeletonDefinition` is the first: it is a table, Apple's own
table, and it can be read out of a cache and then checked against a host that answers the same
questions. `ARSkeleton`, `ARSkeleton2D`, `ARSkeleton3D`, `ARBody2D` and `ARBodyAnchor` are the
second: they hold where a body *was*, and this tree has no body to have been anywhere.

What is carried: `ARSkeletonDefinition`, with the seventeen-joint two-dimensional table this
Mac's own ARKit answers (see the tables below and `tests/backports/host/arkit-skeleton`, which
compares name by name and parent by parent and requires the run to go red when either table is
changed).

What is not carried, and why:

* `ARSkeleton.definition`, `.jointCount`, `-[ARSkeleton isJointTracked:]`,
  `ARSkeleton2D.jointLandmarks`, `-[ARSkeleton2D landmarkForJointNamed:]`,
  `ARSkeleton3D.jointModelTransforms`, `.jointLocalTransforms`, and the two
  `-localTransformForJointName:` and `-modelTransformForJointName:` methods, `ARBody2D.skeleton`, `ARBodyAnchor.skeleton` and
  `.estimatedScaleFactor`. Every one of these is a value derived from an estimate of a body that
    was in front of a camera. There is no such estimate here: the port's tracker is visual-inertial
  and estimates a *device* pose (see `TrackerDifferential.md` for what it does measure), and
  nothing in this workspace turns a frame into a human body. The only honest answers available
    without one are zeros and empties, and a class whose every property reads zero is a fake that
    looks like a working one -- a caller cannot tell it from a body that was tracked and found to be
    perfectly still.

* `ARSkeletonDefinition.defaultBody3DSkeletonDefinition` and `.neutralBodySkeleton3D`, and with
    them the ninety-one `jointNames` that *were* measured. The names are known; the hierarchy behind
    them is not, because it is not in either image: `-[ARSkeletonDefinition
    initDefault3DSkeletonDefinition]` builds both arrays in a loop over a CoreIK rig, asking CoreIK
    for each joint's name and its parent's name, and the parent table is therefore a result rather
    than a constant. A definition with the right ninety-one names and no parents is not Apple's
    definition. These rows are **owed**, not implemented, and the cause is recorded next to them.

The line this draws is the one the rest of this repository draws: a value is carried when it was
measured from something real, and it is owed when there is nothing to measure it from. A joint name
is a constant Apple chose and printed; a body pose is an observation of a world this device is not
standing in.
