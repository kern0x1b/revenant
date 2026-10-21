#include "float_bits.h"

float __floatundisf(unsigned long long value)
{
    return revenant_float(value);
}
