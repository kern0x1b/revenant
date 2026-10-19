# What iOS 10 added to the pasteboard: the four questions, and the one method that is not carried

Introduced in iOS 10.0: `-[UIPasteboard hasStrings]`, `hasURLs`, `hasImages`, `hasColors`, `-setItems:options:`, the
option keys `UIPasteboardOptionLocalOnly` and `UIPasteboardOptionExpirationDate`, and the type `UIPasteboardTypeAutomatic`.

Source: UIKit of the armv7s cache of iOS 10.3.4 and the Pasteboard framework it calls, read for what the methods do;
UIKit of iOS 6.1.3 armv7, read for what the release already has; and the host's own UIKit under Mac Catalyst, run over
`device/pasteboard10-cases.m` by `host/pasteboard10/run.sh`.

## The four questions

- What the release asks: the four `has...` answers are in `UIPasteboard`'s concrete subclass, `_UIConcretePasteboard`;
  the base class answers NO. Each asks a helper for the collection of the pasteboard's items, which for the general
  pasteboard is fetched from the pasteboard service and waited for on a semaphore, and asks that collection
  `-canInstantiateObjectOfClass:` with `NSString`, `NSURL`, `UIImage` or `UIColor`. The collection is the Pasteboard
  framework's `PBItemCollection`, which asks each `PBItem` in turn. So the question is not "which type identifiers are
  on the pasteboard" but "can the pasteboard hand me one of these four".
- What iOS 6 has for it: that same question, without the framework and the service. `UIKit` of 6.1.3 exports
  `UIPasteboardTypeListString`, `UIPasteboardTypeListURL`, `UIPasteboardTypeListImage` and `UIPasteboardTypeListColor`,
  the four lists of type identifiers the release's own `-strings`, `-URLs`, `-images` and `-colors` read items through,
  and `-containsPasteboardTypes:` answers whether any item carries one of a list's types. The port answers each `has...`
  with `-containsPasteboardTypes:` over the list of its own kind, so it is the release asking itself the question its
  own accessors would ask.
- What was measured. The host's answers for the thirteen cases of `device/pasteboard10-cases.m` are in
  `device/pasteboard10-expectations.h`; each case records the four predicates beside whether the four object accessors
  return anything. In all thirteen the two halves agree on the host: nothing it can hand over is missed by the
  predicate, and nothing the predicate claims is missing from the accessors. Worth naming among them: a
  `NSURL` on the pasteboard answers YES to both `hasURLs` and `hasStrings`, because a URL is written as text as well; a
  string that reads as a URL answers YES to `hasURLs` too; an image set over a string replaces it, since both take item
  zero, and only `hasImages` stays; bytes under a type of the application's own answer NO to all four.
- Where it can differ from iOS 10 and cannot be closed here: `PBItemCollection` decides from type identifiers the
  service holds, and its decision follows the conformance of those identifiers. Where an item is written under a type of
  the application's own that *conforms* to `public.image` or `public.text`, iOS 10 can still instantiate the object and
  the release's list, which names identifiers, does not reach it. Such an item is answered NO here and YES there. It is
  the release's own limit, the same one its `-images` and `-strings` have, and not a guess of the port's: what the port
  answers is exactly what the pasteboard of this release can hand over.

## The method, and what it promises that this release cannot keep

- `-setItems:options:` rebuilds the items as representations with loader blocks, checks their values, and passes them with
  the options to `-_setItemsAndSave:options:`, which sets the collection's local-only flag and its expiration date from
  `UIPasteboardOptionLocalOnly` and `UIPasteboardOptionExpirationDate`, checking that they are an `NSNumber` and an
  `NSDate`, and saves the collection through the service. An expiration has to clear the pasteboard when the date comes,
  after the application that set it has gone, which only the service can do; password managers rely on it. A port in the
  application's process cannot keep that promise.
- The port therefore CARRIES `-setItems:options:`, as a category over the release's own class, and the promise it cannot
  keep is stated in the row's effect instead of being hidden: the items go to the release's own `-setItems:`, the two
  option keys are read and recorded against the pasteboard, and neither is applied. An application that needs an item
  to expire, or to stay off other devices, gets the release's behaviour and not the service's - which is what calling a
  release API could only have given it anyway.
- `UIPasteboardTypeAutomatic` is the type identifier `com.apple.uikit.type-automatic`, which the release's own
  `-setItems:options:` reads to choose a representation by the class of the value. The port's category does not read it,
  because the port's method hands its items to the release's plain `-setItems:`; the identifier is still exported, and
  what the port's member does with a value of that type is what the release's storer does with it.

## The type lists, and how many entries each holds

`tests/backports/device/pasteboard10.m` walks the four list symbols and proves each is the release's own; it now also reads each one through its `dlsym` address, checks that it is a non-empty array, and prints its count beside the provenance line. The run that quotes those counts has NOT happened yet - the emulated session is a separate round - so nothing in the registry claims a number. The port's rule does not need one: `-[UIPasteboard setObjects:]` stores under the first entry because the port answers only for the type it was given, which is the only choice when a list holds one entry and leaves the rest untouched when it holds several. When the run happens the counts land here and in the row, and the rule stands either way.

## The option keys are exported

The two option keys exist as `NSString`s with the system's own values (`expirationDate` and `localOnly`, as `host/tail2/run.sh` reads them), so an application that refers to the symbols directly, without a check of the release, loads and does not read a null pointer. Both are now READ, by the port's `-setItems:options:` and by its `-setObjects:localOnly:expirationDate:`, through `-charonRecordOptions:`, which writes the port's own record and calls no storer - `-setItems:` sets the board's items, so an empty call made to record the options would empty the board. Their rows moved from `inert` to `implemented` with that same statement in their effect: the keys are read and recorded, and the release applies neither.

What the release does with an item is its own answer. The run above measured a write on an emulated iOS 6.0 being taken and silently lost, with `-setStrings:` the one that raises; it did not measure `-setItems:` and nothing here claims it raises. The port's member hands the items over and does not assert what comes back.

## What the device run reached, and what it could not

`device/pasteboard10.m` on an emulated iOS 6.0 (iPhone3,1, 10A403), as a process of its own:

- All eight provenance checks pass. `-hasStrings`, `-hasURLs`, `-hasImages` and `-hasColors` come from
  `libUIKitBackports.dylib`, and `UIPasteboardTypeListString`, `...URL`, `...Image` and `...Color` come from the
  release's own UIKit, which is the point: the port answers the question and the release supplies the lists.
- `+pasteboardWithUniqueName` answers a pasteboard, and an empty one reads `0000 | 0000` - the four predicates and
  the four accessors agree with the host.
- Everything the test *writes* comes back empty. A process with no application does not reach the pasteboard
  store on this release: `-setString:`, `-setURL:`, `-setImage:` and `-setColor:` take without complaint and
  nothing is there afterwards, and `-setStrings:` raises inside UIKit building a dictionary from a store it could
  not read. That is the release's own environment and not the port: the predicate is answered by
  `-containsPasteboardTypes:`, which is the release's, over items the release did not keep.

So the content half of the cases needs an application, or a device, and is not carried by the emulated run. The
test reports the exception instead of dying on it, so what was reached and what was not is legible in the output
rather than a signal.
