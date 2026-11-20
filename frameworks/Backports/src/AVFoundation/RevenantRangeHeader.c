#include "RevenantRangeHeader.h"
#include <limits.h>

static int revenant_decimal(const char **cursor, long long *out)
{
    const char *p = *cursor;
    if (*p < '0' || *p > '9')
        return 0;
    long long value = 0;
    while (*p >= '0' && *p <= '9') {
        int digit = *p - '0';
        if (value > (LLONG_MAX - digit) / 10)
            return 0;
        value = value * 10 + digit;
        p++;
    }
    *cursor = p;
    *out = value;
    return 1;
}

RevenantRangeStatus revenant_range_header_parse(const char *value, long long total,
                                                long long *offset, long long *length, int *to_end)
{
    *offset = 0;
    *length = 0;
    *to_end = 0;
    if (!value) {
        *to_end = 1;
        return REVENANT_RANGE_OK;
    }
    const char *p = value;
    if (p[0] != 'b' || p[1] != 'y' || p[2] != 't' || p[3] != 'e' || p[4] != 's' || p[5] != '=')
        return REVENANT_RANGE_INVALID;
    p += 6;
    if (*p == '-') {
        p++;
        long long suffix;
        if (!revenant_decimal(&p, &suffix) || *p != '\0' || suffix == 0)
            return REVENANT_RANGE_INVALID;
        if (total < 0)
            return REVENANT_RANGE_NEEDS_TOTAL;
        *offset = total > suffix ? total - suffix : 0;
        *length = total < suffix ? total : suffix;
        return REVENANT_RANGE_OK;
    }
    long long first;
    if (!revenant_decimal(&p, &first) || *p != '-')
        return REVENANT_RANGE_INVALID;
    p++;
    if (*p == '\0') {
        if (total >= 0 && first >= total)
            return REVENANT_RANGE_INVALID;
        *offset = first;
        *to_end = 1;
        return REVENANT_RANGE_OK;
    }
    long long last;
    if (!revenant_decimal(&p, &last) || *p != '\0' || last < first)
        return REVENANT_RANGE_INVALID;
    if (total >= 0 && last >= total)
        last = total - 1;
    if (last < first)
        return REVENANT_RANGE_INVALID;
    if (last - first >= LLONG_MAX)
        return REVENANT_RANGE_INVALID;
    *offset = first;
    *length = last - first + 1;
    return REVENANT_RANGE_OK;
}
