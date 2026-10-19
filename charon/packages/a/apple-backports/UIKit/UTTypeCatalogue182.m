#import "CharonUTType.h"

// UniformTypeIdentifiers' system type catalogue, iOS 18.2: UTTypeJPEGXL, the one constant of SDK 26.2's
// UTCoreTypes.h the corpus places at 18.2. It has an object of its own because an object carries API of one
// release: the gate measured UTTypeCatalogue18.m holding seven 18.0 names and this one from 18.2. The identifier
// is the `UTI:` line of the constant's doc comment in UTCoreTypes.h of charon/.agent-work/sdk-26.2, and
// tests/backports/host/uttypeconstants reads it back off the host. The storage follows UTTypeCatalogue18.m.

// UTTypeJPEGXL is public.jpeg-xl.
UTType *UTTypeJPEGXL;

__attribute__((constructor)) static void charon_uttype_catalog_182(void)
{
    UTTypeJPEGXL = [UTType typeWithIdentifier:@"public.jpeg-xl"];

    // Handed to the index -[UTType supertypes] reads; see UIKit/UTTypeCatalogueIndex.m.
    charon_uttype_catalogue_add(@[UTTypeJPEGXL]);
}
