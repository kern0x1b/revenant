#import "../uikit2/uirest.h"
#import <WebKit/WebKit.h>

static NSURL *extension_fixture_base(void)
{
    const char *fromEnv = getenv("WEBEXT_MANIFEST");
    if (fromEnv == NULL || fromEnv[0] == '\0')
        return nil;
    NSString *path = [@(fromEnv) stringByStandardizingPath];
    if (!path.isAbsolutePath)
        return nil;
    return [NSURL fileURLWithPath:[path stringByDeletingLastPathComponent] isDirectory:YES];
}

static NSArray *extension_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];
    NSURL *base = extension_fixture_base();
    if (base == nil) {
        [lines addObject:ur_line(@"case extension.fixture", @"(no absolute WEBEXT_MANIFEST, so there is no extension to ask)")];
        return lines;
    }
    [WKWebExtension extensionWithResourceBaseURL:base
                               completionHandler:^(WKWebExtension *e, NSError *error) {
        if (e == nil) {
            [lines addObject:ur_line(@"case extension.loaded", @"(the loader refused it)")];
            [lines addObject:ur_line(@"case extension.errorDomain", error.domain ?: @"(no error)")];
            return;
        }
        [lines addObject:ur_line(@"case extension.loaded", ur_yes(YES))];
        [lines addObject:ur_line(@"case extension.manifestKeys", @((long)((NSDictionary *)e.manifest).count))];
        [lines addObject:ur_line(@"case extension.manifestKeyList",
                                 [[[(NSDictionary *)e.manifest allKeys] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","])];
        [lines addObject:ur_line(@"case extension.manifestVersion", @((long)e.manifestVersion))];
        [lines addObject:ur_line(@"case extension.errors", @((long)e.errors.count))];
        for (double v = 0; v <= 5; v += 1)
            [lines addObject:ur_line(([NSString stringWithFormat:@"case extension.supportsManifestVersion:%ld", (long)v]),
                                     ur_yes([e supportsManifestVersion:v]))];

        [lines addObject:ur_line(@"case extension.displayName", e.displayName)];
        [lines addObject:ur_line(@"case extension.displayShortName", e.displayShortName)];
        [lines addObject:ur_line(@"case extension.displayVersion", e.displayVersion)];
        [lines addObject:ur_line(@"case extension.displayDescription", e.displayDescription)];
        [lines addObject:ur_line(@"case extension.displayActionLabel", e.displayActionLabel)];
        [lines addObject:ur_line(@"case extension.version", e.version)];
        [lines addObject:ur_line(@"case extension.defaultLocale", e.defaultLocale.localeIdentifier ?: @"(nil)")];

        NSArray *requested = [e.requestedPermissions.allObjects sortedArrayUsingSelector:@selector(compare:)];
        NSArray *optional = [e.optionalPermissions.allObjects sortedArrayUsingSelector:@selector(compare:)];
        [lines addObject:ur_line(@"case extension.requestedPermissions", [requested componentsJoinedByString:@","])];
        [lines addObject:ur_line(@"case extension.optionalPermissions", [optional componentsJoinedByString:@","])];
        [lines addObject:ur_line(@"case extension.requestedPermissionMatchPatterns",
                                 [[[e.requestedPermissionMatchPatterns.allObjects valueForKey:@"string"] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","])];
        [lines addObject:ur_line(@"case extension.optionalPermissionMatchPatterns",
                                 [[[e.optionalPermissionMatchPatterns.allObjects valueForKey:@"string"] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","])];
        [lines addObject:ur_line(@"case extension.allRequestedMatchPatterns",
                                 [[[e.allRequestedMatchPatterns.allObjects valueForKey:@"string"] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","])];
        [lines addObject:ur_line(@"case extension.requestedPermissionMatchPatternCount",
                                 @((long)e.requestedPermissionMatchPatterns.count))];
        [lines addObject:ur_line(@"case extension.allRequestedMatchPatternCount",
                                 @((long)e.allRequestedMatchPatterns.count))];

        [lines addObject:ur_line(@"case extension.hasBackgroundContent", ur_yes(e.hasBackgroundContent))];
        [lines addObject:ur_line(@"case extension.hasPersistentBackgroundContent", ur_yes(e.hasPersistentBackgroundContent))];
        [lines addObject:ur_line(@"case extension.hasInjectedContent", ur_yes(e.hasInjectedContent))];
        [lines addObject:ur_line(@"case extension.hasOptionsPage", ur_yes(e.hasOptionsPage))];
        [lines addObject:ur_line(@"case extension.hasOverrideNewTabPage", ur_yes(e.hasOverrideNewTabPage))];
        [lines addObject:ur_line(@"case extension.hasCommands", ur_yes(e.hasCommands))];
        [lines addObject:ur_line(@"case extension.hasContentModificationRules", ur_yes(e.hasContentModificationRules))];
    }];
    ur_spin(^BOOL {
        return [lines count] >= 32;
    }, 20.0);
    return lines;
}
