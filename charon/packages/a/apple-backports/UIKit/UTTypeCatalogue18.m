#import "CharonUTType.h"

// UniformTypeIdentifiers' system type catalogue, iOS 18.0: the 7 constants of SDK 26.2's
// UTCoreTypes.h whose availability the corpus places at 18.0. UTTypeJPEGXL (18.2) is in UTTypeCatalogue182.m.
// Every identifier below is the `UTI:` line of that constant's own doc comment in
// System/Library/Frameworks/UniformTypeIdentifiers.framework/Headers/UTCoreTypes.h of
// charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk -- transcribed one row per constant, nothing recalled
// and nothing inferred from the identifier's own shape. One value is not the header's:
// UTTypeInternetShortcut, where the header repeats the identifier of the constant directly above it
// and the system's own UniformTypeIdentifiers answers com.microsoft.internet-shortcut (measured, and
// re-measured on every run of tests/backports/host/uttypeconstants, which reads the value out of the
// host rather than out of this file). facts/UIKit/UTTypeCatalogue.md carries the whole table.
//
// One release per object file: this object holds the 18.0 catalogue only, and the files beside it hold
// the other bands, so every symbol first appears in exactly one release and release-split is clean.
// The constants are plain, non-const globals filled in once by a constructor, the way UIKit/UTType.m
// already fills the eleven it carried first and the way CFEmptyCollections.m fills
// __NSArray0__/__NSDictionary0__: a recent SDK's header declares these `UTType *const`, but that is a
// promise to the header's callers, not a constraint on how this backport's translation unit stores
// them.

// UTTypeCSS is public.css.
UTType *UTTypeCSS;

// UTTypeHEICS is public.heics.
UTType *UTTypeHEICS;

// UTTypeEXR is com.ilm.openexr-image.
UTType *UTTypeEXR;

// UTTypeDNG is com.adobe.raw-image.
UTType *UTTypeDNG;

// UTTypeTarArchive is public.tar-archive.
UTType *UTTypeTarArchive;

// UTTypeGeoJSON is public.geojson.
UTType *UTTypeGeoJSON;

// UTTypeLinkPresentationMetadata is com.apple.linkpresentation.metadata.
UTType *UTTypeLinkPresentationMetadata;

__attribute__((constructor)) static void charon_uttype_catalog_18(void)
{
    UTTypeCSS = [UTType typeWithIdentifier:@"public.css"];
    UTTypeHEICS = [UTType typeWithIdentifier:@"public.heics"];
    UTTypeEXR = [UTType typeWithIdentifier:@"com.ilm.openexr-image"];
    UTTypeDNG = [UTType typeWithIdentifier:@"com.adobe.raw-image"];
    UTTypeTarArchive = [UTType typeWithIdentifier:@"public.tar-archive"];
    UTTypeGeoJSON = [UTType typeWithIdentifier:@"public.geojson"];
    UTTypeLinkPresentationMetadata = [UTType typeWithIdentifier:@"com.apple.linkpresentation.metadata"];

    // Handed to the index -[UTType supertypes] reads; see UIKit/UTTypeCatalogueIndex.m.
    charon_uttype_catalogue_add(@[UTTypeCSS, UTTypeHEICS, UTTypeEXR, UTTypeDNG, UTTypeTarArchive, UTTypeGeoJSON, UTTypeLinkPresentationMetadata]);
}
