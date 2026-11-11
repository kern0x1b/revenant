#ifndef REVENANT_EXTENDED_LAYOUT_H
#define REVENANT_EXTENDED_LAYOUT_H

#include <stdbool.h>

#define REVENANT_EXTENDED_LAYOUT_TOP 1UL
#define REVENANT_EXTENDED_LAYOUT_ALL 15UL

unsigned long RevenantExtendedLayoutMappedEdges(bool edgesStored, unsigned long edges, bool opaqueBars);

#endif
