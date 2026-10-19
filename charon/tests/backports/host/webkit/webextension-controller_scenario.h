/* The questions both sides are asked, in one place, so the system's WebKit and the port's cannot be
 * asked different ones. This file is compiled TWICE by run.sh: once plain, with no port code in the
 * process, where the names below are Apple's; and once with renames.sh's -D flags, where the very same
 * names are the port's. Each side then answers the same list, in the same order, and the test compares
 * them line by line with ur_agree.
 *
 * What is HERE is what the two sides must answer the same. What they must NOT is in the test file:
 * -webViewConfiguration and -defaultWebsiteDataStore are the two members the port cannot make, and
 * WKWebExtensionDataRecord cannot be built on the host at all, so asking the host about them would
 * record an answer the port is not supposed to match. Those are port cases with the port's own
 * expected values, and the reasons are in facts/WebKit/WebExtensionController.md.
 *
 * Every value here is normalized by ur_norm before it is compared: a CharonHost prefix is stripped and
 * a pointer becomes PTR, so the comparison is about the answer and not about where it was printed from.
 */
#import "../uikit2/uirest.h"
/* The SDK's own WebKit, and NOT the port's headers: in the system build these are Apple's declarations, and
 * in the port build renames.sh's -D flags make the same declarations name the port's classes, which is what
 * lets one file of questions be asked of both sides. */
#import <WebKit/WebKit.h>

/* One fixed UUID, built here and not generated, so both sides are handed the SAME identifier and the
 * answer can be compared as a string. A fresh [NSUUID UUID] per side would differ on every run and the
 * case would fail for a reason that has nothing to do with the port. */
static NSString *scenario_identifier(void)
{
    return [[NSUUID alloc] initWithUUIDString:@"6F9619FF-8B86-D011-B42D-00C04FC964FF"];
}

