#import <UIKit/UIKit.h>

@protocol UIUserActivityRestoring <NSObject>

@optional

- (void)restoreUserActivityState:(NSUserActivity *)activity;

@end

static void revenant_emit_UIUserActivityRestoring(void)
{
    (void)@protocol(UIUserActivityRestoring);
}