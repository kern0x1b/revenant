# The measured constants of the 31 objects (tools/corpus/cfconst.tsv)

The rows of `tools/corpus/cfconst.tsv` are the constants that the committed objects defined before this table existed:
31 objects in seven frameworks, 558 declarations. `tools/gen/measured.lua` writes each object into `.gen/<Framework>/`
at `gen` time, so no object of these is committed. Each row is one declaration: its object, the headers the object
imports, the release and architecture of the dyld cache its value was read from (`cache`), the declared type, the
name, and the initializer as the object carried it (a `@"..."` string, a `CFSTR("...")` string, a number, or the
struct `{ -2, 0, 0 }` of HKSourceRevisionAnyOperatingSystem, whose three words the caches hold, see HKConstants110).

The check that the values are what the caches hold is `tools/corpus/cfconst-check.lua`: for each row it reads the
symbol out of its named cache through `tools/corpus/cache-value.lua`, which goes through the project's reader
(`modules/apple/dyld.lua`), and compares what the cache holds with the initializer: a string by its text, a number by
its float32 bits, and a struct field by field, one word per field at the cache's pointer size. A row whose field, or
whose string, differs from the cache fails the check; there is no pin. A row the reader cannot judge is reported by
name.

Regenerate and check:

    xmake l tools/gen.lua gen --framework <Framework>          # writes .gen/<Framework>/<Object>.m
    REVENANT_ROOT=$PWD xmake l tools/corpus/cfconst-check.lua    # reads the caches named in the table

The prose below is each object's own header comment, as the object carried it before the table existed. Where it names
the reader, that is `tools/corpus/cache-value.lua`, the reader the check runs, and the release is the cache the row's
`cache` column names.

## ContactsRelationLabels110

The CNLabel names of iOS 11.0, with the texts Contacts itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/Contacts/Values.md).

One file for the one release these arrived in: an object carries the API of a single release. The armv7
ladder measures CNLabelContactRelationDaughter of them first appearing in the cache of iOS 11.0, which is the release the object is
carried from.

The text is the release's own and is not a spelling of the symbol: a label the release never made and this
port never stores is still the name a dictionary of the release's own book is keyed by when a caller writes
one, and it is what facts/Contacts/Values.md records.

## ContactsRelationLabels130

The CNLabel names of iOS 13.0, with the texts Contacts itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/Contacts/Values.md).

One file for the one release these arrived in: an object carries the API of a single release. The armv7
ladder measures CNLabelContactRelationAunt of them first appearing in the cache of iOS 16.0, which is the release the object is
carried from.

The text is the release's own and is not a spelling of the symbol: a label the release never made and this
port never stores is still the name a dictionary of the release's own book is keyed by when a caller writes
one, and it is what facts/Contacts/Values.md records.

## ContactsRelationLabels140

The CNLabel names of iOS 14.0, with the texts Contacts itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/Contacts/Values.md).

One file for the one release these arrived in: an object carries the API of a single release. The armv7
ladder measures CNLabelContactRelationGranddaughterOrNiece of them first appearing in the cache of iOS 16.0, which is the release the object is
carried from.

The text is the release's own and is not a spelling of the symbol: a label the release never made and this
port never stores is still the name a dictionary of the release's own book is keyed by when a caller writes
one, and it is what facts/Contacts/Values.md records.

## ContactsRelationLabels143

The CNLabel names of iOS 14.3, with the texts Contacts itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/Contacts/Values.md).

One file for the one release these arrived in: an object carries the API of a single release. The armv7
ladder measures CNLabelPhoneNumberAppleWatch of them first appearing in the cache of iOS 16.0, which is the release the object is
carried from.

The text is the release's own and is not a spelling of the symbol: a label the release never made and this
port never stores is still the name a dictionary of the release's own book is keyed by when a caller writes
one, and it is what facts/Contacts/Values.md records.

## CoreDataNames100

The CoreData names of iOS 10.0, with the texts CoreData itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/CoreData/Names.md).

One file for the one release these arrived in: an object carries the API of a single release.

The text is the release's own and is NOT the name of the symbol, and that is the whole point of reading
it: the userInfo keys of the object-ID notifications are inserted_objectIDs and its four siblings, the
query generation key is newQueryGeneration and the pool key NSPersistentStoreConnectionPoolMaxSize, while
the five ubiquitous names of 7.0 are their own. A spelling of the constant would be a key that the
release never fills and no release ever reads.

## CoreDataNames103

The CoreData names of iOS 10.3, with the texts CoreData itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/CoreData/Names.md).

