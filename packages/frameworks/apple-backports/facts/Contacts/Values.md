# The values of a contact, iOS 9.0

Contacts came in iOS 9.0 as an Objective-C surface over the same local store
`AddressBook` had kept since iPhone OS 2.0. The C API of that store is whole in
iOS 6.1.3 - `ABAddressBookCreate`, `ABAddressBookCopyArrayOfAllPeople`,
`ABAddressBookSave`, `ABPersonCopyLocalizedPropertyName`, the multi-value family
and the vCard pair are all exported by the armv7 shared cache of the release - so
the classes here are a translation, not a new subsystem.

Source: `Contacts` of the arm64 shared cache of iOS 12.0 for the value of every
constant and for the shape of the classes (`+[CNLabeledValue makeIdentifier]` at
`0x18bc96fc0`, which asks `+identifierProvider` at `0x18bc96f3c` for a
`CNUuidIdentifierProvider`); the resources of `Contacts.framework` on an
iPhone4,1 running 9.3.6 - `English.lproj/CNContact.strings`,
`CNPostalAddress.strings`, `CNSocialProfile.strings`, `MessagingServices.strings`
and `SocialServices.strings` - for what the release displays; `AddressBook` of the
armv7 shared cache of 6.1.3 and `AddressBook.framework`'s own
`English.lproj/Localized.strings` and `ABAddressFormats.plist` on an iPhone4,1
running 6.1.3 for what the release under this port carries.

## The keys are the same strings

Every constant is defined with the string the release holds, read out of the
cache, not spelled from memory: `CNContactGivenNameKey` is `givenName`,
`CNContactStoreDidChangeNotification` is `CNContactStoreDidChangeNotification`,
`CNLabelHome` is `_$!<Home>!$_`, `CNContactPropertyNotFetchedExceptionName` is
`CNPropertyNotFetchedException`. The labels of `AddressBook` and of Contacts are
the same strings - `kABHomeLabel` is `_$!<Home>!$_` in the release too - so a
label needs no translation in either direction.

## How a property maps onto the book

| Contacts | AddressBook |
| --- | --- |
| `givenName`, `middleName`, `familyName` | `kABPersonFirstNameProperty`, `kABPersonMiddleNameProperty`, `kABPersonLastNameProperty` |
| `namePrefix`, `nameSuffix`, `nickname` | `kABPersonPrefixProperty`, `kABPersonSuffixProperty`, `kABPersonNicknameProperty` |
| `phoneticGivenName`, `phoneticMiddleName`, `phoneticFamilyName` | the three `…PhoneticProperty` |
| `organizationName`, `departmentName`, `jobTitle`, `note` | `kABPersonOrganizationProperty`, `kABPersonDepartmentProperty`, `kABPersonJobTitleProperty`, `kABPersonNoteProperty` |
| `contactType` | `kABPersonKindProperty` |
| `birthday`, `dates` | `kABPersonBirthdayProperty`, `kABPersonDateProperty` |
| `phoneNumbers`, `emailAddresses`, `urlAddresses` | `kABPersonPhoneProperty`, `kABPersonEmailProperty`, `kABPersonURLProperty` |
| `postalAddresses` | `kABPersonAddressProperty` |
| `contactRelations` | `kABPersonRelatedNamesProperty` |
| `socialProfiles`, `instantMessageAddresses` | `kABPersonSocialProfileProperty`, `kABPersonInstantMessageProperty` |
| `imageData`, `thumbnailImageData` | `ABPersonCopyImageDataWithFormat` |

A postal address is a dictionary in the book: `street` is `Street`, `city` is
`City`, `state` is `State`, `postalCode` is `ZIP`, `country` is `Country` and
`ISOCountryCode` is `CountryCode`. A social profile is a dictionary too, and its
`urlString` is `url` and its `userIdentifier` is `identifier`.

## Where iOS 6 differs, and it is written down rather than hidden

- **`previousFamilyName` and `nonGregorianBirthday` have nowhere to live.** The
  release exports no maiden-name property and no `kABPersonAlternateBirthdayProperty`
  at all. The two properties answer as the release's own empty value, a contact
  read out of the book never carries them, and the facts of the save request say
  what a write does with them.
- **`subLocality` and `subAdministrativeArea`** arrived in iOS 10.3 and the
  release's address dictionary has no such field, so they are always empty. Their
  keys are carried so that a `keysToFetch` naming them still links.
- **A labeled value's `identifier` is a UUID**, as it is in the release, which
  makes one through `CNUuidIdentifierProvider`. The release's book identifies an
  entry of a multi-value by an integer instead, so the entry's
  `ABMultiValueIdentifier` is kept beside the UUID and is what a save uses to find
  the entry again. Nothing hands that integer out.
