/*
 * The listener call that arrived in iOS 16.0, which the 16.0 cache is the first to export, so an object
 * of its own: the rest of the listener is iOS 12, and tools/release-split.lua is what says so. The limit
 * on new connections, which the iOS 13.4 cache first exports, is in nw134-listener.m.
 */

#import "CharonNW.h"

void nw_listener_set_new_connection_group_handler(nw_listener_t listener, nw_listener_new_connection_group_handler_t handler)
{
    CharonNWListenerSetNewConnectionGroup(listener, handler);
}
