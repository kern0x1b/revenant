#include "revenant_sinpi.h"

float __sinpif(float x)
{
    double sine;
    double sine_tail;
    double cosine;
    double cosine_tail;
    revenant_sincospi_core(x, &sine, &sine_tail, &cosine, &cosine_tail);
    return (float)sine;
}
