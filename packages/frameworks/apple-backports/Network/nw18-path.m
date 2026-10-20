#import "RevenantNW.h"
#include <Availability.h>

#define REVENANT_IOS_18 API_AVAILABLE(ios(18.0))

REVENANT_IOS_18 bool nw_path_is_ultra_constrained(nw_path_t path)
{
    (void)path;
    return false;
}
