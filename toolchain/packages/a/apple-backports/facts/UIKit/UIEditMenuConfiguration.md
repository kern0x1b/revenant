# UIEditMenuConfiguration, iOS 16.0

Introduced in iOS 16.0: the value an edit menu interaction is given to show its menu - an identifier, the point the menu comes
from, and the arrow direction it prefers. The declarations come from the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`,
`identifier` and `sourcePoint` and `preferredArrowDirection` as `id<NSCopying>` copy and readonly, CGPoint readonly, and the enum
`UIEditMenuArrowDirection`) and from `spec/UIKit/declarations.tsv` (`ios=16.0` on the class and each member).

The only public constructor is `+configurationWithIdentifier:sourcePoint:`. `-init` and `+new` are marked unavailable in the header, so an
application cannot send them. The runtime still answers `-init`, and the port keeps that answer too (see below).

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/editmenu-config`, which compiles the port's
`UIKit/UIEditMenuConfiguration.m` beside the host's class in one process and prints the same checks for both.

## As UIKit does

- `+configurationWithIdentifier:sourcePoint:` keeps an immutable identifier as the object it was given: the same object comes back. A mutable
  string is **copied**, so a later change to it is not seen.
- A nil identifier becomes a fresh `NSUUID` for each configuration: the class is `__NSConcreteUUID`, its description is 36 characters, and two
  configurations get different identifiers.
- `sourcePoint` is kept as given. It is readonly.
- `preferredArrowDirection` is readwrite and stored as given. Its default is `UIEditMenuArrowDirectionAutomatic` (0); the enumeration is
  Automatic 0, Up 1, Down 2, Left 3, Right 4.
- The runtime `-init` (sent through the method, since the compiler will not take it) answers a configuration with a nil identifier, a zero
  point and an automatic arrow. The port gets this from its instance variables' zero values.
- The class is an `NSObject` subclass and does not conform to `NSCopying`.

## What the port does

- `UIKit/UIEditMenuConfiguration.m`: the factory allocates the object and runs `-charon_initWithIdentifier:sourcePoint:`, which sends `[super init]`
  and then sets the identifier (a copy, or a new `NSUUID` for nil) and the point. The method is not named `init...` because ARC does not allow
  `self` to be assigned in an init-family method here, and `init` is unavailable at compile time.
- The arrow direction is an ordinary stored property.

## A named divergence

The host's class answers YES to `-respondsToSelector:` for `setIdentifier:` and `setSourcePoint:`, although the header declares both properties
readonly. The port answers NO, as the header says. The host's setters are not public API, so the port does not add them: a setter nobody
declared would be a private surface to match the host, not a behaviour. `run.sh` asserts both answers, and it fails if the host stops answering
YES, so the port is revisited when the divergence is gone.

## Tests

- `tests/backports/host/editmenu-config/run.sh`: 18 checks, 16 compared line for line with the host, and the 2 setter answers as the named
  divergence. Measured green on the worktree.
- Planted control: a port whose nil identifier stays nil (a silent fake) fails the run on `nil-identifier-class`, `nil-identifier-is-NSUUID` and
  `nil-identifier-description-length`. Measured red.

## Caveats

- **device-unverified.** The port has not been run on the iPhone 4S or the iPad 2. The class is plain Objective-C state with no hardware under it,
  so the host run is its oracle, but the device run is still owed.
- The consumer is `UIEditMenuInteraction`, which is inert in the port: it takes the configuration and shows no menu, so nothing in the
  port presents one (`facts/UIKit/UIEditMenuInteraction.md`).
