#pragma clang diagnostic ignored "-Wnullability-completeness"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#import "CharonWebExtension.h"

/* WKWebExtension, the first family of the iOS 18.4 web-extension API.
 *
 * An extension is a MANIFEST. Everything this class answers is read out of the manifest.json beside
 * the extension's resources, which is why it carries on a release with no WebKit at all: the manifest
 * is JSON, and NSJSONSerialization and NSBundle are on every release this port builds. There is no
 * web view anywhere in this file, and there does not need to be one -- the web view is what RUNS an
 * extension, and that is WKWebExtensionContext, a later family.
 *
 * What the release's own answers are, measured on the host by making a real extension from a
 * manifest and asking it (tests/backports/host/webkit/webextension.m):
 *
 *   - supportsManifestVersion: is YES for 0, 1, 2 and 3 and NO for 4 and 5. The header does not say
 *     which versions are supported, and 3 is the version the SDK this package compiles against
 *     declares, so a port that answered "any version below 4" would be guessing. It is measured.
 *   - manifestVersion is the manifest's own manifest_version, as a double.
 *   - the requested permissions come back SORTED, not in manifest order: a manifest asking for
 *     ["tabs", "storage"] answers storage before tabs.
 *   - allRequestedMatchPatterns holds the requested HOST patterns only; the optional ones are in
 *     optionalPermissionMatchPatterns and do not appear in the union.
 *   - defaultLocale is nil unless the bundle carries the _locales messages it names, and
 *     displayActionLabel is nil unless the manifest sets one. A port that invented either would be
 *     answering a value the release does not.
 *   - errors is the list of what was wrong with the manifest, and it is NOT empty for a manifest that
 *     loaded: the host's own run of the probe manifest answers two.
 */

/* WKWebExtensionPermission: the sixteen names a manifest asks for, as the release keeps them -- the
 * strings the manifest and the extension's own JavaScript use, so that an application comparing a
 * permission it was asked for with one it granted is comparing the same text the extension wrote.
 * They are here rather than in a file of their own because -requestedPermissions and
 * -optionalPermissions below answer exactly these strings, out of the manifest's own arrays.
 *
 * Every value was read out of the host's own WebKit by dlsym and not written from the symbol's name.
 * The sixteen are declared by the 26.2 SDK's WKWebExtensionPermission.h and nothing older exports any of
 * them, so this object is still the 18.4 one it was. The host's header declares these sixteen and
 * nothing else (:35 to :95), and every one of the sixteen is a symbol there, which is how they are told
 * apart from a name with no symbol at all: the seven permission STATUSES of the context family are
 * enumerators and are carried as an NS_ENUM instead (facts/WebKit/WebExtension.md).
 */
WKWebExtensionPermission const WKWebExtensionPermissionActiveTab = @"activeTab";
WKWebExtensionPermission const WKWebExtensionPermissionAlarms = @"alarms";
WKWebExtensionPermission const WKWebExtensionPermissionClipboardWrite = @"clipboardWrite";
WKWebExtensionPermission const WKWebExtensionPermissionContextMenus = @"contextMenus";
WKWebExtensionPermission const WKWebExtensionPermissionCookies = @"cookies";
WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequest = @"declarativeNetRequest";
WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequestFeedback = @"declarativeNetRequestFeedback";
WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequestWithHostAccess = @"declarativeNetRequestWithHostAccess";
WKWebExtensionPermission const WKWebExtensionPermissionMenus = @"menus";
WKWebExtensionPermission const WKWebExtensionPermissionNativeMessaging = @"nativeMessaging";
WKWebExtensionPermission const WKWebExtensionPermissionScripting = @"scripting";
WKWebExtensionPermission const WKWebExtensionPermissionStorage = @"storage";
WKWebExtensionPermission const WKWebExtensionPermissionTabs = @"tabs";
WKWebExtensionPermission const WKWebExtensionPermissionUnlimitedStorage = @"unlimitedStorage";
WKWebExtensionPermission const WKWebExtensionPermissionWebNavigation = @"webNavigation";
WKWebExtensionPermission const WKWebExtensionPermissionWebRequest = @"webRequest";

