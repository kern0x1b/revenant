# PassKit on iOS 6: the measurement pass, and what it decides

`apple.objc.inventory` against the armv7 dyld shared cache of **6.1.3**, and it splits PassKit in two
before a line of code is written:

| class | in the release? | what it has there |
| --- | --- | --- |
| `PKPass` | **yes**, 90 instance methods, 1 class method | `-initWithData:error:`, `-initWithCoder:`, `-encodeWithCoder:`, `-copyWithZone:`, `-supportsSecureCoding`, `passTypeIdentifier`, `serialNumber`, `uniqueID`, `teamID`, `organizationName`, `localizedDescription`, `localizedName`, `templateDescription`, `activationDate`, `expirationDate`, `relevantDate`, `institution`, `passURL`, `webServiceURL`, `logoRect`, `logoText`, `iconImage`, `barcode`, `transitType`, `authenticationToken`, `manifestHash`, `storeIdentifiers` |
| `PKPassLibrary` | **yes**, 34 instance methods, 1 class method | `-containsPass:`, `-cardAddedWithUniqueID:`, `-cardChangedWithUniqueID:`, `-cardRemovedWithPassTypeIdentifier:serialNumber:`, `-cardRemovedWithInfo:`, `-passes`, `-passesWithHandler:`, `-passWithUniqueID:`, `-passWithPassTypeIdentifier:serialNumber:`, `-removePass:`, `-addFakeBulletin`, `-isPassLibraryAvailable` (class) |
| `PKAddPassesViewController` | **yes**, 26 instance methods, 1 class method | `-initWithPass:`, `-initWithPass:orURL:`, `-initWithURL:`, `-initWithNibName:bundle:`, `-setDelegate:`, `delegate`, `-isAvailable` (class) |
| `PKRemotePass` | **yes**, 8 instance methods, superclass `PKPass` | the release's own pass relay: a pass on another device, which is what `PKPass.remotePass` answers with |
| `PKLocalPass` | **yes**, 42 instance methods, superclass `PKPass` | the release's own pass on this device |
| `PKPaymentAuthorizationViewController`, `PKPaymentRequest`, `PKPaymentSummaryItem`, `PKPaymentToken`, `PKPaymentAuthorizationController` | **no** | absent from the release entirely: zero `PKPayment*` and zero `PKAddPayment*` classes in the 12549 the cache yields |

**Eight of the thirty selectors an earlier revision of this table claimed are not in the cache, and
that drift is what made a registry row's reason false.** Checked one by one against the measured
`apple.objc.inventory` dump of the armv7 cache of 6.1.3 (`.agent-work/runs/passkit-1/rung3-6.1.3-objc.tsv`):

| claimed | where | really |
| --- | --- | --- |
| `PKPass.passNumber` | iOS 9 | **absent from 6.1.3** |
| `PKPass.userName` | iOS 8 | **absent from 6.1.3** |
| `PKPass.deviceName` | iOS 9 | **absent from 6.1.3** |
| `PKPass.primaryAccountNumberSuffix` | iOS 8 | **absent from 6.1.3** |
| `PKPass.foregroundColor` | iOS 8 | **absent from 6.1.3** |
| `PKPass.backgroundColor` | iOS 8 | **absent from 6.1.3** |
| `PKPass.logoImage` | iOS 8 | **absent from 6.1.3** -- the release has `-iconImage`, `-logoRect` and `-logoText` |
| `PKPassLibrary.-passesOfType:` | iOS 8 | **absent from 6.1.3** -- the release has `-passes` and `-passesWithHandler:` |

The `PKAddPassesViewController` row was right in all six. So the table claimed **30** selectors across
the three rows and **22** are there; eight were not. `PKPass.deviceName` is the one that cost
something: the registry row for it read "Apple's own answers it for a pass on another device", on the
authority of a table listing `deviceName` among the release's members. The release has no such
accessor, so that sentence was false, and the row now says what the cache says.

**A bare name is not a member: `first-rung` answers presence, never ownership.** Run over the held
ladder, `deviceName` first appears at **3.0** -- and that is *another class's* selector (`UIDevice`),
not `PKPass`'s. The ladder searches every C string in a cache, so a name shared by a hundred classes
reads at whichever release introduced the first of them. So for a name owned by a class, presence in
the ladder says nothing about whether THAT class has it, and the only measurement that does is
`apple.objc.inventory`'s per-class selector list. Read the ladder for whether a name exists anywhere;
read the inventory for who owns it.

**A third trap, which cost this table three more entries: the inventory prefixes every selector with
`-`, class methods included.** Its class-method table is keyed `-selector`, not `+selector` (which is
what `carried_by_release` in `modules/apple/backports.lua` looks up). So a class method written `+`
in prose matches nothing on a naive grep, and reads as absent when it is present. `+supportsSecureCoding`,
`+isPassLibraryAvailable` and `+isAvailable` are all in the cache as `-supportsSecureCoding`,
`-isPassLibraryAvailable`, `-isAvailable`; all three are the class column, and all three are there.

The five classes of the 8.0 payment request, measured the same way, with the control that certifies
the reader in the same run:

```
$ CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
      $HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
12549 rows: 11378 class and 1171 protocol

$ awk -F'\t' '$1=="class" && $2 ~ /^PK/ {print $2}' inv-6.1.3.tsv | wc -l
64
$ awk -F'\t' '$1=="class" && $2 ~ /^PKPayment/ {n++} END{print n+0}' inv-6.1.3.tsv
0
$ awk -F'\t' '$1=="class" && $2 ~ /^NS/ {n++} END{print n+0}' inv-6.1.3.tsv
590
$ awk -F'\t' '$1=="class" && $2 ~ /^PKA/ {n++} END{print n+0}' inv-6.1.3.tsv
1        # PKAddPassesViewController
```

So the release carries 66 classes beginning `PK` and **zero** beginning `PKPayment`, in a run that
finds 590 beginning `NS` and the one `PKA` there is: the zero is the release's and not the reader's.
`tools/cache-index/first-rung.lua` agrees and gives the version each arrived: `PKPayment`,
`PKPaymentPass`, `PKPaymentRequest`, `PKPaymentSummaryItem` and `PKPaymentToken` all read **8.0**, and
`PKPaymentButton` reads **8.3**. Presence, not version -- the held ladder has a hole at 13.0/14.0/15.0,
so a name first seen at 8.0 here is 8.0 and not 12.0.

The release's own `PKPass` has **90** instance methods and they do not include `-paymentPass`. Checked
one at a time against that row of the run's output: `-initWithData:error:`, `-initWithCoder:`,
`-encodeWithCoder:`, `-copyWithZone:`, `-passTypeIdentifier`, `-serialNumber`, `-organizationName`,
`-expirationDate`, `-logoRect` and `-relevantDate` are in the release, and `-paymentPass` is not.
That is why `PKPass.paymentPass` is `absent` on a measured ground rather than on the hardware's.

