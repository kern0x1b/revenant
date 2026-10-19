/* What the host's WebKit answers for the iOS 18.4 web-extension API, family by family, with no web
 * view of ours anywhere. Every value this prints is a measurement, and each is what the registry
 * rows' `source` names: the host's own WebKit under Mac Catalyst.
 *
 * The manifest is named by WEBEXT_MANIFEST and is this directory's manifest/ subdirectory. Nothing
 * here carries an absolute path: the privacy hook refused a probe that hard-coded one, and it was
 * right. Run it through ./run-webextension.sh rather than by hand.
 *
 * A star in a MATCH PATTERN is data, not prose, and a block comment cannot hold one -- the star in a
 * pattern's path ENDS the comment -- so the patterns are built from a hex escape, which is the real
 * character, and the comments above them say "star".
 */
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#include <stdio.h>

#define STAR "\x2a"

/* WEBEXT_MANIFEST names the manifest.json ITSELF, and the probe uses that path as given: it checks
 * the file is there, and the base URL it loads is the file's own directory, which is deleting the
 * one component and appending NOTHING. The first version deleted the last component and appended
 * "manifest", which guessed at the shape of what it was handed -- a relative invocation resolved
 * elsewhere and the run answered 19 records with no error, because nothing checked how many there
 * should be. The record count is now checked, so that cannot be quiet again. */
static NSString *manifestPath(void)
{
    const char *fromEnv = getenv("WEBEXT_MANIFEST");
    /* RESOLVED, and that is the whole fix for the relative case: a relative path becomes a relative
     * file URL, and WebKit's extension loader is killed by one rather than answering an error --
     * exit 137 with only the 19 pattern records printed, and nothing said why. An absolute path to
     * the manifest.json, either way it is spelled. */
    /* It must be ABSOLUTE, and the probe says so rather than being killed by the loader: handed a
     * relative URL, WebKit's extension loader does not answer an error, it takes the process down
     * (exit 137) with only the 19 pattern records printed and nothing said why. That was measured
     * twice, with a path that exists and with one that does not, and standardising the path does not
     * help -- stringByStandardizingPath resolves ~ and . and leaves a relative path relative. So the
     * check is here, in the probe, where it can be a message. */
    return [(fromEnv ? @(fromEnv) : @"manifest/manifest.json") stringByStandardizingPath];
}

static NSString *manifestDirectory(void)
{
    return [manifestPath() stringByDeletingLastPathComponent];
}

/* How many records this check claims, and it is checked: a run that answers a different number has
 * either lost a case or gained one, and both are silent otherwise.
 *
 * The number belongs to ONE manifest: manifest/manifest.json, committed here beside this program, and the
 * one run.sh hands it. The count was 77 against a manifest that was never committed, so the number
 * described a file nobody else could see and the check could not be reproduced; it is 78 against this one,
 * measured with it. A manifest that changes its permissions, its host permissions or its commands changes
 * this count, and the check is what says so. */
static const int EXPECTED_RECORDS = 78;
static int records = 0;
static int manifestMissed = 0;

static void line(NSString *key, id value)
{
    printf("%s\t%s\n", key.UTF8String,
           value == nil ? "(nil)"
                        : [[value isKindOfClass:[NSString class]] ? value : [value description] UTF8String]);
    fflush(stdout);   /* stdout is fully buffered to a file, and a trap would eat the whole record */
    records++;
}

