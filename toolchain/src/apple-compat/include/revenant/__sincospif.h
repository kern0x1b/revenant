#ifdef __cplusplus
extern "C" void __sincospif(float, float *, float *);
extern "C" float __sinpif(float);
extern "C" float __cospif(float);
extern "C" float __tanpif(float);
#else
void __sincospif(float, float *, float *);
float __sinpif(float);
float __cospif(float);
float __tanpif(float);
#endif
