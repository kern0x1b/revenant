# Merging a remote save, iOS 9.0

`+[NSManagedObjectContext mergeChangesFromRemoteContextSave:intoContexts:]` takes the dictionary a save leaves behind
(the object IDs, or their URLs, under `NSInsertedObjectsKey`, `NSUpdatedObjectsKey`, `NSDeletedObjectsKey`,
`NSRefreshedObjectsKey`, `NSInvalidatedObjectsKey`, `NSInvalidatedAllObjectsKey`) and merges it into each context.
It is how the objects of a context are brought up to date after a batch update or a batch delete, which change the
store and leave the contexts as they were.

Source: CoreData of the arm64 shared cache of iOS 12.0, where the method hands its two arguments to
`+_mergeChangesFromRemoteContextSave:intoContexts:`, a selector the release iOS 6 has as well; the host's Core Data,
asked for every case below, and held to the same expectations on an iPad 2 running 6.1.3 (`tests/backports/device/coredata9merge.m`).

## What it does

An updated object the context holds is refreshed with the changes merged, so an edit the context made and has not saved is
kept and still a change; an object the IDs do not name is left alone; a URL names an object as its ID does. A deleted object
is marked deleted. The context posts its did change notification, with `updated` and `refreshed` for the first and
`deleted` for the second, before the method returns. An empty or `nil` dictionary and an empty array of contexts change
nothing and do not raise.

## Where iOS 6 answers differently

iOS 6 posts the notification when the context next processes its changes, so the port asks the context to process them
on its queue after the merge; the notification has no `NSObjectsChangedByMergeChangesKey`, which the newest release adds.
