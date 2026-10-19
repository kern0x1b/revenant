#include <stdlib.h>

__attribute__((visibility("hidden")))
const char *__progname;

__attribute__((constructor(101)))
static void revenant_read_progname(void)
{
    __progname = getprogname();
}
