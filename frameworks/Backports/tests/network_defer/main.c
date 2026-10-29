#include <stdio.h>

extern void *nw_parameters_create(void);
extern const void *RevenantDeferSentinel(void);

int main(void)
{
    const void *value = nw_parameters_create();
    int backport = value == RevenantDeferSentinel();
    printf("nw_parameters_create served by the backport %d (expected %d)\n", backport, REVENANT_DEFER_EXPECT_BACKPORT);
    return backport == REVENANT_DEFER_EXPECT_BACKPORT ? 0 : 1;
}
