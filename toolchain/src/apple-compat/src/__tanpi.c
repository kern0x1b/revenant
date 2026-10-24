#include "revenant_sinpi.h"

double __tanpi(double x)
{
    double sine;
    double cosine;
    revenant_sincospi_core(x, &sine, &cosine);
    return sine / cosine;
}
