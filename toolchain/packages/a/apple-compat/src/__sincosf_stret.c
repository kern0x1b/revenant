float sinf(float);
float cosf(float);

struct revenant_float2 {
    float sine;
    float cosine;
};

__attribute__((visibility("hidden")))
struct revenant_float2 __sincosf_stret(float x)
{
    struct revenant_float2 result = { sinf(x), cosf(x) };
    return result;
}
