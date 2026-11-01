#include "PoolAlloc.h"

#include <cstdint>
#include <cstdio>

namespace {

int failures = 0;

void expect(bool ok, const char* what)
{
    std::printf("%s: %s\n", ok ? "ok" : "FAILED", what);
    if (!ok)
        ++failures;
}

}

int main()
{
    glslang::TPoolAllocator pool;
    const size_t huge = ~static_cast<size_t>(0);

    expect(pool.allocate(huge - 8) == nullptr, "a request within 8 bytes of SIZE_MAX returns nullptr");
    expect(pool.allocate(huge / 4 + 1) == nullptr, "a request one past SIZE_MAX / 4 returns nullptr");

    unsigned char* small = static_cast<unsigned char*>(pool.allocate(64));
    expect(small != nullptr, "a 64-byte request succeeds");
    if (small) {
        for (int i = 0; i < 64; ++i)
            small[i] = static_cast<unsigned char>(i);
        expect(small[63] == 63, "the 64 bytes are writable");
    }

    pool.popAll();
    std::printf("%d failure(s)\n", failures);
    return failures == 0 ? 0 : 1;
}
