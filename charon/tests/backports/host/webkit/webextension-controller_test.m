/* The controller family, held to what the SYSTEM answered: the same scenario, asked of the port, compared
 * with the answers webextension-controller_system.m recorded on this host with no port code in the
 * process. Compiled WITH renames.sh's flags, so every class name in the scenario is the port's.
 *
 * Three things this checks that a comparison alone does not:
 *
 *   1. That the PORT answered. A class the system also has is one the port and the system both define,
 *      and a build that linked the wrong objects would compare the system against itself and agree with
 *      everything. dladdr on the answering IMP is what tells the two apart: the port's methods live in
 *      this binary and the system's live in the WebKit framework.
 *   2. That the port's CONSTANTS are the port's, for the same reason and by the same means: the address
 *      of the symbol itself, not the string it points at.
 *   3. That no case was lost. A scenario that answered fewer lines than it has cases would agree with a
 *      truncated record, so the count is claimed and checked.
 *
 * The port-only cases are the members the port cannot answer the system's way, and they are here rather
 * than in the shared scenario because asking the host about them would record an answer the port is not
 * meant to match: -webViewConfiguration and -defaultWebsiteDataStore are real objects the host makes and
 * the port has no web view to make, and WKWebExtensionDataRecord cannot be built on the host at all --
 * +new and -init are NS_UNAVAILABLE there. Each carries the value the port is expected to answer, and
 * the reason is in facts/WebKit/WebExtensionController.md.
 */
#import "webextension-controller_scenario.h"
/* The port's OWN headers, for the one thing the SDK's cannot declare: the CharonInit categories the port
 * implements, which are how a WKWebExtensionDataRecord is built at all -- the host marks +new and -init
 * NS_UNAVAILABLE, so no host program can have one. Compiled with -DCHARON_HOST_DIFFERENTIAL, so what these
 * headers contribute here is the port's additions and not a second declaration of Apple's classes. */
#import "CharonWebExtension.h"
#import "CharonWebExtensionController.h"

/* How many cases the scenario claims. A run that answers a different number has lost one or gained one,
 * and a comparison against a shorter record would not notice. */
/* Measured on this host with this manifest: 24 cases before the two that need a real extension, and 26
 * with them. A run that answers a different number has lost one or gained one, and a comparison against a
 * shorter record would not notice. */
static const NSUInteger EXPECTED_CASES = 42;

/* The image that answered, so a failure says WHICH one answered rather than only that the wrong one did. */
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

static BOOL answered_by_the_port(Class cls, SEL selector)
{
    NSString *image = answering_image(cls, selector);
    return [image rangeOfString:@"WebKit"].location == NSNotFound && [image rangeOfString:@"(no"].location == NSNotFound;
}

