# NSKeyedUnarchiver, the API of iOS 11.0

Introduced in iOS 11.0: reading an archive into a value of an allowed class,
reporting failure through an error rather than an exception.

Source: Foundation of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372); the
current behaviour from the differential test against the host's Foundation
(`tests/backports/host/keyedarchive11`).

| method | address in 11.0 |
|---|---|
| `+unarchivedObjectOfClass:fromData:error:` | `0x181556e74` |
| `+unarchivedObjectOfClasses:fromData:error:` | `0x181556f0c` |
| `-initForReadingFromData:error:` | `0x1815563fc` |

## Behaviour

`+unarchivedObjectOfClass:fromData:error:` wraps the class in an `NSSet` of one
(`-initWithObjects:count:` with a count of 1), calls
`+unarchivedObjectOfClasses:fromData:error:` and releases the set. It carries no
logic of its own.

`+unarchivedObjectOfClasses:fromData:error:` runs in this order:

1. `[[NSKeyedUnarchiver alloc] initForReadingFromData:data error:error]`.
2. A `nil` unarchiver ends the method at once; the error is already filled in.
3. `-setRequiresSecureCoding:YES`.
4. `-setDecodingFailurePolicy:` with `NSDecodingFailurePolicySetErrorAndReturn`.
5. A tail call to `-decodeTopLevelObjectOfClasses:forKey:@"root" error:`.

`-finishDecoding` is **not** called, and 11.0 does not release the unarchiver
either; the port releases it.

## What the caller sees

| case | domain and code | `NSDebugDescription` |
|---|---|---|
| the data is not an archive | `NSCocoaErrorDomain` `4864` `NSCoderReadCorruptError` | why it was refused |
| nothing is stored under `root` | `NSCocoaErrorDomain` `4865` `NSCoderValueNotFoundError` | `requested key: 'root'` |
| `nil` is stored under `root` | the same `4865` | the same |
| the value is of another class | `NSCocoaErrorDomain` `4864` | the class found and the classes allowed |

A missing key and a `nil` value are not told apart, so the port judges by the
decoded result rather than by `-containsValueForKey:`.

A property list value passes even when its class is not among the allowed ones:
an archive holding a string, read as `unarchivedObjectOfClass:[NSNumber class]`,
still answers the string, while an archive holding an `NSDate` does not. That
belongs to `-decodeObjectOfClasses:forKey:` itself and the port leaves it alone.

## `-initForReadingFromData:error:`

Answers `nil` with `4864` when the data is not an archive. After a successful
init `requiresSecureCoding` is already `YES` and the failure policy is
`NSDecodingFailurePolicySetErrorAndReturn`.

iOS 6 has no failure policy at all: the port catches the exception from
`-initForReadingWithData:` and turns it into `4864`, and the policy itself lives
in the `NSCoder+TopLevel.m` backport.
