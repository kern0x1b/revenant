/*
 * The listener calls of iOS 13.4: the limit on the new connections a listener accepts, which the held
 * iOS 13.4 cache is the first to export, so an object of their own. The rest of the listener is in
 * nw16-listener.m and in the iOS 12 objects, and tools/release-split.lua is what says so.
 */

#import "CharonNW.h"

void nw_listener_set_new_connection_limit(nw_listener_t listener, uint32_t new_connection_limit)
{
    CharonNWListenerSetNewConnectionLimit(listener, new_connection_limit);
}

uint32_t nw_listener_get_new_connection_limit(nw_listener_t listener)
{
    return CharonNWListenerGetNewConnectionLimit(listener);
}
