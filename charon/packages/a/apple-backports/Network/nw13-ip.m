#import "CharonNW.h"
#import "CharonNWSupport.h"

void nw_ip_options_set_local_address_preference(nw_protocol_options_t options, nw_ip_local_address_preference_t preference)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "local_address_preference", preference);
}
