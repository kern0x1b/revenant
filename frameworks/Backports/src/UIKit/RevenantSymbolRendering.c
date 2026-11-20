#include "RevenantSymbolRendering.h"

int revenant_symbol_color_index(RevenantSymbolRendering rendering, int layer, int count)
{
    if (layer < 0)
        layer = 0;
    if (rendering != RevenantSymbolRenderingPalette && rendering != RevenantSymbolRenderingMulticolor)
        return 0;
    if (count <= 0)
        return 0;
    return layer % count;
}

double revenant_symbol_layer_alpha(RevenantSymbolRendering rendering, int layer)
{
    if (rendering != RevenantSymbolRenderingHierarchical)
        return 1.0;
    if (layer <= 0)
        return 1.0;
    if (layer == 1)
        return 153.0 / 255.0;
    if (layer == 2)
        return 76.0 / 255.0;
    return 45.0 / 255.0;
}
