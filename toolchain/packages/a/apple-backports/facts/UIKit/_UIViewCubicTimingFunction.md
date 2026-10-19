# _UIViewCubicTimingFunction

Introduced in iOS 10.0. Private: it is in no SDK header. Two control points and
nothing else - not a `CAMediaTimingFunction` but a plain object that can make one.

Source: UIKit of the armv7s cache of iOS 10.3.4.

It is carried under Apple's own name for the same reason as
`NSUnitConverterReciprocal`: `UICubicTimingParameters` archives it as an object
under the `timingFunction` key, so the class name is written into the archive,
and an archive that cannot cross is not the same archive.
## Carried under Apple's name, but only where there is none

The class is private, so the framework exports no symbol for it. A band can drop
and re-export an object whose symbols the release already exports; here there are
none to match, so the object would stay in every band and a release that has the
class would end up with two of that name.

The name cannot simply be given up, because an archive names the class and an
unarchiver looks it up by that name. So the class is defined under a Charon name
and Apple's name is registered **for** it, as a subclass made at run time, and only
where `objc_getClass` shows the runtime has none. On iOS 6 ours answers to the
name; on a release that has its own, nothing is registered and the system's is
used.

The registration happens when the library loads, not when the first instance is
made. That is not a detail: an unarchiver resolves a class by name before anything
has had a reason to make one, so a lazy registration would leave an archive
written by the real framework undecodable. The device test caught exactly that -
`NSClassFromString` answered nil until something else had built a curve.


| member | behaviour |
|---|---|
| `-init` | raises `NSInvalidArgumentException`: `Don't call %@.` |
| `-initWithControlPoint1:controlPoint2:` | keeps the two points. |
| `-controlPoint1`, `-controlPoint2` | the points. |
| `-_mediaTimingFunction` | `+[CAMediaTimingFunction functionWithControlPoints::::]` of the four numbers. |
| `-copyWithZone:` | a new one with the same points. |
| `-description` | `<%@ point1 = %@ point2 = %@>` |

## Archiving

| key | encoded with | decoded with |
|---|---|---|
| `point1` | `-encodeCGPoint:forKey:` | `-decodeCGPointForKey:` |
| `point2` | `-encodeCGPoint:forKey:` | `-decodeCGPointForKey:` |

Non-keyed coders raise `NSInvalidUnarchiveOperationException`:
`%@ only supports keyed coding.`
