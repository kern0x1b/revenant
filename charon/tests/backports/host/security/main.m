#import <Foundation/Foundation.h>
#import <stdio.h>
#import "security-cases.h"

// Each constant's value, read out of WHICHER build is linked in: the host's own Security.framework, or
// the port's object. compare.lua requires them to agree, one check per constant, and the port's values
// were written from the host's answers rather than typed.
//
// The recorder is a plain C function, not a block cast to one: this repository's own guide is explicit
// that a block pointer and a function pointer are not the same thing, and it is right.
static void record(const char *name, const char *value)
{
    printf("%s\t%s\n", name, value);
}

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        security_run(record);
    }
    return 0;
}
