#include "revenant_sinpi.h"

float __cospif(float x)
{
    double sine;
    double cosine;
    revenant_sincospi_core(x, &sine, &cosine);
    return (float)cosine;
}
