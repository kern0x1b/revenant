# What the picker remembers, iOS 15.0 and 16.0

Four rows: the two properties `PHPickerConfiguration` gained in iOS 15 - `selection` and
`preselectedAssetIdentifiers` - and the two methods `PHPickerViewController` gained in iOS 16,
`deselectAssetsWithIdentifiers:` and `moveAssetWithIdentifier:afterAssetWithIdentifier:`. The
rows are in `registry/PhotosUI/ios15.json` and `registry/PhotosUI/ios16.json`; the code is in
`PHPickerConfiguration15.m` and `PHPickerViewController16.m`, both categories, because the
objects that implement those classes are `PHPickerConfiguration14.m` and
`PHPickerViewController14.m` and an object carries the API of one release only.

Source: `PHPicker.h` of the iOS 16.4 SDK, the SDK this package compiles against, for the four
declarations and the wording beside each; `sdk-26.2-surface.tsv` for the same four by name, kind
and introduced release; and `tests/backports/host/photosui/run.sh`, which asks the host's own
PhotosUI and this port the same 38 questions and compares the answers line for line.

## What the comparison settles, and what it cannot

Thirty-eight questions, and the host's answers and the port's are the same on thirty-four. The
four that are not are questions the host's own implementation does not answer at all: an empty
array and a nil one to `+allFilterMatchingSubfilters:`, a nil one to `+notFilterOfSubfilter:`,
and `PHAssetPlaybackStyleUnsupported` to `+playbackStyleFilter:`. Each of those takes the probe's
process down with it, which is why the probe asks every question in a forked child, and each is
listed with its reason in `tests/backports/host/photosui/stated-differences.tsv`.

So for the two properties, the compared answers are: a configuration starts with the default
selection and with an empty non-nil array of preselected identifiers, and a copy holds the
selection, the identifiers, the limit and the filter that were set on it. That last one is the
part worth having measured: `-[PHPickerConfiguration copyWithZone:]` of the 14.0 object builds a
new configuration and carries three properties across, so a copy made before this file existed
would have dropped the two of iOS 15, and `NSCopying` is a conformance the class declares.

What the comparison cannot settle, and does not pretend to: what a filter *matches*. The header's
API has no query for it, on this port or on the host. That is in `Filters.md`, with the four
questions the host does not answer.

## Where iOS 6 differs

`selection` is kept and read back, and both cases the 16.4 header names behave the same way here:
`Default` and `Ordered` both deliver the one result the release's picker chooses, when the user
chooses it. There is no order to keep in a picker that holds one item, and nothing to deliver
continuously with. The two cases iOS 17 added are not in the header this package compiles
against and are not named; a value outside the ones it knows is kept as given, which is what
`selectionLimit` already does with a limit the release cannot honour.

`preselectedAssetIdentifiers` is kept, copied and read back, and the picker preselects none of
it. The header gives the reason itself: the array "should be an empty array if selectionLimit
is 1 or photoLibrary is not specified", and this port's configuration never names a photo
library - `-initWithPhotoLibrary:` takes one and does not keep it, because iOS 6's library is not
an application's own to name. It could not be honoured if it were set either:
`-[PHPickerResult assetIdentifier]` is nil whatever the configuration was made with, so a
preselected asset could not be recognized when the user chose it, and the header says the item
providers of a preselected asset are empty anyway.

The two methods of iOS 16 do nothing, and that is the case the header names rather than a gap in
the port. Each says "Does nothing if asset identifiers are invalid or not selected, or
photoLibrary is not specified in the configuration"; the last is always true here, and the first
two follow from it. The picker's own results carry no identifier, and the picker holds no
selection to change: `-[UIImagePickerController imagePickerController:didFinishPickingMediaWithInfo:]`
is answered at once and the delegate is called with it, so what the user had chosen is the
delegate call and not a state the picker keeps.

## Where it is proved

`tests/backports/device/phpickermodel.m` calls all four on a real device, as a command-line test
built like a port image: 38 checks, 0 failures on an iPad 2 running iOS 6.1.3 (2026-10-01). The
defaults, the copy, the two selectors and the two calls that change nothing are all measured there.

`tests/backports/device/phpicker.m` asks the picker itself what a composed filter shows - the
release's picker is given the media types the filter names, and reading them back off the child is
the only public way to ask. It is an application, and it is compiled here and not run: this device
has no `/private/var/tmp/sblaunch`, and that part is the coordinator's or the emulator's.
