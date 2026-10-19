/* The content rule list store, held to what the SYSTEM answered: the same scenario, asked of the port,
 * compared with the answers contentrulelist_system.m recorded on this host with no port code in the
 * process. Compiled WITH renames.sh's flags, so every class name in the scenario is the port's.
 *
 * Three things this checks that a comparison alone does not:
 *
 *   1. That the PORT answered. Both classes exist on the host too, so a build that linked the wrong
 *      objects would compare the system against itself and agree with everything: dladdr on the
 *      answering IMP is what tells the two apart.
 *   2. That no case was lost. A scenario that answered fewer lines than it has cases would agree with
 *      a truncated record, so the count is claimed and checked.
 *   3. That the answers came from a store and not from a stub: the store's own directory is asked for
 *      after a compile, through the filesystem, which is the only place a stored list can be seen from
 *      outside the object.
 */
#import "contentrulelist_scenario.h"

/* How many cases the scenario claims, measured by the count this file's first run printed. A run that
 * answers a different number has lost one or gained one, and a comparison against a shorter record
 * would not notice. */
static const NSUInteger EXPECTED_CASES = 109;

/* The image that answered, so a failure says WHICH one answered rather than only that the wrong one
 * did. The port's methods live in this binary and the system's live in the WebKit framework. */
static NSString *answering_image(Class cls, SEL selector)
{
    IMP implementation = cls ? class_getMethodImplementation(cls, selector) : NULL;
    if (implementation == NULL)
        return @"(no implementation)";
    Dl_info info;
    if (!dladdr((void *)implementation, &info) || info.dli_fname == NULL)
        return @"(dladdr knows nothing about it)";
    return @(info.dli_fname);
}

int main(void)
{
    @autoreleasepool {
        const char *path = getenv("CHARON_EXPECTED");
        if (path == NULL) {
            fprintf(stderr, "CHARON_EXPECTED is not set: this program compares against nothing\n");
            return 2;
        }
        NSString *recorded = [NSString stringWithContentsOfFile:@(path) encoding:NSUTF8StringEncoding error:NULL];
        NSMutableArray *system = [NSMutableArray array];
        for (NSString *line in [recorded componentsSeparatedByString:@"\n"])
            if (line.length)
                [system addObject:line];

        /* Which image answers each class: asked first, so a build that linked the wrong objects says so
         * here rather than agreeing with the system about everything. */
        /* asked through the class OBJECT and not through objc_getClass, because this file is compiled
         * with renames.sh's -D flags and a class NAME in a string literal is not renamed: the host's own
         * WKContentRuleListStore would have been asked, and both classes exist on both sides. */
        CHECK([answering_image([WKContentRuleListStore class],
                               @selector(getAvailableContentRuleListIdentifiers:))
                   rangeOfString:@"WebKit"].location == NSNotFound,
              "the port's store answers, not the system's");
        CHECK([answering_image([WKContentRuleList class], @selector(identifier))
                   rangeOfString:@"WebKit"].location == NSNotFound,
              "the port's list answers, not the system's");

        NSArray *ours = content_rule_list_scenario();
        CHECK(ours.count == EXPECTED_CASES, "the scenario answered every case it claims");
        CHECK(system.count == EXPECTED_CASES, "the record holds every case the scenario claims");
        ur_agree(@"content rule list store", ours, system);

        /* the store is a directory with a file in it, which is the only thing outside the object that
         * can show a compiled list was kept: read through the filesystem, not through the store */
        NSURL *url = rule_store();
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:url.path error:NULL];
        CHECK(contents.count == 1, "the store's directory holds exactly one file of its own");

        return charon_failures ? 1 : 0;
    }
}