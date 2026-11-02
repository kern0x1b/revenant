#include "../revenant_impl.h"
#import "RevenantUTType.h"

UTType *BACKPORT_IMPL(UTTypeCSS);

UTType *BACKPORT_IMPL(UTTypeHEICS);

UTType *BACKPORT_IMPL(UTTypeEXR);

UTType *BACKPORT_IMPL(UTTypeDNG);

UTType *BACKPORT_IMPL(UTTypeTarArchive);

UTType *BACKPORT_IMPL(UTTypeGeoJSON);

UTType *BACKPORT_IMPL(UTTypeLinkPresentationMetadata);

__attribute__((constructor)) static void revenant_uttype_catalog_18(void)
{
    UTTypeCSS = [UTType typeWithIdentifier:@"public.css"];
    UTTypeHEICS = [UTType typeWithIdentifier:@"public.heics"];
    UTTypeEXR = [UTType typeWithIdentifier:@"com.ilm.openexr-image"];
    UTTypeDNG = [UTType typeWithIdentifier:@"com.adobe.raw-image"];
    UTTypeTarArchive = [UTType typeWithIdentifier:@"public.tar-archive"];
    UTTypeGeoJSON = [UTType typeWithIdentifier:@"public.geojson"];
    UTTypeLinkPresentationMetadata = [UTType typeWithIdentifier:@"com.apple.linkpresentation.metadata"];

    revenant_uttype_catalogue_add(@[UTTypeCSS, UTTypeHEICS, UTTypeEXR, UTTypeDNG, UTTypeTarArchive, UTTypeGeoJSON, UTTypeLinkPresentationMetadata]);
}
