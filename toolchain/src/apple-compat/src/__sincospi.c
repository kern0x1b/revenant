#include "revenant_sinpi.h"

void __sincospi(double x, double *sinp, double *cosp)
{
    revenant_sincospi_core(x, sinp, cosp);
}
