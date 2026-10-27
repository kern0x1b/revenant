#include <stdlib.h>
#include "RevenantPhotoMoves.h"

void RevenantPhotoLongestIncreasingSubsequence(const size_t *values, size_t count, unsigned char *inSequence)
{
    for (size_t index = 0; index < count; index++)
        inSequence[index] = 0;
    if (count == 0)
        return;
    size_t *tails = malloc(count * sizeof(size_t));
    size_t *previous = malloc(count * sizeof(size_t));
    size_t length = 0;
    for (size_t index = 0; index < count; index++) {
        size_t low = 0, high = length;
        while (low < high) {
            size_t middle = low + (high - low) / 2;
            if (values[tails[middle]] < values[index])
                low = middle + 1;
            else
                high = middle;
        }
        previous[index] = low > 0 ? tails[low - 1] : count;
        tails[low] = index;
        if (low == length)
            length++;
    }
    size_t cursor = length ? tails[length - 1] : count;
    while (cursor < count) {
        inSequence[cursor] = 1;
        cursor = previous[cursor];
    }
    free(tails);
    free(previous);
}