static void extension_family(void)
{
    NSString *path = manifestPath();
    if (!path.isAbsolutePath) {
        fprintf(stderr, "WEBEXT_MANIFEST must be an ABSOLUTE path to a manifest.json, and got %s: a relative one takes WebKit's extension loader down (exit 137) instead of answering an error\n",
                path.UTF8String);
        manifestMissed = 1;
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        fprintf(stderr, "no manifest at %s\n", path.UTF8String);
        manifestMissed = 1;
        return;
    }
    NSURL *base = [NSURL fileURLWithPath:manifestDirectory() isDirectory:YES];
    [WKWebExtension extensionWithResourceBaseURL:base
                               completionHandler:^(WKWebExtension *e, NSError *err) {
        if (e == nil) {
            line(@"extension/error", err.localizedDescription ?: @"(none)");
            return;
        }
        line(@"extension/errors", @((long)e.errors.count));
        line(@"extension/manifestKeys", @((long)[(NSDictionary *)e.manifest count]));
        for (double v = 0; v <= 5; v += 1)
            line(([NSString stringWithFormat:@"extension/supportsManifestVersion:%ld", (long)v]),
                 [e supportsManifestVersion:v] ? @"YES" : @"NO");
        line(@"extension/manifestVersion", @((long)e.manifestVersion));
        line(@"extension/displayName", e.displayName);
        line(@"extension/displayShortName", e.displayShortName);
        line(@"extension/displayVersion", e.displayVersion);
        line(@"extension/displayDescription", e.displayDescription);
        line(@"extension/displayActionLabel", e.displayActionLabel);
        line(@"extension/defaultLocale", e.defaultLocale);
        NSArray *requested = [[e.requestedPermissions allObjects] sortedArrayUsingSelector:@selector(compare:)];
        NSArray *optional = [[e.optionalPermissions allObjects] sortedArrayUsingSelector:@selector(compare:)];
        line(@"extension/requestedPermissions", [requested componentsJoinedByString:@","]);
        line(@"extension/optionalPermissions", [optional componentsJoinedByString:@","]);
        for (WKWebExtensionMatchPattern *m in e.requestedPermissionMatchPatterns)
            line(@"extension/requestedPattern", m.string);
        for (WKWebExtensionMatchPattern *m in e.optionalPermissionMatchPatterns)
            line(@"extension/optionalPattern", m.string);
        for (WKWebExtensionMatchPattern *m in e.allRequestedMatchPatterns)
            line(@"extension/allRequestedPattern", m.string);
        line(@"extension/hasBackgroundContent", @((long)e.hasBackgroundContent));
        line(@"extension/hasPersistentBackgroundContent", @((long)e.hasPersistentBackgroundContent));
        line(@"extension/hasInjectedContent", @((long)e.hasInjectedContent));
        line(@"extension/hasOptionsPage", @((long)e.hasOptionsPage));
        line(@"extension/hasOverrideNewTabPage", @((long)e.hasOverrideNewTabPage));
        line(@"extension/hasCommands", @((long)e.hasCommands));
        line(@"extension/hasContentModificationRules", @((long)e.hasContentModificationRules));
    }];
}

static void pattern_family(void)
{
    for (NSString *text in @[@("https://example.com/" STAR), @(STAR "://" STAR ".example.com/" STAR),
                             @"<all_urls>", @("http://" STAR "/" STAR),
                             @(STAR "://example.com:8080/x"), @"https://example.com",
                             @("ftp://example.com/" STAR), @"not a pattern", @""]) {
        NSError *e = nil;
        WKWebExtensionMatchPattern *p = [[WKWebExtensionMatchPattern alloc] initWithString:text error:&e];
        NSString *key = [NSString stringWithFormat:@"pattern/parse/%@", text];
        if (p == nil) {
            line(key, e.domain ?: @"(no error)");
            continue;
        }
        line(key, ([NSString stringWithFormat:@"scheme=%@ host=%@ path=%@ allHosts=%ld allURLs=%ld",
                    p.scheme ?: @"(nil)", p.host ?: @"(nil)", p.path ?: @"(nil)",
                    (long)p.matchesAllHosts, (long)p.matchesAllURLs]));
    }
    WKWebExtensionMatchPattern *p = [[WKWebExtensionMatchPattern alloc]
        initWithString:@("https://" STAR ".example.com/api/" STAR) error:NULL];
    for (NSString *u in @[@"https://a.example.com/api/x", @"https://b.example.com/api/",
                          @"https://example.com/api/x", @"http://a.example.com/api/x",
                          @"https://a.example.com/other", @"https://a.example.com/api/x?q=1",
                          @"https://a.example.com:8443/api/x"])
        line(([NSString stringWithFormat:@"pattern/matches/%@", u]),
             [p matchesURL:[NSURL URLWithString:u]] ? @"YES" : @"NO");
    WKWebExtensionMatchPattern *all = [[WKWebExtensionMatchPattern alloc] initWithString:@"<all_urls>" error:NULL];
    for (NSString *u in @[@"https://a.example.com/x", @"about:blank", @"data:text/plain,hi"])
        line(([NSString stringWithFormat:@"pattern/allUrls/%@", u]),
             [all matchesURL:[NSURL URLWithString:u]] ? @"YES" : @"NO");
}