/* The port's cases: each member the port cannot answer the system's way, with the value it must answer. */
static void port_cases(void)
{
    /* the two members that stay nil, and why: a non-nil answer would be a real WKWebViewConfiguration or
     * WKWebsiteDataStore, and the port has no web view to make either with. */
    WKWebExtensionControllerConfiguration *nonPersistent = [WKWebExtensionControllerConfiguration nonPersistentConfiguration];
    /* the two load methods and the nil-extension case below are asked of a controller of their own, so
     * that nothing they do can change what the cases above measured */
    WKWebExtensionController *bare = [[WKWebExtensionController alloc] initWithConfiguration:nonPersistent];
    charon_check(nonPersistent.webViewConfiguration == nil, "case port.configuration.webViewConfigurationIsNil",
                 nonPersistent.webViewConfiguration);
    charon_check(nonPersistent.defaultWebsiteDataStore == nil, "case port.configuration.defaultWebsiteDataStoreIsNil",
                 nonPersistent.defaultWebsiteDataStore);

    /* the two load methods, which the host answers with a raise rather than an answer: measured,
     * NSInternalInconsistencyException "Invalid parameter not satisfying: [extensionContext
     * isKindOfClass:WKWebExtensionContext.class]" for a nil context. The port answers NO and hands back
     * the context family's error domain instead of throwing, which is this family's rule for a wrong
     * argument -- +configurationWithIdentifier: checks rather than throws for the same reason -- and the
     * port could not load a context if it tried, having no web view to load one into. */
    NSError *loadError = nil;
    BOOL loaded = [bare loadExtensionContext:(WKWebExtensionContext *)nil error:&loadError];
    charon_check(!loaded && [loadError.domain isEqualToString:WKWebExtensionContextErrorDomain],
                 "case port.controller.loadExtensionContext", loadError.domain);
    NSError *unloadError = nil;
    BOOL unloaded = [bare unloadExtensionContext:(WKWebExtensionContext *)nil error:&unloadError];
    charon_check(!unloaded && [unloadError.domain isEqualToString:WKWebExtensionContextErrorDomain],
                 "case port.controller.unloadExtensionContext", unloadError.domain);

    /* the method that makes a context, asked with a NIL extension. The system raises here --
     * NSInternalInconsistencyException, "Invalid parameter not satisfying: [extension isKindOfClass:
     * WKWebExtension.class]", measured -- and the port answers nil. That is this family's own rule and not
     * a gap in it: +configurationWithIdentifier: checks a wrong argument and answers nil for the same
     * reason, and a port that threw where the release throws would crash a caller over a nil it can see
     * coming. It is written down here because a difference is a difference, and in the facts file because
     * a reader of the row deserves to know it. */
    charon_check([bare extensionContextForExtension:(WKWebExtension *)nil] == nil,
                 "case port.controller.extensionContextForNilExtension", @"the port raised");

    /* the data record, which the port builds and the host cannot: +new and -init are NS_UNAVAILABLE on
     * WKWebExtensionDataRecord, so the port's own initialiser is the only way to have one, and every
     * member below has to answer what it was built from. */
    NSArray *types = @[WKWebExtensionDataTypeLocal, WKWebExtensionDataTypeSynchronized];
    NSArray *errors = @[[NSError errorWithDomain:WKWebExtensionDataRecordErrorDomain code:17 userInfo:nil]];
    NSString *identifier = @"A-RECORD-IDENTIFIER";
    NSString *displayName = @"A record";
    WKWebExtensionDataRecord *record = [(WKWebExtensionDataRecord *)[WKWebExtensionDataRecord alloc] charon_initWithIdentifier:identifier
                                                                                                                 displayName:displayName
                                                                                                          containedDataTypes:[NSSet setWithArray:types]
                                                                                                                       errors:errors];
    charon_check([NSStringFromClass([record class]) isEqualToString:@"WKWebExtensionDataRecord"] ||
                 [NSStringFromClass([record class]) rangeOfString:@"WKWebExtensionDataRecord"].location != NSNotFound,
                 "case port.class.dataRecord", NSStringFromClass([record class]));
    charon_check([record.uniqueIdentifier isEqualToString:identifier], "case port.dataRecord.uniqueIdentifier", record.uniqueIdentifier);
    charon_check([record.displayName isEqualToString:displayName], "case port.dataRecord.displayName", record.displayName);
    charon_check([record.containedDataTypes isEqualToSet:[NSSet setWithArray:types]], "case port.dataRecord.containedDataTypes",
                 [[record.containedDataTypes.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]);
    charon_check(record.errors.count == 1 && [record.errors.firstObject.domain isEqualToString:WKWebExtensionDataRecordErrorDomain], "case port.dataRecord.errors",
                 record.errors);
    /* a record the port built holds no bytes, so the total and the size of any set of types are both the
     * zero it was built with -- the same zero the release answers for a record with nothing in it. */
    charon_check(record.totalSizeInBytes == 0, "case port.dataRecord.totalSizeInBytes", @(record.totalSizeInBytes));
    charon_check([record sizeInBytesOfTypes:[NSSet setWithArray:types]] == 0, "case port.dataRecord.sizeInBytesOfTypes",
                 @([record sizeInBytesOfTypes:[NSSet setWithArray:types]]));
}

int main(void)
{
    @autoreleasepool {
        const char *path = getenv("CHARON_EXPECTED");
        if (path == NULL) {
            fprintf(stderr, "CHARON_EXPECTED is not set: the port's answers have nothing to be compared against\n");
            return 2;
        }
        NSString *recorded = [NSString stringWithContentsOfFile:@(path) encoding:NSUTF8StringEncoding error:NULL];
        NSArray *ours = controller_scenario(), *theirs = [recorded componentsSeparatedByString:@"\n"];
        charon_check(ours.count == EXPECTED_CASES, "the scenario answered every case it claims",
                     [NSString stringWithFormat:@"%lu of %lu", (unsigned long)ours.count, (unsigned long)EXPECTED_CASES]);
        ur_agree(@"the controller family's answers are the ones this host gives", ours, theirs);
        port_cases();

        /* which image answered each class, and each constant: without this the comparison above can be
         * the system compared with itself, which agrees with everything including a wrong answer */
        struct {
            const char *label;
            Class cls;
            const char *selector;
        } probes[] = {
            {"WKWebExtensionController", [WKWebExtensionController class], "initWithConfiguration:"},
            {"WKWebExtensionControllerConfiguration", [WKWebExtensionControllerConfiguration class], "nonPersistentConfiguration"},
            {"WKWebExtensionDataRecord", [WKWebExtensionDataRecord class], "charon_initWithIdentifier:displayName:containedDataTypes:errors:"},
        };
        for (size_t index = 0; index < sizeof(probes) / sizeof(probes[0]); index++)
            charon_check(answered_by_the_port(probes[index].cls, sel_registerName(probes[index].selector)),
                         ([NSString stringWithFormat:@"the port's %s is what answers", probes[index].label]).UTF8String,
                         answering_image(probes[index].cls, sel_registerName(probes[index].selector)));

        const void *constants[] = {
            &WKWebExtensionDataRecordErrorDomain, &WKWebExtensionDataTypeLocal,
            &WKWebExtensionDataTypeSession, &WKWebExtensionDataTypeSynchronized,
        };
        for (size_t index = 0; index < sizeof(constants) / sizeof(constants[0]); index++) {
            Dl_info info;
            const char *where = (dladdr((void *)constants[index], &info) && info.dli_fname) ? info.dli_fname : "(dladdr knows nothing about it)";
            charon_check(strstr(where, "WebKit") == NULL, "a constant the port exports is the port's own, not the framework's", @(where));
        }

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures == 0 ? 0 : 1;
}
