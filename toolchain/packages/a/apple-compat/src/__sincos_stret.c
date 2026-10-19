double sin(double);
double cos(double);

struct charon_double2 {
    double sine;
    double cosine;
};

__attribute__((visibility("hidden")))
struct charon_double2 __sincos_stret(double x)
{
    struct charon_double2 result = { sin(x), cos(x) };
    return result;
}
