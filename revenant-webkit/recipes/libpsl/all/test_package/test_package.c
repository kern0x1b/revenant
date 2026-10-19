#include <libpsl.h>

int main(void)
{
    const psl_ctx_t *list = psl_builtin();
    if (!list)
        return 1;
    return psl_is_public_suffix(list, "co.uk") && !psl_is_public_suffix(list, "example.co.uk") ? 0 : 1;
}
