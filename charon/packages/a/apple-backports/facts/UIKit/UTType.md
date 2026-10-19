# `UTType` and its eleven carried constants, iOS 14

Source: the local machine's own SDK headers - `UniformTypeIdentifiers/UTType.h` and
`UniformTypeIdentifiers/UTCoreTypes.h` under `/Library/Developer/CommandLineTools/SDKs/
MacOSX26.5.sdk` - for the class's surface and the exact identifier string behind each constant;
`UIDocumentPickerViewController.h` from the same SDK drop for the two `initFor...` pairs that
demand this class. Behaviour is not reasoned: it is the `UTType*` C functions MobileCoreServices
already carries on iOS 6 (`UTTypeConformsTo`, `UTTypeCopyPreferredTagWithClass`,
`UTTypeCopyDescription`, `UTTypeCreatePreferredIdentifierForTag`, `UTTypeIsDynamic`,
`UTTypeIsDeclared`) - the same functions `UIDocumentPickerViewController.m`'s own
`charon_acceptsPath:` was already calling before this class existed.

## What `UTType` is

A recent SDK's object wrapper around the same Uniform Type Identifier a release since iOS 3
already names with a plain `NSString`/`CFStringRef`. `UTType.identifier` is that string; every
other property and method on the class is answered by calling the matching `UTType*` C function
with it. Nothing about behaviour is invented - the class is carried as a thin object shell over
functions that already work correctly on iOS 6.

`typeWithIdentifier:` builds the wrapper directly. `typeWithFilenameExtension:`,
`typeWithFilenameExtension:conformingToType:`, `typeWithMIMEType:`,
`typeWithMIMEType:conformingToType:` and `typeWithTag:tagClass:conformingToType:` all resolve
through `UTTypeCreatePreferredIdentifierForTag`, exactly as the SDK header documents each being
equivalent to a `typeWithTag:tagClass:conformingToType:` call.

## The eleven constants

Only the constants an application is likely to reach for while filtering a document picker are
carried, not the full 150-some-constant catalogue `UTCoreTypes.h` declares - a constant this
backport does not carry is only reached if an application references it directly, and that is a
LOAD-FAIL this corpus has not yet raised for this band. Each identifier below was read directly
out of the local SDK's `UTCoreTypes.h`, not recalled or guessed:

| Constant | Identifier |
| --- | --- |
| `UTTypeItem` | `public.item` |
| `UTTypeContent` | `public.content` |
| `UTTypeData` | `public.data` |
| `UTTypeDirectory` | `public.directory` |
| `UTTypeURL` | `public.url` |
| `UTTypeFileURL` | `public.file-url` |
| `UTTypeText` | `public.text` |
| `UTTypePlainText` | `public.plain-text` |
| `UTTypeUTF8PlainText` | `public.utf8-plain-text` |
| `UTTypeImage` | `public.image` |
| `UTTypePDF` | `com.adobe.pdf` |

Each is a plain, non-`const` global, filled in once by a `constructor` function, the same
technique `CFEmptyCollections.m` already uses for `__NSArray0__`/`__NSDictionary0__`: the real
SDK header declares these `UTType *const`, but that is a promise to the header's callers, not a
constraint on how this backport's own translation unit stores them.

## What the build gate measured, not reasoned

`UTTypeIsDeclared` and `UTTypeIsDynamic` are not exported by 6.1.3's armv7 release -
`build-gate.lua`'s own imports check flagged both as weak imports the release resolves to NULL.
`isDeclared`/`isDynamic` guard each call. Until 2026-09-23 the guard answered `YES`/`NO` for every
identifier on 6.1.3, which was wrong for a dynamic identifier - `UTTypeCreatePreferredIdentifierForTag`
of 6.1.3 makes `dyn.` identifiers for tags it has no type for (measured: `dyn.age81y8xvse` for the
extension `zzqq`). This library now carries both functions (`UIKit/UTTypeDynamic8.m`,
`facts/MobileCoreServices/UTTypeDynamic.md`), so the guard passes and they answer.

## What differs from the system

`tags` only ever reports `UTTagClassFilenameExtension` and `UTTagClassMIMEType`, the two tag
classes `charon_acceptsPath:` and the constants above already need; the release's real registry
of additional tag classes (`com.apple.nspboard-type`, `com.apple.ostype`, and so on) is not read.
`version`, `referenceURL` and `supertypes` are now carried, in `facts/UIKit/UTTypeDeclarations.md`: a
type's version and reference URL are properties of the type's declaration, so they are read out of the
process's own UTI declarations, and `supertypes` is the release's own conformance test run over the
catalogue.

## The three properties whose getter the SDK spells `is`

`dynamic`, `declared` and `publicType` are declared by SDK 26.2's own `UTType.h` as

    @property (readonly, getter=isDynamic) BOOL dynamic;
    @property (readonly, getter=isDeclared) BOOL declared;
    @property (readonly, getter=isPublicType) BOOL publicType;

so the selectors an application calls are `-isDynamic`, `-isDeclared` and `-isPublicType`, which is what
this class has answered since it was written. No SDK header declares a `-dynamic`, `-declared` or
`-publicType` selector, and none is added here: adding one would be API no release has, carrying it for
no caller. `modules/apple/backports.lua`'s own check_registry reads a row spelled with the property's own
name against the `is` getter as well -- its own comment names that case (`getter=isPreviewing`) -- and the
corpus names the row with the property's spelling, which is the spelling the check pairs.

`tests/backports/host/uttypeconstants` reads the host's own `isDeclared`, `isDynamic` and `isPublicType`
for four system types and prints them on every run.
