# transactionAuthor and shouldRefetchContacts, iOS 15.0 and 15.4

Both were reviewed against the same measure the change-history journal was:
"the release's book has no seam for this" describes a task, not a wall, unless
nothing iOS 6 gives can build the behaviour at all. One of the two survives
that measure whole; the other survives only as far as its effect reaches.

Source: the headers of SDK 16.4 for the declarations; `Contacts` of the arm64
shared cache of iOS 12.0 for the shape of the class; `AddressBook` of the
armv7 shared cache of 6.1.3 for the store `-[CNContactStore
executeSaveRequest:error:]` reads and writes.

## shouldRefetchContacts

`-executeSaveRequest:error:` is this port's own code, not a call into a
release method it cannot see inside - it already walks every added and
updated contact to write their values onto an `ABRecord` and, for an add,
to give the object its new identifier. Refetching those same objects after
a successful save is a read this port already knows how to do, over the same
`ABAddressBookGetPersonWithRecordID` and `readRecord:into:keys:filling:` the
rest of the store uses.

When `shouldRefetchContacts` is `YES`, every `CNMutableContact` that was added
or updated by a save that succeeds is re-read from the book, restricted to
the keys it already carries, and updated in place - the same object the
application is holding, not a copy. A contact whose identifier no longer
names a record (removed by a concurrent process between the save and the
refetch) is left as the save itself wrote it; the refetch is a courtesy on
top of a save that already went through, not a second chance for it to fail.

## transactionAuthor

`AddressBook` attributes no author to a change - there is no field on a
record, no argument to `ABAddressBookSave`, nothing `ABAddressBookRegisterExternalChangeCallback`
carries that names who made an edit. This is the same boundary
`facts/Contacts/History.md` documents for `CNChangeHistoryEvent.transactionAuthor`
and `excludedTransactionAuthors`, and it does not move: there is nothing in
iOS 6 to build an author out of, approximate or otherwise.

What does not need that data is the property itself. `transactionAuthor` is a
plain `copy` string an application sets before a save and can read back after
- nothing in the real SDK requires it to reach storage, only to hold the
value it was given between the two. This port keeps it exactly that way: set,
read back, `nil` by default. What it does not do, because nothing can, is
carry the value onto a record, into `ABAddressBookSave`, or out through a
later `-enumeratorForChangeHistoryFetchRequest:error:` - a save made under one
`transactionAuthor` and a change-history event answering for the same edit
agree on nothing about who made it, on this port as they would find nothing
to agree on in the release's own book either.