One file for the one release these arrived in: an object carries the API of a single release.

The text is the release's own and is NOT the name of the symbol, and that is the whole point of reading
it: the userInfo keys of the object-ID notifications are inserted_objectIDs and its four siblings, the
query generation key is newQueryGeneration and the pool key NSPersistentStoreConnectionPoolMaxSize, while
the five ubiquitous names of 7.0 are their own. A spelling of the constant would be a key that the
release never fills and no release ever reads.

## CoreDataNames140

The CoreData names of iOS 14.0, with the texts CoreData itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/CoreData/Names.md).

One file for the one release these arrived in: an object carries the API of a single release.

The text is the release's own and is NOT the name of the symbol, and that is the whole point of reading
it: the userInfo keys of the object-ID notifications are inserted_objectIDs and its four siblings, the
query generation key is newQueryGeneration and the pool key NSPersistentStoreConnectionPoolMaxSize, while
the five ubiquitous names of 7.0 are their own. A spelling of the constant would be a key that the
release never fills and no release ever reads.

## CoreDataNames170

The CoreData names of iOS 17.0, with the texts CoreData itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/CoreData/Names.md).

One file for the one release these arrived in: an object carries the API of a single release.

The text is the release's own and is NOT the name of the symbol, and that is the whole point of reading
it: the userInfo keys of the object-ID notifications are inserted_objectIDs and its four siblings, the
query generation key is newQueryGeneration and the pool key NSPersistentStoreConnectionPoolMaxSize, while
the five ubiquitous names of 7.0 are their own. A spelling of the constant would be a key that the
release never fills and no release ever reads.

## CoreDataNames180

The CoreData names of iOS 18.0, with the texts CoreData itself gives them, read out of the arm64e
shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/CoreData/Names.md).

One file for the one release these arrived in: an object carries the API of a single release.

The text is the release's own and is NOT the name of the symbol, and that is the whole point of reading
it: the userInfo keys of the object-ID notifications are inserted_objectIDs and its four siblings, the
query generation key is newQueryGeneration and the pool key NSPersistentStoreConnectionPoolMaxSize, while
the five ubiquitous names of 7.0 are their own. A spelling of the constant would be a key that the
release never fills and no release ever reads.

## CoreServicesNames80

The names CoreServices added in iOS 8.0, with the texts CoreServices itself gives them, read out
of the arm64e shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/CoreServices/Names.md).

One file for the one release these arrived in: an object carries the API of a single release, and the
armv7 ladder measures this name first appearing in the cache of iOS 8.0.

The text is the release's own and is not a spelling of the symbol: a uniform type identifier is what a
file's type is compared by, and a spelling of the constant would be a different type.

## CoreServicesNames90

The names CoreServices added in iOS 9.0, with the texts CoreServices itself gives them, read out
of the arm64e shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/CoreServices/Names.md).

One file for the one release these arrived in: an object carries the API of a single release, and the
armv7 ladder measures this name first appearing in the cache of iOS 9.0.

The text is the release's own and is not a spelling of the symbol: a uniform type identifier is what a
file's type is compared by, and a spelling of the constant would be a different type.

## CoreServicesNames91

The names CoreServices added in iOS 9.1, with the texts CoreServices itself gives them, read out
of the arm64e shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/CoreServices/Names.md).

One file for the one release these arrived in: an object carries the API of a single release, and the
armv7 ladder measures this name first appearing in the cache of iOS 9.1.

The text is the release's own and is not a spelling of the symbol: a uniform type identifier is what a
file's type is compared by, and a spelling of the constant would be a different type.

## NSProgress+Keys6

