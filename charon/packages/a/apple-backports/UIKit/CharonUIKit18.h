// CharonUIKit18.h - the 18.0, 18.2 and 18.4 names UIKit's 18.x bands add, declared because the BUILD SDK
// does not have them.  The 18.0 block comes first and has a block of its own with its own guard; what
// follows this comment is the 18.2 and 18.4 half, and each half says what its own names are.
//
// The build SDK is 16.4, so none of the classes below exist in a header the port compiles against:
// measured, the 16.4 SDK's UIKit.framework/Headers holds 351 headers and @interface UIGlassEffect,
// @interface UIWritingToolsCoordinator and @interface UIConversationEntry are in none of them (the same
// measurement CharonUIKit26.h rests on).  A class is a DYLD SYMBOL - an application that links
// strongly against UIWritingToolsCoordinator names _OBJC_CLASS_$_UIWritingToolsCoordinator and dyld has
// to find it - so for these names the whole honest answer is that the NAME EXISTS AND IS EXPORTED.
//
// So each class here is declared and given an empty implementation, exactly as CharonUIKit26.h's
// twenty-one are.  That is not a stub: a class with no members IS the complete honest answer for a
// name whose only requirement is that dyld resolve it, and a class with invented members would be
// worse than an empty one - it would answer for behaviour nobody measured.  The registry row for each
// says exactly that.
//
// NO SUPERCLASS BUT NSObject AND NO PROTOCOLS, AND THAT IS THE MEASURED CLAIM, NOT A DEFAULT.  Nothing
// in this tree declares what these classes inherit from or conform to: the 26.2 sysroot is not in the
// store (only iPhoneOS16.4.sdk is, at ~/.xmake/packages/i/iphoneos-sdk/16.4/), so there is no
// declaration here to read a superclass or a protocol list out of, and declaring one would be a guess
// with a symbol on it.  NSObject is the minimum that makes the name exist.  A caller that sends one of
// these a message from UIKit gets an unrecognised-selector answer, which is the same answer it gets
// from a class that exists and has no such method - and the row says so rather than implying a
// behaviour the port has not measured.
//
// THE 18.2 AND 18.4 HALF IS GUARDED ON THE SDK'S OWN AVAILABILITY MACROS rather than on __has_include,
// because the header names these classes live in are not measurable from this tree.  The 18.0 block below
// is guarded on __has_include instead, keyed on the header 26.2 puts UITab in, which is measurable and is
// what the class names there are read from.  AvailabilityVersions.h in the 16.4 SDK
// defines __IPHONE_16_4 as its highest and no __IPHONE_17_* or __IPHONE_18_*, so both guards are open
// here; an SDK of 18.2 or later defines __IPHONE_18_2 and the SDK's own declaration is used instead,
// and this file steps aside rather than redefining it.
#ifndef CHARON_UIKIT18_H
#define CHARON_UIKIT18_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// =====================================================================================
// THE 18.0 BAND: 28 classes, declared for the same reason as the 18.2 and 18.4 ones below and with the
// same limits.  A class is a DYLD SYMBOL - an application that links strongly against UITab names
// _OBJC_CLASS_$_UITab and dyld has to resolve it before main runs - so for these names the whole honest
// answer is that the NAME EXISTS AND IS EXPORTED, and an absent row would be that symbol missing.
// COORDINATION.md section 2: "`absent` for a strong-imported class symbol is forbidden - that is not a
// missing feature, that is dyld killing the application at launch."  CharonUIKit26.h's twenty-one are
// carried on exactly this ground.
//
// Each class is declared with NO MEMBERS, because a member invented here would answer for behaviour
// nobody measured: 6.1.3 has no tab sidebar, no writing-tools formatter, no zoom transition and no
// update link, those arriving with an OS twelve years after the release this port replaces.  Every row
// of this block says exactly that, and the rows for the members that are NOT here say why.
//
// THREE SUPERCLASSES, and only three, because an inheritance is what a caller compiles against and a
// protocol conformance is a promise about a method: UITabGroup and UISearchTab inherit UITab, which
// this same block declares and this same object exports, and UITextFormattingViewController inherits
// UIViewController, which the port already carries.  Both parents resolve at load time, so an instance
// of the child answers everything the parent answers and nothing pretends to.  The conformance lists
// the 26.2 headers give these classes are deliberately NOT transcribed: NSCopying with no -copyWithZone:
// is a claim that crashes its first caller, which is the opposite of what an empty class is for.
//
// UICalendarSelectionWeekOfYear is the one class whose 26.2 superclass is not transcribed, and it is
// not an oversight: 26.2 declares it over UICalendarSelection, the port carries no UICalendarSelection
// (its row is absent in registry/UIKit/ios15-16.json), and a class whose superclass the library does
// not export cannot be resolved by dyld at all - it would trade a missing symbol for a worse one.  So
// it is declared over NSObject and its row says so.
//
// Guarded on __has_include, keyed on the header 26.2 puts UITab in, so an SDK that ships these names
// steps aside rather than redefining them.  Read with the 18.2 block below under different guards:
// both are open on the 16.4 build SDK, which has neither UITab.h nor __IPHONE_18_2.
#if !__has_include(<UIKit/UITab.h>)

