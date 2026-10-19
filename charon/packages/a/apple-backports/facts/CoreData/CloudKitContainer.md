# NSPersistentCloudKitContainer on a release with no CloudKit

Source: the CoreData headers of SDK 16.4 for the declarations, and the host's
own CoreData, read at run time, for the value of
`NSPersistentStoreRemoteChangeNotificationPostOptionKey`
(`NSPersistentStoreRemoteChangeNotificationOptionKey`). Nothing of a release was
read for the mirroring itself: no release this port runs on has CloudKit, so
there is nothing there to compare against, and what the container does with a
record is the newest documentation's, not a measurement.

## Why the class is carried rather than left out

An application that links `NSPersistentCloudKitContainer` carries a strong
reference to the class symbol, so a missing class is not a method that fails -
it is a process that does not start. The demand corpus finds it exactly that
way, as a load failure rather than a crash on use. The class is therefore
present.

It is present as a real container, not as a stub. `NSPersistentCloudKitContainer`
is a subclass of `NSPersistentContainer`, which this package already carries in
full, and it inherits every bit of it: the model is found by name, the store
descriptions are built, `loadPersistentStoresWithCompletionHandler:` loads the
stores, and `viewContext` and `newBackgroundContext` work as they do on the
plain container. An application that uses the CloudKit container for what it
mostly is - a container - gets a container that works, and its data is written
and read on the device exactly as Core Data writes and reads it.

## What is not there

- **Nothing is mirrored.** No record leaves the device, none arrives, and there
  is no CloudKit container behind the identifier. The first container made says
  so once in the log.
- `NSPersistentCloudKitContainerOptions` keeps the identifier it was made with
  and hands it back, and nothing reads it.
- `NSPersistentStoreDescription.cloudKitContainerOptions` keeps the options and
  reads them back. They are held beside the description with an associated
  object rather than inside it, because the description is an iOS 10 object of
  this package and its members belong to that release; the visible difference is
  that `-copy` gives a description with no options, where the release's copy
  carries them.
- `databaseScope` is absent. It names which CloudKit database a store mirrors
  into, nothing here mirrors, and its type is CloudKit's own `CKDatabaseScope`,
  which this release has no framework for.
- `NSPersistentStoreRemoteChangeNotificationPostOptionKey` exists and is
  accepted in a store's options, and changes nothing: no store here watches for
  changes made by another process, so `NSPersistentStoreRemoteChangeNotification`
  is never posted. That is what the entry of the notification itself already
  says, and this key does not change it.

The schema initialiser, the record and record-ID lookups, the share API and the
`NSPersistentCloudKitContainerEvent` machinery of iOS 14 are not carried: each
needs a CloudKit database to answer from.
