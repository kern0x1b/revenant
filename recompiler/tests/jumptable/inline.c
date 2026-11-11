#include <stdint.h>

extern int32_t xl_inline(int32_t kind);
extern int32_t xl_inline_after(void);

int main(void) {
    static const int32_t expect[] = {10, 20, 30, 40, -1};
    int32_t mask = 0;
    for (int32_t k = 0; k <= 4; k++) {
        if (xl_inline(k) != expect[k]) mask |= (1 << k);
    }
    if (xl_inline_after() != 7) mask |= 1 << 5;
    return mask;
}
