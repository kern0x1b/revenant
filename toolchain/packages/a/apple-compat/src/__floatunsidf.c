#include "float_bits.h"

double __floatunsidf(unsigned int value)
{
    return charon_double(value);
}
