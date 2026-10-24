#include "revenant_sinpi.h"

void __sincospif(float x, float *sinp, float *cosp)
{
    double sine;
    double cosine;
    revenant_sincospi_core(x, &sine, &cosine);
    *sinp = (float)sine;
    *cosp = (float)cosine;
}
