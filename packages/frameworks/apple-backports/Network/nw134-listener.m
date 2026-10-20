#import "RevenantNW.h"

void nw_listener_set_new_connection_limit(nw_listener_t listener, uint32_t new_connection_limit)
{
    RevenantNWListenerSetNewConnectionLimit(listener, new_connection_limit);
}

uint32_t nw_listener_get_new_connection_limit(nw_listener_t listener)
{
    return RevenantNWListenerGetNewConnectionLimit(listener);
}
