#ifndef REVENANT_RANGE_HEADER_H
#define REVENANT_RANGE_HEADER_H

typedef enum {
    REVENANT_RANGE_OK = 0,
    REVENANT_RANGE_INVALID = 1,
    REVENANT_RANGE_NEEDS_TOTAL = 2
} RevenantRangeStatus;

#define REVENANT_RANGE_TOTAL_UNKNOWN (-1LL)

RevenantRangeStatus revenant_range_header_parse(const char *value, long long total,
                                                long long *offset, long long *length, int *to_end);

#endif
