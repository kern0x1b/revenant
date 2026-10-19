# `UTType`'s version, reference URL, supertypes and the exported/imported type pair, iOS 14

What `UIKit/UTTypeDeclarations14.m` implements, and where each answer comes from.

## Where a type's version and reference URL are declared

A Uniform Type Identifier's version and reference URL are properties of the type's *declaration*, not
of the type. `System/Library/Frameworks/CoreServices.framework/Headers/UTType.h` lists them among the
keys of a Type Declaration Dictionary:

```
kUTExportedTypeDeclarationsKey, kUTImportedTypeDeclarationsKey, kUTTypeIdentifierKey,
kUTTypeTagSpecificationKey, kUTTypeConformsToKey, kUTTypeDescriptionKey, kUTTypeIconFileKey,
kUTTypeReferenceURLKey, kUTTypeVersionKey
```

and a declaration is written down in exactly one place: an `Info.plist`, as the process's own
`UTExportedTypeDeclarations` and `UTImportedTypeDeclarations` arrays. So the port reads the same two
arrays out of the same main-bundle dictionary, under the same key strings, that Apple's implementation
reads.

The key strings were measured rather than spelled from the header: the host's own
`kUTExportedTypeDeclarationsKey` is `UTExportedTypeDeclarations`, `kUTImportedTypeDeclarationsKey` is
`UTImportedTypeDeclarations`, `kUTTypeIdentifierKey` is `UTTypeIdentifier`, `kUTTypeVersionKey` is
`UTTypeVersion` and `kUTTypeReferenceURLKey` is `UTTypeReferenceURL`. They are written as literals in the
port rather than read through the `kUT...Key` symbols, because this release's CoreServices exports those
as data symbols whose presence would have to be measured per band and nothing else here needs them.

## What that means for a system type, and what the host answers

iOS 6's own UTI declarations live in LaunchServices' store, which exports no accessor for a version or
a reference URL. The release's whole UTType surface is `UTTypeCreatePreferredIdentifierForTag`,
`UTTypeCopyPreferredTagWithClass`, `UTTypeCopyAllTagsWithClass`, `UTTypeCopyDescription`,
`UTTypeConformsTo`, `UTTypeIsDeclared` and `UTTypeIsDynamic`, all of which `UIKit/UTType.m` already
calls. So for every type the process does not declare, `-version` and `-referenceURL` answer nil.

That is Apple's own answer for those types, and it is what `UTType.h` says it should be: "Most types do
not specify a version", "Most types do not specify reference URLs". `tests/backports/host/uttypeconstants`
reads the host's own values for four system types and they are nil on both, for every one of them:

```
public.png: declared 1 dynamic 0 public 1 version (nil) referenceURL (nil) supertypes 4
public.plain-text: declared 1 dynamic 0 public 1 version (nil) referenceURL (nil) supertypes 4
com.adobe.pdf: declared 1 dynamic 0 public 0 version (nil) referenceURL (nil) supertypes 4
public.data: declared 1 dynamic 0 public 1 version (nil) referenceURL (nil) supertypes 1
```

## `-supertypes`

`UTType.h` defines the property as "the set of types to which the receiving type conforms, directly or
indirectly", and notes that testing `-conformsToType:` is more efficient than reading it.

The release answers the conformance question itself -- that is what `UTTypeConformsTo` is, and what
`-conformsToType:` already calls -- but exports no function that *enumerates* a type's supertypes. So
the set is built by asking the release about each type in the catalogue the port carries, which is the
same direction Apple's own implementation walks: over the declared types, testing conformance to each.

The catalogue is collected at run time rather than written out a second time in the class:
`UIKit/UTTypeCatalogueIndex.m` holds the index, `UIKit/UTType.m` and the four
`UIKit/UTTypeCatalogue<BAND>.m` files each hand their own constants to it in their own constructors,
and the index is a file of its own because it exports no API symbol (both of its functions begin
`charon_`, which `modules/apple/backports.lua`'s `internal_symbol()` reads as one of Charon's own
helpers), so no band drops it and leaves the callers without it.

The receiver is not among its own supertypes: `UTTypeConformsTo` answers YES for a type against itself,
and the set the header describes is the types the receiver conforms to.

## `+exportedTypeWithIdentifier:` and `+importedTypeWithIdentifier:`

`UTType.h` states both rules in full.

`+exportedTypeWithIdentifier:` "Gets an active UTType corresponding to a type that is declared as
'exported' by the current process", and "If identifier does not correspond to any type known to the
system, the result is undefined." The host, whose process declares no export at all, answers the type
carrying the identifier it was given:

```
exported/importedTypeWithIdentifier: for com.example.nothing-declared-here: exported com.example.nothing-declared-here, imported com.example.nothing-declared-here
```

So the port answers the type for the identifier, narrowed to the process's own declaration when it has
one.

`+importedTypeWithIdentifier:` is the one with a rule of its own: "In the general case, this method
returns a type with the same identifier, but if that type has a preferred filename extension and another
type is the preferred type for that extension, then that other type is substituted." Both halves are the
release's own functions -- `UTTypeCopyPreferredTagWithClass` for the extension and
`UTTypeCreatePreferredIdentifierForTag` for the preferred type -- so the rule is carried out literally.
The differential reads the host's answer for `public.jpeg`, whose preferred extension is `jpeg` and
whose preferred type for `jpeg` is `public.jpeg`, so nothing is substituted there:

```
public.jpeg preferred extension jpeg, preferred type for it public.jpeg, conforming 1
```

The `conformingToType:` forms narrow by the parent the header says the result is "expected to conform
to", which is `UTTypeConformsTo` again.