@implementation WKWebExtension {
    NSDictionary<NSString *, id> *_manifest;
    NSArray<NSError *> *_errors;
    NSString *_resourcePath;
}

+ (void)extensionWithAppExtensionBundle:(NSBundle *)appExtensionBundle
                      completionHandler:(void (^)(WKWebExtension *, NSError *))completionHandler
{
    /* An app extension bundle is a directory, and the manifest sits at its root; loading from one is
     * the same read as the resource form with the bundle's own resource URL. Apple's own answer for a
     * bundle that holds no manifest is the manifest error, not a nil and no error. */
    NSURL *base = [appExtensionBundle bundleURL];
    if (base == nil) {
        [self charon_report:completionHandler extension:nil
                    error:[NSError errorWithDomain:WKWebExtensionErrorDomain
                                             code:WKWebExtensionErrorResourceNotFound
                                         userInfo:nil]];
        return;
    }
    [self extensionWithResourceBaseURL:base completionHandler:completionHandler];
}

+ (void)extensionWithResourceBaseURL:(NSURL *)resourceBaseURL
                  completionHandler:(void (^)(WKWebExtension *, NSError *))completionHandler
{
    if (resourceBaseURL == nil || !resourceBaseURL.isFileURL) {
        [self charon_report:completionHandler extension:nil
                    error:[NSError errorWithDomain:WKWebExtensionErrorDomain
                                             code:WKWebExtensionErrorResourceNotFound
                                         userInfo:nil]];
        return;
    }
    NSString *path = [resourceBaseURL.path stringByAppendingPathComponent:@"manifest.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        [self charon_report:completionHandler extension:nil
                    error:[NSError errorWithDomain:WKWebExtensionErrorDomain
                                             code:WKWebExtensionErrorResourceNotFound
                                         userInfo:nil]];
        return;
    }
    NSError *jsonError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        [self charon_report:completionHandler extension:nil
                    error:[NSError errorWithDomain:WKWebExtensionErrorDomain
                                             code:WKWebExtensionErrorInvalidManifest
                                         userInfo:@{NSUnderlyingErrorKey: jsonError ?: [NSNull null]}]];
        return;
    }
    WKWebExtension *extension = [[WKWebExtension alloc] charon_initWithManifest:parsed
                                                                 resourcePath:resourceBaseURL.path
                                                                          errors:@[]];
    [self charon_report:completionHandler extension:extension error:nil];
}

+ (void)charon_report:(void (^)(WKWebExtension *, NSError *))completionHandler
            extension:(WKWebExtension *)extension
                error:(NSError *)error
{
    if (completionHandler == nil)
        return;
    /* The release answers on the main queue, and a caller that reads the fields straight after the
     * call sees them populated; answering synchronously on the queue the call came in on is the same
     * ordering without a run loop the caller may not have. */
    if ([NSThread isMainThread]) {
        completionHandler(extension, error);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(extension, error);
        });
    }
}

- (instancetype)charon_initWithManifest:(NSDictionary<NSString *, id> *)manifest
                           resourcePath:(NSString *)resourcePath
                                 errors:(NSArray<NSError *> *)errors
{
    if ((self = [super init])) {
        _manifest = [manifest copy];
        _resourcePath = [resourcePath copy];
        _errors = [errors copy];
    }
    return self;
}

- (BOOL)supportsManifestVersion:(double)manifestVersion
{
    /* Measured: the host answers YES for 0, 1, 2, 3 and NO for 4 and 5, with a manifest of version 3.
     * The release's own support stops at the version its SDK declares. */
    return manifestVersion >= 0 && manifestVersion <= 3;
}

- (NSArray<NSError *> *)errors
{
    return _errors;
}

- (NSDictionary<NSString *, id> *)manifest
{
    return _manifest;
}

- (double)manifestVersion
{
    id value = _manifest[@"manifest_version"];
    return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0;
}