**One of the neighbouring rows needs a word of care, and it is not this slice's row.** `-logoImage` is
*not* among those 90 either, and neither is `-dictionaryRepresentation` — yet the selector
`dictionaryRepresentation` **is** in the release, in a run of its own: it is one exact line in
`$HOME/.charon/dyld/6.1.3/selectors_armv7.txt`, and **224** classes carry it in the inventory
(`MKMapItem`, `GEOPlace`, `GEORoute` and the rest). It is absent from `PKPass`'s *method list* because Apple's
PassKit adds it in a **category** on `PKPass`, and `apple.objc.inventory` reads a cache's class method
lists without merging a category compiled into one image onto a class defined in another — the same
blind spot `tools/release-split.lua` names in its own header. So `PKPass14.m`'s `CharonReleaseJSON`
category declaring it is right, and a row that read "PKPass has 90 methods, therefore
`dictionaryRepresentation` is not among them" would be wrong. The distinction matters only for
category methods, which is why the check above was run one selector at a time instead of by count.

`apple.dyld`'s `first_releases` for the 75 classes the SDK 26.2 declares and this port does not
have: 8.0 ×7, 8.1 ×1, 9.0 ×6, 10.0.1 ×1, 10.1.1 ×2, 11.0 ×5, 12.0 ×1, 16.0 ×39, 18.0 ×9, and 3 in
no held release (the 26.x identity-document classes).

## `PKRemotePass`: the release has the pass relay, so `remotePass` is an answer and not an absence

> **Superseded (2026-10-03).** No category answers `PKPass.remotePass` in the tree, and its row is
> `absent`: the property is a BOOL read through `-isRemotePass`, which the registry's property spelling
> cannot carry - see "`PKPass.remotePass` is a BOOL read through `-isRemotePass`" below and
> `PassKit/PKPaymentPass9.m`. The cache measurement of `PKRemotePass` / `PKLocalPass` here stands.

The cache holds **`PKRemotePass`**, superclass `PKPass`, 8 instance methods, and **`PKLocalPass`**,
superclass `PKPass`, 42 -- the release's own split of a pass by where it lives. That is Apple's pass
relay of 6.1.3 working, the service that kept a pass on another device current, and it is the reason
`PKPass.remotePass` (SDK 9.0) is **not** the "absent hardware" row its two siblings were.

