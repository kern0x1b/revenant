#include "float_bits.h"

double __floatunsidf(unsigned int value)
{
    return revenant_double(value);
}
