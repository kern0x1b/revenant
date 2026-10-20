# The volume keys of iOS 11.0

Introduced in iOS 11.0: four resource keys of a volume - the capacity available
for important and for opportunistic use, and whether it can hold immutable files
and POSIX permissions. A program reads them through
`-getResourceValue:forKey:error:` and `-resourceValuesForKeys:error:`, methods
every release has and whose answers are the release's own.

Source: the SDK 16.4 header `NSURL.h` for what each key means, the host's
Foundation for the strings, and an iPad 2 running 6.1.3 for what that release does
with a key it does not know.

## What iOS 6 does with an unknown key

Measured on the device with the four names and with a name no release has: the
call answers **success**, with no value and no error, and `-resourceValuesForKeys:`
leaves the key out of its dictionary. A known key beside them
(`NSURLVolumeAvailableCapacityKey`, `NSURLVolumeTotalCapacityKey`) answers its number.
So an application that reads an unknown key gets `nil`, and `nil` turns into 0 through
`-longLongValue` and into NO through `-boolValue`.

That is why the keys are not simply declared. A key that is only a name would tell an
application it has no room to save anything.

## What is carried

`NSURLVolumeAvailableCapacityForImportantUsageKey` is the capacity available for
resources the user expects to be there: the header says it includes the space the
system expects to clear by purging what is cached, and on the host the two differ by
what is purgeable. A release with nothing purgeable answers the capacity that is
available, so on iOS 6 the two are one number, and the constant carries the **string of
`NSURLVolumeAvailableCapacityKey`**, which the release answers. The application asks
for a key by the constant and the release answers the available capacity. The string
is the one departure: on the host the constant is its own name.

The other three keys are carried under their own names, as on the host, and the
release answers nothing for them:
- `NSURLVolumeAvailableCapacityForOpportunisticUsageKey` is the capacity left after
  what the system keeps for itself, and how much that is was not measured, so it is
  not made up; `nil`, read as 0, is the answer that makes an application download
  nothing on its own account.
- `NSURLVolumeSupportsImmutableFilesKey` and `NSURLVolumeSupportsAccessPermissionsKey`
  read as NO, which the release's volumes are not known to contradict, and which is
  what a volume with neither reads as.
