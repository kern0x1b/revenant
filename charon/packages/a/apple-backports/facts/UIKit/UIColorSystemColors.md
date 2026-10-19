# The system colours of iOS 7 and iOS 9

Source: the UIKitCore of iOS 12.0 arm64 (`dyld_shared_cache_arm64`), read for the components themselves,
and the other frameworks of the same release that draw with them.

**Superseded by the palette rule of `UIColorDynamic.md`:** the port now answers these nine as dynamic colours with the values of 18.0
(green, teal and purple changed; the others keep the light value below). What follows is what 12.0 carried, kept as the record.

That answer is ours only where the release has no getter of its own. `attach.c` adds a backported method only when the class
and its superclasses lack the selector (`charon_implements`), and the release's own UIColor has these class methods: none of
them in 6.1.3, all but `systemPurpleColor` from 7.0 through 8.4.1, all nine from 9.0 through 10.3.4 (`objc.inventory` of the
held armv7 and armv7s caches, with `+redColor` found on every one of them and `+systemIndigoColor` on none). So a band of 7.0
or later answers the release's own colour, which is the value an application gets there without the port, and the 18.0 values
answer on 6.x, and for `systemPurpleColor` on 7.0 to 8.4.1. There is one source per colour on every band: nothing in the port
reads these rows of the table except the nine getters, and everything else asks the getters.

In 12.0 the nine colours are opaque and fixed - this is before the release made them depend on an appearance -
and each is a triple of bytes over 255:

| colour | red | green | blue |
|---|---|---|---|
| `systemRedColor` | 255 | 59 | 48 |
| `systemGreenColor` | 76 | 217 | 100 |
| `systemBlueColor` | 0 | 122 | 255 |
| `systemOrangeColor` | 255 | 149 | 0 |
| `systemYellowColor` | 255 | 204 | 0 |
| `systemPinkColor` | 255 | 45 | 85 |
| `systemTealColor` | 90 | 200 | 250 |
| `systemGrayColor` | 142 | 142 | 147 |
| `systemPurpleColor` | 88 | 86 | 214 |

Every component of that table that is not 0 or 1 is a `double` literal in UIKitCore of iOS 12.0, in the
constant pools its colour code reads from - `59/255` at `0x1ad730288`, `48/255` at `0x1ad730c58`,
`76/255`, `217/255` and `100/255` at `0x1ad730c60`, `0x1ad72e488` and `0x1ad730c70`, `122/255` at
`0x1ad730c78`, `149/255` at `0x1ad730c80`, `204/255` at `0x1ad72e308`, `45/255` and `85/255` at
`0x1ad730ca0` and `0x1ad72f8d0`, `90/255`, `200/255` and `250/255` at `0x1ad730c88`, `0x1ad730c90` and
`0x1ad730c98`, `142/255` and `147/255` at `0x1ad72ee68` and `0x1ad72ee70`, and `88/255`, `86/255` and
`214/255` at `0x1ad730ca8`, `0x1ad72f8c0` and `0x1ad72f440`.

Nine other frameworks of that release carry the pairs whole, which is how a value can be tied to its
colour rather than only to the pool: `(59, 48)` in StoreKitUI, `(217, 100)` in ChatKit, `(122, 255)` in
VectorKit, `(149, 0)` in HomeUI, `(204, 0)` in Vision, `(45, 85)` in SpringBoardUI, `(200, 250)` in
Weather, `(142, 147)` in PassKitCore and `(86, 214)` in GameCenterUI - each of them a framework that
draws in the system colour of its own kind.

The host is not a source for these: under Mac Catalyst the palette follows the Mac, and
`+systemBlueColor` there answers `(0, 136, 255)`, the machine's accent, not the release's blue.
