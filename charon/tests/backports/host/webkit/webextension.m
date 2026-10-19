#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#include <stdio.h>

#define STAR "\x2a"

static NSString *manifestPath(void)
{
    const char *fromEnv = getenv("WEBEXT_MANIFEST");
    return [(fromEnv ? @(fromEnv) : @"manifest/manifest.json") stringByStandardizingPath];
}

static NSString *manifestDirectory(void)
{
    return [manifestPath() stringByDeletingLastPathComponent];
}

static const int EXPECTED_RECORDS = 78;
static int records = 0;
static int manifestMissed = 0;

static void line(NSString *key, id value)
{
    printf("%s\t%s\n", key.UTF8String,
           value == nil ? "(nil)"
                        : [[value isKindOfClass:[NSString class]] ? value : [value description] UTF8String]);
    fflush(stdout);
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
