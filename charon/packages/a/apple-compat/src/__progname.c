#include <stdlib.h>

__attribute__((visibility("hidden")))
const char *__progname;

__attribute__((constructor(101)))
static void charon_read_progname(void)
{
    __progname = getprogname();
}
