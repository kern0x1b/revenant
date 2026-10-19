#include "float_bits.h"

double __floatundidf(unsigned long long value)
{
    return charon_double(value);
}
