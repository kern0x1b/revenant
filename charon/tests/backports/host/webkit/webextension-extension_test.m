/* The extension family, held to what the SYSTEM answered for the same manifest: the same scenario, asked
 * of the port, compared with what webextension-extension_system.m recorded on this host with no port code
 * in the process. Compiled WITH renames.sh's flags, so every class name in the scenario is the port's.
 *
 * dladdr is what tells the two apart. WKWebExtension is a class the system declares and the port
 * implements, so a build that linked the wrong objects would compare the system against itself and agree
 * with every answer, including a wrong one. The check comes before the comparison for that reason.
 *
 * The port's own +extensionWithResourceBaseURL:completionHandler: is the port's, not the framework's --
 * it reads the manifest with NSJSONSerialization instead of handing it to WebKit's loader -- so that one
 * is checked with dladdr too, and by name, because it is the method that decides whether there is an
 * extension to ask at all.
 */
#import "webextension-extension_scenario.h"

/* Measured on this host with this manifest; a run that answers a different number has lost one or gained
 * one, and a comparison against a shorter record would not notice. */
static const NSUInteger EXPECTED_CASES = 32;

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
            fprintf(stderr, "CHARON_EXPECTED is not set: the port's answers have nothing to be compared against\n");
            return 2;
        }
        /* which image answers, before anything is compared: a comparison that cannot tell the two apart
         * agrees with everything */
        NSString *image = answering_image([WKWebExtension class], sel_registerName("extensionWithResourceBaseURL:completionHandler:"));
        charon_check([image rangeOfString:@"WebKit"].location == NSNotFound, "the port's own loader is what loads the extension, not the framework's",
                     [NSString stringWithFormat:@"%@ answered +extensionWithResourceBaseURL:completionHandler:", image]);
        NSString *members = answering_image([WKWebExtension class], sel_registerName("displayName"));
        charon_check([members rangeOfString:@"WebKit"].location == NSNotFound, "the port's members are the ones the class answers with",
                     [NSString stringWithFormat:@"%@ answered -displayName", members]);

        NSString *recorded = [NSString stringWithContentsOfFile:@(path) encoding:NSUTF8StringEncoding error:NULL];
        NSArray *ours = extension_scenario(), *theirs = [recorded componentsSeparatedByString:@"\n"];
        charon_check(ours.count == EXPECTED_CASES, "the scenario answered every case it claims",
                     [NSString stringWithFormat:@"%lu of %lu", (unsigned long)ours.count, (unsigned long)EXPECTED_CASES]);
        ur_agree(@"the extension family's answers are the ones this host gives for this manifest", ours, theirs);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures == 0 ? 0 : 1;
}
