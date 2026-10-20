#include <stdint.h>

extern int32_t xl_dispatch(int32_t kind);

int main(void) {
    static const int32_t expect[] = {100, 200, 999, 999, 300, 400, -1};
    int32_t mask = 0;
    for (int32_t k = 0; k <= 6; k++) {
        if (xl_dispatch(k) != expect[k]) mask |= (1 << k);
    }
    return mask;
}
