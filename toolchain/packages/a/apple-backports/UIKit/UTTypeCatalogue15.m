#import "CharonUTType.h"

UTType *UTTypeMakefile;

__attribute__((constructor)) static void charon_uttype_catalog_15(void)
{
    UTTypeMakefile = [UTType typeWithIdentifier:@"public.make-source"];

    charon_uttype_catalogue_add(@[UTTypeMakefile]);
}
