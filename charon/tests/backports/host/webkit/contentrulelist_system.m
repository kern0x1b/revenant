/* Records what the SYSTEM's WebKit answers for the content rule list store, with no port code in the
 * process at all, so the file it writes is the host's own answers and nothing else. run.sh then runs
 * the test against the port with this file as its expectation, and against the SAME store directory,
 * so a list the system compiled is still in the store when the port is asked about it.
 *
 * Compiled WITHOUT renames.sh's flags, so every name in the scenario is Apple's.
 */
#import "contentrulelist_scenario.h"

int main(void)
{
    @autoreleasepool {
        const char *path = getenv("CHARON_EXPECTED");
        if (path == NULL) {
            fprintf(stderr, "CHARON_EXPECTED is not set: this program records what the system answers and has nowhere to put it\n");
            return 2;
        }
        NSArray *answers = content_rule_list_scenario();
        [[answers componentsJoinedByString:@"\n"] writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("system: recorded %lu answers in %s\n", (unsigned long)answers.count, path);
    }
    return 0;
}