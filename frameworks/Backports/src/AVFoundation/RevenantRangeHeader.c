#include "RevenantRangeHeader.h"
#include <stdlib.h>
#include <string.h>

void revenant_range_header_parse(const char *value, long long *offset, long long *length, int *to_end)
{
    *offset = 0;
    *length = 0;
    *to_end = 1;
    if (!value)
        return;
    const char *bytes = value;
    if (strncmp(bytes, "bytes=", 6) == 0)
        bytes += 6;
    const char *dash = strchr(bytes, '-');
    if (!dash)
        return;
    char *first = malloc((size_t)(dash - bytes) + 1);
    if (!first)
        return;
    memcpy(first, bytes, (size_t)(dash - bytes));
    first[dash - bytes] = '\0';
    if (*first == '\0') {
        *length = strtoll(dash + 1, NULL, 10);
    } else {
        *offset = strtoll(first, NULL, 10);
        if (*(dash + 1) != '\0') {
            long long last = strtoll(dash + 1, NULL, 10);
            *length = last - *offset + 1;
            *to_end = 0;
        }
    }
    free(first);
}
