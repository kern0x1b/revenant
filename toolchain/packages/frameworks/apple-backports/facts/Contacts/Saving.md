# Writing the address book through a save request, iOS 9.0

`CNSaveRequest` collects what is to be added, changed and removed, and
`-[CNContactStore executeSaveRequest:error:]` writes all of it into the
release's own book in one `ABAddressBookSave`.

Source: the headers of SDK 16.4 for the declarations; `AddressBook` of the
armv7 shared cache of 6.1.3 for `ABPersonCreate`, `ABPersonCreateInSource`,
`ABAddressBookAddRecord`, `ABAddressBookRemoveRecord`, `ABAddressBookSave` and
`ABAddressBookRevert`; the `Errors.strings` of `Contacts.framework` on an
iPhone4,1 running 9.3.6 for what the release's own error codes mean.

## What one execution does

1. A book is opened, and refused at once with `CNErrorCodeAuthorizationDenied`
   if the owner has not granted access.
2. Every contact to be added becomes a new `ABPerson` - in the source whose
   record id the container identifier names, or in the book's default source
   when none is given - and is handed to `ABAddressBookAddRecord`.
3. Every contact to be updated is looked up by its identifier with
   `ABAddressBookGetPersonWithRecordID` and has its values written onto that
   record. A contact whose identifier names no record fails the save with
   `CNErrorCodeRecordDoesNotExist`.
4. Every contact to be deleted is looked up the same way and handed to
   `ABAddressBookRemoveRecord`.
5. `ABAddressBookSave` writes the lot. The save is all or nothing: the first
   refusal stops it, `ABAddressBookRevert` throws the changes away, and the
   error comes back in `CNErrorDomain` with the release's own `CFError` under
   `NSUnderlyingErrorKey`.
6. A contact that was added is given the record id the book assigned it, so its
   `identifier` names it from then on. Before the save it is the UUID the
   contact was made with.

Only the keys a contact says are available are written, so a contact fetched
with a few keys and updated writes back only those. A key whose value is an
empty string or an empty array removes the property from the record, which is
what the release's own editor does.

## Where iOS 6 differs, and the save refuses rather than pretends

- **`previousFamilyName` and `nonGregorianBirthday` have no field in the
  release's book.** A save of a contact that carries a value under either is
  refused with `CNErrorCodeValidationConfigurationError` and a reason naming
  the key. Dropping the value quietly and answering success is the one thing
  this package will not do with the owner's data. A contact that leaves both
  empty saves as it would under iOS 9.
- **The entries of a multi-value get new identifiers.** The release exports no
  way to write a chosen `ABMultiValueIdentifier`, so a save rebuilds the
  multi-value and the book numbers the entries again. The `identifier` of a
  `CNLabeledValue` an application held on to therefore names nothing after a
  save of that contact; refetch to get the current ones.
- **Groups and members are carried.** `addGroup:toContainerWithIdentifier:`,
  `updateGroup:`, `deleteGroup:`, `addMember:toGroup:` and
  `removeMember:fromGroup:` execute over `ABGroup`, the same way the contact
  operations execute over `ABPerson`; `facts/Contacts/Groups.md` says how.
- **`transactionAuthor` and `shouldRefetchContacts`** of iOS 15 are carried;
  `facts/Contacts/SaveRequest.md` says what each does and the one honest
  boundary of the two - the release's book records no author of a change, so
  `transactionAuthor` reads back exactly what was set and reaches nothing
  else.
- A save of this process's own does not post
  `CNContactStoreDidChangeNotification`, which follows the release's external
  change callback; iOS 9 posts it for a change from another store.
