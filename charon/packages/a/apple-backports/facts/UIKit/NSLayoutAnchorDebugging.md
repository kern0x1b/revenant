# NSLayoutAnchor's debugging properties, absent on iOS

`NSLayoutAnchor` declares four properties "for debugging only": `name`, `item`, `hasAmbiguousLayout` and
`constraintsAffectingLayout`. The SDK 16.4 headers mark each `API_UNAVAILABLE(ios, watchos, tvos)` (`NSLayoutAnchor.h`, lines 53 to
56), and their availability is macOS 10.12. The iOS release does not have them, so the port does not declare them: a call raises
"unrecognized selector" on the release, and `respondsToSelector:` answers NO.

The port's `NSLayoutAnchor.m` declared the four `@dynamic` with no accessor, which claimed a presence the release does not have. The
declaration is removed; nothing else changes, since the calls raised before and raise now.

The host differs. Mac Catalyst answers all four (probed with a view's `leadingAnchor` on the host: the class is `NSLayoutXAxisAnchor`,
`name` is "leading", `item` answers the view, and `hasAmbiguousLayout` and `constraintsAffectingLayout` answer). That is the Catalyst
runtime's own AppKit-shaped API, not the iOS release's, so there is no differential for these four: a host check would hold the port
to an API the iOS release does not carry. Measured by the probe only.

## The SDK 26.2 IR agrees

The 26.2 IR (`coord/sdkrun/out/ir/full.tsv`, the property and accessor rows of `NSLayoutAnchor` at `NSLayoutAnchor.h` lines 53 to 56) gives
each of the four `ios=-/-/-/1`. The column reads `intro/dep/obs/unavail`, so the fourth field 1 means unavailable on iOS; macOS 10.12 is
the only platform that has them. The port therefore keeps no declaration of them, and the removal is the release's answer.
