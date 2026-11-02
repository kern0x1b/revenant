#include "../revenant_impl.h"
#import "RevenantSCN.h"

const SCNMatrix4 BACKPORT_IMPL(SCNMatrix4Identity) = {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
};

const SCNVector3 BACKPORT_IMPL(SCNVector3Zero) = {0, 0, 0};
const SCNVector4 BACKPORT_IMPL(SCNVector4Zero) = {0, 0, 0, 0};
