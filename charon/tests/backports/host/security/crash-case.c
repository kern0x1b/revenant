/* The two verdicts a driver must keep apart, and a case that produces each on demand.
 *
 * A case that dies on a signal prints nothing, and a driver that reports a missing output file as a
 * difference says "the port's class was not found" about a process that never got that far. This case
 * exists so the driver is exercised by BOTH shapes without waiting for a real mutation to segfault:
 *
 *   crash    raises SIGSEGV, so the driver must say "crashed: 11" and NOT "class not found"
 *   missing  prints a WRONG line, so the driver must say the difference and name it
 *   clean    prints the value the comparison wants
 *
 * Three times in the Security series a mutation was caught by a signal - EXIT=134 for the C strings and
 * EXIT=139 for the dispatch_data values - and each time the comparison reported the rows after the crash
 * as "the case did not measure it". That is a harness failure reported as a missing class.
 */
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>

/* The `missing` COUNTER, counted by RESOLVING A SYMBOL, because a counter that reads 0 and can never
 * become 1 proves nothing. The first version compared a FUNCTION NAME WITH NULL, which is always false,
 * so the missing path could never fire.
 *
 * argv[1] names the symbol to resolve. Run it with a name that does not exist and `missing` becomes 1 -
 * that is the control, and it is what makes the counter falsifiable.
 */
int main(int argc, char **argv)
{
    if (argc > 2 && strcmp(argv[2], "resolve") == 0) {
        void *found = dlsym(RTLD_DEFAULT, argv[1]);
        printf("resolved\t%s\t%d\n", argv[1], found ? 0 : 1);
        return found ? 0 : 1;
    }
    const char *mode = argc > 1 ? argv[1] : "clean";
    if (strcmp(mode, "crash") == 0) {
        printf("about to die\n");
        fflush(stdout);
        raise(SIGSEGV);            /* no return: nothing after this is printed */
    }
    if (strcmp(mode, "missing") == 0) {
        printf("value\t1\n");      /* one value, so the comparison sees a MISSING one, not a wrong one */
        return 0;
    }
    printf("value\t1\t1\n");
    return 0;
}
