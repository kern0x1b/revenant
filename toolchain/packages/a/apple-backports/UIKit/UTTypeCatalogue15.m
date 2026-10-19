#import "RevenantUTType.h"

UTType *UTTypeMakefile;

__attribute__((constructor)) static void revenant_uttype_catalog_15(void)
{
    UTTypeMakefile = [UTType typeWithIdentifier:@"public.make-source"];

    revenant_uttype_catalogue_add(@[UTTypeMakefile]);
}
