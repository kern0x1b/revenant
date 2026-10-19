#import "../uikit2/uirest.h"
#import <WebKit/WebKit.h>

static NSString *scenario_identifier(void)
{
    return [[NSUUID alloc] initWithUUIDString:@"6F9619FF-8B86-D011-B42D-00C04FC964FF"];
}

static NSArray *controller_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];

    WKWebExtensionControllerConfiguration *nonPersistent = [WKWebExtensionControllerConfiguration nonPersistentConfiguration];
    [lines addObject:ur_line(@"case configuration.nonPersistent.identifier", nonPersistent.identifier)];
    [lines addObject:ur_line(@"case configuration.nonPersistent.persistent", ur_yes(nonPersistent.persistent))];

    WKWebExtensionControllerConfiguration *named = [WKWebExtensionControllerConfiguration configurationWithIdentifier:scenario_identifier()];
    [lines addObject:ur_line(@"case configuration.named.identifier", named.identifier.UUIDString)];
    [lines addObject:ur_line(@"case configuration.named.persistent", ur_yes(named.persistent))];

    WKWebExtensionControllerConfiguration *plainDefault = [WKWebExtensionControllerConfiguration defaultConfiguration];
    [lines addObject:ur_line(@"case configuration.default.identifierIsNil", ur_yes(plainDefault.identifier == nil))];
    [lines addObject:ur_line(@"case configuration.default.persistent", ur_yes(plainDefault.persistent))];
    [lines addObject:ur_line(@"case configuration.default.isTheSameObjectAsNonPersistent", ur_yes(plainDefault == nonPersistent))];

    WKWebExtensionController *controller = [[WKWebExtensionController alloc] initWithConfiguration:named];
    [lines addObject:ur_line(@"case class.controller", NSStringFromClass([controller class]))];
    [lines addObject:ur_line(@"case class.configuration", NSStringFromClass([nonPersistent class]))];
    [lines addObject:ur_line(@"case controller.init.isARealObject", ur_yes(controller != nil))];
    [lines addObject:ur_line(@"case controller.configuration.isTheObjectItWasGiven", ur_yes(controller.configuration == named))];
    [lines addObject:ur_line(@"case controller.delegate", controller.delegate)];
    [lines addObject:ur_line(@"case controller.extensions.count", @(controller.extensions.count))];
    [lines addObject:ur_line(@"case controller.extensionContexts.count", @(controller.extensionContexts.count))];

    NSSet *allTypes = [WKWebExtensionController allExtensionDataTypes];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes.count", @(allTypes.count))];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes", [[allTypes.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","])];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes.hasLocal", ur_yes([allTypes containsObject:WKWebExtensionDataTypeLocal]))];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes.hasSession", ur_yes([allTypes containsObject:WKWebExtensionDataTypeSession]))];
    [lines addObject:ur_line(@"case controller.allExtensionDataTypes.hasSynchronized", ur_yes([allTypes containsObject:WKWebExtensionDataTypeSynchronized]))];

    [lines addObject:ur_line(@"case controller.extensionContextForURL", [controller extensionContextForURL:[NSURL URLWithString:@"https://a.example.com/x"]])];

    [lines addObject:ur_line(@"case constant.DataRecordErrorDomain", WKWebExtensionDataRecordErrorDomain)];
    [lines addObject:ur_line(@"case constant.DataTypeLocal", WKWebExtensionDataTypeLocal)];
    [lines addObject:ur_line(@"case constant.DataTypeSession", WKWebExtensionDataTypeSession)];
    [lines addObject:ur_line(@"case constant.DataTypeSynchronized", WKWebExtensionDataTypeSynchronized)];

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
                                       [lines addObject:ur_line(@"case controller.extensions.afterLoadingOne", @(controller.extensions.count))];
                                       [lines addObject:ur_line(@"case controller.extensionContextForARealExtension", [controller extensionContextForExtension:extension])];
                                   }];
        ur_spin(^BOOL {
            return [lines count] >= 42;
        }, 20.0);
    }

    return lines;
}