/* An action and a command cannot be MADE by a program -- both headers mark -init and +new
 * NS_UNAVAILABLE -- and neither is allocated here. [WKWebExtensionAction alloc] answers a pointer
 * and then SEGFAULTS when ARC releases the uninitialised object at the end of the scope, which is the
 * whole of the release's answer to a program that tries, and a harness cannot hold an object that
 * dies on release. The fact a row rests on is the header's NS_UNAVAILABLE, and the host's
 * NSInternalInconsistencyException when a context is asked for something that is not an extension. */
static void action_family(void)
{
}

static void context_family(void)
{
    NSString *path = manifestPath();
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        fprintf(stderr, "no manifest at %s\n", path.UTF8String);
        manifestMissed = 1;
        return;
    }
    NSURL *base = [NSURL fileURLWithPath:manifestDirectory() isDirectory:YES];
    [WKWebExtension extensionWithResourceBaseURL:base
                               completionHandler:^(WKWebExtension *ext, NSError *err) {
        if (ext == nil) {
            line(@"context/error", err.localizedDescription ?: @"(none)");
            return;
        }
        WKWebExtensionContext *c = [WKWebExtensionContext contextForExtension:ext];
        line(@"context/isObject", @((long)(c != nil)));
        if (c == nil)
            return;
        line(@"context/webExtensionIsTheOnePassed", @((long)(c.webExtension == ext)));
        line(@"context/webExtensionController", c.webExtensionController);
        line(@"context/uniqueIdentifier", c.uniqueIdentifier);
        line(@"context/baseURL", c.baseURL);
        line(@"context/optionsPageURL", c.optionsPageURL);
        line(@"context/overrideNewTabPageURL", c.overrideNewTabPageURL);
        line(@"context/loaded", @((long)c.loaded));
        line(@"context/inspectable", @((long)c.inspectable));
        line(@"context/errors", @((long)c.errors.count));
        line(@"context/unsupportedAPIs", @((long)c.unsupportedAPIs.count));
        line(@"context/granted", @((long)c.grantedPermissions.count));
        line(@"context/denied", @((long)c.deniedPermissions.count));
        line(@"context/current", @((long)c.currentPermissions.count));
        line(@"context/grantedPatterns", @((long)c.grantedPermissionMatchPatterns.count));
        line(@"context/deniedPatterns", @((long)c.deniedPermissionMatchPatterns.count));
        line(@"context/currentPatterns", @((long)c.currentPermissionMatchPatterns.count));
        line(@"context/hasAccessToAllHosts", @((long)c.hasAccessToAllHosts));
        line(@"context/hasAccessToAllURLs", @((long)c.hasAccessToAllURLs));
        line(@"context/hasAccessToPrivateData", @((long)c.hasAccessToPrivateData));
        line(@"context/hasRequestedOptionalAccessToAllHosts", @((long)c.hasRequestedOptionalAccessToAllHosts));
        line(@"context/hasContentModificationRules", @((long)c.hasContentModificationRules));
        line(@"context/hasInjectedContent", @((long)c.hasInjectedContent));
        line(@"context/webViewConfiguration", c.webViewConfiguration);
        line(@"context/openTabs", @((long)c.openTabs.count));
        line(@"context/openWindows", @((long)c.openWindows.count));
        line(@"context/focusedWindow", c.focusedWindow);
        line(@"context/commands", @((long)c.commands.count));
        WKWebExtensionCommand *first = c.commands.firstObject;
        line(@"context/commandIdentifier", first.identifier);
        line(@"context/commandTitle", first.title);
        line(@"context/inspectionName", c.inspectionName);
    }];
}

int main(void)
{
    @autoreleasepool {
        extension_family();
        pattern_family();
        action_family();
        context_family();
        /* the extension and context families answer through completion handlers on the main queue, so
         * the run loop has to turn or nothing they would print is ever printed */
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:20]];
    }
    if (manifestMissed)
        return 1;
    if (records != EXPECTED_RECORDS) {
        fprintf(stderr, "the probe answered %d records and this check claims %d: a case was lost or gained\n",
                records, EXPECTED_RECORDS);
        return 1;
    }
    return 0;
}
