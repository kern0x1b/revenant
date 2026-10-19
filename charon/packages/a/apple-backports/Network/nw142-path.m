/*
 * Why a path is unsatisfied, as iOS 14.2 names it.
 *
 * The reasons the header lists are the ones a system's own policy produces - a permission the user
 * has denied, a network the user has turned off - and the release this port builds for has no such
 * policy to report: its reachability says only whether the network is there, never why it is not.
 * A path that is unsatisfied here is unsatisfied for a reason the release does not name, which is
 * what `not_available` says, and that is what an unsatisfied path answers. A path that is satisfied
 * has no reason either.
 */

#import <Network/Network.h>

nw_path_unsatisfied_reason_t nw_path_get_unsatisfied_reason(nw_path_t path)
{
    (void)path;
    return nw_path_unsatisfied_reason_not_available;
}
