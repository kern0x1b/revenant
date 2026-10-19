/* Records what the SYSTEM's WebKit answers for the extension family, with no port code in the process, so
 * the file it writes is the host's own answers. Compiled WITHOUT renames.sh's flags. The manifest is the
 * committed fixture, named by WEBEXT_MANIFEST, and both sides are handed the same one.
 */
#import "webextension-extension_scenario.h"

int main(void)
{
    @autoreleasepool {
        const char *path = getenv("CHARON_EXPECTED");
        if (path == NULL) {
            fprintf(stderr, "CHARON_EXPECTED is not set: this program records what the system answers and has nowhere to put it\n");
            return 2;
        }
        NSArray *answers = extension_scenario();
        [[answers componentsJoinedByString:@"\n"] writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("extension-system: recorded %lu answers in %s\n", (unsigned long)answers.count, path);
    }
    return 0;
}
