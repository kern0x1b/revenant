#import "CharonUTType.h"

UTType *UTTypeCSS;

UTType *UTTypeHEICS;

UTType *UTTypeEXR;

UTType *UTTypeDNG;

UTType *UTTypeTarArchive;

UTType *UTTypeGeoJSON;

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

    charon_uttype_catalogue_add(@[UTTypeCSS, UTTypeHEICS, UTTypeEXR, UTTypeDNG, UTTypeTarArchive, UTTypeGeoJSON, UTTypeLinkPresentationMetadata]);
}
