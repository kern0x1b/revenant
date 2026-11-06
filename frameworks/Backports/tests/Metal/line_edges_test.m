#import "../Foundation/check.h"
#import "RevenantMetalLineEdges.h"

static BOOL revenant_edges_equal(int strip, const uint32_t *stream, size_t count, const uint32_t *expected, size_t expectedCount)
{
    uint32_t edges[64];
    size_t written = RevenantMetalTriangleEdges(strip, stream, count, edges);
    if (written != expectedCount)
        return NO;
    for (size_t i = 0; i < written; i++)
        if (edges[i] != expected[i])
            return NO;
    return YES;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    const uint32_t list[] = {0, 1, 2, 3, 4, 5};
    const uint32_t listEdges[] = {0, 1, 1, 2, 2, 0, 3, 4, 4, 5, 5, 3};
    revenant_check(revenant_edges_equal(0, list, 6, listEdges, 12) != revenant_negative, "a triangle list of two triangles gives their six edges each", @"the edges are not those of the two triangles");

    const uint32_t partial[] = {0, 1, 2, 3};
    const uint32_t partialEdges[] = {0, 1, 1, 2, 2, 0};
    revenant_check(revenant_edges_equal(0, partial, 4, partialEdges, 6) != revenant_negative, "a triangle list drops an incomplete tail", @"the incomplete tail produced edges");

    const uint32_t strip[] = {0, 1, 2, 3};
    const uint32_t stripEdges[] = {0, 1, 1, 2, 2, 0, 1, 2, 2, 3, 3, 1};
    revenant_check(revenant_edges_equal(1, strip, 4, stripEdges, 12) != revenant_negative, "a triangle strip of two triangles gives the edges of both", @"the strip edges are wrong");

    const uint32_t pair[] = {0, 1};
    revenant_check(revenant_edges_equal(1, pair, 2, NULL, 0) != revenant_negative, "a strip shorter than one triangle gives no edges", @"a short strip produced edges");
    revenant_check(revenant_edges_equal(0, pair, 0, NULL, 0) != revenant_negative, "an empty list gives no edges", @"an empty list produced edges");

    const uint32_t remapped[] = {9, 7, 5};
    const uint32_t remappedEdges[] = {9, 7, 7, 5, 5, 9};
    revenant_check(revenant_edges_equal(0, remapped, 3, remappedEdges, 6) != revenant_negative, "the edges keep the vertex indices they were given", @"the indices were changed");

    return revenant_finish();
}
