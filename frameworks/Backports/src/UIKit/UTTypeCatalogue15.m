#include "../revenant_impl.h"
#import "RevenantUTType.h"

UTType *BACKPORT_IMPL(UTTypeMakefile);

__attribute__((constructor)) static void revenant_uttype_catalog_15(void)
{
    BACKPORT_IMPL(UTTypeMakefile) = [UTType typeWithIdentifier:@"public.make-source"];

    revenant_uttype_catalogue_add(@[BACKPORT_IMPL(UTTypeMakefile)]);
}
