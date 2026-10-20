#import <Network/Network.h>
#import <Availability.h>
#import "RevenantNW.h"

#define REVENANT_IOS_26 API_AVAILABLE(ios(26.0))

#if !__has_include(<Network/proxy_config.h>)
typedef NS_ENUM(int, nw_link_quality_t) {
    nw_link_quality_unknown = 0,
    nw_link_quality_minimal = 10,
    nw_link_quality_moderate = 20,
    nw_link_quality_good = 30,
};
#endif

REVENANT_IOS_26 nw_link_quality_t nw_path_get_link_quality(nw_path_t path)
{
    (void)path;
    return nw_link_quality_unknown;
}
