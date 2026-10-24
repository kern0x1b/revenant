#include "revenant_sinpi.h"

void __sincospi(double x, double *sinp, double *cosp)
{
    double sine_tail;
    double cosine_tail;
    revenant_sincospi_core(x, sinp, &sine_tail, cosp, &cosine_tail);
}