// The tab bar of 18.0: a tab, a group of tabs, the search tab, what the sidebar scrolls to, what a
// sidebar row is asked for, the row itself, and the sidebar.
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

// Shadow properties: the object a background configuration shares the five values of a shadow with.
// 6.1.3 draws a shadow through CALayer and has no object for it, so the name is all there is.
API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIShadowProperties : NSObject
@end

// Writing Tools and its formatting panel: the style, the descriptor, the component and its group, the
// change value, the panel's configuration, and the panel itself.
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

// The panel.  Its superclass is UIViewController, which the port carries, so an instance of it is a
// view controller and answers what a view controller answers.
API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UITextFormattingViewController : UIViewController
@end

// The update link's three objects: the phase, the info about one update, the link itself.
API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIUpdateActionPhase : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIUpdateInfo : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIUpdateLink : NSObject
@end

// The zoom transition and the three contexts its blocks are handed.
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

// An adaptive image glyph, and the share sheet's collaboration-mode restriction.
API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface NSAdaptiveImageGlyph : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIActivityCollaborationModeRestriction : NSObject
@end

// A week of a year as a calendar selection.  Over NSObject and not over the UICalendarSelection 26.2
// declares, because the port carries no UICalendarSelection: see the note above the block.
API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(tvos, watchos)
@interface UICalendarSelectionWeekOfYear : NSObject
@end

// The document controller's launch options, and a scene's system-protection manager.
API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UIDocumentViewControllerLaunchOptions : NSObject
@end

API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos)
@interface UISceneSystemProtectionManager : NSObject
@end

#endif   // !__has_include(<UIKit/UITab.h>)

#if !defined(__IPHONE_18_2)

// Writing Tools, iOS 18.2.  Three objects and nothing else: the coordinator a text view talks to, the
// per-request context it hands back, and the timing parameters a text animation is driven with.
API_AVAILABLE(ios(18.2))
@interface UIWritingToolsCoordinator : NSObject
@end

API_AVAILABLE(ios(18.2))
@interface UIWritingToolsCoordinatorContext : NSObject
@end

API_AVAILABLE(ios(18.2))
@interface UIWritingToolsCoordinatorAnimationParameters : NSObject
@end

#endif   // !defined(__IPHONE_18_2)

#if !defined(__IPHONE_18_4)

// The conversation a suggestion belongs to, and the suggestion itself.  Eight names in three families,
// because that is how the queue names them: the abstract pair (UIConversationContext, UIConversationEntry)
// and the two concrete pairs that specialise it for Mail and Messages.
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

// What a text input offers while the user types: one input suggestion, and the smart reply that is one.
API_AVAILABLE(ios(18.4))
@interface UIInputSuggestion : NSObject
@end

API_AVAILABLE(ios(18.4))
@interface UISmartReplySuggestion : NSObject
@end

#endif   // !defined(__IPHONE_18_4)

NS_ASSUME_NONNULL_END

#endif   // CHARON_UIKIT18_H
