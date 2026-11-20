#include "RevenantRangeHeader.h"
#include <stdio.h>

static int failures = 0;

static void expect(const char *name, const char *value, long long total,
                   RevenantRangeStatus status, long long off, long long len, int to_end)
{
    long long offset = -1, length = -1;
    int end = -1;
    RevenantRangeStatus got = revenant_range_header_parse(value, total, &offset, &length, &end);
    if (got != status || offset != off || length != len || end != to_end) {
        printf("FAIL %s: got %d/%lld/%lld/%d want %d/%lld/%lld/%d\n", name,
               got, offset, length, end, status, off, len, to_end);
        failures++;
    }
}

int main(void)
{
    expect("missing", NULL, REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("empty", "", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("junk", "bytes=garbage", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("letters", "bytes=abc-def", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("wrong unit", "items=0-9", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("no dash", "bytes=500", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("bare range", "500-", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("leading plus", "bytes=+1-2", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("whitespace", "bytes= 0-1", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("two dashes", "bytes=1-2-3", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("overflow", "bytes=999999999999999999999-", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);

    expect("closed range", "bytes=0-499", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_OK, 0, 500, 0);
    expect("middle range", "bytes=100-199", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_OK, 100, 100, 0);
    expect("single byte", "bytes=0-0", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_OK, 0, 1, 0);
    expect("A greater than B", "bytes=500-100", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("closed clamped to total", "bytes=100-999", 200, REVENANT_RANGE_OK, 100, 100, 0);
    expect("closed beyond total", "bytes=300-399", 200, REVENANT_RANGE_INVALID, 0, 0, 0);

    expect("open range unknown total", "bytes=500-", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_OK, 500, 0, 1);
    expect("open range known total", "bytes=500-", 1000, REVENANT_RANGE_OK, 500, 0, 1);
    expect("open from zero", "bytes=0-", 1000, REVENANT_RANGE_OK, 0, 0, 1);
    expect("open beyond total", "bytes=500-", 200, REVENANT_RANGE_INVALID, 0, 0, 0);

    expect("suffix needs total", "bytes=-500", REVENANT_RANGE_TOTAL_UNKNOWN, REVENANT_RANGE_NEEDS_TOTAL, 0, 0, 0);
    expect("suffix of known total", "bytes=-500", 1000, REVENANT_RANGE_OK, 500, 500, 0);
    expect("suffix equal to total", "bytes=-500", 500, REVENANT_RANGE_OK, 0, 500, 0);
    expect("suffix longer than total", "bytes=-500", 300, REVENANT_RANGE_OK, 0, 300, 0);
    expect("zero suffix", "bytes=-0", 100, REVENANT_RANGE_INVALID, 0, 0, 0);
    expect("negative suffix", "bytes=-500-", 1000, REVENANT_RANGE_INVALID, 0, 0, 0);

    if (failures)
        return 1;
    printf("resource range tests passed\n");
    return 0;
}
