#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

#ifndef CHARON_HOST_DIFFERENTIAL

typedef NSString *WKWebExtensionPermission NS_STRING_ENUM NS_SWIFT_NAME(WebExtension.Permission);

extern WKWebExtensionPermission const WKWebExtensionPermissionActiveTab;
extern WKWebExtensionPermission const WKWebExtensionPermissionAlarms;
extern WKWebExtensionPermission const WKWebExtensionPermissionClipboardWrite;
extern WKWebExtensionPermission const WKWebExtensionPermissionContextMenus;
extern WKWebExtensionPermission const WKWebExtensionPermissionCookies;
extern WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequest;
extern WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequestFeedback;
extern WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequestWithHostAccess;
extern WKWebExtensionPermission const WKWebExtensionPermissionMenus;
extern WKWebExtensionPermission const WKWebExtensionPermissionNativeMessaging;
extern WKWebExtensionPermission const WKWebExtensionPermissionScripting;
extern WKWebExtensionPermission const WKWebExtensionPermissionStorage;
extern WKWebExtensionPermission const WKWebExtensionPermissionTabs;
extern WKWebExtensionPermission const WKWebExtensionPermissionUnlimitedStorage;
extern WKWebExtensionPermission const WKWebExtensionPermissionWebNavigation;
extern WKWebExtensionPermission const WKWebExtensionPermissionWebRequest;

extern NSString *const WKWebExtensionErrorDomain;
typedef NS_ENUM(NSInteger, WKWebExtensionError) {
    WKWebExtensionErrorUnknown = 1,
    WKWebExtensionErrorResourceNotFound,
    WKWebExtensionErrorInvalidResourceCodeSignature,
    WKWebExtensionErrorInvalidManifest,
    WKWebExtensionErrorUnsupportedManifestVersion,
    WKWebExtensionErrorInvalidManifestEntry,
    WKWebExtensionErrorInvalidDeclarativeNetRequestEntry,
    WKWebExtensionErrorInvalidBackgroundPersistence,
    WKWebExtensionErrorInvalidArchive,
} API_AVAILABLE(ios(18.4));

typedef NS_OPTIONS(NSUInteger, WKWebExtensionMatchPatternOptions) {
    WKWebExtensionMatchPatternOptionsNone = 0,
    WKWebExtensionMatchPatternOptionsIgnoreSchemes = 1 << 0,
    WKWebExtensionMatchPatternOptionsIgnorePaths = 1 << 1,
    WKWebExtensionMatchPatternOptionsMatchBidirectionally = 1 << 2,
} API_AVAILABLE(ios(18.4));

extern NSString *const WKWebExtensionMatchPatternErrorDomain;
typedef NS_ENUM(NSInteger, WKWebExtensionMatchPatternError) {
    WKWebExtensionMatchPatternErrorUnknown = 1,
    WKWebExtensionMatchPatternErrorInvalidScheme,
    WKWebExtensionMatchPatternErrorInvalidHost,
    WKWebExtensionMatchPatternErrorInvalidPath,
} API_AVAILABLE(ios(18.4));

@interface WKWebExtensionMatchPattern : NSObject <NSCopying>
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithString:(NSString *)string error:(NSError **)error __attribute__((objc_method_family(init)));
- (nullable instancetype)initWithScheme:(NSString *)scheme
                                   host:(NSString *)host
                                   path:(NSString *)path
                                  error:(NSError **)error __attribute__((objc_method_family(init)));
- (BOOL)matchesPattern:(nullable WKWebExtensionMatchPattern *)pattern;
- (BOOL)matchesPattern:(WKWebExtensionMatchPattern *)pattern
               options:(WKWebExtensionMatchPatternOptions)options;
- (BOOL)matchesURL:(NSURL *)url;
- (BOOL)matchesURL:(nullable NSURL *)url options:(WKWebExtensionMatchPatternOptions)options;
@property (nonatomic, readonly, copy) NSString *string;
@property (nonatomic, readonly, copy) NSString *scheme;
@property (nonatomic, readonly, copy) NSString *host;
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly) BOOL matchesAllHosts;
@property (nonatomic, readonly) BOOL matchesAllURLs;
@end

@interface WKWebExtension : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (void)extensionWithAppExtensionBundle:(NSBundle *)appExtensionBundle
                      completionHandler:(void (^)(WKWebExtension *extension, NSError *error))completionHandler;
+ (void)extensionWithResourceBaseURL:(NSURL *)resourceBaseURL
                  completionHandler:(void (^)(WKWebExtension *extension, NSError *error))completionHandler;
