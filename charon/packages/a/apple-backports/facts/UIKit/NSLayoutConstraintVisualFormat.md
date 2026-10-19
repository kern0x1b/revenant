# The spacing options of a visual format, iOS 11.0

iOS 11 gave the visual format language a second kind of spacing. Between two
views with text, `V:[a]-[b]` can mean the distance from one baseline to the
next rather than from one edge to the next, and which of the two is meant comes
in the options of
`+[NSLayoutConstraint constraintsWithVisualFormat:options:metrics:views:]`:
`NSLayoutFormatSpacingEdgeToEdge`, which is zero and the default, and
`NSLayoutFormatSpacingBaselineToBaseline`, which is `1 << 19`.
`NSLayoutFormatSpacingMask` is the same bit, for reading an option set back.

Source: the SDK's own enumeration for the values (`NSLayoutConstraint.h`), and
a run on an iPhone 4S (iPhone4,1, 6.1.3, armv7) for what this release does with
them, inside the device tweak of `tests/backports/device/safearea-tweak.m`.

## What this release does with the bit

Nothing, and it says nothing. The same format was parsed twice on the device,
once with no options and once with `1 << 19`:

- no exception is raised - the parser does not check the bits it does not know;
- the same number of constraints comes back;
- the constraint is the same one: the same constant, 8, and the same pair of
  attributes, bottom to top.

So an application that asks for baseline to baseline spacing is laid out edge
to edge, which is what it would have got had it not asked. That is the whole
of the difference, and it is the release's, not the port's: the call never
passes through the backports at all, which is why the registry answers
`ignored` for it and why the entry belongs to the method rather than to the
option - the option is a case of an enumeration, and the compiler writes its
value straight into the application.

`NSLayoutFormatSpacingEdgeToEdge` is zero, so passing it changes nothing on any
release, including this one.
