#pragma clang diagnostic ignored "-Wnullability-completeness"
#import "CharonWebExtension.h"

/* The measured values of the context's constants. A notification NAME drops the "Notification" suffix
 * its symbol carries, and the two user-info keys are "permissions" and "matchPatterns" -- all read by
 * dlsym on this host, not written from the symbol names. */

NSString *const WKWebExtensionContextErrorDomain = @"WKWebExtensionContextErrorDomain";
NSString *const WKWebExtensionContextPermissionsWereGrantedNotification = @"WKWebExtensionContextPermissionsWereGranted";
NSString *const WKWebExtensionContextPermissionMatchPatternsWereGrantedNotification = @"WKWebExtensionContextPermissionMatchPatternsWereGranted";
NSString *const WKWebExtensionContextGrantedPermissionsWereRemovedNotification = @"WKWebExtensionContextGrantedPermissionsWereRemoved";
NSString *const WKWebExtensionContextDeniedPermissionsWereRemovedNotification = @"WKWebExtensionContextDeniedPermissionsWereRemoved";
NSString *const WKWebExtensionContextPermissionMatchPatternsWereDeniedNotification = @"WKWebExtensionContextPermissionMatchPatternsWereDenied";
NSString *const WKWebExtensionContextDeniedPermissionMatchPatternsWereRemovedNotification = @"WKWebExtensionContextDeniedPermissionMatchPatternsWereRemoved";
NSString *const WKWebExtensionContextErrorsDidUpdateNotification = @"WKWebExtensionContextErrorsDidUpdate";
NSString *const WKWebExtensionContextNotificationUserInfoKeyPermissions = @"permissions";
NSString *const WKWebExtensionContextNotificationUserInfoKeyMatchPatterns = @"matchPatterns";

/* WKWebExtensionContext: what an extension, once it has a context, can do and be asked about.
 *
 * A context is SOFTWARE STATE, not a thing a machine either has or lacks, so it is carried and
 * callable. The host hands one out for a real extension and every member below has a measured answer
 * for a FRESH one -- one made from a manifest and never loaded into a web view -- taken by calling
 * +[WKWebExtensionContext contextForExtension:] on this host with an extension built from
 * $D/ext/manifest.json:
 *
 *   contextForExtension:ext  = 0x102e58330      a real object
 *   webExtension             = the extension    webExtensionController = nil, no controller has it
 *   uniqueIdentifier         = a fresh UUID per call -- two calls answered two different ones
 *   baseURL                  = webkit-extension://<that UUID>/
 *   optionsPageURL           = webkit-extension://<that UUID>/options.html
 *   overrideNewTabPageURL    = nil for a manifest with no chrome_url_overrides
 *   loaded 0   inspectable 0
 *   errors = the extension's own two      unsupportedAPIs = 0
 *   every permission set empty; every has* flag NO except hasInjectedContent, YES for a manifest
 *     with content_scripts
 *   webViewConfiguration = nil            openTabs 0  openWindows 0  focusedWindow nil
 *   commands = 1, and it is NOT the manifest's do-it: its identifier is _execute_action and its
 *     title is the action's default_title, because a manifest with an action section has that
 *     command synthesised for it
 *   inspectionName = the manifest's name, an em dash, and "Extension Background Page" for a
 *     manifest with a background section
 *
 * The two that need a LOADED context and so are answered from stored state a context has not got yet
 * are webExtensionController and webViewConfiguration, and the host answers nil for both on a fresh
 * context -- which is what this carries.
 */

@implementation WKWebExtensionContext {
    __weak WKWebExtension *_webExtension;
    __weak WKWebExtensionController *_controller;
    NSString *_uniqueIdentifier;
    NSString *_inspectionName;
    NSArray<WKWebExtensionCommand *> *_commands;
    BOOL _loaded;
    BOOL _inspectable;
}

+ (instancetype)contextForExtension:(WKWebExtension *)extension
{
    /* The host raises on anything that is not a WKWebExtension -- measured:
     *   NSInternalInconsistencyException, reason: 'Invalid parameter not satisfying:
     *   [extension isKindOfClass:WKWebExtension.class]' -- so this checks rather than lets it throw. */
    if (![extension isKindOfClass:[WKWebExtension class]])
        return nil;
    WKWebExtensionContext *context = [[self alloc] charon_initWithExtension:extension];
    [context charon_buildFromManifest];
    return context;
}

- (instancetype)charon_initWithExtension:(WKWebExtension *)extension
{
    if ((self = [super init])) {
        _webExtension = extension;
        /* A fresh identifier per context, and the base URL carries it: measured, two calls to
         * contextForExtension: answered two different UUIDs and two different base URLs. */
        _uniqueIdentifier = [[[NSUUID UUID] UUIDString] copy];
        _commands = @[];
    }
    return self;
}