- (BOOL)supportsManifestVersion:(double)manifestVersion;
@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *manifest;
@property (nonatomic, readonly) double manifestVersion;
@property (nonatomic, nullable, readonly, copy) NSLocale *defaultLocale;
@property (nonatomic, nullable, readonly, copy) NSString *displayName;
@property (nonatomic, nullable, readonly, copy) NSString *displayShortName;
@property (nonatomic, nullable, readonly, copy) NSString *displayVersion;
@property (nonatomic, nullable, readonly, copy) NSString *displayDescription;
@property (nonatomic, nullable, readonly, copy) NSString *displayActionLabel;
@property (nonatomic, nullable, readonly, copy) NSString *version;
- (nullable UIImage *)iconForSize:(CGSize)size;
- (nullable UIImage *)actionIconForSize:(CGSize)size;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionPermission> *requestedPermissions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionPermission> *optionalPermissions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *requestedPermissionMatchPatterns;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *optionalPermissionMatchPatterns;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *allRequestedMatchPatterns;
@property (nonatomic, readonly) BOOL hasBackgroundContent;
@property (nonatomic, readonly) BOOL hasPersistentBackgroundContent;
@property (nonatomic, readonly) BOOL hasInjectedContent;
@property (nonatomic, readonly) BOOL hasOptionsPage;
@property (nonatomic, readonly) BOOL hasOverrideNewTabPage;
@property (nonatomic, readonly) BOOL hasCommands;
@property (nonatomic, readonly) BOOL hasContentModificationRules;
@end

#endif

@interface WKWebExtension (CharonInit)
- (instancetype)charon_initWithManifest:(NSDictionary<NSString *, id> *)manifest
                           resourcePath:(NSString *)resourcePath
                                 errors:(NSArray<NSError *> *)errors __attribute__((objc_method_family(init)));
@end

@class WKWebExtensionContext;
@class WKWebExtensionController;
#ifndef CHARON_HOST_DIFFERENTIAL

@protocol WKWebExtensionWindow;
@protocol WKWebExtensionTab;
@class WKWebView;

@interface WKWebExtensionAction : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly, weak) WKWebExtensionContext *webExtensionContext;
@property (nonatomic, readonly, nullable, weak) id<WKWebExtensionTab> associatedTab;
- (nullable UIImage *)iconForSize:(CGSize)size;
@property (nonatomic, readonly, copy) NSString *label;
@property (nonatomic, readonly, copy) NSString *badgeText;
@property (nonatomic) BOOL hasUnreadBadgeText;
@property (nonatomic, nullable, copy) NSString *inspectionName;
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, copy) NSArray<UIMenuElement *> *menuItems;
@property (nonatomic, readonly) BOOL presentsPopup;
@property (nonatomic, readonly, nullable) UIViewController *popupViewController;
@property (nonatomic, readonly, nullable) WKWebView *popupWebView;
- (void)closePopup;
@end

@interface WKWebExtensionCommand : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, weak) WKWebExtensionContext *webExtensionContext;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, nullable, copy) NSString *activationKey;
@property (nonatomic) UIKeyModifierFlags modifierFlags;
@property (nonatomic, readonly, copy) UIMenuElement *menuItem;
@property (nonatomic, readonly, copy, nullable) UIKeyCommand *keyCommand;
@end

typedef NS_ENUM(NSInteger, WKWebExtensionWindowType) {
    WKWebExtensionWindowTypeNormal,
    WKWebExtensionWindowTypePopup,
} API_AVAILABLE(ios(18.4));

typedef NS_ENUM(NSInteger, WKWebExtensionWindowState) {
    WKWebExtensionWindowStateNormal,
    WKWebExtensionWindowStateMinimized,
    WKWebExtensionWindowStateMaximized,
    WKWebExtensionWindowStateFullscreen,
} API_AVAILABLE(ios(18.4));

@interface WKWebExtensionTabConfiguration : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, nullable, readonly, strong) id <WKWebExtensionWindow> window;
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, nullable, readonly, strong) id <WKWebExtensionTab> parentTab;
@property (nonatomic, nullable, readonly, copy) NSURL *url;
@property (nonatomic, readonly) BOOL shouldBeActive;
@property (nonatomic, readonly) BOOL shouldAddToSelection;
@property (nonatomic, readonly) BOOL shouldBePinned;
@property (nonatomic, readonly) BOOL shouldBeMuted;
@property (nonatomic, readonly) BOOL shouldReaderModeBeActive;
@end

@interface WKWebExtensionWindowConfiguration : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) WKWebExtensionWindowType windowType;
@property (nonatomic, readonly) WKWebExtensionWindowState windowState;
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly, copy) NSArray<NSURL *> *tabURLs;
@property (nonatomic, readonly, copy) NSArray<id <WKWebExtensionTab>> *tabs;
@property (nonatomic, readonly) BOOL shouldBeFocused;
@property (nonatomic, readonly) BOOL shouldBePrivate;
@end

extern NSString *const WKWebExtensionMessagePortErrorDomain;
typedef NS_ENUM(NSInteger, WKWebExtensionMessagePortError) {
    WKWebExtensionMessagePortErrorUnknown = 1,
    WKWebExtensionMessagePortErrorNotConnected,
    WKWebExtensionMessagePortErrorMessageInvalid,
} API_AVAILABLE(ios(18.4));

@interface WKWebExtensionMessagePort : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, nullable) NSString *applicationIdentifier;
@property (nonatomic, copy, nullable) void (^messageHandler)(id _Nullable message, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^disconnectHandler)(NSError * _Nullable error);
@property (nonatomic, readonly, getter=isDisconnected) BOOL disconnected;
@end

