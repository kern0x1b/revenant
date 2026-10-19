# UITabBarItemAppearance and UITabBarItemStateAppearance, iOS 13

Source: the host's own UIKit, under Mac Catalyst, held against the backport by the `appearances` group of
`tests/backports/host/uikit2/run.sh` (1500 random sequences of 16 changes on a tab item appearance, and on the three
item appearances of a tab bar appearance) and the scripted cases of `tests/backports/device/appearances.m`; and the SDK
headers.

## The states

`normal`, `selected`, `disabled` and `focused` are four objects the appearance keeps and answers as they are. Each has
title text attributes, a title offset, an icon colour, a badge offset, a badge background colour, badge text attributes
and a badge title offset. What a state answers is what was set on it, or what it falls back to, or the default:

- **Title attributes.** The default is the font of the style and, for the selected state, its semibold. `disabled` and
  `focused` take the colour and the font set on `normal`; `selected` takes the font only, since a selected tab is drawn in the
  tint, and takes no colour. Other keys, a kern, are never passed on.
- **Badge text attributes.** White and a font by style, and every state takes the colour and font set on `normal`.
- **Offsets.** The title, badge and badge title offsets are zero and every state falls back to `normal`.
- **Icon colour.** nil. `disabled` and `focused` take the colour of `normal`; `selected` does not.
- **Badge background.** The red of the light appearance, 255, 56, 60, or 255, 59, 48 for the carplay and tv styles; every
  state takes the one set on `normal`. Setting nil brings the default back.
- **Setting.** A value that is what the state already answers is not stored; nil clears.

| style | title | badge text |
|---|---|---|
| 0 stacked | 10 medium, selected 10 semibold | 13 regular |
| 1 inline | 13 regular, selected 13 semibold | 13 regular |
| 2 compact inline | 12 regular, selected 12 semibold | 10 medium |
| 3 carplay | none, the attributes answer nil | 10 regular |
| 4 tv | none, the attributes answer nil | 28 regular |

Any other style raises `NSInternalInconsistencyException`, "Unsupported style 5" (no colon here, and one in the button
appearance). `-configureWithDefaultForStyle:` takes the same styles and clears the states. Copying, equality, the
description and the archive are as for the button appearance and in `UIBarAppearanceValues.md`; the description of a state
always prints the icon colour, the badge background and the badge text attributes, and the offsets only when set.

## What iOS 6 does with them

The tab bar applies the stacked appearance, see `BarAppearanceApplication.md`.