- (void)charon_buildFromManifest
{
    WKWebExtension *extension = _webExtension;
    if (extension == nil)
        return;
    /* The command a manifest with an action section gets, which is not one the manifest wrote: the
     * host answers identifier _execute_action and the title from the action's default_title. */
    NSMutableArray<WKWebExtensionCommand *> *commands = [NSMutableArray array];
    id actionSection = extension.manifest[@"action"];
    if (actionSection != nil) {
        (void)[[WKWebExtensionAction alloc] charon_initWithContext:self];
        NSString *title = [actionSection[@"default_title"] isKindOfClass:[NSString class]]
                             ? actionSection[@"default_title"] : extension.displayName;
        WKWebExtensionCommand *execute = [[WKWebExtensionCommand alloc] charon_initWithContext:self
                                                                               identifier:@"_execute_action"
                                                                                    title:title];
        [commands addObject:execute];
    }
    _commands = commands;
    NSMutableString *name = [NSMutableString stringWithString:extension.displayName ?: @""];
    if (extension.hasBackgroundContent)
        [name appendString:@" — Extension Background Page"];
    _inspectionName = [name copy];
}

- (WKWebExtensionController *)webExtensionController
{
    return _controller;
}

- (WKWebExtension *)webExtension
{
    return _webExtension;
}

- (NSString *)uniqueIdentifier
{
    return _uniqueIdentifier;
}

/* -isLoaded and -isInspectable, not -loaded and -inspectable: Apple's own header declares
   `@property (nonatomic, readonly, getter=isLoaded) BOOL loaded` and `@property (nonatomic,
   getter=isInspectable) BOOL inspectable` (WKWebExtensionContext.h:172 and :202), and the getter the
   header names is the API. CharonWebExtension.h now carries the same two attributes, so the property
   and the method that answers it agree with the release. */

- (BOOL)isLoaded
{
    return _loaded;
}

- (BOOL)isInspectable
{
    return _inspectable;
}

- (NSURL *)baseURL
{
    return [NSURL URLWithString:[self charon_baseString]];
}

- (NSString *)charon_baseString
{
    return [NSString stringWithFormat:@"webkit-extension://%@/", _uniqueIdentifier];
}

- (NSURL *)optionsPageURL
{
    if (!_webExtension.hasOptionsPage)
        return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"webkit-extension://%@/options.html", _uniqueIdentifier]];
}

- (NSURL *)overrideNewTabPageURL
{
    /* The host answers nil for a manifest with no chrome_url_overrides, which is what this carries;
     * the page itself is a web view, and a context that has not been loaded has none. */
    return nil;
}

- (NSArray<NSError *> *)errors
{
    return _webExtension.errors;
}

- (NSArray<NSString *> *)unsupportedAPIs
{
    return @[];
}

- (NSSet<WKWebExtensionPermission> *)grantedPermissions
{
    return [NSSet set];
}

- (NSSet<WKWebExtensionPermission> *)deniedPermissions
{
    return [NSSet set];
}

- (NSSet<WKWebExtensionPermission> *)currentPermissions
{
    return [NSSet set];
}

- (NSSet<WKWebExtensionMatchPattern *> *)grantedPermissionMatchPatterns
{
    return [NSSet set];
}

- (NSSet<WKWebExtensionMatchPattern *> *)deniedPermissionMatchPatterns
{
    return [NSSet set];
}

- (NSSet<WKWebExtensionMatchPattern *> *)currentPermissionMatchPatterns
{
    return [NSSet set];
}

- (BOOL)hasAccessToAllHosts
{
    return NO;
}

- (BOOL)hasAccessToAllURLs
{
    return NO;
}

- (BOOL)hasAccessToPrivateData
{
    return NO;
}

- (BOOL)hasRequestedOptionalAccessToAllHosts
{
    return NO;
}

- (BOOL)hasContentModificationRules
{
    return _webExtension.hasContentModificationRules;
}

- (BOOL)hasInjectedContent
{
    return _webExtension.hasInjectedContent;
}

- (WKWebViewConfiguration *)webViewConfiguration
{
    /* nil on the host for a context that has not been loaded, and that is what this carries. */
    return nil;
}

- (NSArray<id<WKWebExtensionTab>> *)openTabs
{
    return @[];
}

- (NSArray<id<WKWebExtensionWindow>> *)openWindows
{
    return @[];
}

- (id<WKWebExtensionWindow>)focusedWindow
{
    return nil;
}

- (NSArray<WKWebExtensionCommand *> *)commands
{
    return _commands;
}

- (WKWebExtensionAction *)actionForTab:(id<WKWebExtensionTab>)tab
{
    return nil;
}

- (NSString *)inspectionName
{
    return _inspectionName;
}

@end
