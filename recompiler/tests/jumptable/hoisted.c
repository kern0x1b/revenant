#include <stdint.h>

extern int32_t xl_hoisted(int32_t kind);

int main(void) {
    static const int32_t expect[] = {11, 22, 33, 44, -1};
    int32_t mask = 0;
    for (int32_t k = 0; k <= 4; k++) {
        if (xl_hoisted(k) != expect[k]) mask |= (1 << k);
    }
    return mask;
}
