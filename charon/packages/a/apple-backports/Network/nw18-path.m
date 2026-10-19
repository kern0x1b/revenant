#import "CharonNW.h"
#include <Availability.h>

#define CHARON_IOS_18 API_AVAILABLE(ios(18.0))

CHARON_IOS_18 bool nw_path_is_ultra_constrained(nw_path_t path)
{
    (void)path;
    return false;
}
