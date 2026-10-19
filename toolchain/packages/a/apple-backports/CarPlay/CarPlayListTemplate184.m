#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlayTemplate.h"

@implementation CPListTemplate (RevenantListTemplate184)

- (BOOL)showsSpinnerWhileEmpty
{
    return [self revenant_showsSpinnerWhileEmpty];
}

- (void)setShowsSpinnerWhileEmpty:(BOOL)showsSpinnerWhileEmpty
{
    [self revenant_setShowsSpinnerWhileEmpty:showsSpinnerWhileEmpty];
}

@end