The five NSProgress userInfo keys the release exports from 6.0 (armv7 caches of 6.0-6.1.6: absent; of 7.0: exported, and
unchanged in the arm64 caches through 18.0, each the string of its own name, read through tools/corpus/cache-value.lua against the
12.0 arm64 cache's Foundation), kept apart from NSProgress+Additions.m's own two constants (7.0, 6.0) so no object mixes a
release its symbols are present at with one they are not (modules/apple/backports.lua's band(), "split it").

## HKConstants8

The 110 exported constants iOS 8 added, with the values HealthKit itself gave them.

Every value below was read out of the armv7 shared cache of iOS 8.0, not assumed: each constant is followed through
its export in the HealthKit image of that cache to the __cfstring that export points at, so what is written here is
the string that release held (~/.revenant/dyld/8.0/dyld_shared_cache_armv7, HealthKit.framework). The reader is
tools/corpus/cache-value.lua, run on the cache. A name
iOS 8.0 exported that the SDK headers do not declare is Apple's private and is not here; a name
the SDK declares that iOS 8.0 did not have came later and is carried in the group of its own
release. The declaration of each is the SDK's own.

## HKConstants82

The exported constants iOS 8.2 added, with the values HealthKit gave them.

Every value below was read out of a release's own image, not assumed: each constant is followed through its export
in that image to the __cfstring it points at. The reader is tools/corpus/cache-value.lua, run on the cache.

HKPredicateKeyPathDateComponents is here and not in the group of 9.3, and that is a measurement
rather than a reading of the header: the SDK header this library is compiled against dates it 9.3, and
the armv7 shared cache of iOS 8.2 exports _HKPredicateKeyPathDateComponents while the one of 8.0 does
not. It is the key path the two activity-summary predicates of HKQuery are built over, and
HKActivitySummary answers it. Where the header and a release's own image disagree, the release is the
one that is right (COORDINATION section 5).

Nine more names arrived in that release and are not here: HKDailyBriskMinutesGoal,
HKDailyStandingHoursGoal, HKFirstDayOfWeekForWeeklyGoalCalculations, HKHealthAppSourceEntitlement,
HKLogSafeBundleIdentifier, HKLogSafeDescription, HKOperatorTypeInArray, HKSourceOptionsForAppleDevice
and HKStackshotWriteWithReason are exported by the 8.2 image and declared by no public header, so
they are Apple's private and this port does not carry them.

## HKConstants90

The 22 exported constants iOS 9.0 added, with the values HealthKit gave them.

Every value below was read out of the armv7 shared cache of iOS 9.0, not assumed: each constant is followed through
its export in the image to the __cfstring it points at, so what is written here is the string that release held.
The reader is tools/corpus/cache-value.lua, run on the cache.

The declaration of each is the SDK's own.

## HKConstants93

The two exported constants iOS 9.3 added, with the values HealthKit gave them.

Read out of the armv7 shared cache of iOS 9.3, not assumed: each constant is followed through its export in the
HealthKit image to the __cfstring it points at. This is the exercise-time type the ring's exercise
ring is counted in, and it is the one constant the release of 9.3 added. The reader is
tools/corpus/cache-value.lua, in the repository, run on the cache.

HKPredicateKeyPathDateComponents - the path the two activity-summary predicates are built over -
is NOT here and the reason is worth a line: the SDK header this library is compiled against dates it
9.3, and the armv7 shared cache of iOS 8.2 exports it while the one of 8.0 does not, so it arrived in
8.2 and is in HKConstants82.m. Where the header and a release's own image disagree, the release is
the one that is right (COORDINATION section 5).

## HKConstants100

The 20 exported constants iOS 10.0 added, with the values HealthKit gave them.

Read out of the arm64 shared cache of iOS 10.0.1, the first HealthKit image this workspace holds
that has all of them: there is no 10.0 or 10.0.1 armv7 cache, and the armv7s slice's data pointers are
tagged, so a 32-bit reading of that one does not give the strings. The reader is tools/corpus/cache-value.lua, run on
the cache, with the symbols in a file of their own (a name, a width, a pointer flag and a string flag per line):

  printf 'HKDocumentTypeIdentifierCDA\tp\tp\ts\n' > .agent-work/runs/hk100-symbols.tsv
  REVENANT_ROOT=$PWD xmake l tools/corpus/cache-value.lua ~/.revenant/dyld/10.0.1/dyld_shared_cache_arm64 \
      .agent-work/runs/hk100-symbols.tsv

Twelve of the twenty hold a string that is not their own name, which is the reason the values are
read rather than written, and they are: HKMetadataKeyLapLength is "HKLapLength",
HKMetadataKeyWeatherCondition is "HKWeatherCondition", HKMetadataKeyWeatherHumidity and
HKMetadataKeyWeatherTemperature are "HKWeatherHumidity" and "HKWeatherTemperature",
HKMetadataKeySwimmingLocationType and HKMetadataKeySwimmingStrokeStyle are
"HKSwimmingLocationType" and "HKSwimmingStrokeStyle", HKPredicateKeyPathCDAAuthorName,
HKPredicateKeyPathCDACustodianName and HKPredicateKeyPathCDAPatientName are "author_name",
"custodian_name" and "patient_name", HKPredicateKeyPathCDATitle is "title", and
HKPredicateKeyPathWorkoutTotalSwimmingStrokeCount and HKWorkoutSortIdentifierTotalSwimmingStrokeCount
are both "totalSwimmingStrokeCount". The other eight hold their own names, among them
HKDocumentTypeIdentifierCDA, which holds "HKDocumentTypeIdentifierCDA" - three sources agree on that
one, the image, the host's own dlsym and this line, and an earlier version of this comment claimed
otherwise.

The declaration of each is the SDK's own.

## HKConstants110

The 18 exported constants iOS 11.0 added.

Seventeen of the eighteen were read out of the arm64 shared cache of iOS 11.0 through
tools/corpus/cache-value.lua, each constant followed through its entry in that cache's symbol table to the
__cfstring it points at, so what is written here is the string that release held. Several of them are
not their own names, which is the reason they are read rather than written.

The eighteenth, HKSourceRevisionAnyOperatingSystem, is read field by field. The SDK header declares it

    HK_EXTERN NSOperatingSystemVersion const HKSourceRevisionAnyOperatingSystem

a struct of three integers. The symbol's 24 bytes, read by tools/corpus/cache-value.lua at width 24 (three
pointer-sized words, the storage of the symbol not bounded by the reader), are in the arm64 shared cache of 11.0
and of 12.0 the three words -2, 0 and 0: the first word is 0xfffffffffffffffe, the second and third are zero.
Two releases agree, so this is not one slice's artefact. The object carries those three words as the value
`{ -2, 0, 0 }`, and tools/corpus/cfconst-check.lua compares each field with its word. The header's comment above
all three names says they match any value of the property; the -2 is consistent with that, and the facts take no
further reading of it.
An earlier reading called the first word a tagged CFString; that was wrong, and the three words above are what
the reader returns.

## HKConstants120

The twenty-seven exported constants the held ladder first sees exported by iOS 12.0.

Fourteen of them hold a value that is not the constant's own name - a key path, a metadata key or an
FHIR type name - and the seven that hold their own name are the clinical type identifiers of that
release. The value of each was read out of the arm64 shared cache of iOS 12.0 through the HealthKit
image's own export trie, and each is what that release's image holds rather than what the name
suggests: HKMetadataKeyCrossTrainerDistance is `HKCrossTrainerDistance`, HKPredicateKeyPathSum is
`quantity`, and the seven identifiers hold their own names. Two controls read the same way:
HKQuantityTypeIdentifierStepCount and HKErrorDomain answer as real strings (`com.apple.healthkit`),
and a name the image does not export is reported by name.

The reader is tools/corpus/cache-value.lua, in the repository, which reads a 64-bit image's stored pointers in 64-bit
words and keeps the 36 address bits of each, dropping the chain bits the slide info keeps above them (0x2 in a
variable of __DATA,__const, 0x4 in the isa of an __cfstring), and adds the cache's base when the result lies in no
mapping. A 32-bit read of such a variable stops with "address ... is in no mapping". The declaration of each constant is the SDK's own, in
HKClinicalType.h, HKFHIRResource.h, HKMetadataEnums.h and HKDefines.h of iOS 16.4 and of iOS 26.2,
each with API_AVAILABLE(ios(12.0), ...).

Six more are here than the twenty-one that release's header names, and the reason is a measurement.
dyld.first_releases() over the held ladder answers 12.0 for six constants the headers mark 11.2 -
HKMetadataKeyAlpineSlopeGrade, HKMetadataKeyAverageSpeed, HKMetadataKeyElevationAscended,
HKMetadataKeyElevationDescended, HKMetadataKeyMaximumSpeed and
HKQuantityTypeIdentifierDistanceDownhillSnowSports - because the 11.0 image is the rung before 12.0 and
exports none of them and the 12.0 image exports all six, and an object carries the API of one release.
Their rows are filed in ios112.json with the 11.2 their headers say. Five of the six hold a value that is
not their own name - HKMetadataKeyAverageSpeed is `HKAverageSpeed` and HKMetadataKeyAlpineSlopeGrade is
`HKAlpineSlopeGrade` - and each value was read out of the host's HealthKit, per constant in
coordination/corpus/ledger/constant-values-HealthKit.tsv, rather than spelled from the name.

## IOSurfacePropertyNames110

The names IOSurface added in iOS 11.0, with the texts IOSurface itself gives them, read out
of the arm64e shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/IOSurface/Names.md).

