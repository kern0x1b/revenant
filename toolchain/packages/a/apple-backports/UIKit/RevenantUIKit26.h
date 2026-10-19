#ifndef CHARON_UIKIT26_H
#define CHARON_UIKIT26_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if !__has_include(<UIKit/UIGlassEffect.h>)

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIGlassEffect : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIGlassContainerEffect : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UICornerRadius : NSObject <NSCopying, NSSecureCoding>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UICornerConfiguration : NSObject <NSCopying, NSSecureCoding>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIScrollEdgeEffect : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIScrollEdgeEffectStyle : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIScrollEdgeElementContainerInteraction : NSObject
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISliderTick : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISliderTrackConfiguration : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UITabAccessory : NSObject
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIBarButtonItemBadge : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIContextMenuSystem : NSObject
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIMainMenuSystem : NSObject
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIMainMenuSystemConfiguration : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIMenuSystemFindElementGroupConfiguration : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIDeferredMenuElementProvider : NSObject
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISceneDestructionCondition : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISceneWindowingControlStyle : NSObject
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIBackgroundExtensionView : UIView
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIViewLayoutRegion : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISymbolContentTransition : NSObject <NSCopying>
@end

#endif

NS_ASSUME_NONNULL_END

#endif
