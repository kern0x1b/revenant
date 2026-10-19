/* The three value holders, held to what the SYSTEM answered: the same scenario, asked of the port,
 * compared with the answers webextension-configuration_system.m recorded on this host with no port code
 * in the process. Compiled WITH renames.sh's flags, so every class name in the scenario is the port's.
 *
 * dladdr on the answering IMP is what tells the two apart: both sides declare all three classes, so a
 * build that linked the wrong objects would compare the system against itself and agree with everything.
 * The class objects are asked through the class OBJECT and not through objc_getClass, because a class
 * NAME in a string literal is not what renames.sh's -D flags rewrite.
 */
#import "webextension-configuration_scenario.h"

static const NSUInteger EXPECTED_CASES = 36;

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

        CHECK([answering_image([WKWebExtensionTabConfiguration class], @selector(index))
                   rangeOfString:@"WebKit"].location == NSNotFound,
              "the port's tab configuration answers, not the system's");
        CHECK([answering_image([WKWebExtensionWindowConfiguration class], @selector(frame))
                   rangeOfString:@"WebKit"].location == NSNotFound,
              "the port's window configuration answers, not the system's");
        CHECK([answering_image([WKWebExtensionMessagePort class], @selector(isDisconnected))
                   rangeOfString:@"WebKit"].location == NSNotFound,
              "the port's message port answers, not the system's");

        NSArray *ours = webextension_configuration_scenario();
        CHECK(ours.count == EXPECTED_CASES, "the scenario answered every case it claims");
        CHECK(system.count == EXPECTED_CASES, "the record holds every case the scenario claims");
        ur_agree(@"the tab and window configurations and the message port", ours, system);
        return charon_failures ? 1 : 0;
    }
}
