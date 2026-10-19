#import "CharonUTType.h"

UTType *UTTypeAHAP;

__attribute__((constructor)) static void charon_uttype_catalog_17(void)
{
    UTTypeAHAP = [UTType typeWithIdentifier:@"com.apple.haptics.ahap"];

    charon_uttype_catalogue_add(@[UTTypeAHAP]);
}
