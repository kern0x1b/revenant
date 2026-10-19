// UIKit18_0.m - the 18.0 band's object: the twenty-eight classes the build SDK does not declare, and
// nothing else.
//
// ONE OBJECT, ONE RELEASE.  Every class below is introduced 18.0.  release-split reads band points only,
// so a 17.0 or a 26.0 class placed here would pass every mechanical check and be wrong; only a reader sees
// it, which is why the file names its release in three places.
//
// WHY THESE CLASSES EXIST AT ALL.  A class is a DYLD SYMBOL: an application that links strongly against
// UITab names _OBJC_CLASS_$_UITab and dyld has to resolve it before main runs, so for these names "the name
// exists and is exported" is load-bearing rather than a placeholder - without it the application does not
// launch at all.  COORDINATION.md section 2 is explicit: "`absent` for a strong-imported class symbol is
// forbidden - that is not a missing feature, that is dyld killing the application at launch."  The same
// ground carries CharonUIKit26.h's twenty-one 26.0 classes and the 18.2 and 18.4 classes of
// CharonUIKit18.h.
//
// WHY THEY ARE EMPTY.  For a name whose whole requirement is that dyld resolve it, an empty class IS the
// complete honest answer.  A member invented here would be worse than none: it would answer for behaviour
// nobody measured, and 6.1.3 has no tab sidebar, no formatting panel, no zoom transition, no update link
// and no scene system-protection manager, because those arrived with an OS twelve years after the release
// this port replaces.  So every one of the twenty-eight rows says exactly that, and the rows for the
// members that are NOT here say why they are not.
//
// NO CONFORMANCE IS DECLARED, and the two superclasses that are, are there for a different reason.
// UITabGroup and UISearchTab inherit UITab and UITextFormattingViewController inherits UIViewController,
// because an inheritance is what a caller's own code compiles against and both parents resolve at load
// time - UITab from this same object, UIViewController from the port.  The NSCopying and NSSecureCoding
// lists the 26.2 headers give these classes are deliberately left out: a conformance with no
// -copyWithZone: is a promise about a method, and its first caller would crash, which is the opposite of
// what an empty class is for.  UICalendarSelectionWeekOfYear is over NSObject rather than over the
// UICalendarSelection 26.2 declares, because the port carries no UICalendarSelection and a class whose
// superclass the library does not export cannot be resolved by dyld at all.
//
// NOTHING FROM ANOTHER RELEASE IS CALLED HERE, and no C function is defined, so this file is safe in a
// band that does not keep its siblings.  The one member of the 18.0 band the port does answer -
// +[UITraitCollection traitCollectionWithListEnvironment:] - is in UITraitCollection+TraitConstructors18.m
// beside it, because a category cannot hold an ivar and the trait store it writes is UITraitList18.m's;
// the three files are one release between them and no more.
//
// What the release carries is measured in facts/UIKit/UIKit18_0.md.

#import "CharonUIKit18.h"

// The tab bar of 18.0: a tab, a group of tabs, the search tab, the sidebar's scroll target, what a
// sidebar row is asked for, the row itself, and the sidebar.
@implementation UITab
@end

@implementation UITabGroup
@end

@implementation UISearchTab
@end

@implementation UITabSidebarScrollTarget
@end

@implementation UITabSidebarItemRequest
@end

@implementation UITabSidebarItem
@end

@implementation UITabBarControllerSidebar
@end

// Shadow properties, the object a background configuration would share its five shadow values with.
@implementation UIShadowProperties
@end

// Writing Tools and the formatting panel: the style, the descriptor, the component and its group, the
// change value, the panel's configuration, and the panel.
@implementation UITextFormattingViewControllerFormattingStyle
@end

@implementation UITextFormattingViewControllerFormattingDescriptor
@end

@implementation UITextFormattingViewControllerComponent
@end

@implementation UITextFormattingViewControllerComponentGroup
@end

@implementation UITextFormattingViewControllerChangeValue
@end

@implementation UITextFormattingViewControllerConfiguration
@end

@implementation UITextFormattingViewController
@end

// The update link's three objects: the phase, the info about one update, the link itself.
@implementation UIUpdateActionPhase
@end

@implementation UIUpdateInfo
@end

@implementation UIUpdateLink
@end

// The zoom transition and the three contexts its blocks are handed.
@implementation UIZoomTransitionAlignmentRectContext
@end

@implementation UIZoomTransitionInteractionContext
@end

@implementation UIZoomTransitionOptions
@end

@implementation UIZoomTransitionSourceViewProviderContext
@end

@implementation UIViewControllerTransition
@end

// An adaptive image glyph, and the share sheet's collaboration-mode restriction.
@implementation NSAdaptiveImageGlyph
@end

@implementation UIActivityCollaborationModeRestriction
@end

// A week of a year as a calendar selection.
@implementation UICalendarSelectionWeekOfYear
@end

// The document controller's launch options, and a scene's system-protection manager.
@implementation UIDocumentViewControllerLaunchOptions
@end

@implementation UISceneSystemProtectionManager
@end