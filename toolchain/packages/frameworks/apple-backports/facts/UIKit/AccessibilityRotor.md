# The accessibility rotor

A rotor is a named search an assistive technology walks through an application: a name it is
described by, and a block that, given a predicate saying where the search is and which way it goes,
answers the next element the rotor should stop on. Any object exposes them, through
`accessibilityCustomRotors`, because the technology looks on the element and its ancestors.

## The seam, stated plainly

**The release's VoiceOver has no rotor at all, so nothing on iOS 6.1.3 ever asks a rotor for its next
item and no search block in this file is ever run by the system.** That is the wall the push allows a
documented refusal at, and it is a wall, not a difficulty: there is no rotor API on the release to
call and no gesture or key command that reaches one.

The API surface is built anyway and in full, which is what the brief asks for at a seam: the three
classes exist, hold what they are given and answer for it, and the whole class is here including the
four members that arrived in iOS 11. Those four were registered `absent` by an earlier band with the
reason "this release's VoiceOver never asks the question the member answers" — which is true of
every member here, including the thirteen that were already undecided, so it was a reason that could
never decide anything. Their entries have moved from `registry/UIKit/ios11.json` to
`registry/UIKit/accessibilityrotor.json` as `implemented`; that is a change to another band's entries
and the coordinator should know about it.

## What each object answers, measured

`tests/backports/host/uikitconst` records the host's own UIKit for all of it and the device is held
to the same answers. Two of the measurements changed this implementation:

- **The two names move in both directions and neither is dropped.** Setting `name` on a rotor made
  with a plain name leaves an `attributedName` describing the same rotor, and setting
  `attributedName` sets `name`. The first version here cleared `attributedName` when `name` was set,
  which the host answers against: after `setName:@"Headings"` its `attributedName.string` is
  `Headings`, and setting the attributed one keeps the style of the plain one. The port now moves the
  string across and keeps the attributes.
- **A predicate made by hand searches backwards.** `UIAccessibilityCustomRotorDirectionPrevious` is
  the *first* case of the enum, so a zeroed predicate is Previous, not Next. The case is recorded by
  name in both directions so this cannot be misread.

A result holds its target element **weakly**, as the header says: a result is a place in an element,
not a claim on it, and a text view that goes away takes its results with it.
