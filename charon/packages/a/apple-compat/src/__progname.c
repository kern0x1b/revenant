#include <stdlib.h>

/* The name of the running program, which a library reads to know what it runs inside and which no SDK header
   declares. The held caches' export tries name iOS 6.0 as the first release that exports it - 53 rungs from 3.0 to
   18.0, read with dyld.first_releases() over the armv7 and armv7s ladder - so every rung below it has no such
   variable, and every one of them exports getprogname(), which the same measurement puts at 3.0 and so at each of
   them. The value is the one the system itself answers with, read into the image's own copy of the variable. */
__attribute__((visibility("hidden")))
const char *__progname;

/* A priority constructor, so the value is there before any other constructor of the image reads it: the release
   fills the variable before the program's own constructors run, and this is the earliest slot clang has for one. */
__attribute__((constructor(101)))
static void charon_read_progname(void)
{
    __progname = getprogname();
}