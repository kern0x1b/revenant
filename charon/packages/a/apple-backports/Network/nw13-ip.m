/*
 * The IP option of iOS 13: which of the device's own addresses a connection prefers to leave from.
 *
 * The release this port builds for has one address per interface and no policy for choosing between
 * them, so the preference is kept and read back and the connection leaves from the address of the
 * interface its path chose, which is the only address there is.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

void nw_ip_options_set_local_address_preference(nw_protocol_options_t options, nw_ip_local_address_preference_t preference)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "local_address_preference", preference);
}
