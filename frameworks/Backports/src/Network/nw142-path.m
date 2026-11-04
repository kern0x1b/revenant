#include "../revenant_impl.h"
#import <Network/Network.h>

nw_path_unsatisfied_reason_t BACKPORT_IMPL(nw_path_get_unsatisfied_reason)(nw_path_t path)
{
    (void)path;
    return nw_path_unsatisfied_reason_not_available;
}
