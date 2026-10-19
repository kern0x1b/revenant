# `NSItemProvider`'s UniformTypeIdentifiers category, iOS 16

The six members and two properties of `UniformTypeIdentifiers/NSItemProvider+UTType.h`, in
`UIKit/NSItemProviderUTType16.m`.

## What the category is

UniformTypeIdentifiers' own spelling of an API `NSItemProvider` already has. Every selector below is one
the port's own `UIKit/NSItemProvider.m` already implements in its type-identifier spelling:

| UniformTypeIdentifiers | the type-identifier member it is |
| --- | --- |
| `-initWithContentsOfURL:contentType:openInPlace:coordinated:visibility:` | `-initWithContentsOfURL:` |
| `-registerDataRepresentationForContentType:visibility:loadHandler:` | `-registerDataRepresentationForTypeIdentifier:visibility:loadHandler:` |
| `-registerFileRepresentationForContentType:visibility:openInPlace:loadHandler:` | `-registerFileRepresentationForTypeIdentifier:fileOptions:visibility:loadHandler:` |
| `-registeredContentTypes` | `-registeredTypeIdentifiers` |
| `-registeredContentTypesForOpenInPlace` | `-registeredTypeIdentifiersWithFileOptions:` |
| `-registeredContentTypesConformingToContentType:` | `-registeredTypeIdentifiers` filtered by `-conformsToType:` |
| `-loadDataRepresentationForContentType:completionHandler:` | `-loadDataRepresentationForTypeIdentifier:completionHandler:` |
| `-loadFileRepresentationForContentType:openInPlace:completionHandler:` | `-loadFileRepresentationForTypeIdentifier:...` and `-loadInPlaceFileRepresentationForTypeIdentifier:...` |

`UTType` is a wrapper over the same Uniform Type Identifier those take -- `-identifier` *is* the
identifier -- so each of these reduces to its twin with `contentType.identifier` substituted, and the
round trip is the system's own.

There is no second implementation here: the representation store, the conformance test
(`UTTypeConformsTo`), the extension-to-identifier resolution (`UTTypeCreatePreferredIdentifierForTag`) and
the temporary-copy rule of `-loadFileRepresentationForTypeIdentifier:` are the port's existing members
and the release's existing functions.

## The two `openInPlace:` arguments

`NSItemProviderFileOptions`' own enumeration is `NSItemProviderFileOptionOpenInPlace = 1` and no other
case (Foundation/NSItemProvider.h:27-29), so the older API takes the same thing as a one-bit mask and
the `BOOL` the newer header declares is that mask.

`-loadFileRepresentationForContentType:openInPlace:completionHandler:` asks the pair the way the release
answers the question rather than dropping the argument: the release's own in-place member when it is
YES, and a copy out of a temporary file when it is not. The completion block's `openInPlace` parameter is
exactly that distinction -- the header says it "will be set to YES if the file was successfully opened in
place, or NO if a copy of the file was created in a temporary directory" -- and the release's
`-loadInPlaceFileRepresentationForTypeIdentifier:` is what reports YES.

## The initialiser

`NSItemProvider+UTType.h` says the initialiser copies the URL's filename into `suggestedName`, that a nil
`contentType` means "deduce the content type from the file extension", and that `coordinated` asks for
file coordination (which the release's own file reading already uses, and which an openInPlace
registration implies). The provider is built the way `-initWithContentsOfURL:` builds it for the deduced
type, with the content type's own identifier taking its place when one is given, and the visibility and
openInPlace file option registered on it.

## Where this object lives

`UIKit/`, not `Foundation/`: `UTType` is built by `UIKit/UTType.m` into `libUIKitBackports`, and
`libFoundationBackports` links only `icucore`, so a Foundation-folder object calling into `UTType` would
be an undefined symbol at link time. The registry rows are in `registry/UIKit/uttype14.json` beside
`UTType`'s own, and their framework is UniformTypeIdentifiers in the corpus and UIKit here, which is
where every `UTType` row already lives.
