/* Records what the SYSTEM's WebKit answers for the controller family, with no port code in the process at
 * all, so the file it writes is the host's own answers and nothing else. run.sh then runs the test
 * against the port with this file as its expectation. Compiled WITHOUT renames.sh's flags, so every name
 * in the scenario is Apple's.
 */
#import "webextension-controller_scenario.h"

int main(void)
{
    @autoreleasepool {
        const char *path = getenv("CHARON_EXPECTED");
        if (path == NULL) {
            fprintf(stderr, "CHARON_EXPECTED is not set: this program records what the system answers and has nowhere to put it\n");
            return 2;
        }
        NSArray *answers = controller_scenario();
        [[answers componentsJoinedByString:@"\n"] writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("system: recorded %lu answers in %s\n", (unsigned long)answers.count, path);
    }
    return 0;
}
