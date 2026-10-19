// CharonWebExtension.h — the WebKit web-extension API of iOS 18.4, as this port carries it.
// The 16.4 SDK this package compiles against has no WebKit.framework web-extension API at all, so
// every declaration below is transcribed from the 26.2 SDK's WKWebExtension*.h: the class, its
// members with their kinds and types, and API_AVAILABLE(ios(18.4)). Facts only — no body, no
// behaviour, and nothing that is not in those headers.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// The host's own WebKit is newer than the 16.4 SDK this package builds against and already declares
// everything between here and the matching #endif, so a host comparison compiles with
// -DCHARON_HOST_DIFFERENTIAL and takes the HOST's declarations instead of ours, with the class names
// prefixed by renames.sh so the port's classes and Apple's live side by side in one process. This is the
// guard MetricKit's CharonMetricKit.h and VideoToolbox's CharonVideoToolbox.h use for exactly this
// reason. The Charon* categories below are the port's own and are declared either way: the port
// implements them, so a host build needs them to compile, and the differential calls them.
#ifndef CHARON_HOST_DIFFERENTIAL

typedef NSString *WKWebExtensionPermission NS_STRING_ENUM NS_SWIFT_NAME(WebExtension.Permission);

/* The sixteen permissions a manifest asks for, from the 26.2 SDK's WKWebExtensionPermission.h,
 * one declaration each: they are values, and a caller that reads one wants the string the
 * manifest wrote. Their values are in WKWebExtensionPermission.m, each read off the host. */
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

// The error domain and the codes the 26.2 SDK's NS_ERROR_ENUM numbers from 1 in this order.
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

// The options the two matches methods take, from the 26.2 SDK's NS_OPTIONS.
typedef NS_OPTIONS(NSUInteger, WKWebExtensionMatchPatternOptions) {
    WKWebExtensionMatchPatternOptionsNone = 0,
    WKWebExtensionMatchPatternOptionsIgnoreSchemes = 1 << 0,
    WKWebExtensionMatchPatternOptionsIgnorePaths = 1 << 1,
    WKWebExtensionMatchPatternOptionsMatchBidirectionally = 1 << 2,
} API_AVAILABLE(ios(18.4));

// The match pattern's error domain and codes, from the 26.2 SDK's NS_ERROR_ENUM, which numbers
// them from 1 in the order it declares them.
extern NSString *const WKWebExtensionMatchPatternErrorDomain;
typedef NS_ENUM(NSInteger, WKWebExtensionMatchPatternError) {
    WKWebExtensionMatchPatternErrorUnknown = 1,
    WKWebExtensionMatchPatternErrorInvalidScheme,
    WKWebExtensionMatchPatternErrorInvalidHost,
    WKWebExtensionMatchPatternErrorInvalidPath,
} API_AVAILABLE(ios(18.4));

// The match pattern, which the extension's permission sets are made of. Its own matching behaviour
// is a later family; what WKWebExtension needs to exist is the class and the string form.
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

// The port's own initialiser. WKWebExtension is a class the RELEASE does not carry, so a class row
// answers for its members, but the spelling is charon_-prefixed all the same: a class the SDK does not
// declare has no header to be transcribed from, and a port-owned initialiser on a class that a later
// SDK WILL carry must never collide with Apple's.
#endif  // CHARON_HOST_DIFFERENTIAL

@interface WKWebExtension (CharonInit)
- (instancetype)charon_initWithManifest:(NSDictionary<NSString *, id> *)manifest
                           resourcePath:(NSString *)resourcePath
                                 errors:(NSArray<NSError *> *)errors __attribute__((objc_method_family(init)));
@end

// The toolbar button and the keyboard commands. Both are NS_UNAVAILABLE to a program -- a CONTEXT
// hands them out -- and both are value holders, so the port carries the members and a context
// supplies the values. WKWebExtensionTab and WKWebExtensionContext are forward-declared here: they
// are their own families and this one only holds weak references to them.
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

// The two configurations an extension's request for a tab or a window arrives as, and the connection
// an extension opens to an application. All three are built by WebKit and handed to the application:
// the tab and the window configurations are ARGUMENTS of the two delegate methods that ask for a tab
// and for a window (WKWebExtensionControllerDelegate.h:84 and :97), and the message port arrives in
// the third (WKWebExtensionControllerDelegate.h:203). Nothing in the 26.2 SDK returns one, so no
// program on any platform can build one -- which is why +new and -init are NS_UNAVAILABLE here as they
// are there, and why what the port's members answer is the release's answer for the only object a
// program can have: one WebKit made (facts/WebKit/WebExtensionConfiguration.md).
//
// The two enums of a window's configuration, from the 26.2 SDK's WKWebExtensionWindow.h, which is where
// that release declares them: the port's own header is the only place they can come from, since the
// 16.4 SDK this package compiles against has no web-extension API at all.
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

