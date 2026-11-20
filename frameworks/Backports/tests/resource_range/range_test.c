#include "RevenantRangeHeader.h"
#include <stdio.h>

static int failures = 0;

static void expect(const char *name, const char *value, long long off, long long len, int to_end)
{
    long long offset = -1, length = -1;
    int end = -1;
    revenant_range_header_parse(value, &offset, &length, &end);
    if (offset != off || length != len || end != to_end) {
        printf("FAIL %s: got %lld/%lld/%d want %lld/%lld/%d\n", name, offset, length, end, off, len, to_end);
        failures++;
    }
}

int main(void)
{
    expect("missing", NULL, 0, 0, 1);
    expect("closed range", "bytes=0-499", 0, 500, 0);
    expect("middle range", "bytes=100-199", 100, 100, 0);
    expect("suffix range", "bytes=-500", 0, 500, 1);
    expect("open range", "bytes=500-", 500, 0, 1);
    expect("bare range", "500-", 500, 0, 1);
    if (failures)
        return 1;
    printf("resource range tests passed\n");
    return 0;
}
