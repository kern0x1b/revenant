#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

static NSString *RevenantAnimationDescription(NSInteger animationType)
{
    switch (animationType) {
    case 0: return @"Awaiting-new-text animation";
    case 1: return @"Text removal animation";
    case 2: return @"Text insertion animation";
    }
    return @"Unknown text animation";
}

NSString *BACKPORT_IMPL(UIWritingToolsCoordinatorTextAnimationDebugDescription)(UIWritingToolsCoordinatorTextAnimation animationType)
{
    return RevenantAnimationDescription(animationType);
}
