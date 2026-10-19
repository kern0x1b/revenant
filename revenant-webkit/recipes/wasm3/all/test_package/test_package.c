#include <wasm3.h>

static const unsigned char add_module[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f,
    0x03, 0x02, 0x01, 0x00,
    0x07, 0x07, 0x01, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00,
    0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b,
};

int main(void)
{
    IM3Environment environment = m3_NewEnvironment();
    IM3Runtime runtime = m3_NewRuntime(environment, 64 * 1024, NULL);
    IM3Module module;
    IM3Function add;
    int ok = runtime
        && !m3_ParseModule(environment, &module, add_module, sizeof(add_module))
        && !m3_LoadModule(runtime, module)
        && !m3_FindFunction(&add, runtime, "add")
        && !m3_CallV(add, 40, 2);
    int32_t sum = 0;
    ok = ok && !m3_GetResultsV(add, &sum) && sum == 42;
    m3_FreeRuntime(runtime);
    m3_FreeEnvironment(environment);
    return ok ? 0 : 1;
}
