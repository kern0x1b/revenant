#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSNotificationName const BACKPORT_IMPL(UISceneWillConnectNotification) = @"UISceneWillConnectNotification";
NSNotificationName const BACKPORT_IMPL(UISceneDidDisconnectNotification) = @"UISceneDidDisconnectNotification";
NSNotificationName const BACKPORT_IMPL(UISceneDidActivateNotification) = @"UISceneDidActivateNotification";
NSNotificationName const BACKPORT_IMPL(UISceneWillDeactivateNotification) = @"UISceneWillDeactivateNotification";
NSNotificationName const BACKPORT_IMPL(UISceneWillEnterForegroundNotification) = @"UISceneWillEnterForegroundNotification";
NSNotificationName const BACKPORT_IMPL(UISceneDidEnterBackgroundNotification) = @"UISceneDidEnterBackgroundNotification";
UISceneSessionRole const BACKPORT_IMPL(UIWindowSceneSessionRoleApplication) = @"UIWindowSceneSessionRoleApplication";
UISceneSessionRole const BACKPORT_IMPL(UIWindowSceneSessionRoleExternalDisplay) = @"UIWindowSceneSessionRoleExternalDisplayNonInteractive";
