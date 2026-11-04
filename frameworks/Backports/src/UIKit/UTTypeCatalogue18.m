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
    BACKPORT_IMPL(UTTypeCSS) = [UTType typeWithIdentifier:@"public.css"];
    BACKPORT_IMPL(UTTypeHEICS) = [UTType typeWithIdentifier:@"public.heics"];
    BACKPORT_IMPL(UTTypeEXR) = [UTType typeWithIdentifier:@"com.ilm.openexr-image"];
    BACKPORT_IMPL(UTTypeDNG) = [UTType typeWithIdentifier:@"com.adobe.raw-image"];
    BACKPORT_IMPL(UTTypeTarArchive) = [UTType typeWithIdentifier:@"public.tar-archive"];
    BACKPORT_IMPL(UTTypeGeoJSON) = [UTType typeWithIdentifier:@"public.geojson"];
    BACKPORT_IMPL(UTTypeLinkPresentationMetadata) = [UTType typeWithIdentifier:@"com.apple.linkpresentation.metadata"];

    revenant_uttype_catalogue_add(@[BACKPORT_IMPL(UTTypeCSS), BACKPORT_IMPL(UTTypeHEICS), BACKPORT_IMPL(UTTypeEXR), BACKPORT_IMPL(UTTypeDNG), BACKPORT_IMPL(UTTypeTarArchive), BACKPORT_IMPL(UTTypeGeoJSON), BACKPORT_IMPL(UTTypeLinkPresentationMetadata)]);
}
