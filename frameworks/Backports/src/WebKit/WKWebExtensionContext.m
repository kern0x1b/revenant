#pragma clang diagnostic ignored "-Wnullability-completeness"
#import "RevenantWebExtension.h"

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
    if (![extension isKindOfClass:[WKWebExtension class]])
        return nil;
    WKWebExtensionContext *context = [[self alloc] revenant_initWithExtension:extension];
    [context revenant_buildFromManifest];
    return context;
}

- (instancetype)revenant_initWithExtension:(WKWebExtension *)extension
{
    if ((self = [super init])) {
        _webExtension = extension;
        _uniqueIdentifier = [[[NSUUID UUID] UUIDString] copy];
        _commands = @[];
    }
    return self;
}

- (void)revenant_buildFromManifest
{
    WKWebExtension *extension = _webExtension;
    if (extension == nil)
        return;
    NSMutableArray<WKWebExtensionCommand *> *commands = [NSMutableArray array];
    id actionSection = extension.manifest[@"action"];
    if (actionSection != nil) {
        (void)[[WKWebExtensionAction alloc] revenant_initWithContext:self];
        NSString *title = [actionSection[@"default_title"] isKindOfClass:[NSString class]]
                             ? actionSection[@"default_title"] : extension.displayName;
        WKWebExtensionCommand *execute = [[WKWebExtensionCommand alloc] revenant_initWithContext:self
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
    return [NSURL URLWithString:[self revenant_baseString]];
}

- (NSString *)revenant_baseString
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
