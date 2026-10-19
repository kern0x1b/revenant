#import "CharonUTType.h"

UTType *UTTypeJPEGXL;

__attribute__((constructor)) static void charon_uttype_catalog_182(void)
{
    UTTypeJPEGXL = [UTType typeWithIdentifier:@"public.jpeg-xl"];

    charon_uttype_catalogue_add(@[UTTypeJPEGXL]);
}