- **The social service names differ in case.** Contacts writes `Twitter`,
  `Facebook`, `LinkedIn`, `MySpace`, `SinaWeibo`, `Flickr` and `Game Center`; the
  release's book writes `twitter`, `facebook`, `linkedin`, `myspace`, `sinaweibo`,
  `flickr` and `gamecenter`. The port translates the seven both ways and passes
  anything else through, so a profile written by iOS 6's own Contacts application
  reads back under the name Contacts uses. The instant-message services need no
  translation: both frameworks spell them `AIM`, `Facebook`, `GaduGadu`,
  `GoogleTalk`, `ICQ`, `Jabber`, `MSN`, `QQ`, `Skype` and `Yahoo`.
- **`+[CNContact localizedStringForKey:]` answers through
  `ABPersonCopyLocalizedPropertyName`**, which is the release's own localization
  in the user's language. Its English differs from the release that owns the API:
  iOS 9.3.6's `CNContact.strings` says `First name` where 6.1.3's
  `Localized.strings` says `First`, and `Company` for `organizationName` in both.
  A key the book has no property for answers with the key itself.
- **`+[CNPostalAddress localizedStringForKey:]`** answers with the token the
  release's own `ABAddressFormats.plist` names a component by - `Street`, `City`,
  `State`, `ZIP`, `Country`, `CountryCode` - and not with a localized string:
  6.1.3 carries no table that localizes them. iOS 9 answers `Street`, `City`,
  `State`, `ZIP`, `Country`, `Country code`, `District` and `County` out of
  `CNPostalAddress.strings`.
- **`+[CNSocialProfile localizedStringForService:]` and the instant-message pair
  answer the service itself**, because 6.1.3 carries no table of display names for
  them. iOS 9 answers `Sina Weibo`, `Tencent Weibo`, `Myspace` and `Google Talk`
  out of `SocialServices.strings` and `MessagingServices.strings`.
- **A comparator sorts by name with `localizedStandardCompare:`** over the given
  name and the family name in the order asked for, and `CNContactSortOrderUserDefault`
  reads the release's own `ABPersonGetSortOrdering()`. The release sorts with a
  collator of its own, so two names that differ only in how a collation orders
  them can come out in a different order than under iOS 9.
- **`CNContactVCardSerialization` writes the platform it runs on into `PRODID`.**
  `dataWithContacts:error:` delegates straight to `ABPersonCreateVCardRepresentationWithPeople`,
  so the line reads `-//Apple Inc.//iOS 6.1.3//EN` on the device and
  `-//Apple Inc.//macOS 27.0//EN` from a host oracle built for Mac Catalyst - each
  side honestly reporting its own `AddressBook.framework`, not a bug in either. A
  device check holding `vcard.encoded` to a host-generated expectation normalizes
  that one token before comparing; every other byte of the vCard still has to
  match exactly. `tests/backports/device/contacts.m` does this.

## Key availability

A contact remembers the keys the fetch asked for. Reading a property whose key
was not among them raises `CNPropertyNotFetchedException` under the name
`CNContactPropertyNotFetchedExceptionName`, which is what the release does, and
`isKeyAvailable:` and `areKeysAvailable:` answer honestly. A contact an
application makes itself has every key available, and setting a value makes its
key available.

## The CNLabel names of iOS 11.0 to 14.3, and where their texts come from

Contacts of iOS 13 added 202 `CNLabel…` names at once — the whole family of kinship labels a contact
can carry (`CNLabelContactRelationAunt`, `…AuntFathersElderSister`, `…YoungestSister`, and the rest) —
and iOS 11.0, 14.0 and 14.3 added five more. All 207 are carried here, and their texts are **Contacts'
own**, not a spelling of the symbol and not a guess:

    each value read out of the arm64e shared cache of iOS 18.0 through its own symbol, with
    tools/corpus/cache-value.lua — the symbol's address in the image's symbol table, the pointer stored there,
    the __cfstring it points at, and the bytes that names

Contacts writes these as a token rather than as a word: `CNLabelContactRelationAunt` is
`_$!<Aunt>!$_`, and `CNLabelContactRelationAuntFathersElderSister` is
`_$!<AuntFathersElderSister>!$_`. Carrying the token and not a readable spelling matters: a label is a
key, and a key that differs by a character is a label no contact ever matches. The 205 kinship names
come from `CNContactRelation.h`, `CNLabelPhoneNumberAppleWatch` from `CNPhoneNumber.h` and
`CNLabelSchool` from `CNLabeledValue.h`.

