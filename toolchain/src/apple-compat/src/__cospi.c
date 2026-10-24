#include "revenant_sinpi.h"

double __cospi(double x)
{
    double sine;
    double cosine;
    revenant_sincospi_core(x, &sine, &cosine);
    return cosine;
}
