#import "RevenantNW.h"

void nw_listener_set_new_connection_group_handler(nw_listener_t listener, nw_listener_new_connection_group_handler_t handler)
{
    RevenantNWListenerSetNewConnectionGroup(listener, handler);
}
