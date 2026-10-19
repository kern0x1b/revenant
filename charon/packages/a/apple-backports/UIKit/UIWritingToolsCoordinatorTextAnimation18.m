#import <UIKit/UIKit.h>

static NSString *CharonAnimationDescription(NSInteger animationType)
{
    switch (animationType) {
    case 0: return @"Awaiting-new-text animation";
    case 1: return @"Text removal animation";
    case 2: return @"Text insertion animation";
    }
    return @"Unknown text animation";
}

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
