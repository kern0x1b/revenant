# NSSecureUnarchiveFromDataTransformer

Introduced in iOS 12.0: a value transformer that unarchives data with secure
coding, for a Core Data attribute that keeps an object.

Source: Foundation of the arm64 shared cache of iOS 12.0
(`+allowedTopLevelClasses` at `0x18198d2ac`, `-transformedValue:` at
`0x18198d4a4`, `-reverseTransformedValue:` at `0x18198d674`); the current
behaviour from the differential test against the host's Foundation
(`tests/backports/host/foundation11`).

## Behaviour

| member | behaviour |
|---|---|
| name | `NSSecureUnarchiveFromDataTransformerName` is `NSSecureUnarchiveFromData`. |
| `+transformedValueClass` | not overridden: `nil` from `NSValueTransformer`. |
| `+allowsReverseTransformation` | not overridden: `YES` from `NSValueTransformer`. |
| `+allowedTopLevelClasses` | `[[self transformedValueClass]]` when a subclass names one, otherwise the fixed list below. |

`-transformedValue:`

1. `nil` answers `nil`.
2. A value that is not data raises `NSInvalidArgumentException` with
   `Cannot unarchive type from non-NSData object.`
3. Otherwise `+[NSKeyedUnarchiver unarchivedObjectOfClasses:fromData:error:]`
   with a set built from `allowedTopLevelClasses`.
4. No object and no error answers `nil`; an error raises
   `NSInvalidUnarchiveOperationException`, whose reason is the error's
   `localizedDescription` and whose `userInfo` carries it under
   `NSUnderlyingError`.

`-reverseTransformedValue:`

1. `nil` answers `nil`.
2. A value of no allowed class raises `NSInvalidArgumentException` with
   `Object of class %@ is not among allowed top level class list %@`.
3. Otherwise `+[NSKeyedArchiver archivedDataWithRootObject:requiringSecureCoding:error:]`
   with secure coding on, and an error raises the archiving twin of the same
   exception.

## The allowed classes, and one departure from 12.0

12.0 allows eight: `NSArray`, `NSDictionary`, `NSString`, `NSNumber`, `NSDate`,
`NSData`, `NSURL`, `NSUUID`. The current implementation allows ten, adding
`NSSet` and `NSNull`. The port allows the ten: an application built against a
recent SDK expects a set or a null to survive the round trip, both are property
list kinds that the archiver already handles, and the list is what the
differential test holds it to.

## Registration

The transformer answers to its name through `+[NSValueTransformer valueTransformerForName:]`.
The port registers it in `+load`, and only when nothing is registered under that
name already, so a release that has the class of its own keeps its own.
