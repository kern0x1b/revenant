/*
 * Whether a path is an ultra-constrained network, as iOS 26 names it.
 *
 * An ultra-constrained path is a low-bandwidth link meant only for a device of its own - a Bluetooth
 * LE link, a LoRaWAN gateway - and the release this port builds for has none, so no path of it is one,
 * which is the answer a device without such a network gives.
 *
 * The declaration is the port's own: the SDK it compiles against is 16.4, which predates the call, and
 * the flag is the boolean the header of a release that has it says it is.
 */

#import "CharonNW.h"
#include <Availability.h>

/* the SDK's own mark for a name this release's cache does not have: it arrived in iOS 18.0 */
#define CHARON_IOS_18 API_AVAILABLE(ios(18.0))

CHARON_IOS_18 bool nw_path_is_ultra_constrained(nw_path_t path)
{
    (void)path;
    return false;
}
