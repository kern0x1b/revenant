#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlayTemplate.h"

@implementation CPListTemplate (CharonListTemplate184)

- (BOOL)showsSpinnerWhileEmpty
{
    return [self charon_showsSpinnerWhileEmpty];
}

- (void)setShowsSpinnerWhileEmpty:(BOOL)showsSpinnerWhileEmpty
{
    [self charon_setShowsSpinnerWhileEmpty:showsSpinnerWhileEmpty];
}

@end
