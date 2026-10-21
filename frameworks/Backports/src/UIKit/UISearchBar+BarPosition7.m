#import "RevenantBarPosition.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantSearchBackgroundsKey;

static void revenant_apply_search_background(UISearchBar *bar)
{
    UIBarPosition position = bar.barPosition;
    BOOL prompted = bar.prompt.length > 0;
    UIImage *image = revenant_effective_background(bar, &RevenantSearchBackgroundsKey, position, prompted ? UIBarMetricsDefaultPrompt : UIBarMetricsDefault);
    if (image || objc_getAssociatedObject(bar, &RevenantSearchBackgroundsKey))
        bar.backgroundImage = image;
}

@implementation UISearchBar (RevenantBarPosition7)

- (UIBarPosition)barPosition
{
    return revenant_bar_position(self, UIBarPositionTop);
}

- (void)setBackgroundImage:(UIImage *)backgroundImage forBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics
{
    revenant_store_background(self, &RevenantSearchBackgroundsKey, backgroundImage, barPosition, barMetrics);
    revenant_apply_search_background(self);
}

- (UIImage *)backgroundImageForBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics
{
    return revenant_stored_background(self, &RevenantSearchBackgroundsKey, barPosition, barMetrics);
}

@end