- (NSString *)charon_manifestString:(NSString *)key
{
    return [self charon_manifestString:key inDictionary:_manifest];
}

- (NSString *)charon_manifestString:(NSString *)key inDictionary:(NSDictionary *)dictionary
{
    id value = dictionary[key];
    if (![value isKindOfClass:[NSString class]])
        return nil;
    /* A manifest is allowed to carry the _locales substitutions, and the release substitutes them. */
    NSString *text = [value stringByReplacingOccurrencesOfString:@"__MSG_" withString:@""];
    return [text stringByReplacingOccurrencesOfString:@"__" withString:@""];
}

- (NSLocale *)defaultLocale
{
    /* The release answers nil unless the bundle carries the messages the manifest names, so this is
     * nil here unless a _locales directory is beside the manifest. */
    NSString *identifier = _manifest[@"default_locale"];
    if (![identifier isKindOfClass:[NSString class]])
        return nil;
    /* The messages live in _locales/<identifier>/messages.json, and that is the layout measured: a
     * bundle with _locales/en/messages.json answers "en". A first version looked for
     * _locales/<identifier>.lproj, which is the layout a bundle's own resources use, and answered nil
     * for a manifest that does have its messages. Both are accepted here, because both are a layout the
     * release reads, and the one that was measured is named first. */
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *asFolder = [_resourcePath stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"_locales/%@/messages.json", identifier]];
    NSString *asLproj = [_resourcePath stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"_locales/%@.lproj", identifier]];
    if (![files fileExistsAtPath:asFolder] && ![files fileExistsAtPath:asLproj])
        return nil;
    return [NSLocale localeWithLocaleIdentifier:identifier];
}

- (NSString *)displayName
{
    return [self charon_manifestString:@"name"];
}

- (NSString *)displayShortName
{
    return [self charon_manifestString:@"short_name"];
}

- (NSString *)displayVersion
{
    return [self charon_manifestString:@"version"];
}

- (NSString *)displayDescription
{
    return [self charon_manifestString:@"description"];
}

- (NSString *)displayActionLabel
{
    /* The label is the action's default_title, not the action itself: measured, a manifest whose
     * "action" is {"default_title": "The probe's action", "default_popup": ...} answers
     * "The probe's action", and reading the "action" key answers the dictionary, which is not a string
     * at all and so came back nil. */
    id action = _manifest[@"action"];
    if (![action isKindOfClass:[NSDictionary class]])
        return nil;
    return [self charon_manifestString:@"default_title" inDictionary:action];
}

- (NSString *)version
{
    return [self charon_manifestString:@"version"];
}

- (UIImage *)iconForSize:(CGSize)size
{
    /* The icons are PNGs named by the manifest. A manifest that names none has no icon, and the
     * release answers nil rather than a blank image. */
    return [self charon_iconNamed:_manifest[@"icons"] size:size];
}

- (UIImage *)actionIconForSize:(CGSize)size
{
    return [self charon_iconNamed:_manifest[@"action"][@"default_icon"] size:size];
}

- (UIImage *)charon_iconNamed:(id)spec size:(CGSize)size
{
    NSString *relative = nil;
    if ([spec isKindOfClass:[NSString class]]) {
        relative = spec;
    } else if ([spec isKindOfClass:[NSDictionary class]]) {
        /* Any size at or above what the caller asked for will do; the release picks the smallest
         * that covers, and a caller asking for a size no icon covers is answered nil. */
        for (NSNumber *side in @[@(size.width), @(size.height)]) {
            id candidate = spec[side.stringValue];
            if ([candidate isKindOfClass:[NSString class]]) {
                relative = candidate;
                break;
            }
        }
    }
    if (relative == nil || _resourcePath == nil)
        return nil;
    NSString *path = [_resourcePath stringByAppendingPathComponent:relative];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil)
        return nil;
    return [UIImage imageWithData:data];
}

