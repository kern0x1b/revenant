# Dynamic colours and the system colours of iOS 13

Introduced in iOS 13: `+colorWithDynamicProvider:`, `-resolvedColorWithTraitCollection:` and the semantic colours - the labels, the
separators, the backgrounds, the fills, the grays 2 to 6 and the two new tints.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), for how a dynamic colour behaves and for the palette where the host
shares it with iOS, held against the backport by the `colors13` group of `tests/backports/host/uikit2`; the values that are the
iPhone's own are from Apple's published table of the iOS 13 system colours (Human Interface Guidelines, Color), which is public
documentation and not code.

## The palette

**Rule: each system colour takes the values of the newest release of the ladder it was measured on (now 18.0).**

The values are in `charon_rows` of `UIKit/UIColorDynamic.m`, light, dark, light with high contrast, dark with high contrast, dark
elevated and dark elevated with high contrast; a variant the release does not give is the base one. The nine colours of iOS 7-9
(`UIColor+SystemColors.m`, `UIColor+SystemPurpleColor.m`) are rows of the same table since this rule, and dynamic like the others.

How 18.0 was read (tools and logs in `.agent-work/plan-and-analysis/b1314-flips/` of the band's checkout):

- **Built by code** in UIKitCore of the ladder's 18.0 cache (`~/.charon/dyld/18.0`): each getter's once-block, or the builder it
  calls, makes one colour per combination of traits with `colorWithRed:green:blue:alpha:` or `colorWithWhite:alpha:`, from doubles in
  UIKitCore's constants. Disassembled and read by `imp.lua`, `once.py`, `readmany.lua` and `colors2.py` (output `imp18/literal-fresh.txt`);
  the trait call's arguments give the variant (style 0 or 2, contrast 0 or 1, level 0 or 1 for elevated).
- **Named**: 18.0 no longer builds the tints and the labels in code; the getter asks for a colour by its own name, and the values are
  in CoreUI's catalogues `DesignLibrary-iOS.bundle/iOSRepositories/{LightStandard,DarkStandard,LightIncreasedContrast,DarkIncreasedContrast}.car`
  of the 18.0 root filesystem (iPhone11,2, build 22A3354, `xmake firmware --device=iPhone11,2 rootfs 18.0`), read by `carcolors.py`
  from the catalogue's COLORS tree: 8-bit components, so an alpha is a byte over 255 (the tertiary label's 0.3 is 76/255 there, and the
  port now answers 76/255). Control of the method: the same read of 16.0's catalogues gives, for cyan, mint and indigo, the values
  16.0's code builds, in all four variants.

| colour | rung | how |
| --- | --- | --- |
| `labelColor`, `secondaryLabelColor`, `tertiaryLabelColor`, `quaternaryLabelColor` | 18.0 | named |
| `placeholderTextColor` | **not measured** | 18.0 asks for it by name, and no catalogue of CoreUI holds that name; the port keeps the iOS 13 table's tertiary label values |
| `linkColor`, `separatorColor`, `opaqueSeparatorColor` | 18.0 | code |
| the six backgrounds (plain and grouped) | 18.0 | code |
| the four fills | 18.0 | code |
| `systemGray2Color` to `systemGray6Color` | 18.0 | code |
| `systemBrownColor`, `systemIndigoColor`, `systemCyanColor`, `systemMintColor` | 18.0 | named |
| `systemRedColor`, `systemGreenColor`, `systemBlueColor`, `systemOrangeColor`, `systemYellowColor`, `systemPinkColor`, `systemTealColor`, `systemGrayColor`, `systemPurpleColor` | 18.0 | named |

What the rule changed against the port's earlier values:

- the labels: their alphas are the catalogue's bytes (76/255 for 0.3, 45/255 and 40/255 for 0.18 and 0.16) and they have high-contrast
  values: secondary (60, 60, 67) at 204/255 and (235, 235, 245) at 178/255, tertiary at 178/255 and 140/255, quaternary at 140/255 and
  102/255;
