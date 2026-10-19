# The photo picker, iOS 14.0

`PHPickerViewController` came in iOS 14.0: a view controller that shows the photo library out of the application's
process, with nothing of the library asked for first, and reports what the user chose to a delegate as `PHPickerResult`s, each an
`NSItemProvider`. `PHPickerConfiguration` says what is wanted (a filter, how many, how it is represented) and `PHPickerFilter` names the kinds.

Source: the header of PhotosUI of iOS 16.4 for the contract; for what the release can do, `UIImagePickerController` of iOS 6, on an iPad 2 and
an iPhone 4S running 6.1.3, from an application that presents the picker. The picker of iOS 14 was not read from a cache, which
holds it in a service the release does not have. The application that presents the picker was run on an iPhone 4S and, with the iPad idiom, on an iPad 2.

## What it is

The controller shows the library and, when the user chooses, calls the delegate's `picker:didFinishPicking:` with one result for each
chosen item, or with none when the user cancels; it does not dismiss itself. A result holds an item provider that offers the item as
a file or as data of the type it has, and an `assetIdentifier` when the configuration was made with a library.

## Where iOS 6 differs

The release has `UIImagePickerController`, which shows the library and chooses one item, and that is what is carried: the controller
of this package holds one as a child, for the media types the filter names, and turns its answer into the answer of the picker.

- One item at most: `selectionLimit` is kept, and a limit of more than one, or of 0 for no limit, is answered with the one item the
  release lets a user choose.
- The filters that mean images or videos or both are carried. A filter of live photos matches nothing of iOS 6, so the picker does not show
  the library and calls the delegate with no results once it has appeared, as a picker the user cancels does. The filters of iOS 15 and 16 (screenshots,
  panoramas, slow motion, bursts, depth effect, cinematic, the playback style, and the combinations that need them) are absent, as are the selection
  of iOS 15 and the preselected identifiers, which the release cannot show.
- An image is offered as `public.jpeg`, or as `public.png`, `com.compuserve.gif` or `public.tiff` when the address of the item says that is what it
  is; its data is made from the image the release's picker gives, so a JPEG is encoded again, at the highest quality, and is not the file of the library. A
  video is offered as the file the release's picker made, in place, under `com.apple.quicktime-movie`, `public.mpeg-4` or `public.movie`.
- `assetIdentifier` is nil, whatever the configuration was made with.
- On the iPad the controller is shown in a popover or presented modally, and both work: the release's picker was presented modally on an iPad 2 without
  an exception, so nothing is asked of the application beyond what it does for the picker of iOS 14.

The delegate is called on the main thread, once. `-deselectAssetsWithIdentifiers:` and `-moveAssetWithIdentifier:afterAssetWithIdentifier:` of iOS 16 are absent.