One file for the one release these arrived in: an object carries the API of a single release, and the
armv7 ladder measures this name first appearing in the cache of iOS 11.0.

The text is the release's own and is not a spelling of the symbol: a uniform type identifier is what a
file's type is compared by, and a spelling of the constant would be a different type.

## IOSurfacePropertyNames120

The names IOSurface added in iOS 12.0, with the texts IOSurface itself gives them, read out
of the arm64e shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/IOSurface/Names.md).

One file for the one release these arrived in: an object carries the API of a single release, and the
armv7 ladder measures this name first appearing in the cache of iOS 12.0.

The text is the release's own and is not a spelling of the symbol: a uniform type identifier is what a
file's type is compared by, and a spelling of the constant would be a different type.

## IOSurfacePropertyNames140

The names IOSurface added in iOS 14.0, with the texts IOSurface itself gives them, read out
of the arm64e shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/IOSurface/Names.md).

One file for the one release these arrived in: an object carries the API of a single release, and the
armv7 ladder measures this name first appearing in the cache of iOS 14.0.

The text is the release's own and is not a spelling of the symbol: a uniform type identifier is what a
file's type is compared by, and a spelling of the constant would be a different type.

## IOSurfacePropertyNames160

The names IOSurface added in iOS 16.0, with the texts IOSurface itself gives them, read out
of the arm64e shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/IOSurface/Names.md).

