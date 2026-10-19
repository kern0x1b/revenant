// CharonUIKit26.h - the names UIKit's 26.0 band adds, declared because the BUILD SDK does not have them.
//
// The build SDK is 16.4, so none of the classes below exist in a header the port compiles against:
// measured, @interface UIGlassEffect and the other twenty are in no header under the 16.4 SDK's
// UIKit.framework/Headers.  A class is a DYLD SYMBOL - an application that links strongly against
// UIGlassEffect names _OBJC_CLASS_$_UIGlassEffect and dyld has to find it - so for these names the
// whole honest answer is that the NAME EXISTS AND IS EXPORTED.  What the release can do with the name
// afterwards is a different question, and for 26.0 on a 6.1.3 target it is nothing: these are rendering
// styles, scene policies and menu systems that arrived with an OS nine years after the release this port
// replaces.
//
// So each class here is declared and given an empty implementation.  That is not a stub: a class with no
// members IS the complete honest answer for a name whose only requirement is that dyld resolve it, and a
// class with invented members would be worse than an empty one - it would answer for behaviour nobody
// measured.  The registry row for each says exactly that, and the row for a member that is not here
// says why.
//
// Guarded on __has_include, like every other header in this package: if a future build SDK ships one of
// these classes, the SDK's own declaration is used and this file steps aside rather than redefining it.
#ifndef CHARON_UIKIT26_H
#define CHARON_UIKIT26_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if !__has_include(<UIKit/UIGlassEffect.h>)

// The 21 classes of the 26.0 band.  Grouped by what they are, because the grouping is the reason each
// one is empty and the reason none of them claims behaviour.

// Liquid-glass rendering: an effect, and the container that composes one.
API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIGlassEffect : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIGlassContainerEffect : NSObject <NSCopying>
@end

// Corner shaping: a radius as its own object, and the configuration that resolves it per corner.
API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UICornerRadius : NSObject <NSCopying, NSSecureCoding>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UICornerConfiguration : NSObject <NSCopying, NSSecureCoding>
@end

// The scroll-edge treatment and its style.
API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIScrollEdgeEffect : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIScrollEdgeEffectStyle : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIScrollEdgeElementContainerInteraction : NSObject
@end

// Sliders: the tick marks and the per-track configuration, both of which arrived with the redesigned
// control rather than with anything the 6.1.3 slider has.
API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISliderTick : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISliderTrackConfiguration : NSObject <NSCopying>
@end

// The tab accessory, and the badge a bar button item may carry.
API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UITabAccessory : NSObject
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIBarButtonItemBadge : NSObject <NSCopying>
@end

// The menu system: its object, its configuration, the provider that defers, and the group configuration
// the finder walks.
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

// Scene policy: when a scene is destroyed, and which windowing style a scene prefers.
API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISceneDestructionCondition : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISceneWindowingControlStyle : NSObject
@end

// The background extension host view, and the layout region a stack lays its children out in.
API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIBackgroundExtensionView : UIView
@end

API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UIViewLayoutRegion : NSObject <NSCopying>
@end

// The symbol transition that crossfades a symbol as it changes.
API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(watchos)
@interface UISymbolContentTransition : NSObject <NSCopying>
@end

#endif   // !__has_include(<UIKit/UIGlassEffect.h>)

NS_ASSUME_NONNULL_END

#endif   // CHARON_UIKIT26_H