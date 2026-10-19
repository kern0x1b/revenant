double sin(double);
double cos(double);

struct revenant_double2 {
    double sine;
    double cosine;
};

__attribute__((visibility("hidden")))
struct revenant_double2 __sincos_stret(double x)
{
    struct revenant_double2 result = { sin(x), cos(x) };
    return result;
}
