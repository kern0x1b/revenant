# UIImage as an item provider object, iOS 11.0

iOS 11.0 made `UIImage` read and write itself through `NSItemProvider`: `-[NSItemProvider loadObjectOfClass:completionHandler:]`
with `UIImage` gives an image from what the provider holds, and `registerObject:` writes one.

Source: UIKitCore of the arm64 shared cache of iOS 12.0 - `+[UIImage readableTypeIdentifiersForItemProvider]` at
`0x1accbdc3c`, `+writableTypeIdentifiersForItemProvider` at `0x1accbe0a4`, `+objectWithItemProviderData:typeIdentifier:error:` at
`0x1accbdce8` and `-loadDataWithTypeIdentifier:forItemProviderCompletionHandler:` at `0x1accbe130`, with the type identifiers they build,
read from the image.

## What it is

The readable types are, in order, `com.apple.uikit.image`, `public.png`, `public.tiff`, `com.compuserve.gif` and `public.jpeg`; the
writable ones are `com.apple.uikit.image`, `public.png` and `public.jpeg`. Reading `com.apple.uikit.image` unarchives the data with an
`NSKeyedUnarchiver`; any of the four image types is read with `-initWithData:`, which is nil for data that is not an image; a type that is none
answers nil.

## Where iOS 6 differs

Nothing the release offers replaces it; the methods are carried as they are, over the release's own `-initWithData:` and
`NSKeyedUnarchiver`. Writing gives `UIImagePNGRepresentation` for PNG, `UIImageJPEGRepresentation` at the highest quality for JPEG,
which iOS 12's own quality was not read for, and the archived image for `com.apple.uikit.image`. The error iOS 12 makes for an archive that
does not decode was not read; a decoding exception of the release is answered as `NSCoderReadCorruptError` in `NSCocoaErrorDomain`,
with the reason of the exception.
