#include "revenant_sinpi.h"

double __sinpi(double x)
{
    double sine;
    double sine_tail;
    double cosine;
    double cosine_tail;
    revenant_sincospi_core(x, &sine, &sine_tail, &cosine, &cosine_tail);
    return sine;
}
