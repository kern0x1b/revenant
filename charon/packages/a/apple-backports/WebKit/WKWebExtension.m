#pragma clang diagnostic ignored "-Wnullability-completeness"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#import "CharonWebExtension.h"

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
    NSString *text = [value stringByReplacingOccurrencesOfString:@"__MSG_" withString:@""];
    return [text stringByReplacingOccurrencesOfString:@"__" withString:@""];
}

- (NSLocale *)defaultLocale
{
    NSString *identifier = _manifest[@"default_locale"];
    if (![identifier isKindOfClass:[NSString class]])
        return nil;
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
    return [self charon_manifestHasKey:@"content_scripts"];
}

- (BOOL)hasOptionsPage
{
    return [self charon_manifestHasKey:@"options_page"] || [self charon_manifestHasKey:@"options_ui"];
}

- (BOOL)hasOverrideNewTabPage
{
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

NSString *const WKWebExtensionErrorDomain = @"WKWebExtensionErrorDomain";
