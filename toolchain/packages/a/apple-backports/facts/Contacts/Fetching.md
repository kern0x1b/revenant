# Reading the address book through Contacts, iOS 9.0

A fetch of iOS 9 is a fetch of the release's own address book. Every call below
opens an `ABAddressBook` with `ABAddressBookCreateWithOptions`, reads what it
was asked for, and closes it again.

Source: the headers of SDK 16.4 for the declarations; `Contacts` of the arm64
shared cache of iOS 12.0 for the shape of the classes; the resources of
`Contacts.framework` on an iPhone4,1 running 9.3.6 for what the release answers;
`AddressBook` of the armv7 shared cache of 6.1.3 for the calls behind it -
`ABAddressBookCopyArrayOfAllPeople`, `ABAddressBookGetPersonWithRecordID`,
`ABAddressBookCopyPeopleWithName`, `ABPersonCopyArrayOfAllLinkedPeople`,
`ABRecordCopyCompositeName`, `ABPersonGetCompositeNameFormatForRecord`,
`ABPersonGetSortOrdering` and the two vCard calls.

## The identifier of a contact is the record id

iOS 9 hands out a UUID because its own database keeps one. The release's book
identifies a person by an integer record id, so that integer, written in
decimal, is the identifier here. It is stable for as long as the record is in
the book, which is what the API promises, and it is what
`unifiedContactWithIdentifier:keysToFetch:error:` and
`+[CNContact predicateForContactsWithIdentifiers:]` take back.

## The predicates

`+[CNContact predicateForContactsMatchingName:]` and the five others answer a
predicate of Charon's own, which the store reads:

| predicate | what runs |
| --- | --- |
| matching name | `ABAddressBookCopyPeopleWithName` |
| with identifiers | `ABAddressBookGetPersonWithRecordID` for each |
| in group | `ABGroupCopyArrayOfAllMembers` of the group with that record id |
| in container | `ABAddressBookCopyArrayOfAllPeopleInSource` of the source with that record id |
| matching email | every person, compared case-insensitively on the address |
| matching phone number | every person, compared on the digits, either number a suffix of the other |

The predicate also answers `-evaluateWithObject:` for a `CNContact`, so it can
filter an array in hand; iOS 9's own predicate raises instead. A predicate that
is not one of these six is refused with `CNErrorCodePredicateInvalid` rather
than quietly ignored. It answers `-copyWithZone:` too, since `CNContactFetchRequest.predicate`
is a `copy` property - found crashing on real hardware (`-[CharonContactPredicate
copyWithZone:]` unimplemented, NSInvalidArgumentException) the first time a
fetch request was ever given one of these six.

As an object it behaves the way the release's own predicates were measured to on
the macOS 26 host's Contacts (`tests/backports/host/contacts/run.sh`, the
`predicate.*` records): `-predicateFormat` answers `identifier IN {"A", "B"}` for
the three identifier-list predicates and nil, without raising, for the other
eight; `-description` answers a non-empty string without raising for every
factory, and the name predicate's names its factory (`predicateForContactsMatchingName:`) -
that is all the records hold. Beyond it the host's own descriptions differ by class
(`CNContainerOfGroupPredicate` answers only `<CNContainerOfGroupPredicate: 0x...>`; the
others list their own keys, such as `name=..., options=...` or `identifiers (count)=...`),
and the port approximates them with one format, its kind and `value=` its argument;
predicates made with the same factory and argument are equal, and nothing else
is; it conforms to `NSSecureCoding` and comes back from a secure archive as the
same predicate. `CNContactFetchRequest` archives its predicate with the other
fields, as the host's request does (its archive carries a `predicate` key). The
host is no oracle for reading that archive back: its own request raises
`NSInvalidUnarchiveOperationException` on `rankSort` (written as a bool, read with
`decodeInt64ForKey:`), so that one record is a named divergence in `run.sh`.

## Unification

`unifiedContactsMatchingPredicate:…` and a fetch request with `unifyResults`
follow `ABPersonCopyArrayOfAllLinkedPeople`. The first record of a linked set
that the walk meets is the one whose identifier the unified contact carries, and
the values of the other records fill what the first leaves empty: a single value
only where the first has none, a labeled value only where no entry of the same
value is already there. The identifiers of the records folded in are kept, so
`isUnifiedWithContactWithIdentifier:` answers for each of them. iOS 9 picks the
record whose name its own store prefers; here it is the order the book gives.

## Keys

`keysToFetch` is honoured: only the properties named are read from the record,
and the contact remembers them, so reading another property raises
`CNPropertyNotFetchedException` exactly as the release does. A descriptor that
is not a plain key - what `descriptorForAllComparatorKeys`,
`descriptorForRequiredKeysForStyle:` and
`+[CNContactVCardSerialization descriptorForRequiredKeys]` answer - is a class
of Charon's own that holds the list of keys it stands for.

## The name of a contact

`CNContactFormatter` does not compose a name itself. It builds a scratch
`ABPerson` that is never added to the book, sets the name parts on it and asks
`ABRecordCopyCompositeName`, so the order of the parts, the delimiter and the
fall back to the organization are the release's own, in the user's language and
settings. `nameOrderForContact:` is `ABPersonGetCompositeNameFormat()`, the
order the owner chose: the release exports no call that answers the order of one
record - `ABPersonGetCompositeNameFormatForRecord` arrived after 6.1.3 and is
not in its cache - so a contact whose script would flip the order under iOS 9
answers the owner's setting here. `delimiterForContact:` is read back out of the composite
name - what lies between the given name and the family name in it - and falls
back to what the release puts between `A` and `B` when the contact has only one
of the two.

The phonetic style is composed here rather than by the release, in the order
`nameOrderForContact:` gives and with that delimiter, because the release
exports no call that composes a phonetic name of parts.

`attributedStringFromContact:style:defaultAttributes:` marks each part of the
name it can find in the string with `CNContactPropertyAttribute`, whose value is
the key of the property, as iOS 9 does.

## vCards

`CNContactVCardSerialization` hands both directions to the release:
`ABPersonCreateVCardRepresentationWithPeople` writes and
`ABPersonCreatePeopleInSourceWithVCardRepresentation` reads. The vCard is
therefore the release's own - vCard 3.0, with the release's own property
coverage, which is not the coverage of iOS 9's writer. A contact read back out
of a vCard is not in the book, so its identifier is a UUID of its own rather
than a record id.

## What a change notification is

`CNContactStoreDidChangeNotification` is posted on the main queue from
`ABAddressBookRegisterExternalChangeCallback`, which the port registers on a
book of its own the first time an address book is opened. That callback fires
for a change made by another process, which is what the notification of iOS 9
means; a save of this process's own does not post it.

## CNContactsUserDefaults

`sortOrder` is `ABPersonGetSortOrdering()`, the setting the owner chose in
Settings, and it is never `CNContactSortOrderNone` or `…UserDefault`.
`countryCode` is the country of the current locale, lowercased, which is what
the release's own address formatting uses; iOS 9 reads it from the Contacts
defaults of the account.
