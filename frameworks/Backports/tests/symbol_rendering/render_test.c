#include "RevenantSymbolRendering.h"
#include <stdio.h>

static int failures = 0;

static void expect_int(const char *name, int got, int want)
{
    if (got != want) {
        printf("FAIL %s got %d want %d\n", name, got, want);
        failures++;
    }
}

static void expect_double(const char *name, double got, double want)
{
    if (got != want) {
        printf("FAIL %s got %.2f want %.2f\n", name, got, want);
        failures++;
    }
}

int main(void)
{
    expect_int("monochrome index", revenant_symbol_color_index(RevenantSymbolRenderingMonochrome, 3, 6), 0);
    expect_int("hierarchical index", revenant_symbol_color_index(RevenantSymbolRenderingHierarchical, 3, 1), 0);
    expect_int("palette first", revenant_symbol_color_index(RevenantSymbolRenderingPalette, 0, 3), 0);
    expect_int("palette second", revenant_symbol_color_index(RevenantSymbolRenderingPalette, 1, 3), 1);
    expect_int("palette wraps", revenant_symbol_color_index(RevenantSymbolRenderingPalette, 4, 3), 1);
    expect_int("palette empty", revenant_symbol_color_index(RevenantSymbolRenderingPalette, 4, 0), 0);
    expect_int("multicolor has no palette", revenant_symbol_color_index(RevenantSymbolRenderingMulticolor, 7, 0), 0);
    expect_int("negative layer", revenant_symbol_color_index(RevenantSymbolRenderingPalette, -2, 3), 0);
    expect_double("automatic alpha", revenant_symbol_layer_alpha(RevenantSymbolRenderingAutomatic, 5), 1.0);
    expect_double("hierarchical first", revenant_symbol_layer_alpha(RevenantSymbolRenderingHierarchical, 0), 1.0);
    expect_double("hierarchical second", revenant_symbol_layer_alpha(RevenantSymbolRenderingHierarchical, 1), 153.0 / 255.0);
    expect_double("hierarchical third", revenant_symbol_layer_alpha(RevenantSymbolRenderingHierarchical, 2), 76.0 / 255.0);
    expect_double("hierarchical later", revenant_symbol_layer_alpha(RevenantSymbolRenderingHierarchical, 3), 45.0 / 255.0);
    expect_double("hierarchical far", revenant_symbol_layer_alpha(RevenantSymbolRenderingHierarchical, 9), 45.0 / 255.0);
    if (failures)
        return 1;
    printf("symbol rendering tests passed\n");
    return 0;
}
