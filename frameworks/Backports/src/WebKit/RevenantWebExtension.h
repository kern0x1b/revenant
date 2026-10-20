#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

#ifndef REVENANT_HOST_DIFFERENTIAL

typedef NSString *WKWebExtensionPermission NS_STRING_ENUM;

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


extern NSString *const WKWebExtensionMatchPatternErrorDomain;

#endif

@interface WKWebExtension (RevenantInit)
- (instancetype)revenant_initWithManifest:(NSDictionary<NSString *, id> *)manifest
                           resourcePath:(NSString *)resourcePath
                                 errors:(NSArray<NSError *> *)errors __attribute__((objc_method_family(init)));
@end

@class WKWebExtensionContext;
@class WKWebExtensionController;
#ifndef REVENANT_HOST_DIFFERENTIAL

@protocol WKWebExtensionWindow;
@protocol WKWebExtensionTab;
@class WKWebView;

extern NSString *const WKWebExtensionMessagePortErrorDomain;


#endif

@interface WKWebExtensionAction (RevenantAction)
- (instancetype)revenant_initWithContext:(WKWebExtensionContext *)context __attribute__((objc_method_family(init)));
- (void)revenant_setLabel:(NSString *)label
              badgeText:(NSString *)badgeText
       inspectionName:(NSString *)inspectionName
             menuItems:(NSArray<UIMenuElement *> *)menuItems
                   icon:(UIImage *)icon
        presentsPopup:(BOOL)presentsPopup
  popupViewController:(UIViewController *)popupViewController
               enabled:(BOOL)enabled;
- (void)revenant_setAssociatedTab:(id<WKWebExtensionTab>)tab;
@end

@interface WKWebExtensionCommand (RevenantCommand)
- (instancetype)revenant_initWithContext:(WKWebExtensionContext *)context
                             identifier:(NSString *)identifier
                                  title:(NSString *)title __attribute__((objc_method_family(init)));
- (void)revenant_setActivationKey:(NSString *)activationKey menuItem:(UIMenuElement *)menuItem;
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


@interface WKWebExtensionContext (RevenantContext)
- (instancetype)revenant_initWithExtension:(WKWebExtension *)extension __attribute__((objc_method_family(init)));
- (void)revenant_buildFromManifest;
@end