**The texts are checked against a second source**, the host's own Contacts, which exports all 207:
`tests/backports/host/contactlabels` reads each value on both sides and compares.

    207 agreed, 0 differed, and the host has no such name for none of them

**One file per release**, because an object carries the API of one release: `ContactsRelationLabels110.m`
(two names), `…130.m` (202), `…140.m` (two) and `…143.m` (one). The armv7 ladder measures the 11.0 pair
first appearing in the cache of iOS 11.0, and all the rest in the cache of iOS 16.0 — nothing between
12.0 and 16.0 is held — which is an upper bound for the 13.0, 14.0 and 14.3 their headers annotate, and
is the release those three objects are carried from.

**What a caller gets, and what it does not.** A caller that writes one of these names into
`keysToFetch:` gets the key it asked for and a contact of the release's book that has no field under
it, exactly as the ten keys of `registry/Contacts/ios10.json` already do. What is *not* claimed is a
label the release never made: the release's own address book stores the labels it had, and this port
adds no others to it.

## What is left of Contacts, and what each remaining row turned out to be

The framework's twenty-one rows that were not labels turned out to be five different things, and only
one of them is work:

- **Six are the corpus's property reader looking for an accessor that is NSObject's.**
  `+[CNContactFetchRequest new]`, `-[CNContactFetchRequest init]`, `+[CNFetchResult new]`,
  `-[CNFetchResult init]`, `+[CNPhoneNumber new]` and `-[CNPhoneNumber init]` are declared by the
  headers of `CNContactFetchRequest`, `CNFetchResult` and `CNPhoneNumber`, and every class inherits
  them from `NSObject`. They want an entry saying so and **no code**, which is what
  `registry/Contacts/remaining.json` gives them.

- **Eleven are the methods of `CNChangeHistoryEventVisitor`,** and they are real but for a smaller
  reason than it looks. The three concrete history events of this package already hand themselves to a
  visitor (`-[CNChangeHistoryAddContactEvent acceptEventVisitor:]` calls `visitAddContactEvent:`), so
  the *sends* were there; what was missing was the **protocol object** itself. Measured: an object that
  names a protocol only in a method signature emits no reference to it — `id<CNChangeHistoryEventVisitor>`
  is erased at run time — so the compiled `CNChangeHistoryEvent13.o` held no
  `__OBJC_PROTOCOL_$_CNChangeHistoryEventVisitor` at all, defined or undefined, and nothing carrying
  the library could answer `conformsToProtocol:` with it. The three dispatch sites now ask
  `if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)])` before handing the event
  over, which is what the framework's own code does, which makes the protocol object one this library
  defines (measured: `D __OBJC_PROTOCOL_$_CNChangeHistoryEventVisitor`), and which also means a
  visitor that does not adopt the protocol is no longer sent a message it does not have.

- **Three are not iOS APIs at all.** `+[CNGroup predicateForSubgroupsInGroupWithIdentifier:]` is
  `NS_AVAILABLE(10_11, NA)` — unavailable on iOS whatever its version — and
  `-[CNSaveRequest addSubgroup:toGroup:]` and `-[CNSaveRequest removeSubgroup:fromGroup:]` are
  `API_AVAILABLE(macos(10.11)) API_UNAVAILABLE(ios)`. The same is true of the SDK 26.2. Nested groups
  are a macOS feature of Contacts. So these are recorded **absent**, with the annotation that says why,
  and no port of them exists or should: an iOS application cannot name them, the compiler refuses them
  against the header, and there is no selector to answer. The corpus lists them as missing iOS rows
  because its scanner reads the declaration rather than the annotation.

- **One is work, and is the "me" card:** `-[CNContactStore unifiedMeContactWithKeysToFetch:error:]`
  (iOS 10.11). The release has no me card — no Contacts framework, and no record of the person who owns
  the device in the AddressBook it does have — so it answers **nil** with an `NSError` in
  `CNErrorDomain` and code **`CNErrorCodeRecordDoesNotExist` (200)**, and the keys are not read, since
  there is no contact to read them out of.

  **What the host answers here, measured, and why the port does not copy it.** Asked on the host for a
  me card, `-[CNContactStore unifiedMeContactWithKeysToFetch:error:]` returns nil with
  `CNErrorCodeAuthorizationDenied` (**100**, "Access Denied") and two userInfo keys. That is a
  *refusal of access*, which is a different case from the absence of a card: on that machine the me
  card exists and the process may not read it, and 100 says so. The port has no card and nothing to
  refuse, so 200 — the record does not exist — is what it says, and the description says which of the
  two cases this is. The host's own `CNError.h` gives `CNErrorCodeRecordDoesNotExist` as 200 and
  `CNErrorCodeAuthorizationDenied` as 100.
