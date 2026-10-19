# `NSString` and `NSURL` UniformTypeIdentifiers additions, iOS 14

The four methods of `UniformTypeIdentifiers/UTAdditions.h`, in `UIKit/UTAdditions14.m`.

## The rule, and the release's own two halves of it

`UTAdditions.h` gives the rule in full, with worked examples: given a partial filename and a content
type, produce a path component carrying that type's extension, appending the extension only when the one
already there is not valid for the type.

Two questions, both answered by the release:

- **Which extension?** `-[UTType preferredFilenameExtension]`, which is
  `UTTypeCopyPreferredTagWithClass(identifier, kUTTagClassFilenameExtension)` -- the release's own
  function, already called by `UIKit/UTType.m`.
- **Is the extension already there valid for the type?** `-[UTType conformsToType:]` against the type
  the release resolves for that extension, which is `-typeWithFilenameExtension:` and so
  `UTTypeCreatePreferredIdentifierForTag` underneath.

`UIKit/UTTypeDeclarations14.m`'s sibling seam `-charon_conformsToFilenameExtension:` on `UTType` states
that second question once; both categories and `NSItemProviderUTType16.m` go through the same two
release functions rather than each answering it its own way.

## The header's own worked examples

`UTAdditions.h` gives three, and they are the cases the implementation is built around:

| partial name | content type | result |
| --- | --- | --- |
| `readme` | `UTTypePlainText` | `readme.txt` |
| `puppy.jpg` | `UTTypeImage` | `puppy.jpg` (the extension is already valid for the type) |
| `puppy.jpg` | `UTTypePlainText` | `puppy.jpg.txt` (it is not) |

and the failure case: "If the extension could not be appended, this method returns a copy of self." That
is a type with no preferred filename extension, which is what a type the release's database has no tag
for answers.

## The directory note

`UTAdditions.h` puts one note on both `NSURL` methods: "The resulting URL has a directory path if
contentType conforms to UTTypeDirectory." `-URLByAppendingPathComponent:isDirectory:` is the release's
own way of saying it, and the conformance test is the same `UTTypeConformsTo` as above.

## Where this object lives

`UIKit/`, for the reason `facts/UIKit/NSItemProviderUTType.md` gives: `UTType` is built into
`libUIKitBackports` and `libFoundationBackports` links only `icucore`, so a Foundation-folder object
calling into `UTType` would be an undefined symbol at link time.
