#import <Foundation/Foundation.h>
#import "RevenantExtendedLayout.h"
#import "check.h"

static void expect_mapped(const char *name, BOOL edgesStored, unsigned long edges, BOOL opaque, unsigned long expected)
{
    unsigned long mapped = RevenantExtendedLayoutMappedEdges(edgesStored, edges, opaque);
    revenant_check(mapped == expected, name, [NSString stringWithFormat:@"the mapped edges are %lu, not %lu", mapped, expected]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    expect_mapped("edges never set map nothing without opaque bars", NO, REVENANT_EXTENDED_LAYOUT_ALL, NO, 0);
    expect_mapped("edges never set map the top edge under opaque bars", NO, REVENANT_EXTENDED_LAYOUT_ALL, YES, REVENANT_EXTENDED_LAYOUT_TOP);
    expect_mapped("UIRectEdgeAll set maps every edge", YES, REVENANT_EXTENDED_LAYOUT_ALL, NO, REVENANT_EXTENDED_LAYOUT_ALL);
    expect_mapped("UIRectEdgeAll set stays all under opaque bars", YES, REVENANT_EXTENDED_LAYOUT_ALL, YES, REVENANT_EXTENDED_LAYOUT_ALL);
    expect_mapped("UIRectEdgeNone maps nothing", YES, 0, NO, 0);
    expect_mapped("UIRectEdgeNone maps nothing under opaque bars", YES, 0, YES, 0);
    expect_mapped("the top edge without opaque bars maps nothing", YES, REVENANT_EXTENDED_LAYOUT_TOP, NO, 0);
    expect_mapped("the top edge under opaque bars maps the top edge", YES, REVENANT_EXTENDED_LAYOUT_TOP, YES,
                  revenant_negative ? 0 : REVENANT_EXTENDED_LAYOUT_TOP);
    expect_mapped("the left, bottom and right edges never map", YES, 14, YES, 0);
    expect_mapped("top and bottom under opaque bars map the top edge only", YES, REVENANT_EXTENDED_LAYOUT_TOP | 4UL, YES, REVENANT_EXTENDED_LAYOUT_TOP);

    return revenant_finish();
}
