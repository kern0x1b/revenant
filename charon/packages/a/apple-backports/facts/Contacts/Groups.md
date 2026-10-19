# Groups, containers and the two value classes beside them, iOS 9.0

`CNGroup`, `CNMutableGroup` and `CNContainer` are the same translation
`CNContact` already is: a group of the release's book is an `ABGroup`, a
container is a source (`ABSource`), and both are `ABRecord`s the C API of
`AddressBook` has carried since iPhone OS 2.0. There is no wall here, so there
is no reason for either class to be `absent` - a call against a missing
`CNGroup` symbol is dyld killing the process at launch, not a feature the
corpus never asked for.

Source: the headers of SDK 16.4 for the declarations; `AddressBook` of the
armv7 shared cache of 6.1.3 for `ABGroupCreate`, `ABGroupCreateInSource`,
`ABGroupCopySource`, `ABGroupCopyArrayOfAllMembers`, `ABGroupAddMember`,
`ABGroupRemoveMember`, `ABAddressBookCopyArrayOfAllGroups`,
`ABAddressBookCopyArrayOfAllGroupsInSource`, `ABAddressBookGetGroupWithRecordID`,
`ABPersonCopySource`, `ABAddressBookCopyArrayOfAllSources` and
`ABAddressBookGetSourceWithRecordID`.

## CNGroup and CNMutableGroup

- `identifier` is the group's `ABRecordID`, written out in decimal, the same
  way a contact's `identifier` is.
- `name` is `kABGroupNameProperty` off the group's record.
- `+predicateForGroupsWithIdentifiers:` and
  `+predicateForGroupsInContainerWithIdentifier:` are real predicates,
  resolved by `-[CNContactStore groupsMatchingPredicate:error:]` against
  `ABAddressBookGetGroupWithRecordID` and
  `ABAddressBookCopyArrayOfAllGroupsInSource`; a nil predicate answers every
  group in the book. `+predicateForSubgroupsInGroupWithIdentifier:` is not in
  the iOS surface of the real SDK (it is marked unavailable there too), so
  this port carries none of it.
- A `CNMutableGroup` starts with a UUID `identifier`, the same way a
  `CNMutableContact` does, and is given the book's record id once a save
  request that adds it succeeds.

## CNContainer

- `identifier` is the source's `ABRecordID`; `name` is `kABSourceNameProperty`;
  `type` is `kABSourceTypeProperty` mapped from `ABSourceType` to
  `CNContainerType` - local, exchange (both plain and GAL), CardDAV (both
  plain and search) map to their `CNContainerType` counterparts, everything
  else (MobileMe, LDAP) maps to `CNContainerTypeUnassigned`, since the real
  SDK names no case for them.
- `+predicateForContainersWithIdentifiers:`,
  `+predicateForContainerOfContactWithIdentifier:` (`ABPersonCopySource`) and
  `+predicateForContainerOfGroupWithIdentifier:` (`ABGroupCopySource`) are
  real; a nil predicate answers every source in the book.
- `-[CNContactStore defaultContainerIdentifier]` already answered the default
  source's identifier before this patch; `containersMatchingPredicate:` now
  lets an application turn that identifier into the container object itself.

## Saving groups and memberships

`-[CNSaveRequest addGroup:toContainerWithIdentifier:]`, `updateGroup:` and
`deleteGroup:` queue the same way the contact operations do, and
`-[CNContactStore executeSaveRequest:error:]` executes them with
`ABGroupCreate`/`ABGroupCreateInSource`, `ABRecordSetValue` on
`kABGroupNameProperty` and `ABAddressBookRemoveRecord`, in the same
all-or-nothing `ABAddressBookSave` the contact operations already share.
`addMember:toGroup:` and `removeMember:fromGroup:` execute with
`ABGroupAddMember` and `ABGroupRemoveMember`. A group or a contact named in a
member operation that is not in the book fails the whole save with
`CNErrorCodeRecordDoesNotExist`, the same as an update or a delete of a
contact that does not exist.

`addSubgroup:toGroup:` and `removeSubgroup:fromGroup:` are marked unavailable
on iOS in the real SDK (`API_UNAVAILABLE(ios)`), so this port carries neither;
`AddressBook` has no group-nesting API for them to sit over either.

## CNContactProperty

A plain value object over a contact, a key, a value, a label and an
identifier. The real SDK exposes no public initializer for it either - it
exists to be handed back by `CNContactPickerViewController`'s delegate, which
this port does not carry (no picker UI is built here). The class itself is
implemented so a strong reference to it does not crash dyld; `alloc`/`init`
answers an empty instance, and nothing in this port ever produces a populated
one, the same as a release running with no contact picker feature reachable.

## CNPostalAddressFormatter

`+stringFromPostalAddress:style:` and the instance form join the non-empty
fields of a `CNPostalAddress` - street, then city/state/postal code on one
line, then country - with newlines, style
`CNPostalAddressFormatterStyleMailingAddress` being the only style the real
SDK names. `+attributedStringFromPostalAddress:style:withDefaultAttributes:`
tags each line with `CNPostalAddressPropertyAttribute` (the source
`CNPostalAddress` key) and `CNPostalAddressLocalizedPropertyNameAttribute`
(`ABPersonCopyLocalizedPropertyName` of that key).

**Where this differs from the release.** The real formatter reads
`ABAddressFormats.plist` to order and label fields per locale - some locales
put the postal code before the city, or add prefixes the U.S. layout does
not. Nothing in this port calls that formatting path, so the layout here is
fixed to the U.S. mailing-address order regardless of locale. An application
comparing this port's output against the device's own Contacts app in a
non-U.S. locale will see a different line order; this is a written-down
divergence, not a silent one.
