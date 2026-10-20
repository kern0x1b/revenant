# The interface style of iOS 12

Source: the UIKit of the host's Mac Catalyst under a light appearance, asked trait by trait, and the
UIKit of iOS 12.0 arm64, read by the session that carries iOS 11 and 12.

The style is a trait like the other four, and `UIUserInterfaceStyleUnspecified` is not a value but the
absence of one. Measured on the host:

| asked | answered |
|---|---|
| `+traitCollectionWithUserInterfaceStyle:` with Light, Dark, Unspecified | Light, Dark, Unspecified |
| a collection of one display scale, and the empty collection | Unspecified |
| the screen's, the current one, a bare view's | Light |
| `merge(light, unspecified)`, `merge(unspecified, light)`, `merge(light, scale)`, `merge(scale, light)` | Light |
| `merge(light, dark)` | Dark |
| `isEqual:` of the unspecified one and the empty one | equal, and the same hash |
| `isEqual:` of the light one and the empty one | not equal, and a different hash |
| `[light containsTraitsInCollection:unspecified]` | YES - an unspecified style asks for nothing |
| `[empty containsTraitsInCollection:light]` | NO |
| `-description` | the style comes last, after the four: `DisplayScale = 2, UserInterfaceStyle = Light` |
| the key it archives under | `UITraitCollectionBuiltinTrait-_UITraitNameUserInterfaceStyle` |

What iOS 12 itself answers is not that. `-[UITraitCollection userInterfaceStyle]` there reads a field of
the built-in trait storage, `+traitCollectionWithUserInterfaceStyle:` copies a template whose field is 0,
and `-[UIScreen _defaultTraitCollectionForInterfaceOrientation:]` builds the screen's traits from the
idiom, the scale, the size classes and the bounds without ever setting a style. On a phone under 12.0 the
style is therefore `Unspecified`: the release had the trait before the device had an appearance.

The backport follows the newest implementation where it can. A collection carries no style unless one was
given, so a collection of values answers `Unspecified`; the collections the backport builds for an
environment - the screen's, a view's, a controller's - carry `Light`, because iOS 6 has exactly one
appearance and it is the light one. Merging takes the last collection that specifies a style, and
equality, the hash, containment, the description and the archive treat the style as the fifth trait.

Where the release carries `UITraitCollection` itself - from the 8.0 band up - only the two members of
this file are added, as a category, and the style lives in an associated object: the release's own
merging, equality and description know nothing of it, and the collections it builds for an environment
carry no style. An application there reads `Unspecified`, which is what iOS 12 answers on a phone, and
never `Dark`.
