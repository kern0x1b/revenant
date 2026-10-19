// The debug description of a Writing Tools text animation, iOS 18.2
// (facts/UIKit/UIWritingToolsCoordinatorTextAnimation.md).
//
// One object carries one release: the symbol here is first exported by iOS 18.2, so every band
// from 18.2 on re-exports the release's own and the bands below keep this one.
//
// Every string below was measured by calling the Mac Catalyst UIKit's own function on macOS 27
// (the probe and its output are in .agent-work/runs/uikit-c/), not taken from a header and not
// guessed from the case names.

#import <UIKit/UIKit.h>

// The three cases SDK 26.2's header declares (UIWritingToolsCoordinator.h:431-447), which carry no
// explicit values and are 0, 1 and 2 in the order it declares them, and the answer the framework
// gives for a value that is none of them - which is a name, not nil. The cases are written as their
// numbers so that one body serves both spellings of the parameter below.
static NSString *CharonAnimationDescription(NSInteger animationType)
{
    switch (animationType) {
    case 0: return @"Awaiting-new-text animation";
    case 1: return @"Text removal animation";
    case 2: return @"Text insertion animation";
    }
    return @"Unknown text animation";
}

// UIWritingToolsCoordinatorTextAnimation is an iOS 18.2 enumeration, and this package is built
// against the 16.4 SDK as well as the 26.2 one. The 16.4 SDK declares neither the type nor the
// function, so there the parameter is spelled with the type the enumeration stands for; on an SDK
// that has the enumeration the spelling is the header's own, which is what the definition has to
// match.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 180200
NSString *UIWritingToolsCoordinatorTextAnimationDebugDescription(UIWritingToolsCoordinatorTextAnimation animationType)
{
    return CharonAnimationDescription(animationType);
}
#else
NSString *UIWritingToolsCoordinatorTextAnimationDebugDescription(NSInteger animationType)
{
    return CharonAnimationDescription(animationType);
}
#endif