#endif

@interface WKWebExtensionAction (CharonAction)
- (instancetype)charon_initWithContext:(WKWebExtensionContext *)context __attribute__((objc_method_family(init)));
- (void)charon_setLabel:(NSString *)label
              badgeText:(NSString *)badgeText
       inspectionName:(NSString *)inspectionName
             menuItems:(NSArray<UIMenuElement *> *)menuItems
                   icon:(UIImage *)icon
        presentsPopup:(BOOL)presentsPopup
  popupViewController:(UIViewController *)popupViewController
               enabled:(BOOL)enabled;
- (void)charon_setAssociatedTab:(id<WKWebExtensionTab>)tab;
@end

@interface WKWebExtensionCommand (CharonCommand)
- (instancetype)charon_initWithContext:(WKWebExtensionContext *)context
                             identifier:(NSString *)identifier
                                  title:(NSString *)title __attribute__((objc_method_family(init)));
- (void)charon_setActivationKey:(NSString *)activationKey menuItem:(UIMenuElement *)menuItem;
@end

extern NSString *const WKWebExtensionContextErrorDomain;
extern NSString *const WKWebExtensionContextPermissionsWereGrantedNotification;
extern NSString *const WKWebExtensionContextPermissionMatchPatternsWereGrantedNotification;
extern NSString *const WKWebExtensionContextGrantedPermissionsWereRemovedNotification;
extern NSString *const WKWebExtensionContextDeniedPermissionsWereRemovedNotification;
extern NSString *const WKWebExtensionContextPermissionMatchPatternsWereDeniedNotification;
extern NSString *const WKWebExtensionContextDeniedPermissionMatchPatternsWereRemovedNotification;
extern NSString *const WKWebExtensionContextErrorsDidUpdateNotification;
extern NSString *const WKWebExtensionContextNotificationUserInfoKeyPermissions;
extern NSString *const WKWebExtensionContextNotificationUserInfoKeyMatchPatterns;

#ifndef CHARON_HOST_DIFFERENTIAL

typedef NS_ENUM(NSInteger, WKWebExtensionContextPermissionStatus) {
    WKWebExtensionContextPermissionStatusDeniedExplicitly = -3,
    WKWebExtensionContextPermissionStatusDeniedImplicitly = -2,
    WKWebExtensionContextPermissionStatusRequestedImplicitly = -1,
    WKWebExtensionContextPermissionStatusUnknown = 0,
    WKWebExtensionContextPermissionStatusRequestedExplicitly = 1,
    WKWebExtensionContextPermissionStatusGrantedImplicitly = 2,
    WKWebExtensionContextPermissionStatusGrantedExplicitly = 3,
} API_AVAILABLE(ios(18.4));

@interface WKWebExtensionContext : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (nullable instancetype)contextForExtension:(WKWebExtension *)extension;
@property (nonatomic, readonly, weak) WKWebExtensionController *webExtensionController;
@property (nonatomic, readonly, weak) WKWebExtension *webExtension;
@property (nonatomic, readonly, copy) NSUUID *uniqueIdentifier;
@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;
@property (nonatomic, readonly, getter=isInspectable) BOOL inspectable;
@property (nonatomic, readonly, copy) NSURL *baseURL;
@property (nonatomic, readonly, nullable, copy) NSURL *optionsPageURL;
@property (nonatomic, readonly, nullable, copy) NSURL *overrideNewTabPageURL;
@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;
@property (nonatomic, readonly, copy) NSArray<NSString *> *unsupportedAPIs;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionPermission> *grantedPermissions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionPermission> *deniedPermissions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionPermission> *currentPermissions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *grantedPermissionMatchPatterns;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *deniedPermissionMatchPatterns;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *currentPermissionMatchPatterns;
@property (nonatomic, readonly) BOOL hasAccessToAllHosts;
@property (nonatomic, readonly) BOOL hasAccessToAllURLs;
@property (nonatomic, readonly) BOOL hasAccessToPrivateData;
@property (nonatomic, readonly) BOOL hasRequestedOptionalAccessToAllHosts;
@property (nonatomic, readonly) BOOL hasContentModificationRules;
@property (nonatomic, readonly) BOOL hasInjectedContent;
@property (nonatomic, readonly, nullable) WKWebViewConfiguration *webViewConfiguration;
@property (nonatomic, readonly) NSArray<id<WKWebExtensionTab>> *openTabs;
@property (nonatomic, readonly) NSArray<id<WKWebExtensionWindow>> *openWindows;
@property (nonatomic, readonly, nullable) id<WKWebExtensionWindow> focusedWindow;
@property (nonatomic, readonly) NSArray<WKWebExtensionCommand *> *commands;
- (nullable WKWebExtensionAction *)actionForTab:(id<WKWebExtensionTab>)tab;
@property (nonatomic, readonly, nullable) NSString *inspectionName;
@end

#endif

@interface WKWebExtensionContext (CharonContext)
- (instancetype)charon_initWithExtension:(WKWebExtension *)extension __attribute__((objc_method_family(init)));
- (void)charon_buildFromManifest;
@end