- `separatorColor` with high contrast: (60, 60, 67) at 0.37 and (84, 84, 88) at 0.68;
- the backgrounds with high contrast, and dark elevated with high contrast, which the row had no place for before: secondary
  (235, 235, 240) light, (36, 36, 38) dark, (54, 54, 56) elevated; tertiary (54, 54, 56) dark and (68, 68, 70) elevated; grouped
  (235, 235, 240) light and (36, 36, 38) elevated; secondary grouped (36, 36, 38) dark and (54, 54, 56) elevated; tertiary grouped
  (235, 235, 240), (54, 54, 56) and (68, 68, 70); plain (36, 36, 38) elevated;
- brown and indigo with high contrast: (127, 101, 69) and (181, 148, 105); (54, 52, 163) and (125, 122, 255);
- the iOS 7-9 tints, which were the fixed values of 12.0 (`UIColorSystemColors.md`): now dynamic, with their dark and high-contrast
  values; green moved from (76, 217, 100) to (52, 199, 89), teal from (90, 200, 250) to (48, 176, 199), purple from (88, 86, 214) - the
  value iOS 13 gave to indigo - to (175, 82, 222); red, blue, orange, yellow, pink and gray keep their light value.

Unchanged by 18.0: link, opaque separator, the fills, the grays 2 to 6, cyan and mint.

## Dynamic colours

A dynamic colour is made with a provider, asked for the traits it is to answer for. The host does not ask at creation; the port must,
since it draws the colour by its light value, so it asks once with the current collection and then again for each
`-resolvedColorWithTraitCollection:` - a colour the provider returns that is dynamic is resolved again, and one that is not is the
answer. A colour that is not dynamic resolves to itself, as the host's do. Two colours made from one provider are two colours, and a
colour of the same components made with `colorWithRed:...` is not dynamic.

**What differs.** A dynamic colour is a colour of the release with the provider kept beside it, so everything that reads it - a view's
background, a label's text, `CGColor`, `getRed:...` - reads its value for the collection current when it was made, the light one, and
does not follow a collection that is made current later. `-colorWithAlphaComponent:` of a dynamic colour is a colour of the light
value with that alpha and is not dynamic, where the host keeps it dynamic. Equality is the release's, by components.

The named colours are made once, each a dynamic colour of its table, so the same object answers every call.

## `systemCyanColor` and `systemMintColor`, iOS 15.0

Two more rows of the same table (`UIKit/UIColorDynamic.m`), dynamic as the others. The values were **read from the 16.0 cache**, not
from a published table: `+[UIColor systemCyanColor]` and `+systemMintColor` of UIKitCore each build their colour once, in a block that
calls `colorWithRed:green:blue:alpha:` for each combination of interface style and contrast, and the components are doubles loaded from
UIKitCore's constants. The block was disassembled and the doubles read from the cache
(`.agent-work/plan-and-analysis/b1314-flips/imp.lua`, `once.py`, `colors.py`; output in `imp16/*.txt` there), with
`systemIndigoColor` as the control: it reads (88, 86, 214) light and (94, 92, 230) dark, the values this file already carried.

| colour | light | dark | light, high contrast | dark, high contrast |
| --- | --- | --- | --- | --- |
| cyan | (50, 173, 230) | (100, 210, 255) | (0, 113, 164) | (112, 215, 255) |
| mint | (0, 199, 190) | (99, 230, 226) | (12, 129, 123) | (99, 230, 226) |

Alpha is 1 in every one. Mint's dark high-contrast colour is its dark colour: the block passes the same three registers for both. Which
argument of the trait call is the interface style (0 unspecified, 2 dark) and which the contrast (0 normal, 1 high) is read from the
calls' order and from the indigo control, not from a symbol. These are the values of 16.0; whether 15.0 had the same was not read (no
15 cache). `objc.inventory` (`ladder-rest.log`): neither getter is in 6.1.3 or 12.0, both are in 16.0 and 18.0.

18.0 gives cyan and mint the same values (see the palette above).

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked cyan and mint in light, dark and light with high contrast, and against the 18.0 palette purple light and dark, teal, green, red dark with high contrast, indigo light with high contrast, the secondary background dark elevated with high contrast and the tertiary label's alpha of 76/255; all as in the table.
