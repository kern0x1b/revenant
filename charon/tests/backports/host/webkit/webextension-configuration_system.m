/* Records what the SYSTEM's WebKit answers for the tab configuration, the window configuration and the
 * message port, with no port code in the process at all. Compiled WITHOUT renames.sh's flags, so every
 * name in the scenario is Apple's.
 */
#import "webextension-configuration_scenario.h"

int main(void)
{
    @autoreleasepool {
        const char *path = getenv("CHARON_EXPECTED");
        if (path == NULL) {
            fprintf(stderr, "CHARON_EXPECTED is not set: this program records what the system answers and has nowhere to put it\n");
            return 2;
        }
        NSArray *answers = webextension_configuration_scenario();
        [[answers componentsJoinedByString:@"\n"] writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("system: recorded %lu answers in %s\n", (unsigned long)answers.count, path);
    }
    return 0;
}
