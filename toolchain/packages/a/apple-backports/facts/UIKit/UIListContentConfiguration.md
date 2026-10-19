# UIListContentConfiguration and its text and image properties, iOS 14.0

A value that says what a row shows: text, secondary text (plain or attributed), an image, and how each is set. Twelve style factories (cell, subtitle, value, three sidebars, headers and footers of plain and grouped lists, accompanied sidebars) and a bare `init`.

## What the port does as UIKit does
- Every default of every factory (fonts, colours, paddings, margins, side by side), measured.
- `updatedConfigurationForState:` follows the host: sidebar styles take the medium font, a focused row white text, a highlighted row 30% transformers, a faded one alpha 0.5, a disabled one tertiary and quaternary colours. What the application set - a font, a colour, a transformer, a tint - is kept when the state changes; alpha is multiplicative.
- Equality, copy, coding by the port's own keys and the description as the host prints it. Blocks are not archived.
- `UIListContentImageStandardDimension` is -CGFLOAT_MAX, as the header has it.

## Differences
- Font sizes and colours are read from the host's values, not from Dynamic Type; `adjustsFontForContentSizeCategory` is kept and does nothing on this release.
- `showsExpansionTextWhenTruncated` is iOS 15 and `@dynamic`.

## What the host measures that a phone would not

The host is Catalyst, so its metrics are those of the Mac idiom: row margins {15,16,15,8}, a plain row estimate of 40.04 (44 x 0.91), a sidebar inset of 12.987 (10 / 0.77), a corner radius of 26 for grouped and sidebar lists, some Mac colours. The port follows the host's raw values, except the row estimate of a list layout, which is 44, the phone's. Nothing here was measured on an iPhone; `Dynamic Light Alpha` was 0.12 in light and 0.4 in dark, and the port carries 0.12, since this release has no dark mode.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured with random values and states side by side with the port in one process, and the header of SDK 16.4. The differential tests are `tests/backports/host/uikit2` (the `listvalues` group for values, the windowed `listcell` group for views); the device application is `tests/backports/device/lists.m`, held to the numbers the host recorded in `lists-expectations.h`.

## `showsExpansionTextWhenTruncated`

`UIListContentTextProperties.showsExpansionTextWhenTruncated` is NO by default, keeps the value set, and a copy keeps it; it is also
archived with the other text properties. It has no registry row. Only the value is carried: a truncated label does not show expansion
text in this port. Measured by `tests/backports/host/storage-config`.

## On iOS 6

The sidebar header's default text is the host's route: the body text style at the medium weight, built from the body font's descriptor with the weight trait (`charon_medium_body_font` in `UIKit/CharonLists.m`). On the host that gives the style's line spacing, half a point more than a plain medium system font's, which measured half a point short in every content view of that style.

On the release there is no medium face and no style leading, and the port has neither to add. Measured on an iPad 2 (6.1.3) through the port's own `+[UIListContentConfiguration sidebarHeaderConfiguration]`: its text font is `Helvetica` at 17 points with a line height of 21, exactly what `[UIFont systemFontOfSize:17]`, the body style's font (`UIFontTextStyles.md`) and `systemFontOfSize:weight:` at `UIFontWeightMedium` give; CoreText, handed the regular face's descriptor with the weight trait 0.23, returns `Helvetica` again (only bold resolves, to `Helvetica-Bold`), so the descriptor route neither fails nor falls back to `systemFontOfSize:`. On iOS 6 the header's font is therefore the release's regular 17-point system font, as it was before this route, and the content size category it follows on the host is the one category iOS 6 has. `tests/backports/device/lists.m` holds the equality.

The medium weight the sidebar takes for a selected row is the release's system font: the weight backport of `UIFont` maps every weight up to medium to the regular font, so a selected sidebar row is not different in its font, only in its colours and transformers when focused or highlighted.
