#include "../revenant_impl.h"
#import "RevenantUTType.h"

UTType *BACKPORT_IMPL(UTTypeJPEGXL);

__attribute__((constructor)) static void revenant_uttype_catalog_182(void)
{
    BACKPORT_IMPL(UTTypeJPEGXL) = [UTType typeWithIdentifier:@"public.jpeg-xl"];

    revenant_uttype_catalogue_add(@[BACKPORT_IMPL(UTTypeJPEGXL)]);
}