The release tracks the distinction **by class identity, not by a property**: 6.1.3's `PKPass` carries
no `remotePass` accessor and no `isRemotePass` either (all 90 selectors measured, the only `remote`
strings in the whole `PK*` set are `PKAddPassesViewController`'s `-_remoteViewController` and
`PKServiceAddPassesViewController`'s `-remoteViewControllerProxy`). The subclass IS the record. So the
category answers from the release's own data, with no invented state:

    isKindOfClass: the release's own PKRemotePass  ->  self (that is the remote pass)
    otherwise                                        ->  nil   (no other device's pass)

That is a measured answer to a real question, which is the whole difference between this row and
`PKPass.secureElementPass`, where the answer is nil because there is no Secure Element at all. Getting
this from the cache is what a header cannot tell you: `PKPass.h` says the property exists from 9.0 and
says nothing about whether the 6.1.3 release had the thing behind it. It did.

## What this decides

**The wallet is the release's own, so the wallet is not a backport.** `PKPass`, `PKPassLibrary` and
`PKAddPassesViewController` are in the ledger as *missing members* of classes the release already
carries -- `PKPassLibrary.lastUpdatedDate`, `PKPassLibrary.isPassLibraryAvailable` and the rest are
iOS 8/9/11 additions -- so they are **categories on the release's own classes**, not new classes.
That is a different shape of work from MapKit's and a much smaller one: no class symbol, no
`initWithData:error:` of our own, just the members over the release's own objects, and the gate's
category check is what proves they attach.

**Apple Pay is the hardware wall, and it is Apple's -- but the wall is not the whole family.** There is
no Secure Element on a 4S, no Touch ID, and no `PKPaymentAuthorizationController` in the release:
`PKPaymentAuthorizationViewController` and the payment request/token/summary family are all absent
from the release, and Apple's own answer on a device without the hardware is that there is nothing
to authorize. So:

- `+[PKPaymentAuthorizationViewController canMakePayments]` and
  `+[PKPaymentRequest canMakePaymentsUsingNetworks:]` answer **NO**, which is the documented answer
  for a device with no Secure Element, and the registry entry says why in those words.
- **What a completed transaction produces stays absent**: `PKPayment`, `PKPaymentToken`,
  `PKPaymentPass` and `PKPaymentButton`. Every member of the first three is a read of the credential
  the Secure Element encrypted, and a class of those names would answer `nil` where its own header
  promises an object -- see the section on the four below, which is where that is measured rather
  than asserted. **Not** "absent because the release lacks it", which would be true and useless.
- **What the caller itself fills in is carried**: `PKPaymentRequest` and `PKPaymentSummaryItem` are
  `implemented` in `PKPayment8.m`, and the reason is that not one of their 8.0 members is anything
  other than a value the application set and reads back. A payment request is a form; the form is
  real on any device and only the signature it would carry is not.
- `PKAddPaymentPassViewController` and `PKAddPaymentPassRequest` are the other half of the same
  wall: they are the screen that *authorizes* a payment pass, so they are `absent` with the same
  reason, while `PKAddPassesViewController` and `PKPass` (the wallet, not the payment) are the
  release's own and stay.

**One thing this pass settles the same way the MapKit `MKMapItem` one did:** the ruling said "PassKit:
`PKPassLibrary`/`PKPass` over the release's own Passbook". The measurement says there is nothing to
port underneath them -- they *are* the release's Passbook, at 90 and 34 methods respectively -- so
the work is the iOS 8-and-later members of those two classes, not a reimplementation of the library.
Writing a `PKPass` here would be a second copy of something the release already has, which
COORDINATION §9 forbids.

## The check for each family

- The wallet members: a host differential is impossible (macOS has no iOS Passbook), so the emulator
  call test at 6.1.3 is the check, plus the gate's own category check, which proves the members
  attach to the release's classes.
- `canMakePayments`: a straight read, and the emulator call test asks it and records the answer.
- The two classes below: macOS **does** carry `PKPaymentRequest` and `PKPaymentSummaryItem`, so a host
  differential is possible and is the check — Apple's own object is the oracle, because a class that
  only keeps values is defined by what it keeps.

## The payment request family: two carried, four declined, and the line between them

The 8.0 payment request is five classes and the release has none of them (measured above: zero class
rows beginning `PKPayment` in a run of 12549 that finds 66 classes beginning `PK`). What separates
them is not the release — it has none of all five — but **what a member can answer on a device with no
Secure Element**, and that is read off the SDK 26.2 headers rather than assumed:

| class | 8.0 members, from the SDK 26.2 header | verdict |
| --- | --- | --- |
| `PKPaymentSummaryItem` | `+summaryItemWithLabel:amount:`, `label`, `amount` | **carried** in `PKPayment8.m` |
| `PKPaymentRequest` | `merchantIdentifier`, `countryCode`, `currencyCode`, `supportedNetworks`, `merchantCapabilities`, `paymentSummaryItems`, `requiredBillingAddressFields`, `requiredShippingAddressFields`, `shippingMethods`, `applicationData` | **carried** in `PKPayment8.m` |
| `PKPaymentPass` | one readonly `activationState`, **no initializer**, superclass `PKSecureElementPass` | declined |
| `PKPaymentToken` | `transactionIdentifier`, `paymentData`, `paymentInstrumentName`, `paymentNetwork` — **four readonly, no initializer, no class method** | declined |
| `PKPayment` | a **nonnull** readonly `token`, plus two nullable address reads and `shippingMethod` — no initializer | declined |
| `PKPaymentButton` (8.3) | `+buttonWithType:style:` and nothing else that draws | declined |

The carried two hold **values the application put in**, and nothing in either is produced by the
Secure Element or by any service: a payment request is a form, and the form is real on any device. The
declined three are the **result of a transaction**, and every member of each is a read of the
credential the Secure Element encrypted — so a class of those names has no value to answer with, and
`nil` where the header promises an object is the wrong answer rather than a cautious one.
`PKPayment`'s `token` is the sharpest case: it is `nonnull`, so a port class would hand a caller
`nil` for the one property its own declaration guarantees, and a `nil` `paymentData` reaching a
merchant's backend is a silent failure that looks like a successful one.

`PKPaymentButton` is declined for a different reason and says so: **its substrate is present.** The
release has `UIButton` with **134** instance methods (same run), so this is not "the class's base is
missing". It is Apple's own *artwork* — the Apple Pay mark and its card art — which is an asset of a
later PassKit, is in no release held here, and has no public source (`coordination/corpus/sources.md`
Part G lists PassKit among the frameworks with no implementation source at all). A class of that name
would be an empty `UIButton` claiming to be Apple's.

`PKPass.paymentPass` is `absent` on its own measurement rather than on the hardware's: the release's
own `PKPass` carries 90 instance methods and `-paymentPass` is not among them, so `respondsToSelector:`
answers NO and the property cannot be answered by anything the release has. `PKPass14.m` already
declines it for the same reason, and this agrees with that file rather than overriding it.

### What is NOT in `PKPayment8.m`, and why that is the release-split's job alone

The object is the **8.0** object, and only its 8.0 members: `PKPaymentSummaryItem`'s `-type` and
`+summaryItemWithLabel:amount:type:` are 9.0, and `PKPaymentRequest`'s `-shippingType` is 8.3 and its
two `PKContact` members are 9.0. `tools/release-split.lua` cannot enforce this on its own — it reads
band points from **exported symbols**, and an Objective-C class's instance methods are not exported
symbols (`nm -gU` on the object lists the two `_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` names and the
ivars, and no method), so the split is this file's discipline and not the tool's. The file says so at
its own head, and the gate's read of it is the export:

```
$ xmake l tools/release-split.lua .agent-work/runs/pk-ios8-a/objects
release-split: every folder of .agent-work/runs/pk-ios8-a/objects is clean
```

### The differential for the two carried classes

macOS carries both classes, so **Apple's own objects are the oracle** — the one thing this port has
been unable to do for the wallet. The run compiles the port's own object under renamed classes
(`charonHost_PKPaymentRequest`, `charonHost_PKPaymentSummaryItem`, so the driver reaches the port and
never Apple's) beside Apple's two, and compares member by member. Sources and transcripts:
`.agent-work/runs/pk-ios8-a/` (`differential.m`, `port-decls.h`, `real.body`, `mutant.body`,
`libport8.dylib`).

**24 checks, 0 failures** (`./differential > real.body`), against these: the class reached is the
port's own and not Apple's; a fresh request has no merchant identifier and no summary items on both;
each of the ten members reads back what was set, equal to Apple's; the two `PKAddressField` properties
and `merchantCapabilities` default to Apple's own zeros (`PKAddressFieldNone` is 0); and the `copy`
both properties declare holds — a mutable string changed after the call leaves the item reading
`Shipping`.

**One mutant**, because a green mutant is a comparison that decides nothing. `-setLabel:`'s
`[label copy]` becomes a plain assignment, which under ARC retains, and the mutation must turn exactly
the copy case red and nothing else:

```
$ diff real.body mutant.body
< ok   summary item: label was copied, not retained         Shipping
> FAIL summary item: label was copied, not retained         port=Shipping and Handling apple=Shipping
< 24 checks, 0 failures
> 24 checks, 1 failures
```

The two classes' `PKAddressField` spelling is why `port-decls.h` exists as a scratch header: the
tracked stand-in (`CharonPassKitStandin.h`) declares `PKMerchantCapability` and the two controllers
but not `PKAddressField`, and that stand-in is a file shared with the other PassKit bands, so this
run keeps its own header rather than editing theirs. Wiring the two classes into `tests/backports/host/passkit/run.sh`
is the follow-up, and it needs `PKAddressField` in the stand-in first.

## The Secure Element and the wallet: what each member answers, and the measurement behind it

A 4S has no NFC and no Secure Element, so every member below is **answered**, not left out — a
missing symbol crashes an application on a selector, and these are selectors Apple's headers declare.
By kind, and the kind is the rule:

| kind | the answer | why |
| --- | --- | --- |
| a capability question | `NO` | Apple's own documentation gives `NO` where the hardware cannot do it |
| an operation | a completion carrying `PKPassKitErrorDomain` | the release's own domain, first exported at 6.0 |
| `presentSecureElementPass:` | `NO` | its own signature has no completion, so the return value is the answer |

**`PKPassKitErrorDomain` is linked, not defined.** First exported at **6.0** (the gate's own
`first_releases` over the armv7 cache of 6.1.3), so the release owns the string and the package only
names it. The host probe measures it at **20 bytes** and the host framework's own value.

**`PKUnsupportedVersionError` is 2** and is the nearest the header's own enumeration comes to "this
device cannot do that": `PKUnknownError = -1`, `PKInvalidDataError = 1`, `PKUnsupportedVersionError
= 2`, `PKInvalidSignature = 3`, `PKNotEntitledError = 4`. There is no "unsupported hardware" beside
them, and the reason is written down rather than left as an unexplained code.

**Three answers that are the measured one rather than the safe one**, each of which could be
otherwise and was not:

- `+isSuppressingAutomaticPassPresentation` says `NO`. It could say `YES`, which looks conservative.
  It does not: reporting a suppression that does not exist makes a caller restore a presentation that
  was never stopped.
- `-authorizationStatusForCapability:` says `NotDetermined`, **not** `Restricted`. `Restricted` claims
  the hardware was refused, and nothing was asked.
- `+passesOfType:` returns the **empty set, not `nil`**. `nil` says "we do not know", which is a
  different thing to say from "there are none".

## The 26.0 pair, and a correction

**An earlier revision of this file was wrong and said so twice.** It claimed that
`-authorizationStatusForCapability:` and `-requestAuthorizationForCapability:completion:` are in no
held SDK, and it wrote that `PKPaymentCapability` is declared nowhere. Measured in the **SDK 26.2** —
whose root is a *developer folder*, not a bare `.sdk`, which is why an earlier search under
`i/iphoneos-sdk/26.2/` found nothing:

```
$ grep -n "authorizationStatusForCapability\|requestAuthorizationForCapability" \
    .../iPhoneOS26.2.sdk/System/Library/Frameworks/PassKit.framework/Headers/PKPassLibrary.h
121:- (PKPassLibraryAuthorizationStatus)authorizationStatusForCapability:(PKPassLibraryCapability)capability API_AVAILABLE(ios(26.0), watchos(26.0));
124:- (void)requestAuthorizationForCapability:(PKPassLibraryCapability)capability completion:(void (^)(PKPassLibraryAuthorizationStatus status))completion API_AVAILABLE(ios(26.0), watchos(26.0));

$ grep -rc "PKPaymentCapability" .../Headers
count=0
```

**Both methods are real, and both types are real** — but the types are `PKPassLibraryCapability` and
`PKPassLibraryAuthorizationStatus`, **not** `PKPaymentCapability`, which is in no header at all. So the
selector was right and the type name in the row was invented.

**And the value was wrong, which is the worse half.** The same file claimed
`NotDetermined` is `0`. The 26.2 header (`PKPassLibrary.h:34-39`) says:

| enumerator | value |
| --- | --- |
| `PKPassLibraryAuthorizationStatusNotDetermined` | **−1** |
| `PKPassLibraryAuthorizationStatusDenied` | **0** |
| `PKPassLibraryAuthorizationStatusAuthorized` | 1 |
| `PKPassLibraryAuthorizationStatusRestricted` | 2 |

The port returned `0` and the row said `0` is `NotDetermined`. **`0` is `Denied`** — the answer that
says the hardware refused, the exact opposite of "nothing has been asked". Both are now
`PKPassLibraryAuthorizationStatusNotDetermined` (−1), by the header's own enumerator, and the probe
holds them to **−1**.

`PKLibraryCapability` has one case, `PKPassLibraryCapabilityBackgroundAddPasses`. Both enumerations
are declared in `CharonPassKit.h` **only when the build's SDK lacks them** (`#if !defined(__IPHONE_26_0)`),
because a second typedef of the same enum is a hard error and an SDK that has them must keep its own.
The 16.4 SDK this package is built against does not have them; the 26.2 SDK does.

## Two types the first pass of the objects named, and no SDK has

`PKPaymentNetworkCapabilities` and `PKPaymentActivationData` are in no PassKit header in 16.4. The
headers' own types are `PKMerchantCapability` and `NSData`. Both objects compiled clean against the
SDK anyway, so these were wrong in a way the build does not see; the probe's build is what found them.
`-signData:withSecureElementPass:completion:` takes **three** block arguments (signedData, signature,
error) and `-encryptedServiceProviderDataForSecureElementPass:completion:` passes an **`NSDictionary`**
— both from the headers, and both now matching them.

## Every selector in the registry, checked against the SDK 26.2's own headers

The PassKit selector check (removed) walks every method row of `registry/PassKit/` and asks the SDK 26.2
whether it spells that selector. A dotted name like `PKPassLibrary.addPassesWithCompletionHandler` is
not a selector, and a name no header declares is not real API — that is what r3 found, in eight rows,
and this is the check that keeps it from coming back.

The check is deliberately strict, because each of three weaker versions passed a name the review
rejected:

- grepping the joined selector fails on **every real** one — a header writes each keyword with its
  parameter's type and name between, so `addPasses:withCompletionHandler:` is never contiguous text;
- requiring only that each keyword occurs in the file passes the **joined** invented names, because
  `addPasses:` and `withCompletionHandler:` are both there, on *different* lines;
- requiring class and keyword on one line fails on Apple's real headers, which name the class once at
  its `@interface` and never again.

So the check takes the selector's keywords, requires them **all on one line with their colons**, and
requires that line to sit under the `@interface` of the class the row names. A zero-colon selector is
matched bare, because a method taking no argument is written `- (void)openPaymentSetup
API_AVAILABLE(ios(8.3))` with no colon after the name at all.

**31 method rows, 0 misses.** The negative control, which is the part that matters: the eleven invented
spellings r3 found, injected at once, give **9 misses and exit 1** — the two that survive are the 26.0
pair, which are real.

## The probe

`tests/backports/host/passkit/run.sh` compiles the objects onto **renamed** classes
(`charonHost_PKPassLibrary` and the rest, in `port-classes.m`) so the runner reaches the port through
the runtime and never the host's PassKit. **43 check lines over 33 member cases, 0 failures**, and
**two** mutants, because one kind of mutation going red is not evidence that another would:

| mutant | the line | what turns red |
| --- | --- | --- |
| 1 | `+canMakePayments` returns `YES` | exactly one case, `PAC.canMakePayments` |
| 2 | the shared error's code, `PKUnsupportedVersionError` → `PKInvalidSignature` | nine cases — the error's **value**, not just its presence |

The second mutant is the one the transcript was not checking before: an operation's error was written
on a continuation line indented four spaces, and the body filter wanted a letter after two spaces, so
**nine error checks were running and being diffed without appearing in either transcript**. The host
is the oracle for the error domain alone. Build and transcripts: `.agent-work/runs/passkit/`.

## The two payment controllers are carried as CLASSES, not absent

**The finding that changed this**, from the 6.1.3 gate over the first real library build:

```
categories whose class neither iOS 6.1.3 nor the package exports ...
  PKPaymentAuthorizationController(CharonSecureElement: ...) and
  PKPaymentAuthorizationViewController(CharonSecureElement: ...)
```

A category on a class nobody carries is dead code: the loader has nothing to attach it to. Both
classes are measured absent from the armv7 cache of 6.1.3, and the registry said the CLASS was
`absent` (10.0 and 8.0) while its six members said `implemented` — a contradiction the gate found
and the registry did not.

**The class exists on a device without a Secure Element.** That is the whole of the correction, and
it is the standing rule: `absent` is for absent *hardware*, and the Secure Element is hardware, but
its absence is not why the class is missing. A 4S-era iPod answers `+canMakePayments` **NO** — it does
not lack the class, it answers the question. So:

| class | release | base | what it answers |
| --- | --- | --- | --- |
| `PKPaymentAuthorizationController` | 10.0 | `NSObject` | three capability questions, all `NO` |
| `PKPaymentAuthorizationViewController` | 8.0 | `UIViewController` | two capability questions, all `NO` |

**One object per release**, which is the release-split gate's own rule and not tidiness: the class is
8.0 and `+canMakePaymentsUsingNetworks:capabilities:` is 9.0, so that member is in
`PKPaymentAuthorizationViewController9.m` and the class and its 8.0 members are in
`PKPaymentAuthorizationViewController8.m`. An object carrying API of two releases is what that gate
refuses. The 9.0 member is a category on the port's own class and the 8.0 object implements that
class, so together they are one class in two objects.

**What stays absent, and it is the hardware and not the backlog**: `-initWithRequest:` takes a
`PKPaymentPass`, and **there is no `PKPaymentPass` in this release at all** (measured absent from the
armv7 cache of 6.1.3), so a payment sheet over a pass that cannot exist is a sheet with nothing in it.
The delegate callbacks are the same: they would report a presentation that cannot happen.

**The stand-in**, following `CHARON_MEDIAPLAYER_STANDIN` / `MPMediaItemStandin.h` in MediaPlayer: a
host that already has Apple's `PKPaymentAuthorizationController` gives a second `@implementation` of
the name as a duplicate symbol, and the probe would then measure Apple's class. `CharonPassKitStandin.h`
declares both classes as the SDK declares them and carries `PKMerchantCapability`, which the release's
own headers do not declare and which the members are spelled with.

**The probe asks whether the class is there, not only whether a member answers**: 86 check lines over
54 member cases, 0 failures, all four mutants red. Six of the lines are the two controllers, and one of
them checks the *superclass* — a renamed subclass of the host's class would answer all five questions
correctly while being a class the release never had. The five value classes below add their own class,
superclass and member cases, and the fourth mutant is theirs (the update's default status,
`PKPaymentAuthorizationStatusSuccess` → `Failure`, which turns exactly the three status cases red and
leaves a reworded comment in the same file green).

## The five value classes of iOS 11, and why they are carried rather than absent

`PKPaymentAuthorizationResult`, `PKPaymentRequestUpdate`, `PKPaymentRequestShippingContactUpdate`,
`PKPaymentRequestShippingMethodUpdate` and `PKPaymentRequestPaymentMethodUpdate` were `absent` with the
Secure Element's reason, which is the reason this page already overturned for the two controllers:
**`absent` is for absent _hardware_, and the Secure Element's absence is not why a class is missing.**
These five are further from the hardware than the controllers were -- none of them touches a Secure
Element, a card, a pass or a sheet. What decides them is that they are the **value types of the delegate
completion blocks**, and this port already exports the two classes those blocks belong to:

| the port exports | the header's method over it | the class the handler takes |
| --- | --- | --- |
| `PKPaymentAuthorizationViewController` (8.0, `PKPaymentAuthorizationViewController8.m`) | `-paymentAuthorizationViewController:didAuthorizePayment:handler:` (`PKPaymentAuthorizationViewControllerDelegate.h:60`) | `PKPaymentAuthorizationResult` |
| the same | `-paymentAuthorizationViewController:didSelectShippingContact:handler:` (`:88`) | `PKPaymentRequestShippingContactUpdate` |
| the same | `-paymentAuthorizationViewController:didSelectShippingMethod:handler:` (`:74`) | `PKPaymentRequestShippingMethodUpdate` |
| the same | `-paymentAuthorizationViewController:didSelectPaymentMethod:handler:` (`:98`) | `PKPaymentRequestPaymentMethodUpdate` |
| `PKPaymentAuthorizationController` (10.0, `PKPaymentAuthorizationController10.m`) | the same four on `PKPaymentAuthorizationController.h:64, :97, :92, :108` | the same four |

Every one of those methods is `API_AVAILABLE(macos(11.0), ios(11.0), watchos(4.0))` and every one of the
five classes is `API_AVAILABLE(macos(11.0), ios(11.0), watchos(4.0))` in the same header file,
`PKPaymentRequestStatus.h`. They replaced the 8.0 `-completion:(void (^)(PKPaymentAuthorizationStatus))`
(the 8.0 method is `API_DEPRECATED(..., ios(8.0, 11.0))` in the same header). So without this object the
port exports a payment controller whose delegate **cannot be written at all**: the SDK's own header names
a type the port has not got. That, and not the hardware, is what makes these five the port's to carry.

### The measurement, at both band ends, with the control

```
$ CHARON_ROOT=<worktree> xmake l tools/corpus/cache-census.lua PKPayment
6.1.3     ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming PKPayment 0
         classes 11378, of which PKPayment* 0
         protocols 1171, of which PKPayment* 0
4.3       ~/.charon/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming PKPayment 0
         classes 7187, of which PKPayment* 0
         protocols 564, of which PKPayment* 0
11.0      ~/.charon/dyld/11.0/dyld_shared_cache_arm64
         images 1258, of which naming PKPayment 0
         classes 52768, of which PKPayment* 267 (PKPayment PKPaymentActivationResponse ...)
control: 307 name(s) beginning PKPayment found in this run, so a zero on another rung is the release's and not the reader's
```

6.1.3 and 4.3 are the two rungs the package deploys on and the two ends of the absence, and 11.0 is in the
run as the control that makes their zeros mean something: the same reader, the same command, one rung
where the name is there. Transcript: `.agent-work/runs/d10-passkit-r11/census-payment.txt`.

Which release the name is real in, over the whole held ladder:

```
$ xmake l tools/cache-index/first-rung.lua --rungs _OBJC_CLASS_\$_PKPaymentAuthorizationResult
first-rung.lua: read 50 per-release index(es) in 30.44s
_OBJC_CLASS_$_PKPaymentAuthorizationResult	11.0,12.0,16.0,18.0
```

all five answer **11.0**, and `PKPaymentAuthorizationStatus` answers `NONE` -- which is what an
enumeration is: it has no symbol at all, so it is the SDK's declaration and not a release's.

### What Apple's own 11.0 has, measured class by class

```
$ CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
    ~/.charon/dyld/11.0/dyld_shared_cache_arm64
```

| class | superclass | image | Apple's own instance selectors |
| --- | --- | --- | --- |
| `PKPaymentAuthorizationResult` | `NSObject` | PassKitCore | `-errors`, `-initWithStatus:errors:`, `-setErrors:`, `-setStatus:`, `-status` |
| `PKPaymentRequestUpdate` | `NSObject` | PassKitCore | `-initWithPaymentSummaryItems:`, `-paymentSummaryItems`, `-setPaymentSummaryItems:`, `-setStatus:`, `-status` |
| `PKPaymentRequestShippingContactUpdate` | `PKPaymentRequestUpdate` | PassKitCore | `-errors`, `-initWithErrors:paymentSummaryItems:shippingMethods:`, `-setErrors:`, `-setShippingMethods:`, `-shippingMethods` |
| `PKPaymentRequestShippingMethodUpdate` | `PKPaymentRequestUpdate` | PassKitCore | **none** |
| `PKPaymentRequestPaymentMethodUpdate` | `PKPaymentRequestUpdate` | PassKitCore | `-errors`, `-initWithErrors:paymentSummaryItems:`, `-setErrors:` |

Three things in that table are what the port's object is built from. The superclass chain is Apple's own,
which is why the three updates are subclasses of `PKPaymentRequestUpdate` and not of `NSObject`. And
`PKPaymentRequestShippingMethodUpdate` has **no instance selector of its own at all** -- measured, not
inferred from the header -- so what the port adds for it is the class, and its storage is the base
class's reached through it.

**And one thing in that table is deliberately NOT carried.** Apple's own binary also has, on all five,
`-init`, `-initWithCoder:`, `-encodeWithCoder:`, `+supportsSecureCoding` and the `NSSecureCoding`
conformance, plus the private initializers `-initWithStatus:paymentSummaryItems:`,
`-initWithStatus:errors:paymentSummaryItems:shippingMethods:` and, on the payment-method update, a
private `-peerPaymentQuote`. **No SDK header declares any of them**: `rg -c NSSecureCoding` over
`PKPaymentRequestStatus.h` answers **0** in the SDK 26.2 and **0** in the SDK 16.4 the package is built
against. A name no header declares is not API this package carries -- that is the rule
The PassKit selector check (removed) enforces on the method rows, and the reason the 26.2 surface TSV has
no row for a coding method of these classes.

### What a caller gets on this release, which is the honest half

The object stores what the delegate put in it and hands the same values back. `-initWithStatus:errors:`
keeps a **copy** of the errors in the order they were passed -- the header says they are ordered most
serious first (`PKPaymentRequestStatus.h:31-33`) -- and the status is the one the delegate passed,
because that initializer takes it. The one `status` this port CHOOSES is the update's:
`-initWithPaymentSummaryItems:` sets `PKPaymentAuthorizationStatusSuccess`, which is the header's own
stated default for that property (`PKPaymentRequestStatus.h:49-51`, "PKPaymentAuthorizationStatusSuccess
by default") and the enumeration's own zero, since `PKConstants.h:65` declares
`PKPaymentAuthorizationStatus` with no explicit values. The three `null_resettable` error properties
answer the **empty list**, never `nil`, because `null_resettable` is Apple's own promise that the getter
does not.

What a caller **cannot** fill on this device is the other two lists, and the object does not paper over
it: there is no `PKPaymentSummaryItem` in 6.1.3 at all (registry row, 8.0, absent) and no
`PKShippingMethod` either. Both are measured rather than assumed --
`xmake l tools/cache-index/first-rung.lua` with `_OBJC_CLASS_$_PKPaymentSummaryItem` and
`_OBJC_CLASS_$_PKShippingMethod` answers **8.0** for each, which is above 6.1.3 and below the 11.0 the
census found them on. So in practice `paymentSummaryItems` and `shippingMethods` answer the **empty
array** here, which is what the release's own missing classes leave and not a value this port invents. Both properties copy, so a delegate that mutates the array it passed
cannot change what it already reported.

### One object, and what keeps the later releases out of it

`PKPaymentRequestStatus11.m` is the only object, and all five classes first export at 11.0 together
(measured above), which is what `tools/release-split.lua` reads. The SDK the package compiles against is
16.4, and its `PKPaymentRequestStatus.h` declares every property of these classes up to 16.4 --
`orderDetails` (16.0), `shippingMethods` (15.0), `multiTokenContexts`, `recurringPaymentRequest`,
`automaticReloadPaymentRequest` (16.0), `deferredPaymentRequest` (16.4). Auto-synthesis would put all
six accessors in an 11.0 object, so each is `@dynamic`, which is what the tree uses for a property this
release's object does not own (`PDFAnnotation11.m`'s `-bounds`, `MPSImageThreshold13.m`). The built
object's own member list is the check that they stayed out:

```
$ xmake l tools/corpus/objc-inventory.lua PKPaymentRequestStatus11.o armv7
class | PKPaymentAuthorizationResult          |                     | -.cxx_destruct,-errors,-initWithStatus:errors:,-setErrors:,-setStatus:,-status
class | PKPaymentRequestPaymentMethodUpdate    | PKPaymentRequestUpdate | -.cxx_destruct,-errors,-initWithErrors:paymentSummaryItems:,-setErrors:
class | PKPaymentRequestUpdate                 |                     | -.cxx_destruct,-initWithPaymentSummaryItems:,-paymentSummaryItems,-setPaymentSummaryItems:,-setStatus:,-status
class | PKPaymentRequestShippingMethodUpdate   | PKPaymentRequestUpdate |
class | PKPaymentRequestShippingContactUpdate  | PKPaymentRequestUpdate | -.cxx_destruct,-errors,-initWithErrors:paymentSummaryItems:shippingMethods:,-setErrors:,-setShippingMethods:,-shippingMethods
```

Every name in that list is one the SDK's own header declares for **11.0**, and `PKPaymentRequestShippingMethodUpdate`
is empty in the same way Apple's own is.

And the gate's own check, run over that object compiled to a scratch folder beside a record of the SDK it
was compiled against (`.agent-work/runs/d10-passkit-r11/objects/`), which is what release-split reads:

```
$ xmake l tools/release-split.lua .agent-work/runs/d10-passkit-r11/objects
release-split: clean, every object file's symbols first-appear in one release (1 files, 10 symbols, 50 releases checked)
PKPaymentRequestStatus11.o	_OBJC_CLASS_$_PKPaymentAuthorizationResult	11.0
PKPaymentRequestStatus11.o	_OBJC_CLASS_$_PKPaymentRequestPaymentMethodUpdate	11.0
PKPaymentRequestStatus11.o	_OBJC_CLASS_$_PKPaymentRequestShippingContactUpdate	11.0
PKPaymentRequestStatus11.o	_OBJC_CLASS_$_PKPaymentRequestShippingMethodUpdate	11.0
PKPaymentRequestStatus11.o	_OBJC_CLASS_$_PKPaymentRequestUpdate	11.0
PKPaymentRequestStatus11.o	_OBJC_METACLASS_$_PKPaymentAuthorizationResult	11.0
PKPaymentRequestStatus11.o	_OBJC_METACLASS_$_PKPaymentRequestPaymentMethodUpdate	11.0
PKPaymentRequestStatus11.o	_OBJC_METACLASS_$_PKPaymentRequestShippingContactUpdate	11.0
PKPaymentRequestStatus11.o	_OBJC_METACLASS_$_PKPaymentRequestShippingMethodUpdate	11.0
PKPaymentRequestStatus11.o	_OBJC_METACLASS_$_PKPaymentRequestUpdate	11.0
```

Ten symbols, every one of them 11.0, and no `@dynamic` property among them -- which is the mixed-release
defect this file's shape exists to prevent, measured rather than asserted.

### The probe, and two things it found

`tests/backports/host/passkit/run.sh`, transcript in `.agent-work/runs/d10-passkit-r11/probe-run.txt`:

```
ok every transcript reached the runner's own summary line
--- the real run made 54 member case(s) over 86 check line(s):
ok the real run's every case matches the row it checks
ok the mutant differs, so the comparison does see the value it is checking
ok the second mutant differs too, so the error's code is checked and not just its presence
ok the third mutant differs, so PKSecureElement8.m's answers are read
ok the third mutant's difference is the case it names
ok the third mutant's transcript says which case is wrong, not merely that it is
ok the fourth mutant differs, so PKPaymentRequestStatus11.m's answers are read
ok the fourth mutant's difference is the case it names
ok the fourth mutant's transcript says which case is wrong, not merely that it is
    PKPaymentRequestUpdate.status defaults to Success        1                          FAIL
      ... and PKPaymentRequestPaymentMethodUpdate inherits Success for status 1    FAIL
      ... and PKPaymentRequestShippingContactUpdate inherits Success for status 1   FAIL
```

**Two defects the probe found, both in the probe, and both worth naming because either would have read
as a pass.** The first run's `errors:` case passed an `NSError` where the SDK declares an `NSArray` of
them: `[NSError copy]` answers the error, not a list of one, so the case measured nothing. And a runner
that dies mid-transcript leaves **no** `FAIL` in it, because the cases after the crash never ran -- the
first run of that defect ended in an exception, and the only reason it was not green is that the fourth
mutant still differed. So `run.sh` now checks that **every** transcript ends with the runner's own
`# N check(s), N failure(s)` line, before it compares anything.

What the cases measure, and where each answer comes from: the five classes exist (the host has all five,
so a member answering would prove nothing on its own), the superclass chain is Apple's own as 11.0
measures it, `status` reads back what was passed and the update's own default is `Success`, the error
lists keep the order they were given and are **copies** -- proved by emptying the array the delegate
passed and reading the count again -- and the three `null_resettable` lists answer a list, never `nil`.
The last three cases are the negative ones: `PKPaymentRequestUpdate` must carry **no** `shippingMethods`
(15.0), **no** `multiTokenContexts` (16.0) and `PKPaymentAuthorizationResult` **no** `orderDetails`
(16.0), because `@dynamic` is what keeps an 11.0 object from shipping a later release's member.

**The probe asks whether the class is there, not only whether a member answers**: 52 check lines over
40 member cases, 0 failures, both mutants red. Six of the lines are these two classes, and one of them
checks the *superclass* — a renamed subclass of the host's class would answer all five questions
correctly while being a class the release never had.

## Release 9: PKPaymentPass9.m, and two corrections this pass found above

The release-9 object is `PassKit/PKPaymentPass9.m`. It carries `PKAddPaymentPassRequest`,
`PKAddPaymentPassRequestConfiguration` and `PKAddPaymentPassViewController` as classes, and
`-[PKPass deviceName]` as a category on the release's own `PKPass`. The three classes were `absent`
with the reason "the Secure Element: this device has none", and that is the reasoning the 6.1.3 gate
already refused once, in the section above about the two payment controllers: a class exists on a
device without the hardware and answers the question. `+[PKAddPaymentPassViewController
canAddPaymentPass]` answers **NO**, Apple's own documented answer for a device with no Secure
Element. The other two hold the issuer's own `NSString`/`NSData` and need no hardware to exist.

### The measurement, with its command, its output and its control

```
$ xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7
   (run through coordination/heavy.sh; output kept at .agent-work/runs/pk9/inv-6.1.3.tsv)
$ awk -F'\t' '$1=="class" && $2 ~ /^PK/' .agent-work/runs/pk9/inv-6.1.3.tsv | wc -l
66
$ awk -F'\t' '$1=="class"' .agent-work/runs/pk9/inv-6.1.3.tsv | wc -l
11378
```

The 11378 is the control: one run of a working reader, and the 66 is its PassKit count.

| name | in the armv7 cache of 6.1.3? | what the run says |
| --- | --- | --- |
| `PKPass` | **yes**, 90 instance methods | neither `-deviceName` nor `-isRemotePass` among them |
| `PKPassLibrary` | **yes**, 34 instance + 1 class method | no remote-payment member of any kind |
| `PKAddPassesViewController` | **yes**, super `UIViewController` | the release's own pass sheet |
| `PKRemotePass`, `PKLocalPass`, `PKWelcomePass` | **yes**, all super `PKPass` | the release's own pass subclasses |
| `PKAddPaymentPassRequest` | **no** | port defines it |
| `PKAddPaymentPassRequestConfiguration` | **no** | port defines it |
| `PKAddPaymentPassViewController` | **no** | port defines it |
| `PKPaymentMethod` | **no** | and unreachable, see below |
| `PKPaymentPass` | **no** | which is why the delegate callback stays unfired |

The 4.3 end carries no PassKit at all, and that zero is the release's and not the reader's:

```
$ python3 -c "import json; d=json.load(open('~/.charon/dyld/4.3/classes_armv7.json'))['classes']; \
    n=sorted(d); print([x for x in n if x.startswith('UI')].__len__(), [x for x in n if x.startswith('PK')])"
597 ['PKJob', 'PKPaper', 'PKPrintSettings', 'PKPrinter', 'PKPrinterBrowser']
```

597 names beginning `UI` in that run, so the reader works; the five `PK*` names are PDFKit's, and
there is no `PKPass` at 4.3 to hang a category on.

### Correction 1: the PKPass table at the top of this file is not what the release carries

> Already applied (2026-10-03): the table at the top marks these members absent from 6.1.3; this
> section is kept as the measurement behind that.

The table in "The measurement pass" lists `passNumber`, `userName`, `deviceName`,
`primaryAccountNumberSuffix`, `foregroundColor`, `backgroundColor` and `logoImage` among `PKPass`'s
members. **It is a summary of the header, not of the release, and six of those names are not in the
release's PKPass at all** — the class-scoped run above answers 90 instance methods and none of them
is `-deviceName`, `-passNumber`, `-userName`, `-primaryAccountNumberSuffix`, `-foregroundColor`,
`-backgroundColor` or `-logoImage`. `deviceName` is the one this band turns on, and it is in that
list wrongly. Every claim in this file that rests on a *class-scoped* measurement stands; the table
should be read as what the SDK declares, not as what 6.1.3 has.

### Correction 2: `PKPass14.m`'s comment says the release has no `PKRemotePass`. It has one.

`PKPass14.m` says "The release has no `PKPaymentPass` and no `PKRemotePass`". The first half is
measured and right. The second is wrong:

```
$ xmake l tools/cache-index/first-rung.lua PKRemotePass
PKRemotePass	6.1
$ awk -F'\t' '$1=="class" && $2=="PKRemotePass" {print $2, $3}' .agent-work/runs/pk9/inv-6.1.3.tsv
PKRemotePass PKPass
```

So the release carries `PKRemotePass` as a `PKPass` subclass, from 6.1 on. `PKPaymentPass` is
genuinely absent, which is the half that matters and is why this object answers nothing about a
payment pass. Left for the band that owns `PKPass14.m` to correct; it is not this band's row.

### `PKPass.remotePass` is a BOOL read through `-isRemotePass`, and the row said PKRemotePass

The row said "the property's value is a PKRemotePass". It is not. The header is:

```
$ grep -n "remotePass\|deviceName" .../iPhoneOS26.2.sdk/System/Library/Frameworks/PassKit.framework/Headers/PKPass.h
50:@property (nonatomic, assign, readonly, getter=isRemotePass)   BOOL       remotePass API_AVAILABLE(macos(11.0), ios(9.0), watchos(3.0));
51:@property (nonatomic, copy, readonly)                          NSString   *deviceName API_AVAILABLE(macos(11.0), ios(9.0), watchos(3.0));
```

The value is a **BOOL** saying whether this pass lives on another device, and the selector is
**`isRemotePass`**, not `remotePass`. `first-rung.lua` agrees about both: `isRemotePass` reads 9.0 and
`remotePass` reads 9.0 too (it is `PKRemotePass`'s own), while `deviceName` reads **3.0** — which is
another class's selector and not `PKPass`'s, the exact trap the ladder's own note describes, and the
reason the class-scoped run above and not `first-rung` answers this band.

`-[PKPass deviceName]` is carried and answers nil. `PKPass.remotePass` stays `absent`, and that is a
limitation of the check rather than of the answer: the row is spelled `PKPass.remotePass` as the SDK
surface spells it, and `backports.lua`'s `spellings()` turns a property row into `-[PKPass
remotePass]` and `-[PKPass setRemotePass:]` — never the getter that Apple's `getter=` attribute
renames it to. So an `implemented` row could not be shown to be built, while carrying the selector
would leave the registry describing the build wrongly. The answer itself is NO and would be as
honest as `deviceName`'s nil; what is missing is a row spelling that can carry it. Recorded here and
in the row rather than papered over by defining a `-remotePass` method no Apple SDK declares.

### `PKPaymentMethod` is absent because Apple's API gives a caller no way to reach the name

```
$ grep -rn paymentMethodWithType .../iPhoneOS26.2.sdk/System/Library/Frameworks/      # nothing
$ awk -F'\t' '$1=="PassKit" && $4 ~ /PKPaymentMethod/' coordination/corpus/sdk-26.2-surface.tsv
```

The 26.2 header declares three readonly properties and no initializer, and no factory exists in
that SDK, so nothing can construct one and nothing can hand one over: the surface carries no method
row for this class at any version. The one flow that would deliver one sits behind
`+canMakePayments`, which answers NO. So no selector of it can be sent on this device, nothing
crashes by reaching for it, and carrying the class would be a class no caller can obtain an instance
of — which is the line drawn against the three add-payment-pass classes, where a caller *can* reach
every name.

### One object per release, and what places it

Every class in the object first appears at 9.0 (`first-rung.lua` on all three), and `band()` drops an
object from every band whose release already exports all of its symbols. So this file is built
exactly where the release lacks these three classes and nowhere else — which is what keeps the
`PKPass` category from replacing the release's own `-deviceName` in a band that has it. The four
members iOS 10.1, 12.0 and 12.3 added to `PKAddPaymentPassRequestConfiguration` are `@dynamic` and
not answered, so that a 9.0 object carries no other release's API. One clang warning is left on
purpose and is written down in the object: `PKAddPaymentPassRequestConfiguration`'s `-init` is not
overridden, because overriding it means naming one of the release's 9.0 scheme constants (which has
no registry row) or passing nil to a parameter Apple's header declares nonnull.

## Correction (2026-10-16): PKPayment and PKPaymentToken exist on 8.0, and are carried

The paragraphs above that keep `PKPayment` and `PKPaymentToken` absent are withdrawn. Their reading was that every
member of both is a read of what a completed transaction produces. The measurement does not bear that out. The
armv7 cache of iOS 8.0 holds both classes, with these own selectors (`tools/objc-class-surface.lua 8.0 armv7`):

```
PKPayment: super=NSObject
  -initWithToken:, -initWithCoder:, -encodeWithCoder:, -token, -setToken:,
  -billingAddress, -setBillingAddress:, -shippingAddress, -setShippingAddress:,
  -shippingMethod, -setShippingMethod:, +supportsSecureCoding (class)
PKPaymentToken: super=NSObject
  -paymentData, -setPaymentData:, -paymentInstrumentName, -setPaymentInstrumentName:,
  -paymentNetwork, -setPaymentNetwork:, -transactionIdentifier, -setTransactionIdentifier:,
  -initWithCoder:, -encodeWithCoder:, +supportsSecureCoding (class)
```

Both classes are carried in `PKPayment8.m`, with the members above and nothing from later releases. The members hold
what they were given. Nothing here authorizes, signs or decrypts a credential, and the release's own token is not
made by this port: a token built from nothing answers nil in every member. The host answers the same for a fresh
object, and it returns the same token object from `-initWithToken:`, which the port matches. The differential is
`tests/backports/host/payment-value/run.sh` (20 SAME lines, failures 0, and a mutant that drops the token must go red).

Two gaps are named and not guessed. The release's archive keys are not measured, so an archive is round-trippable
within this port but not readable by the release. The shipping method and the two address references are not
written by the coder: the class that would carry the method is not in this port, and a record reference has no
archive form measured against the release.

Still absent, and still decided by the paragraphs above: `PKPaymentPass` (a `PKPass` subclass of 36 instance selectors and one
class method on 8.0, whose payment members read the Secure Element) and `PKPaymentButton` (a control, 8.3). They need their own
measured surface before a row changes.

## Correction (2026-10-16): PKPaymentOrderDetails exists on 16.0, and is carried

The row said absent, on the reason that no release carries the class. That reading was taken from the armv7 cache of
6.1.3, which is older than the class's introduction. The arm64e cache of iOS 16.0 holds it, measured with
`xmake l tools/objc-class-surface.lua 16.0 arm64e PKPaymentOrderDetails` (the output, measured on 2026-10-16):

    PKPaymentOrderDetails: super=NSObject
      -.cxx_destruct
      -authenticationToken
      -encodeWithCoder:
      -initWithCoder:
      -initWithOrderTypeIdentifier:orderIdentifier:webServiceURL:authenticationToken:
      -orderIdentifier
      -orderTypeIdentifier
      -setAuthenticationToken:
      -setOrderIdentifier:
      -setOrderTypeIdentifier:
      -setWebServiceURL:
      -webServiceURL
      -supportsSecureCoding (class)

The class has no own -init, so a plain -init is NSObject's. The port is `PassKit/PKPaymentOrderDetails16.m`. Its four
values are copied on the way in and on each set.

The archive form, measured on the host (macOS PassKit through the Mac Catalyst target, an order built with
`type-1`, `order-1`, `https://example.com/w` and `token-1`, archived with `requiringSecureCoding:YES`): the object is a
`PKPaymentOrderDetails` whose four members are stored under their own names. `orderTypeIdentifier`, `orderIdentifier` and
`authenticationToken` refer to `NSString` objects; `webServiceURL` refers to an `NSURL` object (`NS.base`, `NS.relative`).
The port writes and reads those keys and classes, which the probe checks by comparing the two archives' fields. Each side
also decodes the other's archive back to the values it was given.

The Mac Catalyst probe in `tests/backports/host/payment-value` asks the host and the port the same questions and prints 46
SAME lines with the dropped-token mutant red. Renaming one archive key in a copy of the port makes it print three FAIL lines
and exit 1.

`PKPaymentPass` and `PKPaymentButton` are still absent, as the paragraphs above say.

## PKPaymentMethod (9.0): carried

The 9.0 surface, measured with `xmake l tools/objc-class-surface.lua 9.0 armv7 PKPaymentMethod`:

    PKPaymentMethod: super=NSObject
      -copyWithZone:
      -dealloc
      -displayName
      -encodeWithCoder:
      -initWithCoder:
      -initWithPaymentPass:obfuscateNetworks:
      -network
      -paymentPass
      -setDisplayName:
      -setNetwork:
      -setPaymentPass:
      -setType:
      -type
      -supportsSecureCoding (class)

The port is `PassKit/PKPaymentMethod9.m`. The host (macOS PassKit through the Mac Catalyst target), measured by
`tests/backports/host/payment-value`:

- A fresh method answers type 0 and nil in every member. `-initWithPaymentPass:obfuscateNetworks:` with nil, with either
  flag, answers the same empty method. With a fresh `PKPaymentPass` (`-init`) the answer is the same: type 0, nil network,
  nil paymentPass.
- `type` reads back as set; `displayName` and `network` read back as set and are copies (a later change to the string the
  caller passed does not reach the method).
- A copy has the same members.
- The archive of a method with type 2, displayName `Name` and network `Visa` carries the four members under their own
  names: `type` as a number, the others as strings, a nil member as null.

The host's archive also carries `bankAccount`, `billingAddress`, `installmentBindToken`, `peerPaymentQuoteIdentifier`,
`remoteInstrument`, `subCredential` and `usePeerPaymentBalance`. Those are members of later releases (`billingAddress`
arrived at 13.0 and the others later still), and the 9.0 surface does not have their selectors, so the port does not carry
them. The archive of the 9.0 release is not measured here: no 9.0 run exists on this machine, and the brief does not allow
reading the keys from disassembly. The port uses the four names the host uses for the four members the 9.0 surface has.

The device has no Secure Element, so no pass it could be given carries payment data, and the port keeps none.
