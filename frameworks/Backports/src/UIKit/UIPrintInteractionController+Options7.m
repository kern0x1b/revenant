#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char RevenantPrintCopiesKey;
static const char RevenantPrintPaperKey;

@implementation UIPrintInteractionController (RevenantOptions7)

- (BOOL)showsNumberOfCopies
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantPrintCopiesKey);
    return stored ? stored.boolValue : YES;
}

- (void)setShowsNumberOfCopies:(BOOL)showsNumberOfCopies
{
    if (!showsNumberOfCopies)
        revenant_menus_say_once(@"print-copies", @"UIPrintInteractionController.showsNumberOfCopies: the iOS 6 print panel always shows the copies stepper, so NO is kept and read back and the panel is shown as before");
    objc_setAssociatedObject(self, &RevenantPrintCopiesKey, @(showsNumberOfCopies), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)showsPaperSelectionForLoadedPapers
{
    return [objc_getAssociatedObject(self, &RevenantPrintPaperKey) boolValue];
}

- (void)setShowsPaperSelectionForLoadedPapers:(BOOL)showsPaperSelectionForLoadedPapers
{
    if (showsPaperSelectionForLoadedPapers)
        revenant_menus_say_once(@"print-paper", @"UIPrintInteractionController.showsPaperSelectionForLoadedPapers: the iOS 6 print panel decides by itself when to show paper selection, so YES is kept and read back and the panel is shown as before");
    objc_setAssociatedObject(self, &RevenantPrintPaperKey, @(showsPaperSelectionForLoadedPapers), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
