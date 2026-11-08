#import "../Foundation/check.h"
#import "RevenantMetalGrid.h"

static size_t revenant_covered(size_t grid, size_t threads)
{
    size_t covered = 0;
    for (size_t group = 0; group < RevenantMetalGroupCount(grid, threads); group++)
        covered += RevenantMetalGroupExtent(grid, threads, group);
    return covered;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    revenant_check((RevenantMetalGroupCount(640, 32) == 20) != revenant_negative, "a grid that the group size divides takes exactly the quotient in groups", @"the group count of an even grid is not the quotient");
    revenant_check((RevenantMetalGroupCount(641, 32) == 21) != revenant_negative, "a grid one past a multiple takes one more group", @"the group count of a ragged grid is not rounded up");
    revenant_check((RevenantMetalGroupCount(7, 32) == 1) != revenant_negative, "a grid smaller than one group takes one group", @"a small grid does not take one group");
    revenant_check((RevenantMetalGroupCount(0, 32) == 0) != revenant_negative, "an empty grid takes no group", @"an empty grid took a group");
    revenant_check((RevenantMetalGroupCount(1, 1) == 1) != revenant_negative, "one thread in groups of one takes one group", @"one thread did not take one group");

    revenant_check((RevenantMetalGroupExtent(641, 32, 0) == 32) != revenant_negative, "a full group keeps the whole group size", @"a full group was cut");
    revenant_check((RevenantMetalGroupExtent(641, 32, 19) == 32) != revenant_negative, "the last full group keeps the whole group size", @"the last full group was cut");
    revenant_check((RevenantMetalGroupExtent(641, 32, 20) == 1) != revenant_negative, "the edge group has only the threads that the grid has left", @"the edge group is not the remainder");
    revenant_check((RevenantMetalGroupExtent(7, 32, 0) == 7) != revenant_negative, "a grid smaller than a group runs the threads it has", @"a small grid ran past its end");

    revenant_check((revenant_covered(641, 32) == 641) != revenant_negative, "the groups of a ragged grid cover exactly its threads", @"the groups do not cover the grid exactly");
    revenant_check((revenant_covered(1000, 7) == 1000) != revenant_negative, "the groups of a grid with an odd group size cover exactly its threads", @"the odd groups do not cover the grid exactly");
    revenant_check((revenant_covered(640, 32) == 640) != revenant_negative, "the groups of an even grid cover exactly its threads", @"the even groups do not cover the grid exactly");

    return revenant_finish();
}