// The message port's error domain, and the three codes the 26.2 SDK's NS_ERROR_ENUM numbers from 1 in
// that order. The three codes have no symbol on the host and therefore no row: an enumerator is a
// compile-time integer, and `implemented` is a promise that something of that name is built.
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

// The port's own initialisers and setters, charon_-prefixed so they can never collide with a selector
// a later SDK grows, and in the init family because they assign to self.
#endif  // CHARON_HOST_DIFFERENTIAL

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

// WKWebExtensionContext: what an extension, once it is LOADED, can do and be asked about.
//
// The class and its constants are carried. Its members are NOT, and the reason is measured rather
// than assumed: a context only exists once an extension is loaded in a web view, and the host cannot
// be asked for one here. `-[WKWebExtensionController loadExtensionContext:error:]` does not create a
// context -- it CONSUMES one, and the host raises on it when handed anything else:
//
//   *** Terminating app due to uncaught exception 'NSInternalInconsistencyException',
//   reason: 'Invalid parameter not satisfying: [extensionContext isKindOfClass:WKWebExtensionContext.class]'
//   3   WebKit   -[WKWebExtensionController loadExtensionContext:error:]
//
// and the path that does create one, -[WKWebExtensionController extensionContextForExtension:],
// answers nil on this host for an extension built from a resource:
//
//   extensionContextForExtension = 0x0
//
// So every member below is declared and left unimplemented, and its row says what Apple answers
// without a web view. Nothing in this family is marked implemented on the strength of a measurement
// this port did not take.
extern NSString *const WKWebExtensionContextErrorDomain;
extern NSString *const WKWebExtensionContextPermissionsWereGrantedNotification;          /* "...PermissionsWereGranted" */
extern NSString *const WKWebExtensionContextPermissionMatchPatternsWereGrantedNotification;
extern NSString *const WKWebExtensionContextGrantedPermissionsWereRemovedNotification;
extern NSString *const WKWebExtensionContextDeniedPermissionsWereRemovedNotification;
extern NSString *const WKWebExtensionContextPermissionMatchPatternsWereDeniedNotification;
extern NSString *const WKWebExtensionContextDeniedPermissionMatchPatternsWereRemovedNotification;
extern NSString *const WKWebExtensionContextErrorsDidUpdateNotification;                 /* "...ErrorsDidUpdate" */
extern NSString *const WKWebExtensionContextNotificationUserInfoKeyPermissions;          /* "permissions" */
extern NSString *const WKWebExtensionContextNotificationUserInfoKeyMatchPatterns;      /* "matchPatterns" */

// The seven cases with the 26.2 SDK's OWN numbers and its own order, not an enumeration of our own.
// An app compiles against the SDK's header, so it passes -3 for DeniedExplicitly into a port method
// that answers Granted/Denied/Requested, and reads an answer back as the SDK's number. Numbering the
// cases ourselves makes the two sides disagree about what a value means, and that disagreement is
// silent until run time. The numbers are the SDK's, measured by audit-enums.py against
// WKWebExtensionContext.h:85; see facts/WebKit/WebExtension.md.
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
/* getter=isLoaded and getter=isInspectable are Apple's own (WKWebExtensionContext.h:172 and :202);
   without them a client that reads `context.isLoaded` -- the spelling the release documents, and the
   one the Swift overlay's own NS_SWIFT_NAME-free declaration produces -- would not find it. */
@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;
@property (nonatomic, readonly, getter=isInspectable) BOOL inspectable;
@property (nonatomic, readonly, copy) NSURL *baseURL;   /* webkit-extension://<uniqueIdentifier>/ */
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

// The port's own initialiser, charon_-prefixed and in the init family, and the build step the class
// method calls once it has an extension.
#endif  // CHARON_HOST_DIFFERENTIAL

@interface WKWebExtensionContext (CharonContext)
- (instancetype)charon_initWithExtension:(WKWebExtension *)extension __attribute__((objc_method_family(init)));
- (void)charon_buildFromManifest;
@end
