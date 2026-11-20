#ifndef REVENANT_SYMBOL_RENDERING_H
#define REVENANT_SYMBOL_RENDERING_H

typedef enum {
    RevenantSymbolRenderingAutomatic = 0,
    RevenantSymbolRenderingMonochrome = 1,
    RevenantSymbolRenderingHierarchical = 2,
    RevenantSymbolRenderingPalette = 3,
    RevenantSymbolRenderingMulticolor = 4
} RevenantSymbolRendering;

int revenant_symbol_color_index(RevenantSymbolRendering rendering, int layer, int count);
double revenant_symbol_layer_alpha(RevenantSymbolRendering rendering, int layer);

#endif
