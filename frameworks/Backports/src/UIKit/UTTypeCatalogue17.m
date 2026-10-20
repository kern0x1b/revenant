#import "RevenantUTType.h"

UTType *UTTypeAHAP;

__attribute__((constructor)) static void revenant_uttype_catalog_17(void)
{
    UTTypeAHAP = [UTType typeWithIdentifier:@"com.apple.haptics.ahap"];

    revenant_uttype_catalogue_add(@[UTTypeAHAP]);
}
