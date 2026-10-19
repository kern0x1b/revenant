#ifndef CHARON_UIKIT18_H
#define CHARON_UIKIT18_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if !__has_include(<UIKit/UITab.h>)

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITab : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITabGroup : UITab
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UISearchTab : UITab
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(tvos, watchos)
@interface UITabSidebarScrollTarget : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(tvos, watchos)
@interface UITabSidebarItemRequest : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(tvos, watchos)
@interface UITabSidebarItem : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(tvos, watchos)
@interface UITabBarControllerSidebar : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIShadowProperties : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITextFormattingViewControllerFormattingStyle : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITextFormattingViewControllerFormattingDescriptor : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITextFormattingViewControllerComponent : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITextFormattingViewControllerComponentGroup : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITextFormattingViewControllerChangeValue : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITextFormattingViewControllerConfiguration : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITextFormattingViewController : UIViewController
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIUpdateActionPhase : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIUpdateInfo : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIUpdateLink : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIZoomTransitionAlignmentRectContext : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIZoomTransitionInteractionContext : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIZoomTransitionOptions : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIZoomTransitionSourceViewProviderContext : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIViewControllerTransition : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface NSAdaptiveImageGlyph : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIActivityCollaborationModeRestriction : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(tvos, watchos)
@interface UICalendarSelectionWeekOfYear : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIDocumentViewControllerLaunchOptions : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UISceneSystemProtectionManager : NSObject
@end

#endif

#if !defined(__IPHONE_18_2)

API_AVAILABLE(ios(18.2))
@interface UIWritingToolsCoordinator : NSObject
@end

API_AVAILABLE(ios(18.2))
@interface UIWritingToolsCoordinatorContext : NSObject
@end

API_AVAILABLE(ios(18.2))
@interface UIWritingToolsCoordinatorAnimationParameters : NSObject
@end

#endif

#if !defined(__IPHONE_18_4)

API_AVAILABLE(ios(18.4))
@interface UIConversationContext : NSObject
@end

API_AVAILABLE(ios(18.4))
@interface UIConversationEntry : NSObject
@end

API_AVAILABLE(ios(18.4))
@interface UIMailConversationContext : NSObject
@end

API_AVAILABLE(ios(18.4))
@interface UIMailConversationEntry : NSObject
@end

API_AVAILABLE(ios(18.4))
@interface UIMessageConversationContext : NSObject
@end

API_AVAILABLE(ios(18.4))
@interface UIMessageConversationEntry : NSObject
@end

API_AVAILABLE(ios(18.4))
@interface UIInputSuggestion : NSObject
@end

API_AVAILABLE(ios(18.4))
@interface UISmartReplySuggestion : NSObject
@end

#endif

NS_ASSUME_NONNULL_END

#endif