One file for the one release these arrived in: an object carries the API of a single release, and the
armv7 ladder measures this name first appearing in the cache of iOS 16.0.

The text is the release's own and is not a spelling of the symbol: a uniform type identifier is what a
file's type is compared by, and a spelling of the constant would be a different type.

## IOSurfacePropertyNames180

The names IOSurface added in iOS 18.0, with the texts IOSurface itself gives them, read out
of the arm64e shared cache of iOS 18.0 through each symbol with tools/corpus/cache-value.lua (facts/IOSurface/Names.md).

One file for the one release these arrived in: an object carries the API of a single release, and the
armv7 ladder measures this name first appearing in the cache of iOS 18.0.

The text is the release's own and is not a spelling of the symbol: a uniform type identifier is what a
file's type is compared by, and a spelling of the constant would be a different type.

## UIKitExportedConstants-7-0

The exported constants that arrived in iOS 7.0, and no others: an object carries the API of one
release, so each release's worth of them is its own file. Every value was read, not chosen -- out
of a real dyld shared cache with tools/corpus/cache-value.lua and out of the host's own UIKit, which agree on
every one both could give; tests/backports/host/uikitconst holds the backport to the host's.

## UIKitExportedConstants-8-0

Correction found by tools/corpus/cfconst-check.lua: UISplitViewControllerAutomaticDimension was written as `-3.40282e+38`, which
is 17 float32 ulps short of the value the 8.0 armv7 cache holds (bits 0xFF7FFFFF, which is -FLT_MAX). The table now carries
`-3.40282346638528859811704183484516925440e+38`, FLT_MAX's exact decimal, which converts to that float32 exactly. The check
judges a number row by the float32 bits of its initializer, so the old spelling could not pass.

The exported constants that arrived in iOS 8.0, and no others: an object carries the API of one
release, so each release's worth of them is its own file. Every value was read, not chosen -- out
of a real dyld shared cache with tools/corpus/cache-value.lua and out of the host's own UIKit, which agree on
every one both could give; tests/backports/host/uikitconst holds the backport to the host's.

## UIKitExportedConstants-9-0

The exported constants that arrived in iOS 9.0, and no others: an object carries the API of one
release, so each release's worth of them is its own file. Every value was read, not chosen -- out
of a real dyld shared cache with tools/corpus/cache-value.lua and out of the host's own UIKit, which agree on
every one both could give; tests/backports/host/uikitconst holds the backport to the host's.

## UIKitExportedConstants-9-1

The exported constants that arrived in iOS 9.1, and no others: an object carries the API of one
release, so each release's worth of them is its own file. Every value was read, not chosen -- out
of a real dyld shared cache with tools/corpus/cache-value.lua and out of the host's own UIKit, which agree on
every one both could give; tests/backports/host/uikitconst holds the backport to the host's.

## UIKitExportedConstants-10-0

The exported constants that arrived in iOS 10.0, and no others: an object carries the API of one
release, so each release's worth of them is its own file. Every value was read, not chosen -- out
of a real dyld shared cache with tools/corpus/cache-value.lua and out of the host's own UIKit, which agree on
every one both could give; tests/backports/host/uikitconst holds the backport to the host's.

## UIKitExportedConstants-11-0

The exported constants that arrived in iOS 11.0, and no others: an object carries the API of one
release, so each release's worth of them is its own file. Every value was read, not chosen -- out
of a real dyld shared cache with tools/corpus/cache-value.lua and out of the host's own UIKit, which agree on
every one both could give; tests/backports/host/uikitconst holds the backport to the host's.
