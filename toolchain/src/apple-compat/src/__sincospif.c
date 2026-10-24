#include "revenant_sinpi.h"

void __sincospif(float x, float *sinp, float *cosp)
{
    double sine;
    double sine_tail;
    double cosine;
    double cosine_tail;
    revenant_sincospi_core(x, &sine, &sine_tail, &cosine, &cosine_tail);
    *sinp = (float)sine;
    *cosp = (float)cosine;
}
