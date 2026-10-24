#ifdef __cplusplus
extern "C" void __sincospi(double, double *, double *);
extern "C" double __sinpi(double);
extern "C" double __cospi(double);
extern "C" double __tanpi(double);
#else
void __sincospi(double, double *, double *);
double __sinpi(double);
double __cospi(double);
double __tanpi(double);
#endif
