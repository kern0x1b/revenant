#import "RevenantBarPosition.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantNavigationBackgroundsKey;

@implementation UINavigationBar (RevenantBarPosition7)

- (UIBarPosition)barPosition
{
    return revenant_bar_position(self, UIBarPositionTop);
}

- (void)setBackgroundImage:(UIImage *)backgroundImage forBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics
{
    revenant_store_background(self, &RevenantNavigationBackgroundsKey, backgroundImage, barPosition, barMetrics);
    [self setBackgroundImage:revenant_effective_background(self, &RevenantNavigationBackgroundsKey, self.barPosition, barMetrics) forBarMetrics:barMetrics];
}

- (UIImage *)backgroundImageForBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics
{
    return revenant_stored_background(self, &RevenantNavigationBackgroundsKey, barPosition, barMetrics);
}

@end
