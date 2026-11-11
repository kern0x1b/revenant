#include "RevenantExtendedLayout.h"

unsigned long RevenantExtendedLayoutMappedEdges(bool edgesStored, unsigned long edges, bool opaqueBars)
{
    if (edgesStored && edges == REVENANT_EXTENDED_LAYOUT_ALL)
        return REVENANT_EXTENDED_LAYOUT_ALL;
    if (opaqueBars)
        return edges & REVENANT_EXTENDED_LAYOUT_TOP;
    return 0;
}
