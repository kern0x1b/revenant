# UIAccessibilityAdditions — the twenty-seven rows, and what they really were

The header's own name is about accessibility; what it declares is the view and colour additions of
iOS 7 to 13. Read the registry first and then the build, and the twenty-seven rows are not what the
corpus's `none` column said.

## What was already there, and how I found out

**Nine of the twenty-seven were already built and already registered**: the semantic system colours
`systemRedColor` through `systemGrayColor`, in the tree's own `UIColor+SystemColors.m`. Five more
were built and registered elsewhere: `performWithoutAnimation:`, both spellings of
`userInterfaceLayoutDirectionForSemanticContentAttribute:`, the spring animation and `focused`.

The corpus calls them missing because the measurement asked the wrong question. It looked for a
selector **on the class it named**, and a category's class methods are not on the class's own row in
the inventory — the same trap this file's neighbours record for instance methods. Asking the whole
inventory file instead of one class's row is what found them, and asking the registry first is what
kept me from re-implementing any of them. Both orderings mattered and both were wrong at first.

## The values, measured

Every value in this family was read out of the host's own UIKit through the library's own symbol,
never typed from the HIG, and `tests/backports/host/uikitadditions` holds the backport to it:

- the semantic colours as 8-bit components: red 255,56,60; orange 255,141,40; yellow 255,204,0;
  green 52,199,89; pink 255,45,85; purple 203,48,224; blue 0,136,255; gray 142,142,147;
- `inheritedAnimationDuration` 0, and `canBecomeFocused` and `focused` both no;
- a semantic content attribute means `rightToLeft` only when it is the one that forces it, and
  `leftToRight` otherwise, in both spellings;
- a colour by a name that is not in the catalogue is **nil**, as is an empty name.

## Display-P3, and the one number that does not match to the fourth decimal

`initWithDisplayP3Red:green:blue:alpha:` and `colorWithDisplayP3Red:green:blue:alpha:` convert the
components to the sRGB this device's display shows, through Core Graphics' own matrix. The first
matrix I wrote from memory was wrong by **0.07** — the differential caught it — and the corrected
one lands within **0.0001** of the host: display-P3 (0.5, 0.25, 0.75, 0.8) comes out 0.5378, 0.2321,
0.7771 against the host's 0.7770, and **137,59,198,204 in 8 bits on both**.

The differential therefore compares the 8-bit components and not the fractions, and that is the whole
of the reason: this device's display is eight bits per channel and 0.0001 is under a third of one
step, so the fractions are not an answer an application can see and asserting them would be a test
that fails on a difference the hardware cannot express. The difference is recorded here rather than
hidden by the choice.

## Keyframe animation is the release's own animation, deferred

A keyframe's block takes **no time**: the release's animation system defers each one and interpolates
between its start and its duration. So the port does exactly that and nothing more — it collects the
keyframes while the block runs, and runs each with `+animateWithDuration:delay:options:...` at the
delay its own start says and for the length its own duration says, both relative to the whole, with
the completion when the whole has passed. The interpolation between the values a block sets is then
the release's own interpolation, not a reimplementation of it.

## The two seams, stated

- **A system's named animation is the system's.** A shake or a wipe is a set of effects this release
  does not have and no public mechanism provides one. `performSystemAnimation:onViews:...` runs the
  caller's own animations on the views they named and calls the completion; the named effect itself
  is what the port cannot reproduce, and the registry entry says so in the same words.
- **The three attributed-string accessibility questions are asked by an assistive technology that
  this release does not have.** `pickerView:accessibilityAttributedLabelForComponent:`, its hint, and
  `accessibilityAttributedScrollStatusForScrollView:` are `@optional` methods of delegate protocols
  — there are no accessors for them on the picker or the scroll view, and the plain-string forms
  beside them arrived in the same release. I wrote accessors for them, found on checking the header
  that **no such API exists**, and deleted them: inventing a method no header declares is the R4 trap
  in reverse. They are carried as the protocols the header declares, and nothing on this release asks
  them — the same seam as the accessibility rotor, and for the same reason.

## References

The layout-direction questions, the focus answers and the animation timing are the port's own, from
the measured host answers above. **Chameleon (BSD)** and **WinObjC (MIT)** were consulted for the
UIKit behaviour these rows describe — the semantic content attribute's mapping to a layout direction,
the focus and safe-area hooks on a view, and the keyframe and spring animation shapes — and neither
carries a value this port invents: the values above are the host's, and the behaviour is built on the
release's own animation.
