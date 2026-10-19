#import "RevenantNW.h"
#import "RevenantNWSupport.h"

void nw_ip_options_set_local_address_preference(nw_protocol_options_t options, nw_ip_local_address_preference_t preference)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)((RevenantNWProtocolOptions *)options)->_values, "local_address_preference", preference);
}
