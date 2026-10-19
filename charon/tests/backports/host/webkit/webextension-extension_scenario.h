/* The extension family's questions, in one file, asked of the SYSTEM and of the PORT.
 *
 * Compiled twice, the way webextension-controller_scenario.h is: once plain, with no port code in the
 * process, where the names are Apple's; and once with renames.sh's -D flags, where the same names are the
 * port's. webextension.m prints these too, so the questions exist once and the 78 records it claims and
 * the comparison the test makes cannot drift apart.
 *
 * What is asked here is what the host answers for an extension that was loaded from a manifest, and the
 * manifest is manifest/manifest.json, committed beside these files and handed to both sides by run.sh. An
 * extension is the one family on this side that needs something on disk to exist at all, and that is what
 * the fixture is for: without it there is no WKWebExtension object to ask, and the answer would be about
 * the absence of one rather than about the API. Nothing here needs a window, a web view or a user.
 *
 * -defaultLocale is asked for its localeIdentifier rather than its description, because a description is
 * an object dump: the host's answer would be an address and two runs would never agree.
 */
#import "../uikit2/uirest.h"
#import <WebKit/WebKit.h>

/* One fixed manifest, named by the environment and checked to be absolute: a relative one takes WebKit's
 * extension loader down (exit 137) with no error rather than answering one. */
static NSURL *extension_fixture_base(void)
{
    const char *fromEnv = getenv("WEBEXT_MANIFEST");
    if (fromEnv == NULL || fromEnv[0] == '\0')
        return nil;
    NSString *path = [@(fromEnv) stringByStandardizingPath];
    if (!path.isAbsolutePath)
        return nil;
    /* the base URL is the manifest's OWN directory, and that is the whole of it: deleting one component
     * and appending nothing. A first version appended "manifest" and guessed at the shape of what it
     * had been handed. */
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
        /* the manifest itself, and the version it declares */
        [lines addObject:ur_line(@"case extension.loaded", ur_yes(YES))];
        [lines addObject:ur_line(@"case extension.manifestKeys", @((long)((NSDictionary *)e.manifest).count))];
        /* the manifest itself, as its keys: the dictionary is what the row is about, and a count alone
         * would agree with a manifest that carried the same NUMBER of the wrong keys */
        [lines addObject:ur_line(@"case extension.manifestKeyList",
                                 [[[(NSDictionary *)e.manifest allKeys] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","])];
        [lines addObject:ur_line(@"case extension.manifestVersion", @((long)e.manifestVersion))];
        [lines addObject:ur_line(@"case extension.errors", @((long)e.errors.count))];
        for (double v = 0; v <= 5; v += 1)
            [lines addObject:ur_line(([NSString stringWithFormat:@"case extension.supportsManifestVersion:%ld", (long)v]),
                                     ur_yes([e supportsManifestVersion:v]))];

        /* the names the manifest carries, each with the fallback the release applies when the key is
         * absent -- so a port that read the wrong key answers a different string rather than nil */
        [lines addObject:ur_line(@"case extension.displayName", e.displayName)];
        [lines addObject:ur_line(@"case extension.displayShortName", e.displayShortName)];
        [lines addObject:ur_line(@"case extension.displayVersion", e.displayVersion)];
        [lines addObject:ur_line(@"case extension.displayDescription", e.displayDescription)];
        [lines addObject:ur_line(@"case extension.displayActionLabel", e.displayActionLabel)];
        [lines addObject:ur_line(@"case extension.version", e.version)];
        /* the locale by its identifier: the description is an object dump and would never compare */
        [lines addObject:ur_line(@"case extension.defaultLocale", e.defaultLocale.localeIdentifier ?: @"(nil)")];

        /* the permissions, and the patterns that go with them, each sorted so the order a set happens to
         * enumerate in is not part of the answer */
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

        /* what the manifest declares, as the release answers it */
        [lines addObject:ur_line(@"case extension.hasBackgroundContent", ur_yes(e.hasBackgroundContent))];
        [lines addObject:ur_line(@"case extension.hasPersistentBackgroundContent", ur_yes(e.hasPersistentBackgroundContent))];
        [lines addObject:ur_line(@"case extension.hasInjectedContent", ur_yes(e.hasInjectedContent))];
        [lines addObject:ur_line(@"case extension.hasOptionsPage", ur_yes(e.hasOptionsPage))];
        [lines addObject:ur_line(@"case extension.hasOverrideNewTabPage", ur_yes(e.hasOverrideNewTabPage))];
        [lines addObject:ur_line(@"case extension.hasCommands", ur_yes(e.hasCommands))];
        [lines addObject:ur_line(@"case extension.hasContentModificationRules", ur_yes(e.hasContentModificationRules))];
    }];
    /* the loader answers on the main queue, so the run loop has to turn or nothing above is ever asked */
    ur_spin(^BOOL {
        return [lines count] >= 32;
    }, 20.0);
    return lines;
}
