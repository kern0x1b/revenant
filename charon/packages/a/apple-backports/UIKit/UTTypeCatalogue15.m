#import "CharonUTType.h"

// UniformTypeIdentifiers' system type catalogue, iOS 15: the 1 constants of SDK 26.2's
// UTCoreTypes.h whose availability the corpus places in this band, out of the 15.0 the file declares.
// Every identifier below is the `UTI:` line of that constant's own doc comment in
// System/Library/Frameworks/UniformTypeIdentifiers.framework/Headers/UTCoreTypes.h of
// charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk -- transcribed one row per constant, nothing recalled
// and nothing inferred from the identifier's own shape. One value is not the header's:
// UTTypeInternetShortcut, where the header repeats the identifier of the constant directly above it
// and the system's own UniformTypeIdentifiers answers com.microsoft.internet-shortcut (measured, and
// re-measured on every run of tests/backports/host/uttypeconstants, which reads the value out of the
// host rather than out of this file). facts/UIKit/UTTypeCatalogue.md carries the whole table.
//
// One release per object file: this object holds the 15.0 catalogue only, and the files beside it hold
// the other bands, so every symbol first appears in exactly one release and release-split is clean.
// The constants are plain, non-const globals filled in once by a constructor, the way UIKit/UTType.m
// already fills the eleven it carried first and the way CFEmptyCollections.m fills
// __NSArray0__/__NSDictionary0__: a recent SDK's header declares these `UTType *const`, but that is a
// promise to the header's callers, not a constraint on how this backport's translation unit stores
// them.

// UTTypeMakefile is public.make-source.
UTType *UTTypeMakefile;

__attribute__((constructor)) static void charon_uttype_catalog_15(void)
{
    UTTypeMakefile = [UTType typeWithIdentifier:@"public.make-source"];

    // Handed to the index -[UTType supertypes] reads; see UIKit/UTTypeCatalogueIndex.m.
    charon_uttype_catalogue_add(@[UTTypeMakefile]);
}
