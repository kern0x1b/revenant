#import "webextension-controller_scenario.h"
#import "RevenantWebExtension.h"
#import "RevenantWebExtensionController.h"

static const NSUInteger EXPECTED_CASES = 42;

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

static void port_cases(void)
{
    WKWebExtensionControllerConfiguration *nonPersistent = [WKWebExtensionControllerConfiguration nonPersistentConfiguration];
    WKWebExtensionController *bare = [[WKWebExtensionController alloc] initWithConfiguration:nonPersistent];
    revenant_check(nonPersistent.webViewConfiguration == nil, "case port.configuration.webViewConfigurationIsNil",
                 nonPersistent.webViewConfiguration);
    revenant_check(nonPersistent.defaultWebsiteDataStore == nil, "case port.configuration.defaultWebsiteDataStoreIsNil",
                 nonPersistent.defaultWebsiteDataStore);

    NSError *loadError = nil;
    BOOL loaded = [bare loadExtensionContext:(WKWebExtensionContext *)nil error:&loadError];
    revenant_check(!loaded && [loadError.domain isEqualToString:WKWebExtensionContextErrorDomain],
                 "case port.controller.loadExtensionContext", loadError.domain);
    NSError *unloadError = nil;
    BOOL unloaded = [bare unloadExtensionContext:(WKWebExtensionContext *)nil error:&unloadError];
    revenant_check(!unloaded && [unloadError.domain isEqualToString:WKWebExtensionContextErrorDomain],
                 "case port.controller.unloadExtensionContext", unloadError.domain);

    revenant_check([bare extensionContextForExtension:(WKWebExtension *)nil] == nil,
                 "case port.controller.extensionContextForNilExtension", @"the port raised");

    NSArray *types = @[WKWebExtensionDataTypeLocal, WKWebExtensionDataTypeSynchronized];
    NSArray *errors = @[[NSError errorWithDomain:WKWebExtensionDataRecordErrorDomain code:17 userInfo:nil]];
    NSString *identifier = @"A-RECORD-IDENTIFIER";
    NSString *displayName = @"A record";
    WKWebExtensionDataRecord *record = [(WKWebExtensionDataRecord *)[WKWebExtensionDataRecord alloc] revenant_initWithIdentifier:identifier
                                                                                                                 displayName:displayName
                                                                                                          containedDataTypes:[NSSet setWithArray:types]
                                                                                                                       errors:errors];
    revenant_check([NSStringFromClass([record class]) isEqualToString:@"WKWebExtensionDataRecord"] ||
                 [NSStringFromClass([record class]) rangeOfString:@"WKWebExtensionDataRecord"].location != NSNotFound,
                 "case port.class.dataRecord", NSStringFromClass([record class]));
    revenant_check([record.uniqueIdentifier isEqualToString:identifier], "case port.dataRecord.uniqueIdentifier", record.uniqueIdentifier);
    revenant_check([record.displayName isEqualToString:displayName], "case port.dataRecord.displayName", record.displayName);
    revenant_check([record.containedDataTypes isEqualToSet:[NSSet setWithArray:types]], "case port.dataRecord.containedDataTypes",
                 [[record.containedDataTypes.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]);
    revenant_check(record.errors.count == 1 && [record.errors.firstObject.domain isEqualToString:WKWebExtensionDataRecordErrorDomain], "case port.dataRecord.errors",
                 record.errors);
    revenant_check(record.totalSizeInBytes == 0, "case port.dataRecord.totalSizeInBytes", @(record.totalSizeInBytes));
    revenant_check([record sizeInBytesOfTypes:[NSSet setWithArray:types]] == 0, "case port.dataRecord.sizeInBytesOfTypes",
                 @([record sizeInBytesOfTypes:[NSSet setWithArray:types]]));
}

int main(void)
{
    @autoreleasepool {
        const char *path = getenv("REVENANT_EXPECTED");
        if (path == NULL) {
            fprintf(stderr, "REVENANT_EXPECTED is not set: the port's answers have nothing to be compared against\n");
            return 2;
        }
        NSString *recorded = [NSString stringWithContentsOfFile:@(path) encoding:NSUTF8StringEncoding error:NULL];
        NSArray *ours = controller_scenario(), *theirs = [recorded componentsSeparatedByString:@"\n"];
        revenant_check(ours.count == EXPECTED_CASES, "the scenario answered every case it claims",
                     [NSString stringWithFormat:@"%lu of %lu", (unsigned long)ours.count, (unsigned long)EXPECTED_CASES]);
        ur_agree(@"the controller family's answers are the ones this host gives", ours, theirs);
        port_cases();

        struct {
            const char *label;
            Class cls;
            const char *selector;
        } probes[] = {
            {"WKWebExtensionController", [WKWebExtensionController class], "initWithConfiguration:"},
            {"WKWebExtensionControllerConfiguration", [WKWebExtensionControllerConfiguration class], "nonPersistentConfiguration"},
            {"WKWebExtensionDataRecord", [WKWebExtensionDataRecord class], "revenant_initWithIdentifier:displayName:containedDataTypes:errors:"},
        };
        for (size_t index = 0; index < sizeof(probes) / sizeof(probes[0]); index++)
            revenant_check(answered_by_the_port(probes[index].cls, sel_registerName(probes[index].selector)),
                         ([NSString stringWithFormat:@"the port's %s is what answers", probes[index].label]).UTF8String,
                         answering_image(probes[index].cls, sel_registerName(probes[index].selector)));

        const void *constants[] = {
            &WKWebExtensionDataRecordErrorDomain, &WKWebExtensionDataTypeLocal,
            &WKWebExtensionDataTypeSession, &WKWebExtensionDataTypeSynchronized,
        };
        for (size_t index = 0; index < sizeof(constants) / sizeof(constants[0]); index++) {
            Dl_info info;
            const char *where = (dladdr((void *)constants[index], &info) && info.dli_fname) ? info.dli_fname : "(dladdr knows nothing about it)";
            revenant_check(strstr(where, "WebKit") == NULL, "a constant the port exports is the port's own, not the framework's", @(where));
        }

        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures == 0 ? 0 : 1;
}