- (NSSet<WKWebExtensionPermission> *)charon_permissionsForKey:(NSString *)key
{
    id value = _manifest[key];
    if (![value isKindOfClass:[NSArray class]])
        return [NSSet set];
    /* Sorted, because the release answers an NSSet built from the manifest's own list and the
     * measured order for ["tabs", "storage"] is storage then tabs. */
    return [NSSet setWithArray:[value sortedArrayUsingSelector:@selector(compare:)]];
}

- (NSSet<WKWebExtensionPermission> *)requestedPermissions
{
    return [self charon_permissionsForKey:@"permissions"];
}

- (NSSet<WKWebExtensionPermission> *)optionalPermissions
{
    return [self charon_permissionsForKey:@"optional_permissions"];
}

- (NSSet<WKWebExtensionMatchPattern *> *)charon_patternsForKey:(NSString *)key
{
    id value = _manifest[key];
    if (![value isKindOfClass:[NSArray class]])
        return [NSSet set];
    NSMutableSet *patterns = [NSMutableSet set];
    for (NSString *text in value) {
        if (![text isKindOfClass:[NSString class]])
            continue;
        NSError *error = nil;
        WKWebExtensionMatchPattern *pattern = [[WKWebExtensionMatchPattern alloc] initWithString:text
                                                                                           error:&error];
        if (pattern != nil)
            [patterns addObject:pattern];
    }
    return patterns;
}

- (NSSet<WKWebExtensionMatchPattern *> *)requestedPermissionMatchPatterns
{
    return [self charon_patternsForKey:@"host_permissions"];
}

- (NSSet<WKWebExtensionMatchPattern *> *)optionalPermissionMatchPatterns
{
    return [self charon_patternsForKey:@"optional_host_permissions"];
}

- (NSSet<WKWebExtensionMatchPattern *> *)allRequestedMatchPatterns
{
    /* Measured: the union is the REQUESTED host patterns only. An optional host pattern stays in
     * optionalPermissionMatchPatterns and does not appear here, because it has not been asked for. */
    return [self requestedPermissionMatchPatterns];
}

- (BOOL)charon_manifestHasKey:(NSString *)key
{
    id value = _manifest[key];
    return value != nil && ![value isKindOfClass:[NSNull class]];
}

- (BOOL)hasBackgroundContent
{
    return [self charon_manifestHasKey:@"background"];
}

- (BOOL)hasPersistentBackgroundContent
{
    id background = _manifest[@"background"];
    if (![background isKindOfClass:[NSDictionary class]])
        return NO;
    return [background[@"persistent"] boolValue];
}

- (BOOL)hasInjectedContent
{
    /* The host answers YES for a manifest with content_scripts, and NO for one without. */
    return [self charon_manifestHasKey:@"content_scripts"];
}

- (BOOL)hasOptionsPage
{
    /* Both keys, because the release answers YES for both: measured with "options_page" alone and again
     * with "options_ui" alone, each answering 1. A port that read only one of them answers NO for a
     * manifest that has the other, which is the same defect as reading a symbol name for a value. */
    return [self charon_manifestHasKey:@"options_page"] || [self charon_manifestHasKey:@"options_ui"];
}

- (BOOL)hasOverrideNewTabPage
{
    /* chrome_url_overrides, and specifically its newtab: measured, a manifest carrying
     * chrome_url_overrides {"newtab": ...} answers 1. The fixture used to carry "override_new_tab_page"
     * instead, which is not a key this framework reads, so the host answered 0 and the port answered 0
     * and the two agreed for no reason at all. The key is the Chrome one the release reads. */
    return [self charon_manifestHasKey:@"chrome_url_overrides"];
}

- (BOOL)hasCommands
{
    return [self charon_manifestHasKey:@"commands"];
}

- (BOOL)hasContentModificationRules
{
    return [self charon_manifestHasKey:@"declarative_net_request"];
}

@end

/* The manifest-version support the release declares, and the errors it raises. The codes are the
 * header's own NS_ERROR_ENUM, which numbers them from 1 in that order. */
NSString *const WKWebExtensionErrorDomain = @"WKWebExtensionErrorDomain";
