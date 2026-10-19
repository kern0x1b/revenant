# UIBarButtonItemAppearance and UIBarButtonItemStateAppearance, iOS 13

Source: the host's own UIKit, under Mac Catalyst, held against the backport by the `appearances` group of
`tests/backports/host/uikit2/run.sh` (1500 random sequences of 16 changes on a button appearance, on its four states and
on the button appearances of a navigation bar and a toolbar appearance) and the scripted cases of
`tests/backports/device/appearances.m`; and the SDK headers.

## The states

`normal`, `highlighted`, `disabled` and `focused` are four objects the appearance keeps and answers as they are, so a
change through one is a change to the appearance. Each has a title text attribute dictionary, a title position
adjustment, a background image and a background image position adjustment. A state object cannot be made on its own.

What a state answers is what was set on it, or what it falls back to, or the default:

- **Attributes.** The default is the font of the style, 17 medium for a plain button and 17 semibold for a prominent one.
  What was set on the state is laid over it key by key. A state that has not set a colour or a font takes the ones of the
  state it falls back to, and only those two keys: a kern or a paragraph style set on the normal state is not passed
  on. `highlighted` and `disabled` fall back to `normal`, `focused` to `highlighted` and then `normal`.
- **The disabled colour.** A disabled state with no colour of its own takes the colour of the normal state made grey
  and faint: the grey is the luminance of the colour, weighted 0.2224, 0.7167 and 0.0606 in linear light, encoded back and
  held to 0.6 at most, and the alpha is 0.45 of the colour's. Set on 1, 0, 0 it gives 0.51 grey at 0.45, the number the host
  answers for red to two places; the weights are fitted to the host's answers for nine colours and are the one
  part of this that is not read out of the host.
- **Offsets.** The title offset and the background image offset fall back the same way and are zero by default.
- **Background image.** It does not fall back: a highlighted state has none until it sets one.
- **Setting.** A value that is what the state already answers is not stored, so setting zero on a state whose
  answer is zero changes nothing and setting it after a non-zero value keeps a zero. Nil clears an image and the
  attributes, and an empty dictionary clears the attributes.

## The appearance

`-init` is `-initWithStyle:` plain. Styles 0 and 7 are plain and 2 is prominent; every other value raises
`NSInternalInconsistencyException`, "Unsupported style: 1". `-configureWithDefaultForStyle:` takes the same styles and
clears everything the states hold. `-copy` and `-copyWithZone:` copy the states. The back button appearance of a
navigation bar appearance is a fifth style that only that class makes. Its own values come first, along the states as
above; then the plain button's: the attributes are the colour and font the plain button answers for the same state,
and the offsets and the background image are the ones the plain button has set on that same state, with no fall back
to its normal state.

`-description` is `<Class: 0x...> baseStyle=plain normal=(titleTextAttributes=default) highlighted=(...) ...`, printing
per state what was set: the attributes as `{(NSColor=...), (NSFont=...)}`, the title offset, the background image, and
the background offset only with an image. The back button adds its `backIndicator=` and `mask=`, and a `basedOn=` pointer.

Equality compares what is stored and treats a stored zero title offset as nothing; the archive is described in
`UIBarAppearanceValues.md`.

## What iOS 6 does with them

Nothing on their own: they are values. The bars apply them, see `BarAppearanceApplication.md`.