static NSArray *controller_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];

    /* the configuration, which is a value holder: it exists with no web view at all */
    WKWebExtensionControllerConfiguration *nonPersistent = [WKWebExtensionControllerConfiguration nonPersistentConfiguration];
    [lines addObject:ur_line(@"case configuration.nonPersistent.identifier", nonPersistent.identifier)];
    [lines addObject:ur_line(@"case configuration.nonPersistent.persistent", ur_yes(nonPersistent.persistent))];

    WKWebExtensionControllerConfiguration *named = [WKWebExtensionControllerConfiguration configurationWithIdentifier:scenario_identifier()];
    [lines addObject:ur_line(@"case configuration.named.identifier", named.identifier.UUIDString)];
    [lines addObject:ur_line(@"case configuration.named.persistent", ur_yes(named.persistent))];

    /* the third constructor, whose answers are whatever the system says they are: recorded on the
     * first run of this file, and the port has to match them. */
    WKWebExtensionControllerConfiguration *plainDefault = [WKWebExtensionControllerConfiguration defaultConfiguration];
    [lines addObject:ur_line(@"case configuration.default.identifierIsNil", ur_yes(plainDefault.identifier == nil))];
    [lines addObject:ur_line(@"case configuration.default.persistent", ur_yes(plainDefault.persistent))];
    [lines addObject:ur_line(@"case configuration.default.isTheSameObjectAsNonPersistent", ur_yes(plainDefault == nonPersistent))];

    /* the controller itself, and what it answers before anything is loaded */
    WKWebExtensionController *controller = [[WKWebExtensionController alloc] initWithConfiguration:named];
    [lines addObject:ur_line(@"case class.controller", NSStringFromClass([controller class]))];
    [lines addObject:ur_line(@"case class.configuration", NSStringFromClass([nonPersistent class]))];
    [lines addObject:ur_line(@"case controller.init.isARealObject", ur_yes(controller != nil))];
    [lines addObject:ur_line(@"case controller.configuration.isTheObjectItWasGiven", ur_yes(controller.configuration == named))];
    [lines addObject:ur_line(@"case controller.delegate", controller.delegate)];
    [lines addObject:ur_line(@"case controller.extensions.count", @(controller.extensions.count))];
    [lines addObject:ur_line(@"case controller.extensionContexts.count", @(controller.extensionContexts.count))];

    /* the class property, and the three names in it */
    NSSet *allTypes = [WKWebExtensionController allExtensionDataTypes];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes.count", @(allTypes.count))];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes", [[allTypes.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","])];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes.hasLocal", ur_yes([allTypes containsObject:WKWebExtensionDataTypeLocal]))];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes.hasSession", ur_yes([allTypes containsObject:WKWebExtensionDataTypeSession]))];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes.hasSynchronized", ur_yes([allTypes containsObject:WKWebExtensionDataTypeSynchronized]))];

    /* the method that makes a context for a URL, which answers nil with no web view to make one in. The
     * same method with a NIL extension is not asked here: the system raises
     * NSInternalInconsistencyException on it -- measured, "Invalid parameter not satisfying: [extension
     * isKindOfClass:WKWebExtension.class]" -- and asking both sides would compare a raise with an answer.
     * It is a port case in the test instead, and the reason is there. */
    [lines addObject:ur_line(@"case controller.extensionContextForURL", [controller extensionContextForURL:[NSURL URLWithString:@"https://a.example.com/x"]])];

    /* the constants: their VALUES are what a caller compares, so both sides must carry the same string */
    [lines addObject:ur_line(@"case constant.DataRecordErrorDomain", WKWebExtensionDataRecordErrorDomain)];
    [lines addObject:ur_line(@"case constant.DataTypeLocal", WKWebExtensionDataTypeLocal)];
    [lines addObject:ur_line(@"case constant.DataTypeSession", WKWebExtensionDataTypeSession)];
    [lines addObject:ur_line(@"case constant.DataTypeSynchronized", WKWebExtensionDataTypeSynchronized)];

    /* the sixteen permissions, whose VALUES are the strings a manifest writes: an application compares a
     * permission it was asked for with one it granted, and the comparison is only right if both sides
     * carry the same text. Sixteen names, sixteen cases, and none of them written from the symbol. */
    [lines addObject:ur_line(@"case constant.PermissionActiveTab", WKWebExtensionPermissionActiveTab)];
    [lines addObject:ur_line(@"case constant.PermissionAlarms", WKWebExtensionPermissionAlarms)];
    [lines addObject:ur_line(@"case constant.PermissionClipboardWrite", WKWebExtensionPermissionClipboardWrite)];
    [lines addObject:ur_line(@"case constant.PermissionContextMenus", WKWebExtensionPermissionContextMenus)];
    [lines addObject:ur_line(@"case constant.PermissionCookies", WKWebExtensionPermissionCookies)];
    [lines addObject:ur_line(@"case constant.PermissionDeclarativeNetRequest", WKWebExtensionPermissionDeclarativeNetRequest)];
    [lines addObject:ur_line(@"case constant.PermissionDeclarativeNetRequestFeedback", WKWebExtensionPermissionDeclarativeNetRequestFeedback)];
    [lines addObject:ur_line(@"case constant.PermissionDeclarativeNetRequestWithHostAccess", WKWebExtensionPermissionDeclarativeNetRequestWithHostAccess)];
    [lines addObject:ur_line(@"case constant.PermissionMenus", WKWebExtensionPermissionMenus)];
    [lines addObject:ur_line(@"case constant.PermissionNativeMessaging", WKWebExtensionPermissionNativeMessaging)];
    [lines addObject:ur_line(@"case constant.PermissionScripting", WKWebExtensionPermissionScripting)];
    [lines addObject:ur_line(@"case constant.PermissionStorage", WKWebExtensionPermissionStorage)];
    [lines addObject:ur_line(@"case constant.PermissionTabs", WKWebExtensionPermissionTabs)];
    [lines addObject:ur_line(@"case constant.PermissionUnlimitedStorage", WKWebExtensionPermissionUnlimitedStorage)];
    [lines addObject:ur_line(@"case constant.PermissionWebNavigation", WKWebExtensionPermissionWebNavigation)];
    [lines addObject:ur_line(@"case constant.PermissionWebRequest", WKWebExtensionPermissionWebRequest)];

    /* a real extension, built from the manifest, and the two answers that depend on one. The host needs
     * a manifest on disk; without WEBEXT_MANIFEST the extension is nil and both sides say so, which is
     * recorded as the answer rather than skipped, so a lost manifest cannot pass quietly. */
    const char *manifest = getenv("WEBEXT_MANIFEST");
    if (manifest == NULL || manifest[0] == '\0') {
        [lines addObject:ur_line(@"case controller.extensions.afterLoadingOne", @"no manifest")];
        [lines addObject:ur_line(@"case controller.extensionContextForARealExtension", @"no manifest")];
    } else {
        NSURL *base = [NSURL fileURLWithPath:[@(manifest) stringByDeletingLastPathComponent] isDirectory:YES];
        [WKWebExtension extensionWithResourceBaseURL:base
                                   completionHandler:^(WKWebExtension *extension, NSError *error) {
                                       if (extension == nil) {
                                           [lines addObject:ur_line(@"case controller.extensions.afterLoadingOne", @"the loader refused it")];
                                           [lines addObject:ur_line(@"case controller.extensionContextForARealExtension", @"the loader refused it")];
                                           return;
                                       }
                                       /* the host still answered 0 here, and a port that appended the
                                        * extension would be answering one more than the release */
                                       [lines addObject:ur_line(@"case controller.extensions.afterLoadingOne", @(controller.extensions.count))];
                                       [lines addObject:ur_line(@"case controller.extensionContextForARealExtension", [controller extensionContextForExtension:extension])];
                                   }];
        /* waited for by the scenario's OWN case count, which is what the test checks: a bound of 26 was
         * the count before the sixteen permissions joined this file, and with it the loader's answer was
         * no longer waited for at all -- the system side recorded 40 of the 42 cases and agreed with the
         * port about nothing. */
        ur_spin(^BOOL {
            return [lines count] >= 42;
        }, 20.0);
    }

    return lines;
}
