#include "float_bits.h"

float __floatunsisf(unsigned int value)
{
    return revenant_float(value);
}
