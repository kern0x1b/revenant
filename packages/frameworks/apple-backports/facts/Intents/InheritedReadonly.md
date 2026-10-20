# A subclass that keeps its superclass's read-only value in its own ivar

The seventeen registry rows `intents-1a` answers, and exactly what is and is not proven about them.

## What the seventeen are

| class | rows | what the row answers |
| --- | --- | --- |
| `INBoatReservation` 2, `INBusReservation` 2, `INFlightReservation` 2, `INLodgingReservation` 2, `INRentalCarReservation` 2, `INRestaurantReservation` 2, `INTicketedEventReservation` 2, `INTrainReservation` 2 | 16 | `-initWithItemReference:reservationNumber:bookingTime:reservationStatus:reservationHolderName:actions:URL:…` and the same initialiser without `URL:` |
| `INRestaurantGuest` 1 | 1 | `-initWithNameComponents:phoneNumber:emailAddress:` |
| `INRideDriver` 2 | 2 | `-initWithPersonHandle:nameComponents:displayName:image:rating:phoneNumber:` and `-initWithPhoneNumber:nameComponents:displayName:image:rating:` |

Sixteen + one + two = **seventeen**. `INRideDriver`'s two were in the slice's second half and are
answered here, the same cause, and the commit message says so.

## Why they were absent, and what changed

`INReservation.h:19-29` is seven **read-only** properties and `-init NS_UNAVAILABLE` and **no
designated initialiser at all**; `INPerson` is the same. So a subclass initialiser that takes one of
those values had nowhere to put it:

- the property is read-only, so it cannot be written from the subclass;
- the superclass offers no initialiser that could hold it, so there is nothing to chain to — the
  chain the generator walked ended at `NSObject -initWithCoder:`, whose `NSCoder *` the SDK does not
  mark nullable and the subclass has no value for;
- so `initialiser()` returned nothing, recorded the cause `chain_nonnull`, and the registry wrote the
  member `absent`.

**The class now keeps a copy in its own ivar and answers the getter itself.** `INTrainReservation`'s
class extension carries `_URL`, `_actions`, `_bookingTime`, `_itemReference`,
`_reservationHolderName`, `_reservationNumber` and `_reservationStatus` next to the two it declared
itself, and the `@implementation` has a getter for each, written as a method and **not** as an
`@synthesize` — a superclass's read-only property is not one this class can synthesise, and
synthesising it would be a claim it does not own. The initialiser stores the value it was given in
that ivar and reaches the superclass through `revenant_intents_super_init`, which is the pattern the
tree already uses twice (`gen-intents.py:647` and `RevenantIntents100.m:334`).

A caller holding an `INReservation *` and sending `itemReference` gets this class's answer, because
the getter is this class's own: one object, one value. **That sentence is the design, and the
statement that it is true at runtime is owed — see below.**

## What is proven, and how

- **The objects compile.** `IN10_0_1.m` and `IN16_0.m`, armv7-apple-ios6.1.3 against the port's SDK,
  `-fobjc-arc -Os -g0 -Wall -Werror=objc-missing-property-synthesis`: **0 errors each**.
- **The rows are carried by the object.** All seventeen checked by name against the compiled objects:
  **0 with no name in either**.
- **The registry says the right thing.** The seventeen are `implemented`, the reasons are the
  generator's own vocabulary ("a member of INX, which the class's own generated implementation
  answers"), and **the effect text on all seventeen is empty**, which is the safe state: an empty
  effect claims nothing the code has not been shown to do.
- **The audit.** `sh tools/intents/generate.sh` from `tools/intents/generate.sh`'s own inputs:
  7 object files and 5 registry files regenerated, **78 method definitions gained and 0 lost** — 17
  initialisers and 61 getters, one per kept value across the eight reservation classes and
  `INRestaurantGuest`. A class the change does not touch (`INCurrencyAmount`) regenerates
  byte-identical, so the diff is only the intended methods.

## What is NOT proven, and is owed

**The port's Intents objects are armv7 iOS 6.1.3 and nothing in this slice runs them.** The
following are **owed to `intents-1c`** and are not claims:

- that the getter **returns** the value the initialiser stored;
- that a caller through a **superclass-typed pointer** sees it;
- that the value **survives an `NSSecureCoding` round trip** — the eight reservation classes and
  `INRestaurantGuest` all conform, and that is how a value crosses a process boundary.

The host half needs the class names renamed before it links, and the rename list is built and
measured but the harness is not in this series: the port's sources `#import <Intents/Intents.h>` and
`RevenantIntents262.h` re-declares the classes the 16.4 SDK lacks, so on the host every one of them is a
**duplicate interface definition** until it is renamed. `RevenantIntents100.m` cannot build for the
host at all (`UIKit/UIKit.h` is iOS-only), so `INIntentResolutionResult` and the resolution helpers
are port-only whatever happens.

## The two protocols with no row

`INIntentSetImageKeyPath` and `_INIntentSetImageKeyPath` have no row in any registry file. They were
`absent` with a reason that named no header, and the generator's `HELD_PROTOCOLS` held them; both are
gone. No Objective-C header declares them (iPhoneOS 16.5 and macOS 27 measured), the Objective-C runtime
loads neither (`NSProtocolFromString` answers NO on Catalyst and macOS), and the SDK's Swift overlay
declares both as Swift-only protocols from iOS 10. `tools/intents/gen-registry.py` skips the two names
(`SWIFT_ONLY_PROTOCOLS`), so a regeneration from the 26.2 corpus does not write them back. The full
measurement is in `facts/Intents/Intents.md`.

## The two `INDateComponentsRange` rows of EventKit

`-[INDateComponentsRange EKRecurrenceRule]` and `-[INDateComponentsRange initWithEKRecurrenceRule:]` are
implemented now. `EKRecurrenceRule` is **EventKit's**, which the Intents header only forward declares; the
package links EventKit into `IntentsBackports`, and the host's measured answers are in
`facts/Intents/Intents.md` ("EventKit's recurrence rule"). Four more
absent rows in `ios10.json` moved onto their own cause for the same reason — three of the reasons were
reaching the registry through a lookup keyed on the whole row while the generator records the cause
under the member's own selector, and the `10_0_1` group was never passed the vocabulary at all.
