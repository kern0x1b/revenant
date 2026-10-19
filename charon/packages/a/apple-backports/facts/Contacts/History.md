# CNFetchResult and the change history, iOS 13.0

`AddressBook` keeps no journal an application can read back - no revision
counter, no per-change log, nothing `ABAddressBookRegisterExternalChangeCallback`
delivers beyond "something changed, go look". `-[CNContactStore
enumeratorForChangeHistoryFetchRequest:error:]` and `currentHistoryToken` are
not a read of a journal the release keeps; they are a journal this port keeps
itself, over `CharonContactsHistory`, built from what iOS 6 does give: the
book's own enumeration, its record identifiers, `kABPersonModificationDateProperty`
on every person, and a group's name and membership.

"It did not exist in iOS 6" describes the change history the release had no
seam for either - it built one at every release update. Building one here out
of two snapshots and a diff is the same act.

Source: the headers of SDK 16.4 for the declarations; `Contacts` of the arm64
shared cache of iOS 12.0 for the shape of the classes; `AddressBook` of the
armv7 shared cache of 6.1.3 for what the store underneath can and cannot
answer.

## The journal

`CharonContactsHistory` snapshots the book on demand: every contact's
identifier and `kABPersonModificationDateProperty`, and every group's
identifier, name and sorted member identifiers. A snapshot is written as a
generation - a UUID-named plist under `Application Support/CharonContacts/History`
- and `currentHistoryToken` is an opaque `NSData` (`NSKeyedArchiver` over the
generation's name) naming exactly that snapshot. Only the most recent 24
generations are kept; writing a new one prunes the oldest.

`-enumeratorForChangeHistoryFetchRequest:error:` takes the snapshot the
request's `startingToken` names, takes a fresh snapshot of the book as it
stands now, and diffs the two:

- a contact absent from the old snapshot and present in the new one is a
  `CNChangeHistoryAddContactEvent`;
- a contact present in both whose `kABPersonModificationDateProperty` differs
  is a `CNChangeHistoryUpdateContactEvent`;
- a contact present in the old snapshot and absent from the new one is a
  `CNChangeHistoryDeleteContactEvent`;
- when `includeGroupChanges` is set, a group is diffed the same way by
  identifier and name, and its membership is diffed by set difference into
  `CNChangeHistoryAddMemberToGroupEvent`/`..RemoveMemberFromGroupEvent`, one
  per member gained or lost by a group present in both snapshots.

The call then writes a new generation of the current state and hands its
token back as the result's `currentHistoryToken`, so the next call chains
from exactly where this one left off.

`currentHistoryToken` read on its own (not through the enumerator) takes a
fresh snapshot, writes it as a new generation, and returns its token - it
does not need to diff anything, only to name a point an application can ask
to diff from later.

## The honest boundaries

- **History begins with the first snapshot.** A `nil` `startingToken` answers
  a `CNChangeHistoryDropEverythingEvent` followed by an add event for every
  contact already in the book, the same shape the release itself answers on
  an application's first call - there is no history before the first
  snapshot, on this port or on the release.
- **A token this journal no longer holds is invalid, not silently empty.**
  Once its generation is pruned - or if the token was never one this journal
  minted - `enumeratorForChangeHistoryFetchRequest:error:` answers
  `CNErrorCodeChangeHistoryInvalidAnchor` rather than fabricating a
  diff against nothing.
- **Two changes between two snapshots collapse into one event.** A contact
  edited twice between one call and the next reports one
  `CNChangeHistoryUpdateContactEvent`, not two - the same way a release that
  is asked to diff two points spanning several edits would.
- **An add and an update inside the same second can collapse into just the
  add.** `kABPersonModificationDateProperty` is the only signal this journal
  has for "changed since the last snapshot", and on the release it carries
  whole seconds. Measured on real hardware (iPad 2, 6.1.3): a contact added
  and then updated inside the same second snapshots with the same
  modification date both times, so the second diff sees no change and
  answers no `CNChangeHistoryUpdateContactEvent` for it - the add already
  reported the contact in its current, already-updated form, so nothing is
  silently lost, but an application counting on one event per save should
  not expect one for an edit that lands in the same second as the add.
- **A record the journal never saw cannot be reported deleted.** Deleting a
  contact or group that came and went between two snapshots this journal
  actually took produces no event at all, since neither snapshot ever named
  it.
- **A removed member whose own contact was deleted is reported once, not
  twice.** `CharonContactsHistory` needs the member's `ABRecordRef` to build
  the `CNContact` a `CNChangeHistoryRemoveMemberFromGroupEvent` carries; if
  the contact itself is gone, only its own `CNChangeHistoryDeleteContactEvent`
  is reported, not a separate membership event for the same disappearance.
- **`excludedTransactionAuthors` has no effect.** `AddressBook` attributes no
  author to a change - there is no seam that names who made an edit - so
  every event this port produces has a `nil` `transactionAuthor`, and a
  request that tries to exclude one excludes nothing. This is a boundary of
  what iOS 6 can answer, not this port pretending to filter.
- **Groups have no modification date property in `AddressBook`.** A group's
  identity for the diff is its name and member set; a change to neither is
  invisible to this journal, the same way a release watching only those two
  facts would see nothing either.

## CNFetchResult

A plain generic container of a `value` and a `currentHistoryToken`.
`-[CNContactStore enumeratorForContactFetchRequest:error:]` (also iOS 13)
runs the same fetch `unifiedContactsMatchingPredicate:keysToFetch:error:`
already does, wraps the result array in an `NSEnumerator`, and hands it back
inside a `CNFetchResult` whose `currentHistoryToken` is `nil` - that fetch
reads the book directly and needs no point in the journal to name.
`enumeratorForChangeHistoryFetchRequest:error:` instead hands back the new
generation's token, so the two enumerators differ exactly where the release's
own do: one names a point in history, the other does not need to.

## CNChangeHistoryEvent and its subclasses

The base class and its eleven documented subclasses exist with their
documented readonly properties and `-acceptEventVisitor:`, which dispatches
to the matching `CNChangeHistoryEventVisitor` method (the optional
group/subgroup visit methods are dispatched only when the visitor implements
them, matching the `@optional` methods of the real protocol).
`CharonContactsHistory` constructs nine of them - every one but
`CNChangeHistoryAddSubgroupToGroupEvent` and `..RemoveSubgroupFromGroupEvent`.

`CNChangeHistoryAddSubgroupToGroupEvent` and `..RemoveSubgroupFromGroupEvent`
are carried as classes because the real SDK declares them for iOS (only the
`CNSaveRequest` methods that would produce them, `addSubgroup:toGroup:`/
`removeSubgroup:fromGroup:`, are marked `API_UNAVAILABLE(ios)`);
`AddressBook` has no group-nesting API either way, so this is a class that
exists and is simply never instantiated, on this port as on the real release.
