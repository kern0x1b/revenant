/*
 * The quality of the link under a path, as iOS 26 names it.
 *
 * A link quality is a measurement of what the link can carry, in four steps from "nothing measured" to
 * "good". The release this port builds for has no way to ask its own link how good it is - the
 * interface is up or it is not, and the signal strength a program can read by hand is not what this
 * measures - so every path answers "no measurement available", which is the first of the four and is
 * what the system answers where it has no measurement either.
 *
 * The declaration is the port's own: the SDK it compiles against is 16.4, which predates the call, and
 * the four values of the quality are the ones the header of a release that has them gives.
 */

#import <Network/Network.h>
#import <Availability.h>
#import "CharonNW.h"

/* The mark the SDK would put on it if the SDK had the call, which is the one the gate reads to place a
   name no release of this machine holds and no header of this SDK declares: it arrived in iOS 26.0. */
#define CHARON_IOS_26 API_AVAILABLE(ios(26.0))

#if !__has_include(<Network/proxy_config.h>)
/* The SDK this file is compiled against declares the whole of iOS 26's Network when it has a
   proxy_config.h - link quality included - and then this declaration would be a second one. */
typedef NS_ENUM(int, nw_link_quality_t) {
    nw_link_quality_unknown = 0,
    nw_link_quality_minimal = 10,
    nw_link_quality_moderate = 20,
    nw_link_quality_good = 30,
};
#endif

CHARON_IOS_26 nw_link_quality_t nw_path_get_link_quality(nw_path_t path)
{
    (void)path;
    return nw_link_quality_unknown;
}

