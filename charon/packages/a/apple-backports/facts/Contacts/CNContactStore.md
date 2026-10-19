# The contact store and its permission, iOS 9.0

`CNContactStore` is the door to the same local database `ABAddressBook` opens,
and the permission in front of it is the same permission: iOS 6.0 is the release
that put contacts behind a prompt, and it exports
`ABAddressBookGetAuthorizationStatus` and
`ABAddressBookRequestAccessWithCompletion` for it.

Source: the headers of SDK 16.4 for the declarations; `Contacts` of the arm64
shared cache of iOS 12.0 for the shape of the class; `AddressBook` of the armv7
shared cache of 6.1.3 for the calls behind it.

## What answers

- `+authorizationStatusForEntityType:` is `ABAddressBookGetAuthorizationStatus()`
  cast. The four values are in the same order in both frameworks - not determined
  0, restricted 1, denied 2, authorized 3 - so the cast is the whole of it. An
  entity type that is not `CNEntityTypeContacts` answers denied; the release has
  no other entity.
- `-requestAccessForEntityType:completionHandler:` opens a book with
  `ABAddressBookCreateWithOptions` and asks
  `ABAddressBookRequestAccessWithCompletion`. The system shows its own prompt once
  for the application, as it does for any caller on iOS 6, and the handler is
  called with what the owner answered. When the book cannot be opened at all the
  handler is called with `NO` and the release's own `CFError`, or with
  `CNErrorCodeAuthorizationDenied` where the release gives no error.
  The handler runs off the main thread, which is where the release's own callback
  runs.
- `-defaultContainerIdentifier` is the record id of the book's default source
  (`ABAddressBookCopyDefaultSource`), written out in decimal. Turning that
  identifier into the `CNContainer` object itself is
  `-containersMatchingPredicate:[CNContainer predicateForContainersWithIdentifiers:]`.
- `-groupsMatchingPredicate:error:` and `-containersMatchingPredicate:error:`
  answer real `CNGroup` and `CNContainer` objects out of `ABGroup` and
  `ABSource`; `facts/Contacts/Groups.md` says how.
- `-enumeratorForContactFetchRequest:error:` wraps the same fetch
  `unifiedContactsMatchingPredicate:keysToFetch:error:` already runs in a real
  `CNFetchResult`; `facts/Contacts/History.md` says how.

## What reads and writes it

The fetches, the save request and the change notification are carried, and
`facts/Contacts/Fetching.md` and `facts/Contacts/Saving.md` say what each one
does and where it differs from the release. The release keeps no journal of
changes an application can read back, so `-enumeratorForChangeHistoryFetchRequest:error:`
and `currentHistoryToken` do not read one out of `AddressBook` - they keep
their own, in a snapshot journal this store writes and diffs itself.
`facts/Contacts/History.md` says how, and where the honest boundaries of a
journal built this way sit.
