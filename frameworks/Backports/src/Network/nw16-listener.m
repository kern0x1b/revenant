#include "../revenant_impl.h"
#import "RevenantNW.h"

void BACKPORT_IMPL(nw_listener_set_new_connection_group_handler)(nw_listener_t listener, nw_listener_new_connection_group_handler_t handler)
{
    RevenantNWListenerSetNewConnectionGroup(listener, handler);
}
