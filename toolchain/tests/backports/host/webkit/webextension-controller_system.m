#import "webextension-controller_scenario.h"

int main(void)
{
    @autoreleasepool {
        const char *path = getenv("REVENANT_EXPECTED");
        if (path == NULL) {
            fprintf(stderr, "REVENANT_EXPECTED is not set: this program records what the system answers and has nowhere to put it\n");
            return 2;
        }
        NSArray *answers = controller_scenario();
        [[answers componentsJoinedByString:@"\n"] writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("system: recorded %lu answers in %s\n", (unsigned long)answers.count, path);
    }
    return 0;
}
